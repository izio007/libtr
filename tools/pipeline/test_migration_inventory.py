"""Inventory fixture: signatures, hashes, reference boundaries, no moves."""
import tempfile
from pathlib import Path
import unittest

from migration_inventory import inventory


class InventoryTests(unittest.TestCase):
    def test_inventory_preserves_files_and_distinguishes_theory(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            matlab = root / 'matlab'
            matlab.mkdir()
            (matlab / 'foo.m').write_text('function y = foo(x)\ny=x;\n', encoding='utf-8')
            (matlab / 'foo_theory.m').write_text('% description', encoding='utf-8')
            (matlab / 'tests').mkdir()
            (matlab / 'tests' / 'test.m').write_text('foo(1); foobar(2);', encoding='utf-8')
            before = {p: p.read_bytes() for p in matlab.rglob('*') if p.is_file()}
            report = inventory(root)
            self.assertEqual(report['files'][0]['proposed_target'], 'matlab/function/foo.m')
            self.assertEqual(report['files'][0]['textual_references'], ['matlab/tests/test.m'])
            self.assertIsNone(report['files'][1]['proposed_target'])
            self.assertEqual(before, {p: p.read_bytes() for p in matlab.rglob('*') if p.is_file()})


if __name__ == '__main__':
    unittest.main()