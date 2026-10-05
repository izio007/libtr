import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

from engine import Pipeline, run_job


class EngineTests(unittest.TestCase):
    def test_result_identity_and_expectations(self):
        with tempfile.TemporaryDirectory() as tmp:
            def run(value, rules):
                engine = Pipeline(tmp, {'suite': 'metrics', 'expectations': {'check': rules}}, 'hash')
                engine.run([('check', lambda: value)])
                return engine.report['stages'][0]['result_ref']
            rules = [dict(path=['rmse'], kind='range', min=0, max=1)]
            first = run({'rmse': 0.5}, rules)
            repeated = run({'rmse': 0.5}, rules)
            self.assertEqual(first['sha256'], repeated['sha256'])
            self.assertEqual(repeated['change'], 'UNCHANGED')
            self.assertEqual(len(list((Path(tmp)/'runtime/pipeline_results').glob('*.json'))), 1)
            changed = run({'rmse': 0.4}, [dict(path=['rmse'], kind='delta', min=-0.2, max=0)])
            self.assertEqual(changed['assessment']['status'], 'PASS')
            self.assertEqual(changed['change'], 'CHANGED')
            with self.assertRaisesRegex(ValueError, 'expectations'):
                run({'rmse': 0.4}, [dict(path=['rmse'], kind='range', min=0, max=0.3)])
            self.assertEqual(run({'rmse': 0.4}, rules)['change'], 'UNCHANGED')

    def test_expectation_refusals(self):
        from result_store import assess, validate
        for value, prior, rule in [
                ({}, None, dict(path=['missing'], kind='equal', value=1)),
                (1, None, dict(path=[], kind='delta', min=0, max=1)),
                (True, None, dict(path=[], kind='range', min=0, max=1)),
                (float('nan'), None, dict(path=[], kind='range', min=0, max=1))]:
            self.assertEqual(assess(value, prior, [rule])['status'], 'FAILED')
        with self.assertRaises(ValueError):
            validate({'check': [dict(path=[], kind='range', min=2, max=1)]})
        with tempfile.TemporaryDirectory() as tmp:
            engine = Pipeline(tmp, {'expectations': {'first': [dict(path=[], kind='equal', value=1)]}}, 'hash')
            later = Mock()
            with self.assertRaises(ValueError):
                engine.run([('first', lambda: 2), ('later', later)])
            later.assert_not_called()
            self.assertEqual(engine.report['stages'][1]['status'], 'NOT_RUN')

    def test_success_report(self):
        with tempfile.TemporaryDirectory() as tmp:
            engine = Pipeline(tmp, {'suite': 'fixture'}, 'config-hash')
            report = engine.run([('first', lambda: 2), ('second', lambda: 3)])
            self.assertEqual(report['status'], 'PASS')
            self.assertEqual([json.loads(Path(s['result_ref']['path']).read_text())
                              for s in report['stages']], [2, 3])
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