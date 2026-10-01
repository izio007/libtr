"""Standard-library JSON Lines client. Exit 0 only for a passed job."""
import argparse
import json
import socket
import time
import uuid
import hashlib
from pathlib import Path

from provenance_attempt import accompanied


def exchange(request, port=5555, timeout=30):
    with socket.create_connection(('127.0.0.1', port), timeout) as connection:
        connection.sendall((json.dumps(request) + '\n').encode('utf-8'))
        with connection.makefile('rb') as stream:
            line = stream.readline(4 * 1024 * 1024)
        if not line.endswith(b'\n'):
            raise RuntimeError('Incomplete or oversized response')
        response = json.loads(line)
        if not response['ok']:
            raise RuntimeError(response['error'])
        return response


def run_job(request, port, timeout):
    print(json.dumps(exchange(request, port), ensure_ascii=False), flush=True)
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            response = exchange(dict(v=1, op='status', id=request['id']), port,
                                timeout=min(30, max(0.1, deadline-time.monotonic())))
        except (TimeoutError, socket.timeout):
            # Retry only status; never submit again after uncertain delivery.
            continue
        if response['report']['state'] not in ('queued', 'running'):
            print(json.dumps(response, ensure_ascii=False, indent=2))
            return response
        time.sleep(1)
    raise TimeoutError(f"Client deadline exceeded; job {request['id']} is NOT cancelled")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['all', 'environment', 'unit', 'integration', 'png', 'documents', 'liveeditor', 'mapping', 'mapping5000'])
    parser.add_argument('--port', type=int, default=5555)
    parser.add_argument('--id', default=uuid.uuid4().hex)
    parser.add_argument('--timeout', type=float, default=600)
    parser.add_argument('--test', help='One unit_test_* name, without extension')
    parser.add_argument('--test-sha256', help='Expected SHA-256 of selected test, or current')
    parser.add_argument('--provenance-spec', type=Path)
    parser.add_argument('--provenance-output', type=Path)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--git', default='git')
    args = parser.parse_args()
    if args.test is not None and args.action != 'unit':
        parser.error('--test requires action unit')
    if bool(args.provenance_spec) != bool(args.provenance_output):
        parser.error('Both provenance options are required')
    request = dict(v=1, op='submit', id=args.id, action=args.action)
    if args.test is not None:
        request['test'] = args.test
    if args.test_sha256:
        if not args.test or args.action != 'unit':
            parser.error('--test-sha256 requires targeted unit test')
        import re
        if not re.fullmatch(r'unit_test_[A-Za-z0-9_]+', args.test):
            parser.error('Invalid test name')
        value = args.test_sha256
        if value == 'current':
            value = hashlib.sha256((args.root/'matlab/tests'/(args.test+'.m')).read_bytes()).hexdigest()
        if not re.fullmatch(r'[0-9a-f]{64}', value):
            parser.error('Expected lowercase SHA-256 or current')
        request['test_sha256'] = value
    clean = True
    if args.provenance_spec:
        response, clean = accompanied(args.root, args.provenance_spec,
                                      args.provenance_output, request,
                                      lambda: run_job(request, args.port, args.timeout), args.git)
    else:
        response = run_job(request, args.port, args.timeout)
    return 0 if clean and response['report']['state'] == 'passed' else 1


if __name__ == '__main__':
    raise SystemExit(main())