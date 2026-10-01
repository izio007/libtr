"""Independent fixtures for TRACE-001..004; no MATLAB server required."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

from traceability_builder import affected, build, compare, publish


class TraceabilityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'spec.md').write_text('abc', encoding='utf-8')
        self.manifest = dict(schema_version=1, nodes=[
            dict(id='R', kind='requirement', path='spec.md'),
            dict(id='C', kind='check', path='spec.md')], edges=[
                dict(source='C', target='R', relation='verifies')])

    def test_invalid_inputs(self):
        variants = []
        duplicate = copy.deepcopy(self.manifest)
        duplicate['nodes'].append(duplicate['nodes'][0])
        variants.append(duplicate)
        for field, value in [('target', 'missing'), ('relation', 'unknown')]:
            item = copy.deepcopy(self.manifest)
            item['edges'][0][field] = value
            variants.append(item)
        for field, value in [('kind', 'unknown'), ('path', '../escape'),
                             ('path', 'absent.md')]:
            item = copy.deepcopy(self.manifest)
            item['nodes'][0][field] = value
            variants.append(item)
        for item in variants:
            with self.subTest(item=item), self.assertRaises((ValueError, OSError)):
                build(self.root, item)

    def test_determinism_hash_and_no_pass(self):
        graph = build(self.root, self.manifest)
        self.manifest['nodes'].reverse()
        self.assertEqual(graph, build(self.root, self.manifest))
        self.assertEqual(graph['nodes'][0]['sha256'],
                         'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')
        self.assertEqual(graph['verification_status'], 'NOT_RUN')

    def test_removed_link_and_cycle(self):
        old = build(self.root, self.manifest)
        new = dict(edges=[])
        self.assertEqual(affected(old, new, ['R']),
                         dict(ancestors=['R'], dependents=['C', 'R']))
        old['edges'].append(dict(source='R', target='C', relation='depends'))
        self.assertEqual(affected(old, new, ['R'])['ancestors'], ['C', 'R'])

    def test_diff_removed_node_preserves_dependents(self):
        old = build(self.root, self.manifest)
        new = copy.deepcopy(old)
        new['nodes'] = [n for n in new['nodes'] if n['id'] != 'R']
        new['edges'] = []
        result = compare(old, new)
        self.assertEqual(result['removed'], ['R'])
        self.assertEqual(result['dependents'], ['C', 'R'])
        self.assertEqual(result['edges_removed'], [('C', 'R', 'verifies')])

    def test_diff_move_content_kind_and_relation(self):
        old = build(self.root, self.manifest)
        new = copy.deepcopy(old)
        new['nodes'][0]['path'] = 'moved.md'
        self.assertEqual(compare(old, new)['moved'], ['C'])
        self.assertEqual(compare(old, new)['changed'], [])
        new['nodes'][0]['kind'] = 'implementation'
        self.assertEqual(compare(old, new)['changed'], ['C'])
        new['nodes'][1]['sha256'] = '0' * 64
        self.assertEqual(compare(old, new)['changed'], ['C', 'R'])
        new['edges'][0]['relation'] = 'depends'
        self.assertEqual(compare(old, new)['edges_added'], [('C', 'R', 'depends')])

    def test_diff_identical_reordered_and_added(self):
        old = build(self.root, self.manifest)
        new = copy.deepcopy(old)
        new['nodes'].reverse()
        self.assertTrue(all(not value for value in compare(old, new).values()))
        new['nodes'].append(dict(id='N', kind='requirement', path='spec.md', sha256='0'*64))
        self.assertEqual(compare(old, new)['added'], ['N'])

    def test_diff_invalid_previous(self):
        graph = build(self.root, self.manifest)
        for change in ('version', 'duplicate', 'orphan'):
            old = copy.deepcopy(graph)
            if change == 'version':
                old['schema_version'] = 2
            elif change == 'duplicate':
                old['nodes'].append(old['nodes'][0])
            else:
                old['edges'][0]['source'] = 'absent'
            with self.subTest(change=change), self.assertRaises(ValueError):
                compare(old, graph)

    def test_publication_no_overwrite_or_escape(self):
        graph = build(self.root, self.manifest)
        output = self.root / 'runtime' / 'graph.json'
        publish(self.root, output, graph)
        self.assertEqual(json.loads(output.read_text(encoding='utf-8')), graph)
        before = output.read_bytes()
        with self.assertRaises(FileExistsError):
            publish(self.root, output, {})
        self.assertEqual(output.read_bytes(), before)
        with self.assertRaises(ValueError):
            publish(self.root, self.root / 'forbidden.json', graph)


if __name__ == '__main__':
    unittest.main()