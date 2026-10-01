"""Seal an executed filter2win package without claiming pending visual acceptance."""
import argparse
import json
from pathlib import Path
import zipfile
from package_filter2win import digest, write_json


def finalize(package, destination):
    report = json.loads((package / 'results/matlab_results.json').read_text(encoding='utf-8'))
    if report['status'] != 'PASS':
        raise ValueError('A passing package execution is required')
    version = report['package_version']
    for name in ('filter2win', 'fifo_double'):
        pdf = package / 'docs' / (name + '.pdf')
        if not pdf.read_bytes().startswith(b'%PDF-'):
            raise ValueError('Invalid PDF signature')
        mlx = package / 'docs/liveeditor' / (name + '_theory.mlx')
        with zipfile.ZipFile(mlx) as archive:
            if archive.testzip() is not None or 'matlab/document.xml' not in archive.namelist():
                raise ValueError('Invalid MLX container')
    for name in ('trajectory', 'window'):
        if not (package / 'results' / (name + '.png')).read_bytes().startswith(b'\x89PNG\r\n\x1a\n'):
            raise ValueError('Invalid PNG signature')
    core = sorted(p.name for p in (package / 'matlab/function').glob('*.m'))
    if core != ['fifo_double.m', 'filter2win.m']:
        raise ValueError('Unexpected production dependency')
    acceptance = {
        'package_version': version, 'status': 'NOT_RUN', 'release_accepted': False,
        'matlab_execution': 'PASS', 'isolated_path': 'PASS',
        'formats_present': ['MATLAB', 'JSON', 'MD', 'HTML', 'PDF', 'MLX', 'PNG', 'MAT'],
        'png_visual_review': 'PASS', 'document_visual_review': 'NOT_RUN',
        'new_server': False, 'production_files': core,
        'limitations': ['Existing server with isolated path, not a new process',
                        'Minimum-window transition requirements remain open',
                        'Zero-allocation is not measured',
                        'Complete readability and document visual audit pending'],
    }
    write_json(package / 'results/acceptance.json', acceptance)
    (package / 'README.md').write_text(
        f'<!-- filter2win package version: {version} -->\n'
        '# filter2win — executed package\n\n'
        'Includes MATLAB implementation, FIFO, tests, JSON data, MD, PDF, HTML,\n'
        'Live Editor MLX and M, actual test results, PNG and plot data.\n'
        'Tests and exports passed on R2025a with only MATLAB and extracted-package\n'
        'paths available. The existing server was used; no fresh-process claim.\n'
        'No LLS/WLLS/GN/GNP kernels or 30/450 km datasets are included.\n\n'
        'For local reproduction in a dedicated MATLAB session, restoredefaultpath,\n'
        'remove user/custom paths, change to the extracted package root, add only\n'
        'matlab/function and matlab/tests, then call run_filter2win_package.\n'
        'Agent execution in libtr remains through tools/runner.sh and the registered\n'
        'filter2win_package suite, whose adapter performs this isolation.\n\n'
        'See results/acceptance.json for open acceptance items. Documentation visual\n'
        'review and a fresh-server run are pending; this is not full release PASS.\n'
        'Binary formats carry version in document/plot content and manifest, not an\n'
        'invalid prefix. Third-party MathJax and strict test JSON retain their headers.\n', encoding='utf-8')
    manifest = json.loads((package / 'manifest.json').read_text(encoding='utf-8'))
    previous = {entry['path']: entry for entry in manifest['files']}
    manifest['files'] = []
    manifest['execution'] = 'PASS'
    for path in sorted(package.rglob('*')):
        if path.is_file() and path.name != 'manifest.json':
            relative = path.relative_to(package).as_posix()
            manifest['files'].append(dict(path=relative, package_version=version,
                size=path.stat().st_size, sha256=digest(path),
                source_sha256=previous.get(relative, {}).get('source_sha256')))
    write_json(package / 'manifest.json', manifest)
    destination.mkdir(parents=True, exist_ok=False)
    target = destination / ('filter2win-' + version + '.zip')
    with zipfile.ZipFile(target, 'x', compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(package.rglob('*')):
            if path.is_file():
                archive.write(path, package.name + '/' + path.relative_to(package).as_posix())
    with zipfile.ZipFile(target) as archive:
        assert archive.testzip() is None
        archive.extractall(destination / 'verification')
    extracted = destination / 'verification' / package.name
    for entry in manifest['files']:
        assert digest(extracted / entry['path']) == entry['sha256']
    write_json(destination / 'archive_report.json', dict(package_version=version,
        archive=str(target), sha256=digest(target), file_count=len(manifest['files']) + 1,
        archive_integrity='PASS', extracted_hashes='PASS', execution='PASS',
        release_acceptance='NOT_RUN'))
    print(target)
    print('SHA256 ' + digest(target))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--package', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    finalize(args.package.resolve(), args.output.resolve())