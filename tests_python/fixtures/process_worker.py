"""Fake subprocesses only; no installed worker CLI is ever used."""

import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path


mode = sys.argv[1]
if mode == 'echo':
    print(json.dumps({'argv': sys.argv[2:], 'cwd': os.getcwd(),
                      'input': sys.stdin.buffer.read().decode('utf-8'),
                      'git_dir': os.environ.get('GIT_DIR'),
                      'custom': os.environ.get('WFK_PROCESS_TEST')}), flush=True)
    print('stderr preserved', file=sys.stderr, flush=True)
elif mode == 'volume':
    for _ in range(1024):
        print('x' * 4096)
elif mode in ('tree', 'exit-tree'):
    child = subprocess.Popen([sys.executable, __file__, 'child', *sys.argv[2:]])
    Path(sys.argv[2]).write_text(str(child.pid), encoding='utf-8')
    print('child ready', flush=True)
    if mode == 'tree':
        signal.signal(signal.SIGINT, signal.SIG_IGN)
        if hasattr(signal, 'SIGBREAK'):
            signal.signal(signal.SIGBREAK, signal.SIG_IGN)
        while True:
            time.sleep(.1)
elif mode == 'child':
    signal.signal(signal.SIGINT, signal.SIG_IGN)
    if hasattr(signal, 'SIGBREAK'):
        signal.signal(signal.SIGBREAK, signal.SIG_IGN)
    time.sleep(1.5)
    Path(sys.argv[3]).write_text('leaked child', encoding='utf-8')
    while True:
        time.sleep(.1)
elif mode == 'sleep':
    print('sleeping', flush=True)
    time.sleep(30)
elif mode == 'interrupt':
    # Exercise the outer scheduler's actual SIGINT handling in an isolated host.
    from wfk.processes import execute
    result = execute([sys.executable, __file__, 'tree', sys.argv[2], sys.argv[3]],
                     Path.cwd(), Path(sys.argv[4]), timeout=20, grace=.1)
    Path(sys.argv[5]).write_text(json.dumps(result), encoding='utf-8')
