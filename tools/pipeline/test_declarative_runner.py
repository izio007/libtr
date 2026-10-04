import json
from pathlib import Path
import tempfile
import unittest
import importlib.util
import re
from declarative_runner import load_config


class ConfigTests(unittest.TestCase):
    def test_filter_package_schema2_closure(self):
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
        self.assertEqual(cfg['schema_version'], 2)
        rules = cfg['rules']
        self.assertEqual(len(rules), len({r['priority'] for r in rules}))
        self.assertEqual(len(rules), len({r['name'] for r in rules}))
        text = (root/'matlab/function/filter2win_features.m').read_text()
        events = set(re.findall(r'^\s*e\.([A-Z_]+)\s*=', text, re.M))
        self.assertFalse({r['event'] for r in rules} - events)
        text = (root/'matlab/function/filter2win.m').read_text()
        handlers = set(map(int, re.findall(r'^\s*case\s+(\d+)\b', text, re.M)))
        self.assertEqual(handlers, set(range(17)))
        case = json.loads((root/'matlab/tests/configs/filter2win_package_case.json').read_text())
        self.assertEqual(set(case['production_functions']), functions)
        self.assertIn('matlab/tests/configs/'+case['filter_config'], module.FILES)
        for name in case['checks']:
            self.assertIn('matlab/tests/'+name+'.m', module.FILES)

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