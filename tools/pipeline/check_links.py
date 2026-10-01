"""Join declared criteria to historical test rows without granting criterion PASS."""
import argparse
import json
from pathlib import Path
import re

from artifact_registry import local, verify
from check_mapping import parse_mapping, validate_definition
from provenance_snapshot import digest
from traceability_builder import publish


def build(root, registry_path, mapping_path, snapshot=None):
    root = Path(root).resolve()
    mapping_path = Path(mapping_path).resolve()
    if not mapping_path.is_relative_to(root) or mapping_path.is_relative_to(root/'runtime'):
        raise ValueError('Mapping must be a primary source')
    raw_registry = Path(registry_path).read_bytes()
    registry = json.loads(raw_registry)
    if registry.get('schema_version') != 1 or verify(root, registry):
        raise ValueError('Invalid or changed artifact registry')
    captured = {}
    if snapshot is not None:
        snapshot = Path(snapshot).resolve()
        raw_manifest = (snapshot/'manifest.json').read_bytes()
        if digest(raw_manifest) != registry.get('input_manifest_sha256'):
            raise ValueError('Snapshot does not match registry')
        manifest = json.loads(raw_manifest)
        if manifest.get('schema_version') != 1:
            raise ValueError('Unsupported snapshot')
        for entry in manifest['inputs']:
            name = entry['path']
            if name in captured:
                raise ValueError('Duplicate snapshot path')
            captured[name] = entry['sha256']

    def version(path, content):
        if snapshot is None:
            return 'UNCONFIRMED'
        name = path.relative_to(root).as_posix()
        if name not in captured:
            return 'NOT_CAPTURED'
        saved = local((snapshot/'inputs').resolve(), name).read_bytes()
        if digest(saved) != captured[name]:
            raise ValueError('Snapshot bytes damaged')
        return 'MATCH' if digest(content) == captured[name] else 'CHANGED'
    run_id = registry['run_id']
    if not re.fullmatch(r'[A-Za-z0-9_-]+', run_id):
        raise ValueError('Invalid run ID')
    expected = 'runtime/pipeline/' + run_id + '/unit_results.json'
    matches = [a for a in registry['artifacts'] if a['path'] == expected]
    if len(matches) != 1:
        raise ValueError('Expected one registered unit_results.json')
    raw_results = local(root, expected).read_bytes()
    if digest(raw_results) != matches[0]['sha256']:
        raise ValueError('Results changed during reading')
    results = json.loads(raw_results)
    if isinstance(results, dict):
        results = [results]
    states = {'passed': 'PASS', 'failed': 'FAILED', 'not_run': 'NOT_RUN'}
    by_name = {}
    for row in results:
        if row['name'] in by_name or row['state'] not in states:
            raise ValueError('Duplicate result or unknown state')
        by_name[row['name']] = row
    raw_mapping = mapping_path.read_bytes()
    rows = parse_mapping(raw_mapping)
    links, seen = [], set()
    for item in rows:
        name, criterion = item['name'], item['criterion']
        seen.add(name)
        definition = local(root, item['definition'])
        source = local(root, item['source'])
        if definition.is_relative_to(root/'runtime') or source.is_relative_to(root/'runtime'):
            raise ValueError('Definitions and code must be primary sources')
        definition_bytes, source_bytes = definition.read_bytes(), source.read_bytes()
        validate_definition(definition_bytes, criterion)
        row = by_name.get(name)
        links.append(dict(item, test_status=states[row['state']] if row else 'NOT_RUN',
                          error=row.get('error', '') if row else '', criterion_status='NOT_RUN',
                          definition_version=version(definition, definition_bytes),
                          source_version=version(source, source_bytes),
                          definition_sha256=digest(definition_bytes), source_sha256=digest(source_bytes)))
    return dict(schema_version=1, run_id=run_id, applicability='UNCONFIRMED',
                mapping_sha256=digest(raw_mapping), registry_sha256=digest(raw_registry),
                mapping_version=version(mapping_path, raw_mapping),
                results_sha256=digest(raw_results), links=links,
                unmapped_results=sorted(set(by_name)-seen))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('root', 'registry', 'mapping', 'output'):
        parser.add_argument(name, type=Path)
    parser.add_argument('--snapshot', type=Path)
    args = parser.parse_args()
    publish(args.root, args.output, build(args.root, args.registry, args.mapping, args.snapshot))


if __name__ == '__main__':
    main()