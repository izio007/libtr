import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from provenance_attempt import accompanied
from pipeline_client import run_job
from provenance_snapshot import digest


class AttemptTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.source = self.root / 'source.m'
        self.source.write_bytes(b'abc')
        self.spec = self.root / 'inputs.json'
        self.spec.write_text(json.dumps(dict(schema_version=1, inputs=[dict(path='source.m', role='kernel')])) )
        self.output = self.root / 'runtime' / 'attempt'
        self.request = dict(v=1, op='submit', id='example', action='unit')
        self.response = dict(ok=True, report=dict(id='example', action='unit',
                             state='passed', artifacts=['result.txt']))
        self.job = self.root / 'runtime/pipeline/example'
        self.job.mkdir(parents=True)
        (self.job/'request.json').write_text(json.dumps(self.request))
        (self.job/'report.json').write_text(json.dumps(self.response['report']))
        (self.job/'result.txt').write_text('result')

    def invoke(self, execute):
        with patch('provenance_snapshot.platform.platform', return_value='fixture'), \
                patch('provenance_snapshot.subprocess.check_output', side_effect=[b'a'*40, b' M source.m']):
            return accompanied(self.root, self.spec, self.output, self.request, execute)

    def record(self):
        return json.loads((self.output / 'attempt.json').read_bytes())

    def test_before_submit_and_immutable_snapshot(self):
        def execute():
            self.assertTrue((self.output / 'manifest.json').is_file())
            self.assertEqual(json.loads((self.output / 'request.json').read_bytes()), self.request)
            return self.response
        response, clean = self.invoke(execute)
        self.assertTrue(clean)
        record = self.record()
        self.assertEqual(record['server_response'], response)
        self.assertEqual(record['applicability'], 'UNCONFIRMED')
        self.assertEqual(record['verification_status'], 'NOT_RUN')
        inventory = json.loads((self.output/'artifact_status.json').read_bytes())
        self.assertEqual(inventory['state'], 'PASS')
        self.assertEqual(inventory['registry_sha256'], digest((self.output/'artifacts.json').read_bytes()))
        self.assertEqual(record['input_manifest_sha256'], digest((self.output/'manifest.json').read_bytes()))
        self.assertEqual((self.output/'inputs/inputs.json').read_bytes(), self.spec.read_bytes())
        with self.assertRaises(FileExistsError):
            self.invoke(lambda: self.fail('must not submit'))

    def test_changed_input_keeps_server_result(self):
        def execute():
            self.source.write_bytes(b'changed')
            return self.response
        response, clean = self.invoke(execute)
        self.assertFalse(clean)
        self.assertEqual(response, self.response)
        self.assertEqual(self.record()['input_comparison']['changed'], ['source.m'])

    def test_connection_failure_recorded_and_raised(self):
        def execute():
            raise ConnectionError('no server')
        with self.assertRaises(ConnectionError):
            self.invoke(execute)
        self.assertIsNone(self.record()['server_response'])
        self.assertEqual(self.record()['client_error']['type'], 'ConnectionError')
        self.assertEqual(json.loads((self.output/'artifact_status.json').read_bytes())['state'], 'NOT_RUN')
        self.assertFalse((self.output/'artifacts.json').exists())

    def test_missing_artifact_blocks_success(self):
        (self.job/'result.txt').unlink()
        response, clean = self.invoke(lambda: self.response)
        self.assertFalse(clean)
        self.assertEqual(response, self.response)
        self.assertEqual(self.record()['server_response']['report']['state'], 'passed')
        self.assertEqual(json.loads((self.output/'artifact_status.json').read_bytes())['state'], 'FAILED')

    def test_failed_math_can_have_valid_inventory(self):
        self.response['report']['state'] = 'failed'
        (self.job/'report.json').write_text(json.dumps(self.response['report']))
        response, clean = self.invoke(lambda: self.response)
        self.assertTrue(clean)
        self.assertEqual(response['report']['state'], 'failed')

    def test_job_output_forbidden_before_submission(self):
        self.output = self.job/'attempt'
        with self.assertRaises(ValueError):
            self.invoke(lambda: self.fail('must not submit'))

    def test_comparison_error_not_success(self):
        with patch('provenance_attempt.changed_inputs', side_effect=PermissionError('denied')):
            _, clean = self.invoke(lambda: self.response)
        self.assertFalse(clean)
        self.assertEqual(self.record()['input_comparison']['error'], 'denied')

    def test_status_timeout_does_not_resubmit(self):
        with patch('pipeline_client.exchange', side_effect=[dict(ok=True), TimeoutError(), self.response]) as exchange:
            response = run_job(self.request, 5555, 30)
        self.assertEqual(response, self.response)
        self.assertEqual([c.args[0]['op'] for c in exchange.call_args_list], ['submit', 'status', 'status'])

    def configure_mapping(self, text='@CRITERION C-1: example\n'):
        self.request['test'] = 'unit_test_example'
        (self.job/'request.json').write_text(json.dumps(self.request))
        (self.root/'criterion.md').write_text(text)
        table = dict(schema_version=1, checks=[dict(name='unit_test_example',
            criterion='C-1', definition='criterion.md', source='source.m')])
        (self.root/'mapping.json').write_text(json.dumps(table))
        spec = json.loads(self.spec.read_text())
        spec['check_mapping'] = 'mapping.json'
        spec['inputs'].extend([dict(path='mapping.json', role='mapping'),
                               dict(path='criterion.md', role='criterion')])
        self.spec.write_text(json.dumps(spec))

    def test_preflight_pass(self):
        self.configure_mapping()
        _, clean = self.invoke(lambda: self.response)
        self.assertTrue(clean)
        self.assertEqual(self.record()['preflight']['state'], 'PASS')

    def test_preflight_failure_never_submits(self):
        self.configure_mapping('@CRITERION C-1: a\n@CRITERION C-1: b\n')
        with self.assertRaises(ValueError):
            self.invoke(lambda: self.fail('must not submit'))
        self.assertEqual(self.record()['preflight']['state'], 'FAILED')
        self.assertIsNone(self.record()['server_response'])

    def test_uncaptured_mapping_never_submits(self):
        self.configure_mapping()
        spec = json.loads(self.spec.read_text())
        spec['inputs'] = [x for x in spec['inputs'] if x['path'] != 'criterion.md']
        self.spec.write_text(json.dumps(spec))
        with self.assertRaises(ValueError):
            self.invoke(lambda: self.fail('must not submit'))
        self.assertEqual(self.record()['preflight']['state'], 'FAILED')


if __name__ == '__main__':
    unittest.main()