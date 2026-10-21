import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

from engine import Pipeline, run_job, write_json


class EngineTests(unittest.TestCase):
    def test_values_and_job_link_stay_in_one_report(self):
        with tempfile.TemporaryDirectory() as tmp:
            engine = Pipeline(tmp, {'suite': 'fixture'})
            value = dict(executed=1, job_id='matlab_job', report_path='job/report.json',
                         stages=[dict(metrics=dict(rmse=0.5))])
            report = engine.run([('first', lambda: value), ('second', lambda: 3)])
            self.assertEqual(report['status'], 'PASS')
            self.assertEqual([stage['value'] for stage in report['stages']], [value, 3])
            self.assertEqual(json.loads((engine.folder/'report.json').read_text()), report)
            self.assertEqual(list(Path(tmp).rglob('*.json')), [engine.folder/'report.json'])

    def test_fail_fast_keeps_prior_value_and_traceback(self):
        with tempfile.TemporaryDirectory() as tmp:
            engine = Pipeline(tmp, {})
            later = Mock()

            def broken():
                raise ValueError('fixture failure')

            with self.assertRaises(ValueError):
                engine.run([('first', lambda: 1), ('broken', broken), ('later', later)])
            later.assert_not_called()
            report = json.loads((engine.folder/'report.json').read_text())
            self.assertEqual(report['status'], 'FAILED')
            self.assertEqual([stage['status'] for stage in report['stages']],
                             ['PASS', 'FAILED', 'NOT_RUN'])
            self.assertEqual(report['stages'][0]['value'], 1)
            error = report['stages'][1]['error']
            self.assertEqual(error['message'], 'fixture failure')
            self.assertEqual(error['type'], 'ValueError')
            self.assertIn('broken', error['traceback'])

    def test_bad_result_does_not_break_failure_report(self):
        for value in (float('nan'), object()):
            with self.subTest(value=value), tempfile.TemporaryDirectory() as tmp:
                engine = Pipeline(tmp, {})
                later = Mock()
                with self.assertRaises((ValueError, TypeError)):
                    engine.run([('bad', lambda: value), ('later', later)])
                later.assert_not_called()
                report = json.loads((engine.folder/'report.json').read_text())
                self.assertEqual(report['status'], 'FAILED')
                self.assertNotIn('value', report['stages'][0])

    def test_bad_json_does_not_replace_previous_report(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)/'report.json'
            write_json(path, {'status': 'RUNNING'})
            with self.assertRaises(ValueError):
                write_json(path, {'bad': float('nan')})
            self.assertEqual(json.loads(path.read_text()), {'status': 'RUNNING'})
            self.assertEqual(list(Path(tmp).iterdir()), [path])

    def test_unique_nonempty_stages(self):
        with tempfile.TemporaryDirectory() as tmp:
            for stages in ([], [('a', lambda: 1), ('a', lambda: 2)], [('', lambda: 1)]):
                with self.assertRaises(ValueError):
                    Pipeline(tmp, {}).run(stages)

    def test_status_retry_never_resubmits(self):
        transport = Mock(side_effect=[{'report': {'state': 'queued'}},
                                     TimeoutError(), {'report': {'state': 'passed'}}])
        result = run_job({'op': 'submit', 'id': 'fixture'}, transport=transport,
                         sleep=lambda _: None)
        self.assertEqual(result['report']['state'], 'passed')
        self.assertEqual([call.args[0]['op'] for call in transport.call_args_list],
                         ['submit', 'status', 'status'])

    def test_submit_uncertainty_no_retry(self):
        transport = Mock(side_effect=TimeoutError('uncertain delivery'))
        with self.assertRaisesRegex(RuntimeError, 'fixture'):
            run_job({'op': 'submit', 'id': 'fixture'}, transport=transport)
        transport.assert_called_once()

    def test_deadline_bounds_calls(self):
        now = [0.0]

        def sleep(seconds):
            now[0] += seconds

        def transport(request, port, timeout):
            self.assertGreater(timeout, 0)
            self.assertLessEqual(timeout, 1)
            now[0] += timeout
            return {'report': {'state': 'running'}}

        with self.assertRaisesRegex(TimeoutError, 'fixture'):
            run_job({'op': 'submit', 'id': 'fixture'}, timeout=1, transport=transport,
                    sleep=sleep, clock=lambda: now[0])

    def test_terminal_failure_not_pass(self):
        transport = Mock(return_value={'report': {'state': 'failed'}})
        self.assertEqual(run_job({'id': 'fixture'}, transport=transport)['report']['state'], 'failed')
        transport.assert_called_once()

    def test_busy_host_never_submits(self):
        from declarative_runner import execute
        with patch('declarative_runner.exchange', return_value={'active': 'other'}) as transport:
            with self.assertRaisesRegex(RuntimeError, 'busy'):
                execute({'suite': 'matmul3', 'timeout_seconds': 1})
        self.assertEqual(transport.call_args.args[0]['op'], 'ping')
        transport.assert_called_once()


if __name__ == '__main__':
    unittest.main()
