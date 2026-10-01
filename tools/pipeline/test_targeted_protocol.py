"""Live targeted selection regression on the running project endpoint (5555)."""
import unittest
import uuid
from pipeline_client import exchange


class TargetedProtocolTests(unittest.TestCase):
    def test_rejection_and_selection_conflict(self):
        for action, name in [('unit', '../unit_test_matmul3'),
                             ('unit', 'unit_test_absent_987654321'),
                             ('environment', 'unit_test_matmul3')]:
            with self.subTest(action=action, name=name), self.assertRaises(RuntimeError):
                exchange(dict(v=1, op='submit', id=uuid.uuid4().hex,
                              action=action, test=name))
        request = dict(v=1, op='submit', id=uuid.uuid4().hex,
                       action='unit', test='unit_test_matmul3')
        self.assertEqual(exchange(request)['id'], request['id'])
        self.assertEqual(exchange(request)['id'], request['id'])
        request['test'] = 'unit_test_pipeline'
        with self.assertRaises(RuntimeError):
            exchange(request)


if __name__ == '__main__':
    unittest.main()