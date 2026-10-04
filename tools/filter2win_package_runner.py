"""Run the extracted filter2win suite through its dedicated localhost server."""
import json
from pathlib import Path
import sys
import time
import uuid
sys.path.insert(0, str(Path(__file__).resolve().parent / 'pipeline'))
from engine import exchange, run_job


def main():
    root = Path(__file__).resolve().parents[1]
    if sys.argv[1:] == ['--ping']:
        print(json.dumps(exchange(dict(v=1, op='ping'))))
        return
    config = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
    if config != {'schema_version': 1, 'suite': 'filter2win_package', 'timeout_seconds': 600}:
        raise ValueError('Unexpected registered configuration')
    host = exchange(dict(v=1, op='ping'))
    # Cygwin and Windows use different path syntax; compare with cygpath on Cygwin.
    host_root = host.get('package_root', '')
    if sys.platform == 'cygwin':
        import subprocess
        host_root = subprocess.check_output(['cygpath', '-u', host_root], text=True).strip()
    if Path(host_root).resolve() != root or host.get('active') or host.get('queued'):
        raise RuntimeError('Wrong or busy package server')
    started = time.monotonic()
    job = uuid.uuid4().hex
    reply = run_job(dict(v=1, op='submit', id=job, suite=config['suite']),
                    timeout=config['timeout_seconds'])
    if reply['report']['state'] != 'passed':
        raise RuntimeError(reply['report'])
    print(f'[SUITE PASS] Executed 1/1 checks successfully. Execution time: {time.monotonic()-started:.2f}s.')


if __name__ == '__main__':
    main()