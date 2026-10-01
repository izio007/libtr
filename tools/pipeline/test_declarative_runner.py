import json
from pathlib import Path
import tempfile
import unittest
from declarative_runner import load_config


class ConfigTests(unittest.TestCase):
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