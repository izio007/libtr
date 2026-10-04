"""Registered handlers and strict configuration for the pipeline engine."""
import contextlib
import hashlib
import io
import json
from pathlib import Path
import sys
import time
import unittest
import uuid

from engine import Pipeline, exchange, run_job

ROOT = Path(__file__).resolve().parents[2]
SUITES = {'matmul3': 'unit_test_matmul3', 'runner_contract': None,
          'pipeline_engine': None,
          'filter2win_package': 'unit_test_filter2win_package',
          'filter2win': 'unit_test_filter2win',
          'filter2win_candidate': 'unit_test_filter2win_candidate',
          'filter2win_isolation': 'unit_test_filter2win_isolation',
          'fifo_double': 'unit_test_fifo_double',
          'filter2win_demo': 'unit_test_filter2win_demo',
          'filter2win_consumers': 'unit_test_filter_engine_scenario'}


def load_config(path, root=ROOT):
    path = Path(path)
    if not path.is_absolute():
        path = root / path
    path = path.resolve()
    if not path.is_relative_to((root / 'matlab/tests/configs').resolve()):
        raise ValueError('Configuration must be inside matlab/tests/configs')
    raw = path.read_bytes()
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError('Duplicate configuration key: ' + key)
            result[key] = value
        return result
    config = json.loads(raw, object_pairs_hook=unique)
    if not isinstance(config, dict) or set(config) != {'schema_version', 'suite', 'timeout_seconds'}:
        raise ValueError('Unexpected configuration fields')
    if type(config['schema_version']) is not int or config['schema_version'] != 1:
        raise ValueError('Unsupported schema')
    if not isinstance(config['suite'], str) or config['suite'] not in SUITES:
        raise ValueError('Unregistered suite')
    timeout = config['timeout_seconds']
    if type(timeout) is not int or not 1 <= timeout <= 3600:
        raise ValueError('Invalid transport timeout')
    return config, hashlib.sha256(raw).hexdigest()


def execute(config):
    if config['suite'] in ('runner_contract', 'pipeline_engine'):
        patterns = ('test_engine.py', 'test_provenance_attempt.py') if config['suite'] == 'pipeline_engine' else ('test_declarative_runner.py',)
        suite = unittest.TestSuite(unittest.defaultTestLoader.discover(
            str(ROOT / 'tools/pipeline'), pattern=pattern) for pattern in patterns)
        output = io.StringIO()
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
            result = unittest.TextTestRunner(stream=output, failfast=True).run(suite)
        if not result.wasSuccessful():
            raise RuntimeError(output.getvalue())
        return result.testsRun
    name = SUITES[config['suite']]
    host = exchange(dict(v=1, op='ping'), timeout=min(30, config['timeout_seconds']))
    if host.get('active') or host.get('queued'):
        raise RuntimeError('Server is busy; job was not submitted')
    request = dict(v=1, op='submit', id=uuid.uuid4().hex, action='unit', test=name,
                   test_sha256=hashlib.sha256((ROOT/'matlab/tests'/(name+'.m')).read_bytes()).hexdigest())
    response = run_job(request, timeout=config['timeout_seconds'], transport=exchange)
    if response['report']['state'] != 'passed':
        raise RuntimeError(json.dumps(response, ensure_ascii=False))
    # Count the selected suite check, not its unreported internal assertions.
    return 1


def main():
    start = time.monotonic()
    try:
        if len(sys.argv) != 2:
            raise ValueError('Expected one configuration path')
        config, config_hash = load_config(sys.argv[1])
        pipeline = Pipeline(ROOT, config, config_hash)
        report = pipeline.run([(config['suite'], lambda: execute(config))])
        total = report['stages'][0]['result']
        print(f'[SUITE PASS] Executed {total}/{total} checks successfully. Execution time: {time.monotonic()-start:.2f}s.')
        return 0
    except Exception as error:
        print(json.dumps(dict(status='FAILED', test_id='declarative_runner',
            location=None, condition=None, failure_reason=str(error), expected='Completed registered suite',
            actual=type(error).__name__, memory_snapshot=None), ensure_ascii=False))
        return 1


if __name__ == '__main__':
    sys.exit(main())