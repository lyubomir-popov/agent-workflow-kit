"""Bounded worker execution with durable output and owned process trees.

The caller classifies the log; output is never captured in memory. Windows
workers start suspended inside a kill-on-close Job Object before they can
create children. POSIX workers get a new session/process group. Descendants
must remain in that containment (deliberate POSIX setsid escape is unsupported).
"""

import math
import os
import shutil
import signal
import subprocess
import tempfile
import time
from pathlib import Path


_GIT_LOCAL = ('GIT_DIR', 'GIT_WORK_TREE', 'GIT_COMMON_DIR', 'GIT_INDEX_FILE',
              'GIT_OBJECT_DIRECTORY', 'GIT_ALTERNATE_OBJECT_DIRECTORIES',
              'GIT_PREFIX', 'GIT_IMPLICIT_WORK_TREE', 'GIT_SHALLOW_FILE',
              'GIT_CONFIG', 'GIT_CONFIG_PARAMETERS', 'GIT_CONFIG_COUNT')


def _environment(overrides):
    environment = dict(os.environ)
    for key in list(environment):
        if key in _GIT_LOCAL or key.startswith(('GIT_CONFIG_KEY_', 'GIT_CONFIG_VALUE_')):
            environment.pop(key, None)
    if overrides is not None:
        environment.update(overrides)
    return environment


def _number(value, name, zero=False):
    if (isinstance(value, bool) or not isinstance(value, (int, float))
            or not math.isfinite(value) or (value < 0 if zero else value <= 0)):
        raise ValueError(f'{name} must be a finite {"nonnegative" if zero else "positive"} number')


def _kill_group(pid, sig):
    try:
        os.killpg(pid, sig)
    except ProcessLookupError:
        pass


def _close_without_interrupt(process):
    # A second Ctrl-C must not abandon containment while the scheduler is
    # preparing its final report. signal.signal is main-thread-only.
    previous = signal.getsignal(signal.SIGINT)
    changed = False
    try:
        try:
            signal.signal(signal.SIGINT, signal.SIG_IGN)
            changed = True
        except ValueError:
            pass
        return process.close()
    finally:
        if changed:
            signal.signal(signal.SIGINT, previous)


class _PosixProcess:
    def __init__(self, argv, cwd, stdin, output, env):
        self.process = subprocess.Popen(argv, cwd=cwd, stdin=stdin, stdout=output,
                                        stderr=output, env=env, start_new_session=True)

    def poll(self):
        return self.process.poll()

    def interrupt(self):
        _kill_group(self.process.pid, signal.SIGINT)

    def close(self):
        # Do this even after the group leader exits: children may still own the
        # output file or continue modifying a worktree.
        _kill_group(self.process.pid, signal.SIGKILL)
        return self.process.wait()


class _WindowsProcess:
    def __init__(self, argv, cwd, stdin, output, env):
        import ctypes
        import msvcrt
        from ctypes import wintypes as wt

        class StartupInfo(ctypes.Structure):
            _fields_ = [('cb', wt.DWORD), ('lpReserved', wt.LPWSTR),
                        ('lpDesktop', wt.LPWSTR), ('lpTitle', wt.LPWSTR),
                        ('dwX', wt.DWORD), ('dwY', wt.DWORD),
                        ('dwXSize', wt.DWORD), ('dwYSize', wt.DWORD),
                        ('dwXCountChars', wt.DWORD), ('dwYCountChars', wt.DWORD),
                        ('dwFillAttribute', wt.DWORD), ('dwFlags', wt.DWORD),
                        ('wShowWindow', wt.WORD), ('cbReserved2', wt.WORD),
                        ('lpReserved2', ctypes.POINTER(wt.BYTE)),
                        ('hStdInput', wt.HANDLE), ('hStdOutput', wt.HANDLE),
                        ('hStdError', wt.HANDLE)]

        class ProcessInfo(ctypes.Structure):
            _fields_ = [('hProcess', wt.HANDLE), ('hThread', wt.HANDLE),
                        ('dwProcessId', wt.DWORD), ('dwThreadId', wt.DWORD)]

        class BasicLimit(ctypes.Structure):
            _fields_ = [('PerProcessUserTimeLimit', ctypes.c_longlong),
                        ('PerJobUserTimeLimit', ctypes.c_longlong),
                        ('LimitFlags', wt.DWORD), ('MinimumWorkingSetSize', ctypes.c_size_t),
                        ('MaximumWorkingSetSize', ctypes.c_size_t),
                        ('ActiveProcessLimit', wt.DWORD), ('Affinity', ctypes.c_size_t),
                        ('PriorityClass', wt.DWORD), ('SchedulingClass', wt.DWORD)]

        class IoCounters(ctypes.Structure):
            _fields_ = [(name, ctypes.c_ulonglong) for name in
                        ('ReadOperationCount', 'WriteOperationCount', 'OtherOperationCount',
                         'ReadTransferCount', 'WriteTransferCount', 'OtherTransferCount')]

        class ExtendedLimit(ctypes.Structure):
            _fields_ = [('BasicLimitInformation', BasicLimit), ('IoInfo', IoCounters),
                        ('ProcessMemoryLimit', ctypes.c_size_t),
                        ('JobMemoryLimit', ctypes.c_size_t),
                        ('PeakProcessMemoryUsed', ctypes.c_size_t),
                        ('PeakJobMemoryUsed', ctypes.c_size_t)]

        self.ctypes = ctypes
        self.kernel = kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        signatures = {
            'CreateJobObjectW': ([ctypes.c_void_p, wt.LPCWSTR], wt.HANDLE),
            'SetInformationJobObject': ([wt.HANDLE, ctypes.c_int, ctypes.c_void_p, wt.DWORD], wt.BOOL),
            'AssignProcessToJobObject': ([wt.HANDLE, wt.HANDLE], wt.BOOL),
            'TerminateJobObject': ([wt.HANDLE, wt.UINT], wt.BOOL),
            'TerminateProcess': ([wt.HANDLE, wt.UINT], wt.BOOL),
            'CloseHandle': ([wt.HANDLE], wt.BOOL),
            'ResumeThread': ([wt.HANDLE], wt.DWORD),
            'WaitForSingleObject': ([wt.HANDLE, wt.DWORD], wt.DWORD),
            'GetExitCodeProcess': ([wt.HANDLE, ctypes.POINTER(wt.DWORD)], wt.BOOL),
            'GenerateConsoleCtrlEvent': ([wt.DWORD, wt.DWORD], wt.BOOL),
            'CreateProcessW': ([wt.LPCWSTR, wt.LPWSTR, ctypes.c_void_p, ctypes.c_void_p,
                                wt.BOOL, wt.DWORD, ctypes.c_void_p, wt.LPCWSTR,
                                ctypes.POINTER(StartupInfo), ctypes.POINTER(ProcessInfo)], wt.BOOL),
        }
        for name, (args, result) in signatures.items():
            function = getattr(kernel, name)
            function.argtypes, function.restype = args, result

        self.job = kernel.CreateJobObjectW(None, None)
        self.handle = None
        info = ProcessInfo()
        if not self.job:
            raise ctypes.WinError(ctypes.get_last_error())
        try:
            limits = ExtendedLimit()
            limits.BasicLimitInformation.LimitFlags = 0x2000  # KILL_ON_JOB_CLOSE
            if not kernel.SetInformationJobObject(self.job, 9, ctypes.byref(limits),
                                                 ctypes.sizeof(limits)):
                raise ctypes.WinError(ctypes.get_last_error())
            startup = StartupInfo()
            startup.cb, startup.dwFlags = ctypes.sizeof(startup), 0x100  # USESTDHANDLES
            input_handle = msvcrt.get_osfhandle(stdin.fileno())
            output_handle = msvcrt.get_osfhandle(output.fileno())
            startup.hStdInput = input_handle
            startup.hStdOutput = startup.hStdError = output_handle
            handles = (input_handle, output_handle)
            inherited = [os.get_handle_inheritable(handle) for handle in handles]
            try:
                for handle in handles:
                    os.set_handle_inheritable(handle, True)
                command = ctypes.create_unicode_buffer(subprocess.list2cmdline(argv))
                environment = ctypes.create_unicode_buffer(
                    '\0'.join(f'{key}={value}' for key, value in
                              sorted(env.items(), key=lambda item: item[0].upper())) + '\0')
                # CREATE_SUSPENDED | CREATE_NEW_PROCESS_GROUP | CREATE_UNICODE_ENVIRONMENT
                if not kernel.CreateProcessW(argv[0], command, None, None, True,
                                             0x4 | 0x200 | 0x400, environment,
                                             str(cwd), ctypes.byref(startup), ctypes.byref(info)):
                    raise ctypes.WinError(ctypes.get_last_error())
            finally:
                for handle, previous in zip(handles, inherited):
                    os.set_handle_inheritable(handle, previous)
            self.handle, self.pid = info.hProcess, info.dwProcessId
            if not kernel.AssignProcessToJobObject(self.job, self.handle):
                raise ctypes.WinError(ctypes.get_last_error())
            if kernel.ResumeThread(info.hThread) == 0xffffffff:
                raise ctypes.WinError(ctypes.get_last_error())
        except BaseException:
            if info.hProcess:
                kernel.TerminateProcess(info.hProcess, 1)
                kernel.WaitForSingleObject(info.hProcess, 0xffffffff)
                kernel.CloseHandle(info.hProcess)
            kernel.CloseHandle(self.job)
            self.job = self.handle = None
            raise
        finally:
            if info.hThread:
                kernel.CloseHandle(info.hThread)

    def poll(self):
        from ctypes import wintypes as wt
        state = self.kernel.WaitForSingleObject(self.handle, 0)
        if state == 0x102:  # WAIT_TIMEOUT
            return None
        if state != 0:
            raise self.ctypes.WinError(self.ctypes.get_last_error())
        code = wt.DWORD()
        if not self.kernel.GetExitCodeProcess(self.handle, self.ctypes.byref(code)):
            raise self.ctypes.WinError(self.ctypes.get_last_error())
        return code.value

    def interrupt(self):
        # Best effort: a GUI/detached caller may have no shared console. The
        # owned Job Object is authoritative after the grace period.
        self.kernel.GenerateConsoleCtrlEvent(1, self.pid)  # CTRL_BREAK_EVENT

    def close(self):
        try:
            if not self.kernel.TerminateJobObject(self.job, 1):
                raise self.ctypes.WinError(self.ctypes.get_last_error())
            self.kernel.WaitForSingleObject(self.handle, 0xffffffff)
            return self.poll()
        finally:
            self.kernel.CloseHandle(self.handle)
            self.kernel.CloseHandle(self.job)


def execute(argv, cwd, log, timeout, grace=2, input_text=None, env=None):
    """Run an argv list and return status after containing all descendants.

    Return keys: returncode, timed_out, interrupted, duration (seconds), log
    (path string). KeyboardInterrupt is consumed after tree cleanup so callers
    can write their final report. Launch errors raise ValueError with a log
    already created. Windows .cmd/.bat workers need a configured native launcher.
    """
    if not isinstance(argv, list) or not argv or any(
            not isinstance(arg, str) or '\0' in arg for arg in argv):
        raise ValueError('worker argv must be a nonempty list of strings without NUL')
    _number(timeout, 'timeout')
    _number(grace, 'grace', zero=True)
    if input_text is not None and not isinstance(input_text, str):
        raise ValueError('input_text must be text')
    cwd, log = Path(cwd), Path(log)
    log.parent.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    timed_out = interrupted = False
    process = None
    returncode = None
    with log.open('wb') as output, tempfile.TemporaryFile() as stdin:
        try:
            if input_text is not None:
                stdin.write(input_text.encode('utf-8'))
                stdin.seek(0)
            environment = _environment(env)
            args = list(argv)
            if os.name == 'nt':
                candidate = args[0]
                if not Path(candidate).is_absolute() and os.path.dirname(candidate):
                    candidate = str(cwd / candidate)
                executable = shutil.which(candidate, path=environment.get('PATH'))
                if not executable:
                    raise ValueError(f'worker executable not found: {args[0]}')
                if Path(executable).suffix.lower() in ('.bat', '.cmd'):
                    raise ValueError('Windows batch workers require a native executable launcher')
                args[0] = str(Path(executable).resolve())
            try:
                cls = _WindowsProcess if os.name == 'nt' else _PosixProcess
                process = cls(args, cwd, stdin, output, environment)
            except OSError as exc:
                raise ValueError(f'cannot launch worker executable {argv[0]}: {exc}') from exc
            try:
                while process.poll() is None:
                    remaining = timeout - (time.monotonic() - started)
                    if remaining <= 0:
                        timed_out = True
                        break
                    time.sleep(min(.05, remaining))
            except KeyboardInterrupt:
                interrupted = True
            if timed_out or interrupted:
                process.interrupt()
                deadline = time.monotonic() + grace
                while time.monotonic() < deadline:
                    try:
                        time.sleep(min(.05, max(0, deadline - time.monotonic())))
                    except KeyboardInterrupt:
                        interrupted = True
                        break
        except KeyboardInterrupt:
            # Also cover interruption during launch setup or signal delivery.
            # Native startup owns its partially created process until it returns.
            interrupted = True
        finally:
            try:
                if process is not None:
                    returncode = _close_without_interrupt(process)
            finally:
                output.flush()
                os.fsync(output.fileno())
    return {'returncode': returncode, 'timed_out': timed_out,
            'interrupted': interrupted, 'duration': time.monotonic() - started,
            'log': str(log)}
