"""Capture explicit inputs; never claim they were executed by MATLAB."""
import argparse
import hashlib
import json
from pathlib import Path
import platform
import subprocess


def encoded(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + '\n').encode('utf-8')


def digest(data):
    return hashlib.sha256(data).hexdigest()


def inputs(root, specification):
    root = Path(root).resolve()
    if specification.get('schema_version') != 1 or not specification.get('inputs'):
        raise ValueError('Expected nonempty schema_version=1 inputs')
    result = {}
    for item in specification['inputs']:
        relative = Path(item['path'])
        path = (root / relative).resolve()
        if (relative.is_absolute() or not path.is_relative_to(root)
                or path.is_relative_to(root / 'runtime')):
            raise ValueError('Input must be a primary source inside root')
        name = path.relative_to(root).as_posix()
        if name in result or not isinstance(item['role'], str) or not item['role'].strip():
            raise ValueError('Duplicate input or empty role')
        result[name] = (item['role'], path.read_bytes())
    return result


def capture(root, specification, output, git='git'):
    root = Path(root).resolve()
    output = Path(output).resolve()
    if not output.is_relative_to(root / 'runtime') or output == root / 'runtime':
        raise ValueError('Output must be below runtime')
    data = inputs(root, specification)
    def command(*args):
        return subprocess.check_output([git, '-C', str(root), *args]).decode('utf-8').strip()
    revision = command('rev-parse', 'HEAD')
    dirty = bool(command('status', '--porcelain', '--untracked-files=all'))
    output.mkdir(parents=True, exist_ok=False)
    entries = []
    for name, (role, content) in sorted(data.items()):
        target = output / 'inputs' / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
        entries.append(dict(path=name, role=role, sha256=digest(content)))
    manifest = dict(schema_version=1, git_sha=revision, dirty=dirty,
                    inputs=entries, coverage='explicit_only',
                    collector_environment=dict(python=platform.python_version(), platform=platform.platform()),
                    execution_status='NOT_RUN', verification_status='NOT_RUN',
                    loaded_code_identity='unconfirmed')
    payload = encoded(manifest)
    (output / 'manifest.sha256').write_text(digest(payload) + '\n', encoding='ascii')
    # Completion marker is written last; failed captures are not complete snapshots.
    (output / 'manifest.json').write_bytes(payload)
    return manifest


def changed_inputs(root, manifest):
    changed = []
    for item in manifest['inputs']:
        path = Path(root) / item['path']
        try:
            same = digest(path.read_bytes()) == item['sha256']
        except FileNotFoundError:
            same = False
        if not same:
            changed.append(item['path'])
    return sorted(changed)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('specification', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--git', default='git')
    args = parser.parse_args()
    if args.specification.resolve().is_relative_to(args.root.resolve() / 'runtime'):
        parser.error('Specification must be outside runtime')
    capture(args.root, json.loads(args.specification.read_text(encoding='utf-8')), args.output, args.git)


if __name__ == '__main__':
    main()