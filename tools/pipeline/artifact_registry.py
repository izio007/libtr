"""External inventory of reported job artifacts; not execution attestation."""
import argparse
import json
from pathlib import Path
import re

from provenance_snapshot import digest
from traceability_builder import publish


def local(root, name):
    if not isinstance(name, str) or '\\' in name:
        raise ValueError('Expected relative POSIX path')
    p = Path(name)
    resolved = (root / p).resolve()
    if p.is_absolute() or '..' in p.parts or not resolved.is_relative_to(root):
        raise ValueError('Path escapes artifact root')
    return resolved


def build(root, attempt_path):
    root = Path(root).resolve()
    attempt_path = Path(attempt_path).resolve()
    if not attempt_path.is_relative_to(root / 'runtime'):
        raise ValueError('Attempt must be inside runtime')
    attempt_bytes = attempt_path.read_bytes()
    attempt = json.loads(attempt_bytes)
    request = attempt['request']
    ident = request['id']
    if not isinstance(ident, str) or not re.fullmatch(r'[A-Za-z0-9_-]+', ident):
        raise ValueError('Invalid run ID')
    response = attempt['server_response']
    if not response or not response.get('ok'):
        raise ValueError('No successful server response')
    job = local(root, 'runtime/pipeline/' + ident)
    report_bytes = (job / 'report.json').read_bytes()
    report = json.loads(report_bytes)
    if report['state'] not in ('passed', 'failed', 'interrupted'):
        raise ValueError('Job is not terminal')
    for field in ('id', 'action', 'state'):
        if report[field] != response['report'][field]:
            raise ValueError('Response/report mismatch')
    saved_request = json.loads((job / 'request.json').read_bytes())
    for field in ('id', 'action', 'test'):
        if saved_request.get(field) != request.get(field):
            raise ValueError('Request mismatch')
    if report['id'] != ident or report['action'] != request['action']:
        raise ValueError('Report identity mismatch')
    manifest_bytes = (attempt_path.parent / 'manifest.json').read_bytes()
    if digest(manifest_bytes) != attempt['input_manifest_sha256']:
        raise ValueError('Manifest hash mismatch')
    names = report['artifacts']
    if not isinstance(names, list) or not all(isinstance(n, str) for n in names):
        raise ValueError('Invalid artifact list')
    if len(set(names)) != len(names):
        raise ValueError('Duplicate artifact')
    entries = []
    for name in sorted(set(names) | {'request.json', 'report.json'}):
        path = local(job, name)
        content = path.read_bytes()
        if name == 'report.json' and content != report_bytes:
            raise ValueError('Report changed during inventory')
        entries.append(dict(path=path.relative_to(root).as_posix(),
                            size=len(content), sha256=digest(content)))
    return dict(schema_version=1, run_id=ident, applicability='UNCONFIRMED',
                coverage='reported_only', git_sha=json.loads(manifest_bytes)['git_sha'],
                input_manifest_sha256=digest(manifest_bytes),
                attempt_sha256=digest(attempt_bytes), artifacts=entries)


def verify(root, registry):
    root = Path(root).resolve()
    problems = []
    for item in registry['artifacts']:
        path = local(root, item['path'])
        try:
            content = path.read_bytes()
            if len(content) != item['size'] or digest(content) != item['sha256']:
                problems.append(dict(path=item['path'], reason='changed'))
        except FileNotFoundError:
            problems.append(dict(path=item['path'], reason='missing'))
    return problems


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('attempt', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    registry = build(args.root, args.attempt)
    job = args.root.resolve() / 'runtime' / 'pipeline' / registry['run_id']
    if args.output.resolve().is_relative_to(job):
        parser.error('Registry must be outside job directory')
    publish(args.root, args.output, registry)


if __name__ == '__main__':
    main()