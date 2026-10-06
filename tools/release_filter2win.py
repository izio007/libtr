"""One-command release orchestration; existing stages, stdlib and common engine."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/pipeline'))
from engine import Pipeline
from package_filter2win import build
from finalize_filter2win import finalize
from filter2win_acceptance import evaluate


def windows(path):
    if sys.platform == 'cygwin':
        return subprocess.check_output(['cygpath', '-w', str(path)], text=True).strip()
    return str(path)


def release(config):
    destination = Path(config['output']).resolve()
    if destination.exists():
        raise ValueError('Output exists; select a new destination, never overwrite a release')
    package = Path(config['package']).resolve() if config.get('package') else (
        Path(config['staging']).resolve() / 'verification' / ('filter2win-' + config['version']))
    if config.get('package') and not package.is_dir():
        raise ValueError('Existing package not found')
    if not config.get('package') and not config.get('allow_host_replacement'):
        raise ValueError('Fresh execution requires explicit host replacement permission')
    pipeline = Pipeline(ROOT, dict(config, suite='filter2win_release'),
                        hashlib.sha256(json.dumps(config, sort_keys=True).encode()).hexdigest())

    def build_stage():
        build(config['version'], Path(config['staging']).resolve())
        return dict(package=str(package))

    def execute_stage():
        subprocess.run(['powershell.exe', '-NoProfile', '-NonInteractive', '-File',
                        windows(ROOT/'tools/invoke_filter2win_acceptance.ps1'),
                        '-Package', windows(package)], check=True)
        return json.loads((package/'results/matlab_results.json').read_text(encoding='utf-8'))

    def gate_stage():
        report = json.loads((package/'results/matlab_results.json').read_text(encoding='utf-8'))
        if report['package_version'] != config['version']:
            raise ValueError('Package version mismatch')
        if report['status'] != 'PASS':
            raise ValueError('Package execution has not passed')
        return evaluate(package, report)

    def seal_stage():
        finalize(package, destination)
        return json.loads((destination/'archive_report.json').read_text(encoding='utf-8'))

    stages = []
    if not config.get('package'):
        stages.append(('build_documents', build_stage))
    if config.get('allow_host_replacement'):
        stages.append(('fresh_matlab', execute_stage))
    stages.extend([('review_gate', gate_stage), ('seal_verify', seal_stage)])
    pipeline.run(stages)
    result = gate_stage()
    print(json.dumps(dict(archive=str(destination/('filter2win-'+config['version']+'.zip')),
                         release_status=result['status'], remaining=result['remaining'],
                         execution_report=str(pipeline.folder/'report.json')), ensure_ascii=False))
    return 0 if result['status'] == 'PASS' else 2


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--version', required=True)
    parser.add_argument('--output', required=True)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument('--staging', help='New staging directory: build and execute')
    source.add_argument('--package', help='Existing tested package: no rebuild')
    parser.add_argument('--allow-host-replacement', action='store_true')
    sys.exit(release(vars(parser.parse_args())))