import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from declarative_runner import execute, load_config, registered_stages
from engine import Pipeline


class ConfigTests(unittest.TestCase):
    def test_all_unit_uses_server_discovery_and_actual_count(self):
        stages = [dict(name='environment', metrics={}),
                  dict(name='unit', metrics=dict(total=17))]
        response = dict(ok=True, report=dict(id='all_job', state='passed', stages=stages))
        with patch('declarative_runner.exchange', return_value={}), \
                patch('declarative_runner.run_job', return_value=response) as run:
            value = execute(dict(suite='all_unit', timeout_seconds=30))
        request = run.call_args.args[0]
        self.assertEqual(request['action'], 'unit')
        self.assertNotIn('test', request)
        self.assertNotIn('test_sha256', request)
        self.assertEqual(value['executed'], 17)

    def test_all_unit_rejects_missing_execution_count(self):
        response = dict(ok=True, report=dict(id='all_job', state='passed', stages=[]))
        with patch('declarative_runner.exchange', return_value={}), \
                patch('declarative_runner.run_job', return_value=response):
            with self.assertRaisesRegex(RuntimeError, 'executed count'):
                execute(dict(suite='all_unit', timeout_seconds=30))

    def test_filter_runs_three_leaf_tests_once(self):
        config = dict(schema_version=1, suite='filter2win', timeout_seconds=30)
        with tempfile.TemporaryDirectory() as folder:
            stages = registered_stages(config)
            self.assertEqual([name for name, _ in stages], ['settings', 'persistent', 'schema2'])
            with patch('declarative_runner.execute', return_value=dict(executed=1)) as run:
                report = Pipeline(folder, config).run(stages)
            self.assertEqual(report['status'], 'PASS')
            self.assertEqual([call.kwargs['test'] for call in run.call_args_list], [
                'unit_test_filter2win_settings', 'unit_test_filter2win_persistent',
                'unit_test_filter2win_schema2'])
            self.assertEqual(sum(stage['value']['executed'] for stage in report['stages']), 3)

    def test_filter_stops_after_first_failed_leaf(self):
        config = dict(schema_version=1, suite='filter2win', timeout_seconds=30)
        with tempfile.TemporaryDirectory() as folder:
            pipeline = Pipeline(folder, config)
            with patch('declarative_runner.execute', side_effect=[dict(executed=1),
                        RuntimeError('persistent failed')]) as run:
                with self.assertRaisesRegex(RuntimeError, 'persistent failed'):
                    pipeline.run(registered_stages(config))
            self.assertEqual(run.call_count, 2)
            self.assertEqual([stage['status'] for stage in pipeline.report['stages']],
                             ['PASS', 'FAILED', 'NOT_RUN'])

    def test_integration_preserves_explicit_consumer_coverage(self):
        config = dict(schema_version=1, suite='filter2win_integration', timeout_seconds=30)
        stages = registered_stages(config)
        self.assertEqual([name for name, _ in stages],
                         ['kernel', 'consumer_scenario', 'consumer_model', 'consumer_plot'])
        with patch('declarative_runner.execute', return_value=dict(executed=1)) as run:
            for _, handler in stages:
                handler()
        self.assertEqual([call.kwargs['test'] for call in run.call_args_list],
                         ['unit_test_filter2win_isolation', 'unit_test_filter_engine_scenario',
                          'unit_test_filter_model', 'unit_test_filter_plot_path'])

    def test_common_deadline_does_not_start_expired_stage(self):
        config = dict(schema_version=1, suite='filter2win', timeout_seconds=10)
        with patch('declarative_runner.time.monotonic', side_effect=[100, 101, 106, 111]), \
                patch('declarative_runner.execute', return_value=dict(executed=1)) as run:
            stages = registered_stages(config)
            stages[0][1]()
            stages[1][1]()
            with self.assertRaises(TimeoutError):
                stages[2][1]()
        self.assertEqual([call.args[0]['timeout_seconds'] for call in run.call_args_list], [9, 4])

    def test_matlab_result_keeps_job_and_returned_metrics(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            source = root/'matlab/tests/unit_test_matmul3.m'
            source.parent.mkdir(parents=True)
            source.write_bytes(b'fixture source')
            returned_stages = [dict(name='unit', state='passed', metrics=dict(total=1, rmse=0.25))]
            response = dict(ok=True, report=dict(id='job_123', state='passed', stages=returned_stages))
            with patch('declarative_runner.ROOT', root), \
                    patch('declarative_runner.exchange', return_value={'active': '', 'queued': 0}), \
                    patch('declarative_runner.run_job', return_value=response) as run:
                value = execute(dict(suite='matmul3', timeout_seconds=30))
            self.assertEqual(value['job_id'], 'job_123')
            self.assertEqual(value['report_path'], str(root/'runtime/pipeline/job_123/report.json'))
            self.assertEqual(value['stages'], returned_stages)
            self.assertEqual(value['executed'], 1)
            request = run.call_args.args[0]
            self.assertEqual(request['test'], 'unit_test_matmul3')
            self.assertEqual(request['test_sha256'], hashlib.sha256(source.read_bytes()).hexdigest())

    def test_matlab_failure_is_not_counted_as_success(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            source = root/'matlab/tests/unit_test_matmul3.m'
            source.parent.mkdir(parents=True)
            source.write_bytes(b'fixture source')
            with patch('declarative_runner.ROOT', root), \
                    patch('declarative_runner.exchange', return_value={}), \
                    patch('declarative_runner.run_job', return_value={'report': {'state': 'failed'}}):
                with self.assertRaises(RuntimeError):
                    execute(dict(suite='matmul3', timeout_seconds=30))

    def test_filter_scenario_declaration(self):
        root = Path(__file__).resolve().parents[2]
        folder = root/'matlab/tests/configs'
        spec = json.loads((folder/'filter2win_observations.json').read_text())
        count = (spec['end_time'] - spec['start_time']) / spec['time_step'] + 1
        self.assertEqual(count, spec['expected_samples'])
        self.assertGreater(spec['time_step'], 0)
        self.assertGreater(spec['rmse_tolerance'], 0)
        self.assertLess(spec['missing_open_interval'][0], spec['missing_open_interval'][1])
        for start, end, level in spec['plateaus']:
            self.assertLessEqual(start, end)
            self.assertIsInstance(level, (int, float))
        self.assertEqual(load_config(folder/'filter2win_consumers_runner.json')['suite'],
                         'filter2win_consumers')

    def test_valid(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            path = root/'matlab/tests/configs/test.json'
            path.parent.mkdir(parents=True)
            value = dict(schema_version=1, suite='matmul3', timeout_seconds=10)
            path.write_text(json.dumps(value))
            self.assertEqual(load_config(path, root), value)

    def test_rejections(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            path = root/'matlab/tests/configs/test.json'
            path.parent.mkdir(parents=True)
            for text in ('{}', '[]', '{"suite":1,"suite":2}',
                         json.dumps(dict(schema_version=1, suite='eval', timeout_seconds=10)),
                         json.dumps(dict(schema_version=1, suite='filter2win_package', timeout_seconds=10)),
                         json.dumps(dict(schema_version=1, suite='matmul3', timeout_seconds=True)),
                         json.dumps(dict(schema_version=1, suite='matmul3', timeout_seconds=10, extra={}))):
                path.write_text(text)
                with self.subTest(text=text), self.assertRaises(ValueError):
                    load_config(path, root)
            with self.assertRaises(ValueError):
                load_config(root/'outside.json', root)


if __name__ == '__main__':
    unittest.main()
