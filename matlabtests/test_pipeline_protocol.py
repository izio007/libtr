"""Live transport tests; run against the isolated validation endpoint."""
import json
import socket
import unittest
import uuid
from pipeline_client import exchange


class ProtocolTests(unittest.TestCase):
    port = 5556

    def test_fragmented_and_coalesced_frames(self):
        with socket.create_connection(('127.0.0.1', self.port), 10) as sock:
            sock.sendall(b'{"v":1,')
            sock.sendall(b'"op":"ping"}\n{"v":1,"op":"ping"}\n')
            with sock.makefile('rb') as stream:
                self.assertTrue(json.loads(stream.readline())['ok'])
                self.assertTrue(json.loads(stream.readline())['ok'])

    def test_reject_invalid_requests(self):
        for request in [dict(v=2, op='ping'), dict(v=1, op='eval'),
                        dict(v=1, op='submit', id='../escape', action='unit'),
                        dict(v=1, op='submit', id='invalid', action='eval')]:
            with self.assertRaises(RuntimeError):
                exchange(request, self.port)

    def test_idempotency_and_conflict(self):
        job = uuid.uuid4().hex
        request = dict(v=1, op='submit', id=job, action='environment')
        self.assertEqual(exchange(request, self.port)['id'], job)
        self.assertEqual(exchange(request, self.port)['id'], job)
        request['action'] = 'unit'
        with self.assertRaises(RuntimeError):
            exchange(request, self.port)


if __name__ == '__main__':
    unittest.main()