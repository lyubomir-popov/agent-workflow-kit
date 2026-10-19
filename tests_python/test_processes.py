import json
import os
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

from wfk import processes


WORKER = Path(__file__).parent / 'fixtures' / 'process_worker.py'


class ProcessTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='wfk processes spaces ')
        self.root = Path(self.temp.name)
        self.log = self.root / 'logs with spaces' / 'worker.log'
        self.addCleanup(self.temp.cleanup)

    def execute(self, *args, **kwargs):
        return processes.execute([sys.executable, str(WORKER), *args],
                                 self.root, self.log, timeout=10, **kwargs)

    def test_success_argv_cwd_utf8_input_and_combined_durable_log(self):
        result = self.execute('echo', 'a b', '$(danger); & "literal"',
                              input_text='hello \u2603\n')
        self.assertEqual(result['returncode'], 0)
        self.assertFalse(result['timed_out'])
        self.assertFalse(result['interrupted'])
        self.assertGreaterEqual(result['duration'], 0)
        self.assertEqual(result['log'], str(self.log))
        lines = self.log.read_text(encoding='utf-8').splitlines()
        value = json.loads(lines[0])
        self.assertEqual(value['argv'], ['a b', '$(danger); & "literal"'])
        self.assertEqual(Path(value['cwd']), self.root)
        self.assertEqual(value['input'], 'hello \u2603\n')
        self.assertIn('stderr preserved', lines)

    def test_child_git_environment_is_sanitized_but_explicit_overrides_win(self):
        with patch.dict(os.environ, {'GIT_DIR': 'inherited wrong repo'}):
            self.execute('echo', env={'WFK_PROCESS_TEST': 'yes'})
            self.assertIsNone(json.loads(self.log.read_text().splitlines()[0])['git_dir'])
            self.execute('echo', env={'GIT_DIR': 'explicit fixture repo'})
            self.assertEqual(json.loads(self.log.read_text().splitlines()[0])['git_dir'],
                             'explicit fixture repo')

    def test_large_output_is_streamed_to_disk(self):
        result = self.execute('volume')
        self.assertGreater(self.log.stat().st_size, 4 * 1024 * 1024)
        self.assertNotIn('stdout', result)
        self.assertNotIn('stderr', result)

    def assert_child_stopped(self, pid_path, marker):
        self.assertTrue(pid_path.exists(), self.log.read_text(errors='replace'))
        time.sleep(1.7)
        self.assertFalse(marker.exists(), 'descendant survived tree cleanup')
        if os.name == 'nt':
            import ctypes
            kernel = ctypes.WinDLL('kernel32', use_last_error=True)
            kernel.OpenProcess.restype = ctypes.c_void_p
            handle = kernel.OpenProcess(0x1000, False, int(pid_path.read_text()))
            if handle:
                try:
                    code = ctypes.c_ulong()
                    kernel.GetExitCodeProcess(ctypes.c_void_p(handle), ctypes.byref(code))
                    self.assertNotEqual(code.value, 259)
                finally:
                    kernel.CloseHandle(ctypes.c_void_p(handle))

    def test_timeout_kills_signal_ignoring_parent_and_child(self):
        pid_path, marker = self.root / 'child.pid', self.root / 'leak'
        result = processes.execute(
            [sys.executable, str(WORKER), 'tree', str(pid_path), str(marker)],
            self.root, self.log, timeout=.5, grace=.1)
        self.assertTrue(result['timed_out'])
        self.assertFalse(result['interrupted'])
        self.assertIsNotNone(result['returncode'])
        self.assertLess(result['duration'], 5)
        self.assert_child_stopped(pid_path, marker)

    def test_tree_cleanup_does_not_terminate_unrelated_worker(self):
        unrelated = subprocess.Popen([sys.executable, str(WORKER), 'sleep'],
                                     stdout=subprocess.DEVNULL)
        try:
            result = processes.execute([sys.executable, str(WORKER), 'sleep'],
                                       self.root, self.log, timeout=.1, grace=.05)
            self.assertTrue(result['timed_out'])
            self.assertIsNone(unrelated.poll())
        finally:
            unrelated.kill()
            unrelated.wait()

    def test_normal_parent_exit_does_not_leave_descendant(self):
        pid_path, marker = self.root / 'child.pid', self.root / 'leak'
        result = self.execute('exit-tree', str(pid_path), str(marker), grace=.1)
        self.assertEqual(result['returncode'], 0)
        self.assert_child_stopped(pid_path, marker)

    def test_keyboard_interrupt_cleans_tree_and_returns_interrupted(self):
        pid_path, marker = self.root / 'child.pid', self.root / 'leak'
        real_sleep = time.sleep
        raised = 0

        def interrupt_when_ready(delay):
            nonlocal raised
            if pid_path.exists() and raised < 2:
                raised += 1
                raise KeyboardInterrupt
            real_sleep(delay)

        with patch('wfk.processes.time.sleep', side_effect=interrupt_when_ready):
            result = self.execute('tree', str(pid_path), str(marker), grace=.1)
        self.assertEqual(raised, 2)
        self.assertTrue(result['interrupted'])
        self.assertFalse(result['timed_out'])
        self.assert_child_stopped(pid_path, marker)

    @unittest.skipIf(os.name == 'nt', 'POSIX SIGINT session scope fixture')
    def test_actual_sigint_does_not_signal_unrelated_process(self):
        pid_path, marker = self.root / 'child.pid', self.root / 'leak'
        report = self.root / 'report.json'
        env = dict(os.environ, PYTHONPATH=str(WORKER.parents[2]))
        host = subprocess.Popen([sys.executable, str(WORKER), 'interrupt',
                                 str(pid_path), str(marker), str(self.log), str(report)],
                                cwd=self.root, env=env, start_new_session=True)
        unrelated = subprocess.Popen([sys.executable, str(WORKER), 'sleep'],
                                     stdout=subprocess.DEVNULL)
        try:
            deadline = time.monotonic() + 5
            while not pid_path.exists() and time.monotonic() < deadline:
                time.sleep(.02)
            os.kill(host.pid, signal.SIGINT)
            host.wait(timeout=5)
            self.assertTrue(json.loads(report.read_text())['interrupted'])
            self.assertIsNone(unrelated.poll())
            self.assert_child_stopped(pid_path, marker)
        finally:
            if host.poll() is None:
                host.kill()
                host.wait()
            unrelated.kill()
            unrelated.wait()

    def test_start_failure_preserves_log_and_has_useful_error(self):
        with self.assertRaisesRegex(ValueError, 'launch|start|executable'):
            processes.execute(['nonexistent-wfk-fixture-39483'], self.root,
                              self.log, timeout=1)
        self.assertTrue(self.log.is_file())

    def test_invalid_arguments_fail_before_launch(self):
        for argv in ('python -c code', [], ['python', 42]):
            with self.subTest(argv=argv), self.assertRaises(ValueError):
                processes.execute(argv, self.root, self.log, timeout=1)
        for timeout in (0, -1, float('nan'), float('inf'), True):
            with self.subTest(timeout=timeout), self.assertRaises(ValueError):
                processes.execute([sys.executable], self.root, self.log, timeout)

    @unittest.skipUnless(os.name == 'nt', 'Windows shell script rejection')
    def test_windows_batch_requires_native_launcher(self):
        script = self.root / 'fixture.cmd'
        script.write_text('@echo unsafe', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'native|batch'):
            processes.execute([str(script)], self.root, self.log, timeout=1)


if __name__ == '__main__':
    unittest.main()
