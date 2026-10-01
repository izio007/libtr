"""Validate declared check links in captured bytes before submission."""
from check_mapping import parse_mapping, validate_definition
from pathlib import Path
from artifact_registry import local
from provenance_snapshot import digest


def validate(snapshot, manifest, mapping_path, request):
    base = (Path(snapshot) / 'inputs').resolve()
    entries = {}
    for item in manifest['inputs']:
        if item['path'] in entries:
            raise ValueError('Duplicate snapshot input')
        entries[item['path']] = item['sha256']

    def read(name):
        if name not in entries:
            raise ValueError('Required check input not captured: ' + str(name))
        content = local(base, name).read_bytes()
        if digest(content) != entries[name]:
            raise ValueError('Damaged check input: ' + name)
        return content

    if request.get('action') != 'unit' or not request.get('test'):
        raise ValueError('Check mapping requires targeted unit request')
    rows = parse_mapping(read(mapping_path))
    seen = set()
    for row in rows:
        name, criterion = row['name'], row['criterion']
        seen.add(name)
        validate_definition(read(row['definition']), criterion)
        read(row['source'])
    if request['test'] not in seen:
        raise ValueError('Requested check is not mapped')
    return dict(state='PASS', mapping=mapping_path, mapping_sha256=entries[mapping_path])