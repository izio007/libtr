import json
import unittest
from check_mapping import parse_mapping, validate_definition


class MappingTests(unittest.TestCase):
    def test_valid(self):
        row = dict(name='test', criterion='C-1', definition='a.md', source='t.m')
        self.assertEqual(parse_mapping(json.dumps(dict(schema_version=1, checks=[row]))), [row])
        validate_definition(b'@CRITERION C-1: description\n', 'C-1')

    def test_invalid_tables(self):
        row = dict(name='test', criterion='C-1', definition='a.md', source='t.m')
        for rows in ([], {}, [None], [row, row], [dict(row, criterion='bad id')],
                     [dict(row, source='')], [dict(row, name=4)]):
            with self.subTest(rows=rows), self.assertRaises(ValueError):
                parse_mapping(json.dumps(dict(schema_version=1, checks=rows)))

    def test_definition(self):
        for raw in (b'', b'@CRITERION OTHER: x', b'@CRITERION C-1: a\n@CRITERION C-1: b'):
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                validate_definition(raw, 'C-1')