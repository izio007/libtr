"""Shared mapping syntax; callers own byte provenance and path policy."""
import json
import re


def parse_mapping(raw):
    table = json.loads(raw)
    if not isinstance(table, dict) or table.get('schema_version') != 1:
        raise ValueError('Unsupported check mapping')
    rows = table.get('checks')
    if not isinstance(rows, list) or not rows:
        raise ValueError('Expected nonempty checks')
    seen = set()
    for row in rows:
        if not isinstance(row, dict) or any(
                not isinstance(row.get(key), str) or not row[key]
                for key in ('name', 'criterion', 'definition', 'source')):
            raise ValueError('Invalid check row')
        if row['name'] in seen or not re.fullmatch(r'[A-Za-z0-9_-]+', row['criterion']):
            raise ValueError('Duplicate check or invalid criterion')
        seen.add(row['name'])
    return rows


def validate_definition(content, criterion):
    ids = re.findall(r'^@CRITERION\s+([A-Za-z0-9_-]+)\s*:',
                     content.decode('utf-8'), re.M)
    if ids.count(criterion) != 1:
        raise ValueError('Missing or ambiguous criterion: ' + criterion)