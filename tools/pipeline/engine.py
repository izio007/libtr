"""Small sequential pipeline and bounded JSON-lines transport; stdlib only."""
import json
import os
from pathlib import Path
import socket
import tempfile
import time
import traceback
import uuid


def exchange(request, port=5555, timeout=30):
    with socket.create_connection(('127.0.0.1', port), timeout) as connection:
        connection.sendall((json.dumps(request) + '\n').encode('utf-8'))
        with connection.makefile('rb') as stream:
            line = stream.readline(4 * 1024 * 1024)
    if not line.endswith(b'\n'):
        raise RuntimeError('Incomplete or oversized response')
    response = json.loads(line)
    if not response.get('ok'):
        raise RuntimeError(response.get('error', 'Invalid response'))
    return response


def run_job(request, port=5555, timeout=600, *, transport=None,
            clock=time.monotonic, sleep=time.sleep):
    """Submit once; retry only status timeouts. Never stop the shared host."""
    transport = transport or exchange
    deadline = clock() + timeout

    def call(message):
        remaining = deadline - clock()
        if remaining <= 0:
            raise TimeoutError('Deadline exceeded; job not confirmed cancelled: ' + request['id'])
        return transport(message, port=port, timeout=min(30, remaining))

    try:
        response = call(request)
    except (OSError, RuntimeError) as error:
        raise RuntimeError('Submission unconfirmed; do not resubmit job ' +
                           request['id'] + ': ' + str(error)) from error
    while response.get('report', {}).get('state', 'queued') in ('queued', 'running'):
        remaining = deadline - clock()
        if remaining <= 0:
            raise TimeoutError('Deadline exceeded; job not confirmed cancelled: ' + request['id'])
        sleep(min(0.2, remaining))
        try:
            response = call(dict(v=1, op='status', id=request['id']))
        except TimeoutError:
            if clock() >= deadline:
                raise TimeoutError('Deadline exceeded; job not confirmed cancelled: ' + request['id'])
    return response


def write_json(path, value):
    """Atomic report replacement; no half-written state after interruption."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8',
                                         dir=path.parent, delete=False) as stream:
            temporary = stream.name
            json.dump(value, stream, ensure_ascii=False, indent=2)
            stream.write('\n')
        os.replace(temporary, path)
    finally:
        if temporary and os.path.exists(temporary):
            os.unlink(temporary)


class Pipeline:
    """Explicit stage state and fail-fast execution; handlers own their work."""

    def __init__(self, root, config, config_hash):
        self.root = Path(root)
        self.id = uuid.uuid4().hex
        self.folder = self.root / 'runtime/pipeline_runs' / self.id
        self.report = dict(id=self.id, status='NOT_RUN', config=config,
                           config_sha256=config_hash, stages=[])

    def run(self, stages):
        names = [name for name, _ in stages]
        if not names or len(names) != len(set(names)):
            raise ValueError('Pipeline requires unique nonempty stages')
        self.report['stages'] = [dict(id=name, status='NOT_RUN') for name in names]
        path = self.folder / 'report.json'
        write_json(path, self.report)
        for record, (_, handler) in zip(self.report['stages'], stages):
            started = time.monotonic()
            try:
                record['result'] = handler()
                record['status'] = 'PASS'
            except (Exception, KeyboardInterrupt) as error:
                record['status'] = self.report['status'] = 'FAILED'
                frames = traceback.extract_tb(error.__traceback__)
                location = dict(file=frames[-1].filename, line=frames[-1].lineno) if frames else None
                defect = dict(status='FAILED', test_id=record['id'], location=location,
                              condition='Stage must complete', failure_reason=str(error),
                              expected=None, actual=type(error).__name__,
                              memory_snapshot=dict(config=self.report['config'],
                                                   rng=None, inputs=None, state=None),
                              pipeline_id=self.id)
                defect_path = self.root / 'runtime/defects' / ('defect_' + self.id + '.json')
                defect_path.parent.mkdir(parents=True, exist_ok=True)
                with defect_path.open('x', encoding='utf-8') as stream:
                    json.dump(defect, stream, ensure_ascii=False, indent=2)
                record['defect'] = str(defect_path)
                record['seconds'] = time.monotonic() - started
                write_json(path, self.report)
                raise
            record['seconds'] = time.monotonic() - started
            write_json(path, self.report)
        self.report['status'] = 'PASS'
        write_json(path, self.report)
        return self.report