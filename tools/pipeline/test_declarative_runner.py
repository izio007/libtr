import json
from pathlib import Path
import tempfile
import unittest
from declarative_runner import load_config


class ConfigTests(unittest.TestCase):
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