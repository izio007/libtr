"""Build an explicit, versioned filter2win source candidate, never a false release."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
FILES = (
    'matlab/function/filter2win.m',
    'matlab/function/fifo_double.m',
    'matlab/tests/unit_test_filter2win.m',
    'matlab/tests/unit_test_fifo_double.m',
    'matlab/tests/configs/fifo_double_cases.json',
    'matlab/tests/configs/filter2win_package_case.json',
    'matlab/tests/run_filter2win_package.m',
    'docs/filter2win_theory.md',
    'docs/fifo_double_theory.md',
)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def build(version, destination):
    """Keep source bytes traceable and all outputs inside a new destination."""
    if not re.fullmatch(r'\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?', version):
        raise ValueError('Expected a semantic version')
    destination.mkdir(parents=True, exist_ok=False)
    package = destination / ('filter2win-' + version)
    package.mkdir()
    origins = {}
    for relative in FILES:
        source = ROOT / relative
        target = package / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        text = source.read_text(encoding='utf-8')
        if source.suffix == '.m':
            text = f'% filter2win package version: {version}\n' + text
        elif source.suffix == '.md':
            text = f'<!-- filter2win package version: {version} -->\n' + text
        # Test JSON has an existing schema; version is in the manifest.
        target.write_text(text, encoding='utf-8')
        origins[relative] = digest(source)

    # Reuse the repository exporter, but redirect every output into staging.
    spec = importlib.util.spec_from_file_location('filter2win_doc_export', ROOT / 'tools/docs/translate_docs.py')
    exporter = importlib.util.module_from_spec(spec)
    sys.dont_write_bytecode = True
    spec.loader.exec_module(exporter)
    exporter.ROOT = package
    exporter.DOCS = package / 'docs'
    for folder in ('html', 'liveeditor'):
        (exporter.DOCS / folder).mkdir()
    for name in ('filter2win', 'fifo_double'):
        exporter.build(exporter.DOCS / (name + '_theory.md'))
        live = exporter.DOCS / 'liveeditor' / (name + '_theory.m')
        live.write_text(f'% filter2win package version: {version}\n' + live.read_text(encoding='utf-8'), encoding='utf-8')
        html = exporter.DOCS / 'html' / (name + '.html')
        text = html.read_text(encoding='utf-8')
        text = text.replace('<!DOCTYPE html>\n', f'<!DOCTYPE html><!-- filter2win package version: {version} -->\n', 1)
        html.write_text(text, encoding='utf-8')
    assets = exporter.DOCS / 'html/assets'
    assets.mkdir()
    shutil.copyfile(ROOT / 'docs/html/assets/tex-svg.js', assets / 'tex-svg.js')

    results = package / 'results'
    results.mkdir()
    write_json(results / 'acceptance.json', {
        'package_version': version,
        'status': 'NOT_RUN',
        'release_accepted': False,
        'checks': {name: 'NOT_RUN' for name in (
            'matlab_tests', 'isolated_server', 'dependency_closure',
            'readability_review', 'html_visual_review', 'pdf_export',
            'mlx_export', 'png_generation')},
        'missing_required_formats': ['PDF', 'MLX', 'PNG'],
        'note': 'Source candidate only. Existing project test results were not reused.',
    })
    (package / 'README.md').write_text(
        f'<!-- filter2win package version: {version} -->\n'
        '# filter2win — source candidate, NOT_RUN\n\n'
        'This is not an accepted release. PDF, MLX, PNG and executed test evidence\n'
        'are not yet available. See results/acceptance.json.\n\n'
        'Production code consists of filter2win.m and fifo_double.m.\n'
        'No positioning algorithms or 30/450 km datasets are included.\n'
        'Runtime isolation has not been demonstrated.\n\n'
        'HTML uses the bundled MathJax asset. Live Editor .m is a text source,\n'
        'not a binary .mlx. JSON and third-party MathJax retain their original\n'
        'format/header; their package version is recorded in manifest.json.\n'
        'The transitional minimum-window requirements remain unresolved.\n', encoding='utf-8')
    commit = subprocess.check_output(['git', '--no-pager', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip()
    manifest = {'package_version': version, 'source_commit': commit,
                'source_dirty': bool(subprocess.check_output(
                    ['git', '--no-pager', '-C', str(ROOT), 'status', '--porcelain'], text=True).strip()),
                'status': 'NOT_RUN', 'files': []}
    for path in sorted(package.rglob('*')):
        if path.is_file():
            relative = path.relative_to(package).as_posix()
            manifest['files'].append({'path': relative, 'package_version': version,
                                      'size': path.stat().st_size, 'sha256': digest(path),
                                      'source_sha256': origins.get(relative)})
    write_json(package / 'manifest.json', manifest)
    archive = destination / ('filter2win-' + version + '-candidate.zip')
    with zipfile.ZipFile(archive, 'x', compression=zipfile.ZIP_DEFLATED) as output:
        for path in sorted(package.rglob('*')):
            if path.is_file():
                output.write(path, path.relative_to(destination).as_posix())
    unpacked = destination / 'verification'
    with zipfile.ZipFile(archive) as output:
        if output.testzip() is not None:
            raise ValueError('Archive integrity failure')
        output.extractall(unpacked)
    restored = unpacked / package.name
    for entry in manifest['files']:
        if digest(restored / entry['path']) != entry['sha256']:
            raise ValueError('Extracted hash mismatch: ' + entry['path'])
    write_json(destination / 'build_report.json', {
        'package_version': version, 'archive': archive.name,
        'sha256': digest(archive), 'manifest_sha256': digest(package / 'manifest.json'),
        'archive_integrity': 'PASS', 'extracted_file_hashes': 'PASS',
        'release_acceptance': 'NOT_RUN', 'file_count': len(manifest['files']) + 1,
    })
    print(f'Candidate built: {archive}; archive integrity PASS; acceptance NOT_RUN')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--version', required=True)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    build(args.version, args.output.resolve())