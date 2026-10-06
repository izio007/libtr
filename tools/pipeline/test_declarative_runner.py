import json
from pathlib import Path
import tempfile
import unittest
import importlib.util
import re
import hashlib
from declarative_runner import load_config


class ConfigTests(unittest.TestCase):
    def test_filter_release_gate(self):
        root = Path(__file__).resolve().parents[2]
        spec = importlib.util.spec_from_file_location('acceptance', root/'tools/filter2win_acceptance.py')
        gate = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(gate)
        with tempfile.TemporaryDirectory() as tmp:
            package = Path(tmp)
            (package/'results').mkdir()
            artifact = package/'kernel.m'
            artifact.write_text('original')
            report = dict(package_version='0.2.0', status='PASS', new_server=True)
            self.assertEqual(gate.evaluate(package, report)['status'], 'NOT_RUN')
            review = dict(schema_version=1, package_version='0.2.0',
                          candidate_sha256=gate.fingerprint(package),
                          checks={name: dict(status='PASS', reviewer='test fixture',
                                             evidence='synthetic evidence', criterion='fixture')
                                  for name in gate.REQUIRED})
            path = package/'results/release_review.json'
            def save():
                path.write_text(json.dumps(review))
            save()
            self.assertTrue(gate.evaluate(package, report)['release_accepted'])
            self.assertEqual(gate.evaluate(package, report), gate.evaluate(package, report))
            report['new_server'] = False
            with self.assertRaises(ValueError):
                gate.evaluate(package, report)
            report['new_server'] = True
            review['checks']['pdf_visual']['status'] = 'FAILED'
            save()
            self.assertEqual(gate.evaluate(package, report)['status'], 'FAILED')
            review['checks']['pdf_visual']['reviewer'] = ''
            save()
            with self.assertRaises(ValueError):
                gate.evaluate(package, report)
            review['checks']['pdf_visual']['reviewer'] = 'test fixture'
            save()
            artifact.write_text('changed')
            with self.assertRaises(ValueError):
                gate.evaluate(package, report)

    def test_filter_source_inventory(self):
        root = Path(__file__).resolve().parents[2]
        inventory = json.loads((root/'proposals/filter2win_source_inventory.json').read_text(encoding='utf-8'))
        entries = inventory['entries']
        self.assertEqual(len(entries), len({entry['source'] for entry in entries}))
        for entry in entries:
            self.assertRegex(entry['source_sha256'], r'^[0-9a-f]{64}$')
            self.assertIn(entry['decision'], ('identical', 'adapted', 'excluded_historical_reference',
                                             'superseded_verification', 'superseded_schema1_document'))
            if entry['target']:
                target = root/entry['target']
                self.assertTrue(target.is_file(), entry['target'])
                if entry['decision'] == 'identical':
                    self.assertEqual(hashlib.sha256(target.read_bytes()).hexdigest(), entry['source_sha256'])
        kernels = [e for e in entries if e['source'].startswith('matlab/function/')]
        self.assertEqual(len(kernels), 8)
        self.assertTrue(all(e['decision'] in ('identical', 'adapted') for e in kernels))

    def test_filter_package_schema3_closure(self):
        root = Path(__file__).resolve().parents[2]
        spec = importlib.util.spec_from_file_location('package_filter2win', root/'tools/package_filter2win.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.assertEqual(len(module.FILES), len(set(module.FILES)))
        for name in module.FILES:
            self.assertTrue((root/name).is_file(), name)
        functions = set(module.PRODUCTION)
        for name in functions:
            relative = 'matlab/function/' + name + '.m'
            self.assertIn(relative, module.FILES)
            text = (root/relative).read_text(encoding='utf-8')
            references = set(re.findall(r'\b(filter2win_[a-z_]+|fifo_double)\s*\(', text))
            self.assertFalse(references - functions)
        cfg = json.loads((root/'matlab/tests/configs/filter2win_config.json').read_text())
        self.assertEqual(cfg['schema_version'], 3)
        legacy = json.loads((root/'matlab/tests/configs/filter2win_schema2_config.json').read_text())
        self.assertEqual(legacy['schema_version'], 2)
        rules = cfg['rules']
        self.assertEqual(len(rules), len({r['priority'] for r in rules}))
        self.assertEqual(len(rules), len({r['name'] for r in rules}))
        text = (root/'matlab/function/filter2win_persistent.m').read_text()
        events = set(re.findall(r"'([A-Z_]+)'", text))
        self.assertFalse({r['event'] for r in rules} - events)
        handlers = set()
        for group, single in re.findall(r'case\s+(?:\{([0-9, ]+)\}|(\d+))', text):
            handlers.update(map(int, re.findall(r'\d+', group or single)))
        expected = set(range(9)) | set(range(10, 16))
        self.assertEqual(handlers, expected)
        fixture = json.loads((root/'matlab/tests/configs/filter2win_schema3_cases.json').read_text())
        self.assertEqual(set(fixture['required_statuses']), expected)
        case = json.loads((root/'matlab/tests/configs/filter2win_package_case.json').read_text())
        self.assertEqual(set(case['production_functions']), functions)
        self.assertIn('matlab/tests/configs/'+case['filter_config'], module.FILES)
        for name in case['checks']:
            self.assertIn('matlab/tests/'+name+'.m', module.FILES)
        isolation = json.loads((root/'matlab/tests/configs/filter2win_isolation.json').read_text())
        self.assertFalse(set(isolation['files']) - set(module.FILES))
        for name in isolation['checks']:
            self.assertIn('matlab/tests/'+name+'.m', isolation['files'])

    def test_filter_scenario_declaration(self):
        root = Path(__file__).resolve().parents[2]
        folder = root / 'matlab/tests/configs'
        spec = json.loads((folder / 'filter2win_observations.json').read_text())
        count = (spec['end_time'] - spec['start_time']) / spec['time_step'] + 1
        self.assertEqual(count, spec['expected_samples'])
        self.assertGreater(spec['time_step'], 0)
        self.assertGreater(spec['rmse_tolerance'], 0)
        self.assertLess(spec['missing_open_interval'][0], spec['missing_open_interval'][1])
        for start, end, level in spec['plateaus']:
            self.assertLessEqual(start, end)
            self.assertIsInstance(level, (int, float))
        config, _ = load_config(folder / 'filter2win_consumers_runner.json')
        self.assertEqual(config['suite'], 'filter2win_consumers')

    def test_valid(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = root/'matlab/tests/configs/test.json'
            path.parent.mkdir(parents=True)
            path.write_text('{"schema_version":1,"suite":"matmul3","timeout_seconds":10}')
            cfg, digest = load_config(path, root)
            self.assertEqual(cfg['suite'], 'matmul3')
            self.assertEqual(len(digest), 64)

    def test_rejections(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = root/'matlab/tests/configs/test.json'
            path.parent.mkdir(parents=True)
            for text in ('{}', '[]', '{"suite":1,"suite":2}',
                         json.dumps(dict(schema_version=1, suite='eval', timeout_seconds=10)),
                         json.dumps(dict(schema_version=1, suite='matmul3', timeout_seconds=True))):
                path.write_text(text)
                with self.assertRaises(ValueError):
                    load_config(path, root)
            with self.assertRaises(ValueError):
                load_config(root/'outside.json', root)
