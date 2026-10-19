import json
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

from wfk import processes


ROOT = Path(__file__).parents[1]
PROBE = ROOT / 'wfk' / 'authprobe.py'
WORKER = Path(__file__).parent / 'fixtures' / 'auth_worker.py'
SECRET = 'credential-marker-do-not-log'


class AuthProbeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='wfk auth probe ')
        self.root = Path(self.temp.name)
        self.capture = self.root / 'request.json'
        self.addCleanup(self.temp.cleanup)

    def command(self, mode, *extra):
        return [sys.executable, str(PROBE), '--', sys.executable, str(WORKER),
                mode, str(self.capture), *map(str, extra)]

    def run_probe(self, mode, *extra, timeout=8):
        return subprocess.run(self.command(mode, *extra), cwd=self.root,
                              stdin=subprocess.DEVNULL, capture_output=True,
                              text=True, timeout=timeout, check=False)

    def assert_secret_absent(self, result):
        self.assertNotIn(SECRET, result.stdout)
        self.assertNotIn(SECRET, result.stderr)

    def test_success_sends_only_auth_status_request_with_required_cli_flags(self):
        result = self.run_probe('success')
        self.assertEqual(result.returncode, 0, result)
        self.assertEqual(result.stdout, 'Authenticated\n')
        self.assertEqual(result.stderr, '')
        self.assert_secret_absent(result)
        captured = json.loads(self.capture.read_text(encoding='utf-8'))
        self.assertTrue(captured['valid'])
        self.assertEqual(captured['request'], {
            'jsonrpc': '2.0', 'id': 1, 'method': 'auth.getStatus', 'params': {}})
        self.assertEqual(captured['flags'],
                         ['--headless', '--stdio', '--no-auto-update'])

    def test_explicit_false_fails_with_nonsecret_reason(self):
        result = self.run_probe('false')
        self.assertEqual(result.returncode, 1, result)
        self.assertEqual(result.stdout, 'Authentication required\n')
        self.assertEqual(result.stderr, '')
        self.assert_secret_absent(result)

    def test_malformed_missing_and_error_responses_fail_closed_without_payloads(self):
        for mode in ('malformed', 'missing', 'error'):
            with self.subTest(mode=mode):
                result = self.run_probe(mode)
                self.assertEqual(result.returncode, 1, result)
                self.assertEqual(result.stdout, 'Authentication check failed\n')
                self.assertEqual(result.stderr, '')
                self.assert_secret_absent(result)

    def test_bounded_notifications_may_precede_the_response(self):
        result = self.run_probe('notify-success')
        self.assertEqual(result.returncode, 0, result)
        self.assertEqual(result.stdout, 'Authenticated\n')
        self.assert_secret_absent(result)

    def test_notification_flood_fails_closed(self):
        result = self.run_probe('notification-flood')
        self.assertEqual(result.returncode, 1, result)
        self.assertEqual(result.stdout, 'Authentication check failed\n')
        self.assert_secret_absent(result)

    def test_frame_and_header_limits_fail_closed(self):
        for mode in ('oversize', 'long-header'):
            with self.subTest(mode=mode):
                result = self.run_probe(mode)
                self.assertEqual(result.returncode, 1, result)
                self.assertEqual(result.stdout, 'Authentication check failed\n')
                self.assert_secret_absent(result)

    def test_no_response_is_not_inferred_from_cli_exit_zero(self):
        worker = self.root / 'empty_worker.py'
        worker.write_text('raise SystemExit(0)\n', encoding='utf-8')
        command = [sys.executable, str(PROBE), '--', sys.executable, str(worker)]
        result = subprocess.run(command, cwd=self.root, capture_output=True,
                                text=True, timeout=8, check=False)
        self.assertEqual(result.returncode, 1, result)
        self.assertEqual(result.stdout, 'Authentication check failed\n')

    def test_outer_runner_contains_descendants_during_helper_cleanup(self):
        marker = self.root / 'leak'
        pid_path = self.root / 'child.pid'
        log = self.root / 'probe.log'
        result = processes.execute(
            self.command('response-hang', marker, pid_path),
            self.root, log, timeout=8, grace=.1)
        self.assertEqual(result['returncode'], 0, log.read_text(errors='replace'))
        self.assertFalse(result['timed_out'])
        self.assertTrue(pid_path.exists())
        time.sleep(3.3)
        self.assertFalse(marker.exists(), 'auth CLI descendant escaped containment')
        self.assertEqual(log.read_text(encoding='utf-8'), 'Authenticated\n')
        self.assertNotIn(SECRET, log.read_text(encoding='utf-8'))

    def test_separator_and_native_argv_are_required(self):
        for argv in ([], ['copilot'], ['--']):
            with self.subTest(argv=argv):
                result = subprocess.run([sys.executable, str(PROBE), *argv],
                                        capture_output=True, text=True, check=False)
                self.assertEqual(result.returncode, 2, result)
                self.assertEqual(result.stderr, '')


if __name__ == '__main__':
    unittest.main()
