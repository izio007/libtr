import json
from pathlib import Path
import tempfile
import unittest

from artifact_registry import build, verify
from provenance_snapshot import digest, encoded
from traceability_builder import publish


class RegistryTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.job = self.root/'runtime/pipeline/job'
        self.job.mkdir(parents=True)
        self.folder = self.root/'runtime/attempt'
        self.folder.mkdir()
        self.request = dict(id='job', action='unit', test='unit_test_example')
        self.report = dict(id='job', action='unit', state='passed', artifacts=['data.bin'])
        self.write(self.job/'request.json', self.request)
        self.write(self.job/'report.json', self.report)
        (self.job/'data.bin').write_bytes(b'abc')
        content = encoded(dict(git_sha='a'*40))
        (self.folder/'manifest.json').write_bytes(content)
        self.attempt = dict(request=self.request, input_manifest_sha256=digest(content),
                            server_response=dict(ok=True, report=self.report))
        self.write(self.folder/'attempt.json', self.attempt)

    def write(self, path, value):
        path.write_bytes(encoded(value))

    def build(self):
        return build(self.root, self.folder/'attempt.json')

    def test_hash_change_missing_and_no_overwrite(self):
        registry = self.build()
        self.assertEqual(verify(self.root, registry), [])
        self.assertEqual(registry['applicability'], 'UNCONFIRMED')
        row = next(x for x in registry['artifacts'] if x['path'].endswith('data.bin'))
        self.assertEqual(row['sha256'], 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')
        output = self.root/'runtime/registry.json'
        publish(self.root, output, registry)
        with self.assertRaises(FileExistsError):
            publish(self.root, output, registry)
        (self.job/'data.bin').write_bytes(b'xyz')
        self.assertEqual(verify(self.root, registry)[0]['reason'], 'changed')
        (self.job/'data.bin').unlink()
        self.assertEqual(verify(self.root, registry)[0]['reason'], 'missing')

    def test_bad_paths_duplicates_and_absent(self):
        for names in [['../escape'], ['/absolute'], ['data.bin','data.bin'], ['absent']]:
            self.report['artifacts'] = names
            self.write(self.job/'report.json', self.report)
            with self.subTest(names=names), self.assertRaises((ValueError, OSError)):
                self.build()

    def test_identity_and_manifest(self):
        self.write(self.job/'request.json', dict(self.request, test='another'))
        with self.assertRaises(ValueError):
            self.build()
        self.write(self.job/'request.json', self.request)
        (self.folder/'manifest.json').write_bytes(b'{}')
        with self.assertRaises(ValueError):
            self.build()

    def test_nonterminal_or_different_response(self):
        for state in ['running', 'failed']:
            self.write(self.job/'report.json', dict(self.report, state=state))
            with self.subTest(state=state), self.assertRaises(ValueError):
                self.build()


if __name__ == '__main__':
    unittest.main()