"""Build a deterministic graph from explicit links; never infer verification."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import tempfile


KINDS = {'contract', 'requirement', 'implementation', 'check', 'result'}
RELATIONS = {'derives', 'depends', 'implements', 'verifies', 'evidence'}


def build(root, manifest):
    root = Path(root).resolve()
    if manifest.get('schema_version') != 1:
        raise ValueError('Unsupported schema_version')
    nodes = {}
    for node in manifest['nodes']:
        ident = node['id']
        if not isinstance(ident, str) or not ident.strip() or ident in nodes:
            raise ValueError('Empty or duplicate ID')
        if node['kind'] not in KINDS:
            raise ValueError('Unknown node kind')
        relative = Path(node['path'])
        path = (root / relative).resolve()
        if relative.is_absolute() or not path.is_relative_to(root):
            raise ValueError('Path escapes root')
        nodes[ident] = dict(id=ident, kind=node['kind'],
                            path=path.relative_to(root).as_posix(),
                            sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    edges = set()
    for edge in manifest['edges']:
        source, target, relation = edge['source'], edge['target'], edge['relation']
        if source not in nodes or target not in nodes:
            raise ValueError('Unknown edge endpoint')
        if relation not in RELATIONS:
            raise ValueError('Unknown relation')
        key = (source, target, relation)
        if key in edges:
            raise ValueError('Duplicate edge')
        edges.add(key)
    return dict(schema_version=1, coverage='explicit_only',
                verification_status='NOT_RUN',
                nodes=[nodes[key] for key in sorted(nodes)],
                edges=[dict(source=s, target=t, relation=r)
                       for s, t, r in sorted(edges)])


def affected(old, new, seeds):
    """Trace both directions independently over the union, including removed links."""
    forward, reverse = {}, {}
    for graph in (old, new):
        for edge in graph['edges']:
            s, t = edge['source'], edge['target']
            forward.setdefault(s, set()).add(t)
            reverse.setdefault(t, set()).add(s)

    def walk(adjacency):
        visited = set(seeds)
        pending = list(visited)
        while pending:
            for node in adjacency.get(pending.pop(), ()):
                if node not in visited:
                    visited.add(node)
                    pending.append(node)
        return sorted(visited)

    return dict(ancestors=walk(forward), dependents=walk(reverse))


def compare(old, new):
    """Conservative structural diff; no claim of semantic equivalence."""
    def index(graph):
        if graph.get('schema_version') != 1:
            raise ValueError('Unsupported graph version')
        nodes = {}
        for node in graph['nodes']:
            ident = node['id']
            if not isinstance(ident, str) or not ident or ident in nodes:
                raise ValueError('Invalid or duplicate graph ID')
            if node['kind'] not in KINDS:
                raise ValueError('Unknown graph kind')
            if not isinstance(node['path'], str) or not isinstance(node['sha256'], str):
                raise ValueError('Invalid graph node')
            nodes[ident] = node
        edges = set()
        for edge in graph['edges']:
            key = (edge['source'], edge['target'], edge['relation'])
            if key[0] not in nodes or key[1] not in nodes or key[2] not in RELATIONS:
                raise ValueError('Invalid graph edge')
            if key in edges:
                raise ValueError('Duplicate graph edge')
            edges.add(key)
        return nodes, edges

    before, before_edges = index(old)
    after, after_edges = index(new)
    added = sorted(after.keys() - before.keys())
    removed = sorted(before.keys() - after.keys())
    shared = before.keys() & after.keys()
    changed = sorted(i for i in shared if any(
        before[i][k] != after[i][k] for k in ('kind', 'sha256')))
    moved = sorted(i for i in shared if before[i]['path'] != after[i]['path'])
    edges_added = sorted(after_edges - before_edges)
    edges_removed = sorted(before_edges - after_edges)
    seeds = set(added + removed + changed + moved)
    for source, target, _ in edges_added + edges_removed:
        seeds.update((source, target))
    return dict(added=added, removed=removed, changed=changed, moved=moved,
                edges_added=edges_added, edges_removed=edges_removed,
                seeds=sorted(seeds), **affected(old, new, seeds))


def publish(root, output, graph):
    runtime = (Path(root).resolve() / 'runtime').resolve()
    output = Path(output).resolve()
    if not output.is_relative_to(runtime) or output == runtime:
        raise ValueError('Output must be inside runtime')
    output.parent.mkdir(parents=True, exist_ok=True)
    data = json.dumps(graph, ensure_ascii=False, sort_keys=True, indent=2) + '\n'
    name = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', newline='\n',
                                         dir=output.parent, delete=False) as stream:
            name = stream.name
            stream.write(data)
        # Atomic create without replacing user artifacts on the same filesystem.
        os.link(name, output)
    finally:
        if name is not None:
            os.unlink(name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('manifest', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--previous', type=Path)
    args = parser.parse_args()
    if args.manifest.resolve().is_relative_to((args.root.resolve() / 'runtime').resolve()):
        parser.error('Manifest must be a primary source outside runtime')
    graph = build(args.root, json.loads(args.manifest.read_text(encoding='utf-8')))
    if args.previous:
        previous = json.loads(args.previous.read_text(encoding='utf-8'))
        graph['impact'] = compare(previous, graph)
    publish(args.root, args.output, graph)


if __name__ == '__main__':
    main()