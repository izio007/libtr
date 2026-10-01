import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from provenance_snapshot import capture, changed_inputs, digest, encoded, inputs


class SnapshotTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        (self.root / 'source.m').write_bytes(b'abc')
        self.spec = dict(schema_version=1, inputs=[dict(path='source.m', role='kernel')])

    def capture(self, dirty=b' M source.m\n'):
        with patch('provenance_snapshot.platform.platform', return_value='test-platform'), \
                patch('provenance_snapshot.subprocess.check_output', side_effect=[b'a'*40+b'\n', dirty]):
            return capture(self.root, self.spec, self.root/'runtime'/'run')

    def test_snapshot_and_changes(self):
        m = self.capture()
        self.assertTrue(m['dirty'])
        self.assertEqual(m['git_sha'], 'a'*40)
        self.assertEqual(m['execution_status'], 'NOT_RUN')
        self.assertEqual(m['loaded_code_identity'], 'unconfirmed')
        self.assertEqual(changed_inputs(self.root, m), [])
        (self.root/'source.m').write_bytes(b'new')
        self.assertEqual(changed_inputs(self.root, m), ['source.m'])
        self.assertEqual((self.root/'runtime/run/inputs/source.m').read_bytes(), b'abc')
        (self.root/'source.m').unlink()
        self.assertEqual(changed_inputs(self.root, m), ['source.m'])

    def test_hash_and_no_overwrite(self):
        m = self.capture(b'')
        self.assertFalse(m['dirty'])
        folder = self.root/'runtime/run'
        self.assertEqual(json.loads((folder/'manifest.json').read_bytes()), m)
        self.assertEqual((folder/'manifest.sha256').read_text().strip(), digest(encoded(m)))
        with self.assertRaises(FileExistsError):
            self.capture()

    def test_invalid_inputs(self):
        for field, value in [('path', '../outside'), ('path', 'runtime/x'),
                             ('path', 'missing'), ('role', ''), ('path', str(self.root/'source.m'))]:
            spec = copy.deepcopy(self.spec)
            spec['inputs'][0][field] = value
            with self.subTest(value=value), self.assertRaises((ValueError, OSError)):
                inputs(self.root, spec)
        spec = copy.deepcopy(self.spec)
        spec['inputs'] *= 2
        with self.assertRaises(ValueError):
            inputs(self.root, spec)

    def test_serialization(self):
        self.assertEqual(encoded(dict(b=2, a=1)), encoded(dict(a=1, b=2)))


if __name__ == '__main__':
    unittest.main()