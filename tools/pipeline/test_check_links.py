import json
from pathlib import Path
import tempfile
import unittest
from check_links import build
from provenance_snapshot import digest, encoded


class CheckLinksTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        (self.root/'criterion.md').write_text('@CRITERION C-1: example\n')
        (self.root/'test.m').write_text('test')
        self.mapping = dict(schema_version=1, checks=[dict(name='test', criterion='C-1', definition='criterion.md', source='test.m')])
        self.rows = [dict(name='test', state='passed', error='')]

    def run_build(self):
        path = 'runtime/pipeline/run/unit_results.json'
        target = self.root/path
        target.parent.mkdir(parents=True, exist_ok=True)
        content = encoded(self.rows)
        target.write_bytes(content)
        registry = dict(schema_version=1, run_id='run', artifacts=[dict(path=path, size=len(content), sha256=digest(content))])
        (self.root/'runtime/registry.json').write_bytes(encoded(registry))
        (self.root/'mapping.json').write_bytes(encoded(self.mapping))
        return build(self.root, self.root/'runtime/registry.json', self.root/'mapping.json')

    def test_status_not_propagated(self):
        link = self.run_build()['links'][0]
        self.assertEqual(link['test_status'], 'PASS')
        self.assertEqual(link['criterion_status'], 'NOT_RUN')
        self.rows = []
        self.assertEqual(self.run_build()['links'][0]['test_status'], 'NOT_RUN')

    def test_failed_and_unmapped(self):
        self.rows = [dict(name='test', state='failed', error='failure'), dict(name='other', state='passed')]
        output = self.run_build()
        self.assertEqual(output['links'][0]['error'], 'failure')
        self.assertEqual(output['links'][0]['test_status'], 'FAILED')
        self.assertEqual(output['unmapped_results'], ['other'])

    def test_ambiguous_definition(self):
        (self.root/'criterion.md').write_text('@CRITERION C-1: a\n@CRITERION C-1: b\n')
        with self.assertRaises(ValueError):
            self.run_build()

    def test_duplicate_or_unknown_results(self):
        for rows in [self.rows*2, [dict(name='test', state='invented')]]:
            self.rows = rows
            with self.assertRaises(ValueError):
                self.run_build()

    def test_tampering_rejected(self):
        self.run_build()
        (self.root/'runtime/pipeline/run/unit_results.json').write_text('[]')
        with self.assertRaises(ValueError):
            build(self.root, self.root/'runtime/registry.json', self.root/'mapping.json')

    def snapshot(self):
        self.run_build()
        folder = self.root/'runtime/snapshot'
        (folder/'inputs').mkdir(parents=True)
        entries = []
        for name in ('mapping.json', 'criterion.md', 'test.m'):
            data = (self.root/name).read_bytes()
            (folder/'inputs'/name).write_bytes(data)
            entries.append(dict(path=name, sha256=digest(data)))
        raw = encoded(dict(schema_version=1, inputs=entries))
        (folder/'manifest.json').write_bytes(raw)
        registry_path = self.root/'runtime/registry.json'
        registry = json.loads(registry_path.read_bytes())
        registry['input_manifest_sha256'] = digest(raw)
        registry_path.write_bytes(encoded(registry))
        return folder

    def test_snapshot_match_and_change(self):
        folder = self.snapshot()
        def linked():
            return build(self.root, self.root/'runtime/registry.json', self.root/'mapping.json', folder)
        output = linked()
        self.assertEqual(output['mapping_version'], 'MATCH')
        self.assertEqual(output['links'][0]['definition_version'], 'MATCH')
        (self.root/'criterion.md').write_text('@CRITERION C-1: changed\n')
        self.assertEqual(linked()['links'][0]['definition_version'], 'CHANGED')
        self.assertEqual(linked()['links'][0]['criterion_status'], 'NOT_RUN')
        (folder/'inputs/test.m').write_text('damage')
        with self.assertRaises(ValueError):
            linked()

    def test_unrelated_snapshot_rejected(self):
        folder = self.snapshot()
        (folder/'manifest.json').write_bytes(b'{}')
        with self.assertRaises(ValueError):
            build(self.root, self.root/'runtime/registry.json', self.root/'mapping.json', folder)


if __name__ == '__main__':
    unittest.main()