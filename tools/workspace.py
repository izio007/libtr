"""Small noninteractive workspace operations; run with Cygwin Python for commits."""
import argparse
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def git(root, *args):
    env = dict(os.environ, GIT_PAGER='cat', GIT_TERMINAL_PROMPT='0',
               GIT_LITERAL_PATHSPECS='1')
    return subprocess.run(['git', '--no-pager', '-C', str(root), *args],
                          env=env, check=True, capture_output=True,
                          text=True, encoding='utf-8').stdout.strip()


def paths(root, names):
    result = []
    for name in names:
        path = Path(name)
        path = path if path.is_absolute() else root / path
        path = path.resolve()
        rel = path.relative_to(root)
        if not rel.parts or rel.parts[0] in ('.git', 'runtime') or path.is_dir():
            raise ValueError('Expected a source file: ' + name)
        result.append(rel.as_posix())
    return result


def check(root, names):
    files = paths(root, names)
    for name in files:
        path = root / name
        if path.exists():
            text = path.read_text(encoding='utf-8', errors='strict')
            if '\ufffd' in text:
                raise ValueError('Replacement character: ' + name)
    git(root, 'diff', '--check', '--', *files)
    git(root, 'diff', '--cached', '--check', '--', *files)
    return files


def commit(root, names, task, status):
    if sys.platform != 'cygwin':
        raise ValueError('Commit requires Cygwin Python')
    if git(root, 'diff', '--cached', '--name-only'):
        raise ValueError('Index is not empty; preserve staged work')
    files = check(root, names)
    git(root, 'add', '--', *files)
    git(root, 'diff', '--cached', '--check', '--', *files)
    # Literal pathspecs prevent wildcard filenames from selecting other files.
    git(root, 'commit', '-m', f'{task}, {status}', '--', *files)
    return git(root, 'log', '-1', '--format=%h %s')


def tree(root, depth):
    def visit(folder, level):
        for item in sorted(folder.iterdir(), key=lambda p: p.name.lower()):
            if item.name in ('.git', 'runtime', '__pycache__'):
                continue
            print('  ' * level + item.name + ('/' if item.is_dir() else ''))
            if item.is_dir() and not item.is_symlink() and level + 1 < depth:
                visit(item, level + 1)
    visit(root, 0)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    sub = parser.add_subparsers(dest='action', required=True)
    sub.add_parser('status')
    t = sub.add_parser('tree')
    t.add_argument('--depth', type=int, choices=range(1, 5), default=2)
    for action in ('check', 'commit'):
        p = sub.add_parser(action)
        p.add_argument('files', nargs='+')
        if action == 'commit':
            p.add_argument('--task', required=True)
            p.add_argument('--status', choices=('NOT_RUN', 'PASS', 'FAILED'), required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    # Apply literal pathspec handling to every git invocation, including tests.
    os.environ['GIT_LITERAL_PATHSPECS'] = '1'
    try:
        if args.action == 'tree':
            tree(root, args.depth)
        elif args.action == 'status':
            print(git(root, 'status', '--short') or 'CLEAN')
        elif args.action == 'check':
            print(f'[CHECK PASS] {len(check(root, args.files))} files')
        else:
            print(commit(root, args.files, args.task, args.status))
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(getattr(error, 'stderr', None) or str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())