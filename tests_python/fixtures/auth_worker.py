"""Fake Content-Length-framed Copilot CLI used by auth-probe tests."""

import json
import signal
import subprocess
import sys
import time
from pathlib import Path


SECRET = 'credential-marker-do-not-log'
FLAGS = ['--headless', '--stdio', '--no-auto-update']


def read_request():
    headers = {}
    while True:
        line = sys.stdin.buffer.readline()
        if not line:
            raise RuntimeError('request ended before headers')
        if line in (b'\n', b'\r\n'):
            break
        name, value = line.decode('ascii').split(':', 1)
        headers[name.lower()] = value.strip()
    body = sys.stdin.buffer.read(int(headers['content-length']))
    return json.loads(body.decode('utf-8'))


def frame(value):
    body = json.dumps(value, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
    return b'Content-Length: ' + str(len(body)).encode('ascii') + b'\r\n\r\n' + body


def send(value):
    sys.stdout.buffer.write(frame(value))
    sys.stdout.buffer.flush()


def validate(request, capture):
    valid = (
        sys.argv[-3:] == FLAGS
        and request == {
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'auth.getStatus',
            'params': {},
        }
        and 'session' not in json.dumps(request).casefold()
        and 'model' not in json.dumps(request).casefold()
        and 'login' not in json.dumps(request).casefold()
    )
    Path(capture).write_text(json.dumps({
        'valid': valid,
        'request': request,
        'flags': sys.argv[-3:],
    }), encoding='utf-8')
    if not valid:
        send({'jsonrpc': '2.0', 'id': 1,
              'error': {'code': -32600, 'message': SECRET}})
        raise SystemExit(3)


def main():
    mode, capture = sys.argv[1:3]
    request = read_request()
    validate(request, capture)
    print(SECRET, file=sys.stderr, flush=True)

    if mode == 'success':
        send({'jsonrpc': '2.0', 'id': 1,
              'result': {'isAuthenticated': True, 'login': SECRET}})
    elif mode == 'false':
        send({'jsonrpc': '2.0', 'id': 1,
              'result': {'isAuthenticated': False, 'reason': SECRET}})
    elif mode == 'error':
        send({'jsonrpc': '2.0', 'id': 1,
              'error': {'code': 401, 'message': SECRET, 'data': {'token': SECRET}}})
    elif mode == 'missing':
        send({'jsonrpc': '2.0', 'id': 1, 'result': {'login': SECRET}})
    elif mode == 'malformed':
        body = ('{"jsonrpc":"2.0","id":1,"result":' + SECRET).encode('utf-8')
        sys.stdout.buffer.write(
            b'Content-Length: ' + str(len(body)).encode('ascii') + b'\r\n\r\n' + body)
        sys.stdout.buffer.flush()
    elif mode == 'notify-success':
        for number in range(3):
            send({'jsonrpc': '2.0', 'method': 'status.changed',
                  'params': {'number': number, 'credential': SECRET}})
        send({'jsonrpc': '2.0', 'id': 1, 'result': {'isAuthenticated': True}})
    elif mode == 'notification-flood':
        try:
            for number in range(40):
                send({'jsonrpc': '2.0', 'method': 'status.changed',
                      'params': {'number': number, 'credential': SECRET}})
            send({'jsonrpc': '2.0', 'id': 1, 'result': {'isAuthenticated': True}})
        except BrokenPipeError:
            pass
    elif mode == 'oversize':
        sys.stdout.buffer.write(b'Content-Length: 1048577\r\n\r\n')
        sys.stdout.buffer.flush()
        time.sleep(30)
    elif mode == 'long-header':
        sys.stdout.buffer.write(b'X-Test: ' + (b'x' * 9000) + b'\r\n\r\n')
        sys.stdout.buffer.flush()
        time.sleep(30)
    elif mode == 'response-hang':
        marker, pid_path = map(Path, sys.argv[3:5])
        child = subprocess.Popen([sys.executable, __file__, 'child-marker',
                                  str(marker), str(pid_path)])
        pid_path.write_text(str(child.pid), encoding='utf-8')
        send({'jsonrpc': '2.0', 'id': 1, 'result': {'isAuthenticated': True}})
        signal.signal(signal.SIGINT, signal.SIG_IGN)
        if hasattr(signal, 'SIGBREAK'):
            signal.signal(signal.SIGBREAK, signal.SIG_IGN)
        if hasattr(signal, 'SIGTERM'):
            signal.signal(signal.SIGTERM, signal.SIG_IGN)
        while True:
            time.sleep(.1)
    else:
        raise RuntimeError(f'unknown mode: {mode}')


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'child-marker':
        time.sleep(3)
        Path(sys.argv[2]).write_text('descendant escaped', encoding='utf-8')
        time.sleep(30)
    else:
        main()
