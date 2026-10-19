"""Bounded, read-only Copilot authentication probe.

This module is deliberately standalone so an auth check does not import the
rest of wfk.  The scheduler owns the deadline and process-tree containment.
"""

import json
import signal
import subprocess
import sys


MAX_FRAME_BYTES = 1024 * 1024
MAX_HEADER_BYTES = 8192
MAX_NOTIFICATIONS = 32
CLI_FLAGS = ('--headless', '--stdio', '--no-auto-update')


class ProbeError(Exception):
    """A protocol or child-process failure with no printable payload."""


def _frame(value):
    body = json.dumps(value, ensure_ascii=False,
                      separators=(',', ':')).encode('utf-8')
    return b'Content-Length: ' + str(len(body)).encode('ascii') + b'\r\n\r\n' + body


def _read_exact(stream, length):
    chunks = []
    remaining = length
    while remaining:
        chunk = stream.read(remaining)
        if not chunk:
            raise ProbeError()
        chunks.append(chunk)
        remaining -= len(chunk)
    return b''.join(chunks)


def _read_message(stream):
    content_length = None
    consumed = 0
    while True:
        remaining = MAX_HEADER_BYTES - consumed
        if remaining <= 0:
            raise ProbeError()
        line = stream.readline(remaining + 1)
        if not line or len(line) > remaining:
            raise ProbeError()
        consumed += len(line)
        if line in (b'\n', b'\r\n'):
            break
        if not line.endswith(b'\n') or b':' not in line:
            raise ProbeError()
        name, value = line.rstrip(b'\r\n').split(b':', 1)
        try:
            name = name.decode('ascii').strip().casefold()
            value = value.decode('ascii').strip()
        except UnicodeDecodeError as exc:
            raise ProbeError() from exc
        if name == 'content-length':
            if content_length is not None or not value.isdecimal():
                raise ProbeError()
            content_length = int(value)
    if content_length is None or content_length > MAX_FRAME_BYTES:
        raise ProbeError()
    try:
        message = json.loads(_read_exact(stream, content_length).decode('utf-8'))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ProbeError() from exc
    if not isinstance(message, dict):
        raise ProbeError()
    return message


def _is_notification(message):
    return (message.get('jsonrpc') == '2.0'
            and isinstance(message.get('method'), str)
            and bool(message['method'])
            and 'id' not in message
            and 'result' not in message
            and 'error' not in message)


def _read_auth_result(stream):
    notifications = 0
    while True:
        message = _read_message(stream)
        if _is_notification(message):
            notifications += 1
            if notifications > MAX_NOTIFICATIONS:
                raise ProbeError()
            continue
        if (message.get('jsonrpc') != '2.0'
                or type(message.get('id')) is not int
                or message['id'] != 1
                or 'error' in message
                or 'result' not in message
                or not isinstance(message['result'], dict)):
            raise ProbeError()
        authenticated = message['result'].get('isAuthenticated')
        if authenticated is True:
            return True
        if authenticated is False:
            return False
        raise ProbeError()


def _spawn(argv):
    """Avoid losing a child to Ctrl-C during the narrow Popen startup window."""
    previous = signal.getsignal(signal.SIGINT)
    interrupted = False

    def defer_interrupt(_signum, _frame):
        nonlocal interrupted
        interrupted = True

    changed = False
    try:
        signal.signal(signal.SIGINT, defer_interrupt)
        changed = True
    except ValueError:
        pass
    try:
        process = subprocess.Popen(
            argv,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            shell=False,
        )
    finally:
        if changed:
            signal.signal(signal.SIGINT, previous)
    if interrupted:
        _stop(process)
        raise KeyboardInterrupt
    return process


def _stop(process):
    """Terminate the CLI leader; the outer runner owns remaining descendants."""
    previous = signal.getsignal(signal.SIGINT)
    changed = False
    try:
        try:
            signal.signal(signal.SIGINT, signal.SIG_IGN)
            changed = True
        except ValueError:
            pass
        if process.poll() is None:
            try:
                process.terminate()
            except OSError:
                pass
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                try:
                    process.kill()
                except OSError:
                    pass
                process.wait()
        else:
            process.wait()
    finally:
        for stream in (process.stdin, process.stdout):
            if stream is not None:
                try:
                    stream.close()
                except OSError:
                    pass
        if changed:
            signal.signal(signal.SIGINT, previous)


def check(argv):
    """Return the explicit auth status from one native Copilot CLI argv."""
    if (not isinstance(argv, list) or not argv
            or any(not isinstance(arg, str) or not arg or '\0' in arg for arg in argv)):
        raise ProbeError()
    process = _spawn([*argv, *CLI_FLAGS])
    try:
        if process.stdin is None or process.stdout is None:
            raise ProbeError()
        process.stdin.write(_frame({
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'auth.getStatus',
            'params': {},
        }))
        process.stdin.flush()
        return _read_auth_result(process.stdout)
    except (BrokenPipeError, OSError) as exc:
        raise ProbeError() from exc
    finally:
        _stop(process)


def main(argv=None):
    """Run the probe. Arguments after ``--`` are the native Copilot argv."""
    arguments = list(sys.argv[1:] if argv is None else argv)
    if len(arguments) < 2 or arguments[0] != '--':
        print('Authentication probe requires native Copilot argv')
        return 2
    try:
        authenticated = check(arguments[1:])
    except KeyboardInterrupt:
        print('Authentication check interrupted')
        return 1
    except Exception:
        print('Authentication check failed')
        return 1
    if authenticated:
        print('Authenticated')
        return 0
    print('Authentication required')
    return 1


if __name__ == '__main__':
    raise SystemExit(main())
