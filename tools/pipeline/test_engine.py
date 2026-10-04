import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

from engine import Pipeline, run_job


class EngineTests(unittest.TestCase):
    def test_success_report(self):
        with tempfile.TemporaryDirectory() as tmp:
            engine = Pipeline(tmp, {'suite': 'fixture'}, 'config-hash')
            report = engine.run([('first', lambda: 2), ('second', lambda: 3)])
            self.assertEqual(report['status'], 'PASS')
            self.assertEqual([s['result'] for s in report['stages']], [2, 3])
            self.assertEqual(json.loads((engine.folder/'report.json').read_text()), report)
            self.assertEqual(report['config_sha256'], 'config-hash')

    def test_fail_fast_snapshot(self):
        with tempfile.TemporaryDirectory() as tmp:
            engine = Pipeline(tmp, {}, 'hash')
            later = Mock()
            def broken():
                raise ValueError('fixture failure')
            with self.assertRaises(ValueError):
                engine.run([('first', lambda: 1), ('broken', broken), ('later', later)])
            later.assert_not_called()
            self.assertEqual([s['status'] for s in engine.report['stages']],
                             ['PASS', 'FAILED', 'NOT_RUN'])
            defect = json.loads(Path(engine.report['stages'][1]['defect']).read_text())
            self.assertEqual(defect['failure_reason'], 'fixture failure')
            self.assertIsNone(defect['memory_snapshot']['rng'])
            self.assertEqual(defect['location']['file'], __file__)

    def test_unique_stages(self):
        with tempfile.TemporaryDirectory() as tmp:
            engine = Pipeline(tmp, {}, 'hash')
            with self.assertRaises(ValueError):
                engine.run([('a', lambda: 1), ('a', lambda: 2)])

    def test_status_retry_never_resubmits(self):
        transport = Mock(side_effect=[{'report': {'state': 'queued'}},
                                     TimeoutError(), {'report': {'state': 'passed'}}])
        result = run_job({'op': 'submit', 'id': 'fixture'}, transport=transport,
                         sleep=lambda _: None)
        self.assertEqual(result['report']['state'], 'passed')
        self.assertEqual([c.args[0]['op'] for c in transport.call_args_list],
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