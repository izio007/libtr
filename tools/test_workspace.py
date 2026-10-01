import tempfile
import unittest
from pathlib import Path
from workspace import check, commit, git, paths


class WorkspaceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        git(self.root, 'init')
        git(self.root, 'config', 'user.name', 'Workspace test')
        git(self.root, 'config', 'user.email', 'test@example.invalid')
        git(self.root, 'config', 'commit.gpgsign', 'false')
        (self.root / 'base.txt').write_text('base\n', encoding='utf-8')
        git(self.root, 'add', 'base.txt')
        git(self.root, 'commit', '-m', 'fixture')

    def test_selected_commit(self):
        (self.root / 'chosen.txt').write_text('chosen\n', encoding='utf-8')
        (self.root / 'other.txt').write_text('other\n', encoding='utf-8')
        result = commit(self.root, ['chosen.txt'], 'Selected', 'PASS')
        self.assertIn('Selected, PASS', result)
        self.assertEqual(git(self.root, 'status', '--short'), '?? other.txt')

    def test_staged_work_preserved(self):
        (self.root / 'other.txt').write_text('other\n', encoding='utf-8')
        git(self.root, 'add', 'other.txt')
        with self.assertRaises(ValueError):
            commit(self.root, ['base.txt'], 'Blocked', 'NOT_RUN')
        self.assertEqual(git(self.root, 'diff', '--cached', '--name-only'), 'other.txt')

    def test_validation(self):
        for name in ('../outside.txt', 'runtime/log.txt', '.git/config'):
            with self.assertRaises(ValueError):
                paths(self.root, [name])
        (self.root / 'bad.txt').write_bytes(b'\xff')
        with self.assertRaises(UnicodeError):
            check(self.root, ['bad.txt'])

    def test_literal_filename(self):
        (self.root / '[a].txt').write_text('literal\n', encoding='utf-8')
        (self.root / 'a.txt').write_text('unrelated\n', encoding='utf-8')
        commit(self.root, ['[a].txt'], 'Literal', 'PASS')
        self.assertEqual(git(self.root, 'status', '--short'), '?? a.txt')


if __name__ == '__main__':
    unittest.main()