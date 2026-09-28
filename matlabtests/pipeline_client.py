"""Standard-library JSON Lines client. Exit 0 only for a passed job."""
import argparse
import json
import socket
import time
import uuid


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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['all', 'environment', 'unit', 'integration', 'png', 'documents', 'liveeditor'])
    parser.add_argument('--port', type=int, default=5555)
    parser.add_argument('--id', default=uuid.uuid4().hex)
    parser.add_argument('--timeout', type=float, default=600)
    args = parser.parse_args()
    request = dict(v=1, op='submit', id=args.id, action=args.action)
    print(json.dumps(exchange(request, args.port), ensure_ascii=False), flush=True)
    deadline = time.monotonic() + args.timeout
    while time.monotonic() < deadline:
        try:
            response = exchange(dict(v=1, op='status', id=args.id), args.port,
                                timeout=min(30, max(0.1, deadline-time.monotonic())))
        except (TimeoutError, socket.timeout):
            # A cooperative MATLAB calculation may temporarily delay callbacks.
            # Retry only the read-only status request, never resubmit the job.
            continue
        if response['report']['state'] not in ('queued', 'running'):
            print(json.dumps(response, ensure_ascii=False, indent=2))
            return 0 if response['report']['state'] == 'passed' else 1
        time.sleep(1)
    raise TimeoutError(f'Client deadline exceeded; job {args.id} is NOT cancelled')


if __name__ == '__main__':
    raise SystemExit(main())