"""Registered test suites for tools/runner.sh."""
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
SUITES = {
    'all_unit': None,
    'matmul3': 'unit_test_matmul3',
    'runner_contract': None,
    'pipeline_engine': None,
    'filter2win': {
        'settings': 'unit_test_filter2win_settings',
        'persistent': 'unit_test_filter2win_persistent',
        'schema2': 'unit_test_filter2win_schema2',
    },
    'filter2win_candidate': 'unit_test_filter2win_candidate',
    'filter2win_isolation': 'unit_test_filter2win_isolation',
    'filter2win_integration': {
        'kernel': 'unit_test_filter2win_isolation',
        'consumer_scenario': 'unit_test_filter_engine_scenario',
        'consumer_model': 'unit_test_filter_model',
        'consumer_plot': 'unit_test_filter_plot_path',
    },
    'fifo_double': 'unit_test_fifo_double',
    'filter2win_demo': 'unit_test_filter2win_demo',
    'filter2win_consumers': {
        'scenario': 'unit_test_filter_engine_scenario',
        'model': 'unit_test_filter_model',
        'plot': 'unit_test_filter_plot_path',
    },
}


def load_config(path, root=ROOT):
    path = Path(path)
    if not path.is_absolute():
        path = root / path
    path = path.resolve()
    if not path.is_relative_to((root / 'matlab/tests/configs').resolve()):
        raise ValueError('Configuration must be inside matlab/tests/configs')

    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError('Duplicate configuration key: ' + key)
            result[key] = value
        return result

    config = json.loads(path.read_bytes(), object_pairs_hook=unique)
    required = {'schema_version', 'suite', 'timeout_seconds'}
    if not isinstance(config, dict) or set(config) != required:
        raise ValueError('Expected schema_version, suite and timeout_seconds only')
    if type(config['schema_version']) is not int or config['schema_version'] != 1:
        raise ValueError('Unsupported schema')
    if not isinstance(config['suite'], str) or config['suite'] not in SUITES:
        raise ValueError('Unregistered suite')
    timeout = config['timeout_seconds']
    if type(timeout) is not int or not 1 <= timeout <= 3600:
        raise ValueError('Invalid transport timeout')
    return config


def execute(config, test=None):
    if config['suite'] in ('runner_contract', 'pipeline_engine'):
        pattern = 'test_engine.py' if config['suite'] == 'pipeline_engine' else 'test_declarative_runner.py'
        suite = unittest.defaultTestLoader.discover(str(ROOT / 'tools/pipeline'), pattern=pattern)
        output = io.StringIO()
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
            result = unittest.TextTestRunner(stream=output, failfast=True).run(suite)
        if not result.wasSuccessful():
            raise RuntimeError(output.getvalue())
        return dict(executed=result.testsRun)

    name = test or SUITES[config['suite']]
    deadline = time.monotonic() + config['timeout_seconds']
    host = exchange(dict(v=1, op='ping'), timeout=min(30, config['timeout_seconds']))
    if host.get('active') or host.get('queued'):
        raise RuntimeError('Server is busy; job was not submitted')
    request = dict(v=1, op='submit', id=uuid.uuid4().hex, action='unit')
    if config['suite'] != 'all_unit':
        request['test'] = name
        request['test_sha256'] = hashlib.sha256((ROOT/'matlab/tests'/(name+'.m')).read_bytes()).hexdigest()
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise TimeoutError('Deadline exceeded before stage submission')
    response = run_job(request, timeout=remaining, transport=exchange)
    report = response['report']
    if report['state'] != 'passed':
        raise RuntimeError(json.dumps(response, ensure_ascii=False))
    job = report['id']
    executed = 1
    if config['suite'] == 'all_unit':
        unit = next((stage for stage in report.get('stages', []) if stage['name'] == 'unit'), None)
        executed = unit.get('metrics', {}).get('total') if unit else None
        if type(executed) is not int or executed < 1:
            raise RuntimeError('MATLAB unit report did not provide a positive executed count')
    # These are actual returned stages, not reconstructed numerical results.
    return dict(executed=executed, job_id=job,
                report_path=str(ROOT/'runtime/pipeline'/job/'report.json'),
                stages=report.get('stages', []))


def registered_stages(config):
    selected = SUITES[config['suite']]
    tests = selected if isinstance(selected, dict) else {config['suite']: selected}
    deadline = time.monotonic() + config['timeout_seconds']

    def run(test):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError('Suite deadline exceeded before stage submission')
        return execute(dict(config, timeout_seconds=remaining), test=test)

    return [(name, lambda test=test: run(test)) for name, test in tests.items()]


def main():
    start = time.monotonic()
    try:
        if len(sys.argv) != 2:
            raise ValueError('Expected one configuration path')
        config = load_config(sys.argv[1])
        pipeline = Pipeline(ROOT, config)
        report = pipeline.run(registered_stages(config))
        total = sum(stage['value']['executed'] for stage in report['stages'])
        print(f'[SUITE PASS] Executed {total}/{total} checks successfully. Execution time: {time.monotonic()-start:.2f}s.')
        return 0
    except Exception as error:
        print(json.dumps(dict(status='FAILED', test_id='declarative_runner',
                              error_type=type(error).__name__, failure_reason=str(error)),
                         ensure_ascii=False))
        return 1


if __name__ == '__main__':
    sys.exit(main())
