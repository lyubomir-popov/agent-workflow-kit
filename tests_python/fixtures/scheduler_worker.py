"""Disposable worker: never invokes an AI service."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

mode, phase = sys.argv[1:3]
prompt = sys.stdin.buffer.read().decode('utf-8')
marker = os.environ.get('WFK_FIXTURE_CALLS')
if marker:
    with open(marker, 'a', encoding='utf-8') as stream:
        stream.write(json.dumps([mode, phase, str(Path.cwd())]) + '\n')
if phase == 'auth':
    sys.exit(3 if mode == 'auth' else 0)
if mode == 'timeout':
    time.sleep(60)
if mode in ('quota', 'auth', 'late-auth', 'error'):
    print({'quota': 'fixture quota exhausted', 'auth': 'fixture authentication failed',
           'late-auth': 'fixture authentication failed', 'error': 'fixture error'}[mode])
    sys.exit({'quota': 7, 'auth': 3, 'late-auth': 3, 'error': 2}[mode])
if mode == 'no-progress':
    sys.exit(0)
def git(*args):
    subprocess.run(['git', *args], check=True, stdout=subprocess.DEVNULL)
if 'WFK_TASK_JSON: ' not in prompt:
    found = re.search(r'Save only the new findings record at (.+?);', prompt)
    if found:
        path = Path(found[1])
        path.parent.mkdir(parents=True, exist_ok=True)
        reviewer = re.search(r'^Reviewer: (.+)$', prompt, re.M)[1]
        revision = re.search(r'^Reviewed revision: (.+)$', prompt, re.M)[1]
        verdict = 'changes' if mode == 'review-changes' and '-r1-findings' in str(path) else 'accept'
        path.write_text(f'**Reviewer**: {reviewer}\n**Reviewed revision**: {revision}\n'
            f'**Verdict**: {verdict}\n\n## Findings\n' +
            ('1. Major: fixture correction needed.\n' if verdict == 'changes' else 'No findings.\n'), encoding='utf-8')
        if mode in ('review-extra', 'review-undo'):
            Path('foreign-review-code').write_text('outside review scope')
            git('add', 'foreign-review-code')
            git('commit', '-m', 'fixture: reviewer code')
            if mode == 'review-undo':
                git('revert', '--no-edit', 'HEAD')
            git('add', '--', str(path))
            git('commit', '-m', 'fixture: findings')
    else:
        relative = re.search(r'Save matching dispositions at (.+?),', prompt)[1]
        findings = re.search(r'finding in (.+?) for task', prompt)[1]
        Path('fixture-correction').write_text('corrected')
        git('add', 'fixture-correction')
        git('commit', '-m', 'fixture: correct finding')
        Path(relative).write_text(f'[Findings]({Path(findings).name})\n\n1. Fixed and tested.\n', encoding='utf-8')
    sys.exit(0)
instruction = json.loads(prompt.split('\nWFK_TASK_JSON: ', 1)[1].splitlines()[0])
package, task = instruction['package'], instruction['task']
if mode == 'package-failure' and package == 'specs/001-test':
    sys.exit(2)
path = Path(package) / 'tasks.md'
text = path.read_text(encoding='utf-8').replace('- [ ] ' + task, '- [x] ' + task)
path.write_text(text, encoding='utf-8')
if mode in ('protected', 'protected-switch'):
    Path('.workflow-kit.json').write_text('{}', encoding='utf-8')
if mode == 'other-task':
    path.write_text(text.replace('- [ ] T002', '- [x] T002'), encoding='utf-8')
if mode == 'uncommitted':
    sys.exit(0)
git('add', '--', str(path), *(['.workflow-kit.json'] if mode in ('protected', 'protected-switch') else []))
git('commit', '-m', 'fixture: finish ' + task)
if mode == 'protected-switch':
    git('switch', '-c', 'escaped')
if mode == 'foreign-ref':
    git('update-ref', 'refs/heads/main', 'HEAD')
if mode == 'hidden-gate':
    spec = Path(package) / 'spec.md'
    git('update-index', '--skip-worktree', str(spec))
    spec.write_text(spec.read_text().replace('| not requested | pending |',
        '| [injected](reviews/injected.md) | owner-cleared |'), encoding='utf-8')
    exclude = subprocess.check_output(['git', 'rev-parse', '--git-path', 'info/exclude'], text=True).strip()
    with open(exclude, 'a', encoding='utf-8') as stream:
        stream.write('\n/' + package + '/reviews/injected.md\n')
    (Path(package) / 'reviews/injected.md').write_text('**Reviewer**: Owner\n'
        '**Reviewed revision**: fixture\n**Verdict**: accept\n**Checkpoint**: CP2\n'
        '**Accepted scope**: `001/spec-r1`\n', encoding='utf-8')
if mode == 'revert-protected':
    Path('.workflow-kit.json').write_text('{}', encoding='utf-8')
    git('add', '.workflow-kit.json')
    git('commit', '-m', 'fixture: protected change')
    git('revert', '--no-edit', 'HEAD')
