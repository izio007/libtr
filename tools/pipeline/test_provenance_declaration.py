"""Check explicit local Python imports, not runtime dependency completeness."""
import ast
import json
from pathlib import Path
import unittest


def missing_local_imports(root, declaration):
    declared = {entry['path'] for entry in declaration['inputs']}
    missing = set()
    for name in declared:
        source = root / name
        if source.suffix != '.py':
            continue
        for node in ast.walk(ast.parse(source.read_text(encoding='utf-8'))):
            if isinstance(node, ast.Import):
                modules = [alias.name for alias in node.names]
            elif isinstance(node, ast.ImportFrom) and node.level == 0:
                modules = [node.module] if node.module else []
            else:
                continue
            for module in modules:
                candidate = source.parent / (module.replace('.', '/') + '.py')
                if candidate.is_file():
                    relative = candidate.relative_to(root).as_posix()
                    if relative not in declared:
                        missing.add(relative)
    return sorted(missing)


class DeclarationTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(__file__).resolve().parents[2]
        self.spec = json.loads((self.root / 'tools/pipeline/provenance_matmul3_inputs.json').read_bytes())

    def test_explicit_local_imports_captured(self):
        self.assertEqual(missing_local_imports(self.root, self.spec), [])

    def test_missing_validator_detected(self):
        self.spec['inputs'] = [entry for entry in self.spec['inputs']
                               if entry['path'] != 'tools/pipeline/check_mapping.py']
        self.assertIn('tools/pipeline/check_mapping.py', missing_local_imports(self.root, self.spec))