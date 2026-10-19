"""Bounded, opt-in dispatch on package branches with durable local evidence."""
from contextlib import contextmanager
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import time
import traceback
import uuid

from . import config, processes, protection, runtime, workflow, worktrees
from .git import commit, common_dir, git, repo_root


def _dirty(repo):
    output = git(repo, 'status', '--porcelain=v1', '-z', '--untracked-files=all').stdout
    fields, paths, index = output.split('\0'), [], 0
    while index < len(fields) and fields[index]:
        field = fields[index]
        paths.append(field[3:])
        if field[0] in 'RC' or field[1] in 'RC':
            index += 1
            paths.append(fields[index])
        index += 1
    # Porcelain intentionally hides assume-unchanged/skip-worktree files. Such
    # advisory flags are unsuitable for an unattended worker checkout.
    for entry in git(repo, 'ls-files', '-v', '-z').stdout.split('\0'):
        if entry and (entry[0].islower() or entry[0] == 'S'):
            paths.append('Git index advisory flag: ' + entry[2:])
    return paths


def _branch(repo):
    return git(repo, 'symbolic-ref', '--quiet', 'HEAD', check=False).stdout.strip()


def _references(repo):
    return dict(line.split('\0') for line in git(repo, 'for-each-ref',
                '--format=%(refname)%00%(objectname)').stdout.splitlines())


def _restore_refs(repo, before, after, expected):
    """CAS-restore existing foreign refs; preserve new refs for owner inspection."""
    notes = []
    for ref in sorted(before.keys() | after.keys()):
        if ref == expected or before.get(ref) == after.get(ref):
            continue
        old, observed = before.get(ref), after.get(ref)
        if old:
            # Never overwrite a concurrent change made after our observation.
            git(repo, 'update-ref', '--no-deref', '-m', 'wfk restore foreign worker ref', ref, old,
                observed or '0' * len(old))
            notes.append(f'Restored unauthorized ref change: {ref}')
        else:
            notes.append(f'Unauthorized new ref retained for inspection: {ref}')
    return notes


def _fresh(package, source=None):
    value = {key: package[key] for key in ('repo', 'package', 'branch', 'archive', 'version')}
    checkout = source or package['source']
    # Only committed owner records grant unattended authority. Ignored files,
    # sparse/advisory index flags and local edits cannot manufacture clearance.
    value.update(source=None, ref='refs/heads/' + package['branch'])
    value = workflow._parse(value)
    value.update(source=checkout, ref=None if checkout else value['ref'])
    return value


def _next_task(package):
    # gate_problem also reads linked decisions/latest findings. Keep those reads
    # on the same committed authority as the parsed checkpoint and task table.
    return workflow.next_task(dict(package, source=None,
                                   ref='refs/heads/' + package['branch']))


def _select(repo, names):
    version = workflow._settings(repo)['workflowModelVersion']
    rows = workflow.catalog(repo)
    if names:
        unknown = set(names) - {row['package'] for row in rows}
        if unknown:
            raise ValueError('Unknown package(s): ' + ', '.join(sorted(unknown)))
        rows = [row for row in rows if row['package'] in names]
    selected = []
    for row in rows:
        if row['archive']:
            if names:
                raise ValueError(f"Archived package cannot run: {row['package']}")
            continue
        source, ref = workflow._source(repo, row)
        package = workflow._parse(dict(row, repo=repo, source=None,
                                       ref='refs/heads/' + row['branch'], version=version))
        package.update(source=source, ref=ref)
        if names or package['lifecycle'] == 'active':
            selected.append(package)
    return selected


@contextmanager
def _lease(repo, package, run_id):
    directory = common_dir(repo) / 'wfk/locks'
    directory.mkdir(parents=True, exist_ok=True)
    key = hashlib.sha256((package['package'] + '\n' + package['branch']).encode()).hexdigest()
    path = directory / (key + '.lock')
    token = json.dumps(dict(run=run_id, pid=os.getpid(), package=package['package']))
    try:
        with path.open('x', encoding='utf-8') as stream:
            stream.write(token)
    except FileExistsError as exc:
        raise ValueError(f'Package is locked: {path}; inspect its owner before manual recovery') from exc
    try:
        yield
    finally:
        if path.is_file() and path.read_text(encoding='utf-8') == token:
            path.unlink()


def _checkout(repo, package):
    for record in worktrees.records(repo):
        if record.get('branch') != 'refs/heads/' + package['branch']:
            continue
        path = Path(record['worktree']).resolve()
        if path == worktrees.primary(repo).resolve():
            raise ValueError('Package branch occupies the primary checkout; move it to a '
                             'clean linked worktree manually before unattended dispatch')
        if 'locked' in record or 'prunable' in record or not path.is_dir():
            raise ValueError(f'Package worktree is locked or unavailable: {path}')
        if _dirty(path):
            raise ValueError(f'Package worktree has local changes: {path}')
        return path, False
    result = worktrees.new(repo, package['branch'])
    return Path(result['path']).resolve(), True


def _prompt(package, task):
    return (f"Implement only {task['id']} in {package['package']} on branch {package['branch']}.\n"
            f"Task: {task['description']}\n"
            'Read AGENTS.md and the package owners. Test first, commit locally and mark only '
            'this task complete. Do not push, merge, edit gate/header/config/catalog or existing '
            'review records, or execute later tasks. Save any uncertainty and stop.\n'
            'WFK_TASK_JSON: ' + json.dumps(dict(package=package['package'], task=task['id'])) + '\n')


def _dispatch(settings, package, task, agent, log, timeout, phase='task', prompt=None,
              allowed_new_reviews=()):
    """One attempt. Protection runs before any outcome can enable more work."""
    source = package['source']
    expected = 'refs/heads/' + package['branch']
    if _branch(source) != expected or _dirty(source):
        raise ValueError('Worker checkout must be clean and on the declared package branch')
    if phase == 'task':
        latest = _next_task(_fresh(package))
        if latest is None or latest['id'] != task['id']:
            raise ValueError('Task/gate changed before dispatch')
    profile = runtime.profile(settings, agent)
    before = commit(source, 'HEAD')
    refs_before = _references(source)
    prompt = prompt or _prompt(package, task)
    tier = re.search(r'\[([HSLX])\]', task['description'])
    context = dict(prompt=prompt, repo=str(source), package=package['package'],
                   task=task['id'], tier=tier[1] if tier else 'S', review=phase)
    arguments = runtime.argv(settings, agent, profile, context)
    runtime.executable(arguments)
    result = processes.execute(arguments, source, log, timeout,
        grace=settings['scheduler']['grace'],
        input_text=prompt if profile['input'] == 'stdin' else None)
    tip = commit(source, expected)
    refs_after = _references(source)
    violations = protection.audit(source, before, tip, package['package'], task['id'],
                                  allowed_new_reviews=allowed_new_reviews)
    row = dict(agent=agent, phase=phase, base=before, tip=tip,
               duration=result['duration'], log=str(log), commits=[], reason='')
    if tip and before and git(source, 'merge-base', '--is-ancestor', before, tip,
                             check=False).returncode == 0:
        row['commits'] = git(source, 'rev-list', '--reverse', f'{before}..{tip}').stdout.splitlines()
    if _branch(source) != expected or commit(source, 'HEAD') != tip:
        violations.append('Worker changed checkout branch or HEAD')
    if any(ref != expected and refs_before.get(ref) != refs_after.get(ref)
           for ref in refs_before.keys() | refs_after.keys()):
        violations.append('Worker changed refs outside the declared package branch')
    if phase == 'review' and before != tip:
        changed = [path for revision in row['commits'] for path in
                   git(source, 'diff-tree', '--no-commit-id', '--name-only', '-r', '-z',
                       revision + '^', revision).stdout.split('\0')]
        if any(path and path not in allowed_new_reviews for path in changed):
            violations.append('Reviewer committed changes beyond its named new findings')
    if violations:
        row.update(outcome='gate-violation', reason='; '.join(violations))
        try:
            if tip and tip != before:
                row['rejected_ref'] = protection.quarantine(source, before, tip, task['id'], branch=expected)
            else:
                recovery = 'refs/wfk/rejected/' + task['id'] + '-' + uuid.uuid4().hex
                if tip:
                    git(source, 'update-ref', '--no-deref', recovery, tip, '0' * len(tip))
                    row['rejected_ref'] = recovery
        finally:
            row['reason'] += '; ' + '; '.join(_restore_refs(source, refs_before, refs_after, expected))
        return row
    failure = runtime.failure(profile, result)
    dirt = _dirty(source)
    if failure:
        row.update(outcome=failure, reason=f'Worker exit {result["returncode"]}' +
                   ('; local changes retained' if dirt else ''))
    elif dirt and (phase == 'task' or any(path not in allowed_new_reviews for path in dirt)):
        row.update(outcome='uncommitted', reason='Worker left local changes; checkout retained')
    elif phase == 'review':
        row['outcome'] = 'done'
    else:
        current = _fresh(package)
        completed = any(t['id'] == task['id'] and t['complete'] for t in current['tasks'])
        row['outcome'] = 'done' if completed and row['commits'] else 'no-progress'
        if row['outcome'] == 'no-progress':
            row['reason'] = 'Completion requires the task checkbox and a new commit'
    return row


def _preflight(settings, package, agent, log, timeout):
    profile = runtime.profile(settings, agent)
    runtime.executable(profile['command'])
    try:
        arguments = runtime.argv(settings, agent, profile, {}, auth=True)
    except ValueError as exc:
        return 'auth', str(exc)
    runtime.executable(arguments)
    before = commit(package['source'], 'HEAD')
    outcome = processes.execute(arguments, package['source'], log,
        min(timeout, settings['scheduler']['authTimeout']), grace=settings['scheduler']['grace'])
    if before != commit(package['source'], 'HEAD') or _dirty(package['source']):
        raise ValueError('Authentication probe changed the worker checkout; inspect it manually')
    failure = runtime.failure(profile, outcome)
    if failure == 'interrupted':
        return failure, 'Authentication preflight interrupted'
    if failure:
        return 'auth', f'{agent} authentication preflight failed ({failure}); see {log}'
    return None, ''


def _save(result):
    report = Path(result['report'])
    lines = ['# Scheduler run', '', f"Run: {result['run']}", f"Status: {result['status']}",
             f"Repository: {result['repo']}", '', '## Tasks', '']
    for row in result['items']:
        lines.extend([f"- {row['package']} {row['task']}: {row['outcome']}",
                      f"  Worktree: {row['worktree']}"])
        for attempt in row.get('attempts', []):
            lines.append(f"  {attempt['agent']}: {attempt['outcome']} | "
                         f"{attempt.get('duration', 0):.3f}s | log: {attempt['log']}")
            if attempt.get('commits'):
                lines.append('  Commits: ' + ', '.join(attempt['commits']))
            if attempt.get('reason'):
                lines.append('  ' + attempt['reason'].replace('\n', ' '))
            if attempt.get('rejected_ref'):
                lines.append('  Recovery: ' + attempt['rejected_ref'])
    for title, key in [('Review phases', 'reviews'), ('Worktree cleanup', 'cleanup'),
                       ('Stops', 'stops'), ('Errors', 'errors'), ('Warnings', 'warnings')]:
        if result.get(key):
            lines.extend(['', '## ' + title, ''])
            for value in result[key]:
                lines.append('- ' + (json.dumps(value, ensure_ascii=True) if isinstance(value, dict)
                                    else str(value).replace('\n', ' ')))
    temporary = report.with_suffix('.tmp')
    temporary.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    temporary.replace(report)


def _cleanup(repo, owned):
    rows = []
    for path in owned:
        try:
            rows_inventory = worktrees.inventory([repo])['items']
            row = next((r for r in rows_inventory if r.get('path') and
                        Path(r['path']).resolve() == path), None)
            reason = (worktrees._keep_reason(row, worktrees.primary(repo).resolve(), Path.cwd().resolve())
                      if row else 'Worktree inventory unavailable')
            if reason:
                rows.append(dict(path=str(path), action='kept', reason=reason))
                continue
            record = next((r for r in worktrees.records(repo)
                           if Path(r['worktree']).resolve() == path), None)
            target, _ = config.resolve_target(repo)
            if (not record or 'locked' in record or 'prunable' in record or _dirty(path)
                    or not target or not worktrees.landed(repo, commit(path, 'HEAD'), target)):
                rows.append(dict(path=str(path), action='kept', reason='Unlanded, dirty, locked or uncertain'))
                continue
            # No force: Git refuses removal when ignored/local bytes need keeping.
            git(repo, 'worktree', 'remove', '--', str(path))
            rows.append(dict(path=str(path), action='removed'))
        except (ValueError, OSError) as exc:
            rows.append(dict(path=str(path), action='kept', reason=str(exc)))
    return rows


def run(repo, packages=None, agents=None, apply=False, max_tasks=1, max_hours=8,
        task_timeout=1800, review=False, reviewer=None, review_checkpoint=None):
    repo = repo_root(repo)
    result = dict(repo=str(repo), items=[], errors=[], warnings=[], stops=[], reviews=[], cleanup=[],
                  dry_run=not apply, status='preview' if not apply else 'running')
    owned, old_term = [], None
    if apply:
        stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ') + '-' + uuid.uuid4().hex[:8]
        directory = common_dir(repo) / 'wfk/runs' / stamp
        directory.mkdir(parents=True, exist_ok=False)
        result.update(run=stamp, report=str(directory / 'report.md'))
        _save(result)
    try:
        if type(max_tasks) is not int or max_tasks <= 0:
            raise ValueError('max_tasks must be a positive integer')
        runtime.positive(max_hours, 'max_hours')
        runtime.positive(task_timeout, 'task_timeout')
        if apply and not packages:
            raise ValueError('Execution requires explicit --package authorization')
        if packages and (not isinstance(packages, (list, tuple)) or
                         any(not isinstance(p, str) for p in packages)):
            raise ValueError('packages must be a list of catalog package paths')
        names = list(dict.fromkeys(agents or ['codex']))
        settings = runtime.load(repo)
        result['warnings'].extend(settings['warnings'])
        for name in names:
            runtime.profile(settings, name)
        if review:
            reviewer = reviewer or settings['reviewer']
            runtime.profile(settings, reviewer)
            if not review_checkpoint:
                raise ValueError('--review requires --review-checkpoint')
        selected = _select(repo, packages)
        if not apply:
            for package in selected:
                try:
                    task = _next_task(package)
                    result['items'].append(dict(package=package['package'], task=task['id'] if task else None,
                                                action='eligible' if task else 'complete'))
                except ValueError as exc:
                    result['items'].append(dict(package=package['package'], task=None,
                                                action='blocked', reason=str(exc)))
            return result
        deadline = time.monotonic() + max_hours * 3600
        try:
            old_term = signal.getsignal(signal.SIGTERM)
            signal.signal(signal.SIGTERM, lambda *_: (_ for _ in ()).throw(KeyboardInterrupt()))
        except ValueError:  # API may be called from a non-main thread.
            old_term = None
        count, stop_run, agent_index = 0, False, 0
        for package in selected:
            if stop_run or count >= max_tasks or time.monotonic() >= deadline:
                break
            try:
                # No worktree or probe for a blocked/inactive package.
                if _next_task(package) is None:
                    result['stops'].append(f"{package['package']}: no unfinished task")
                    continue
                if review and (review_checkpoint not in package['checkpoints'] or
                               package['checkpoints'][review_checkpoint]['state'] == 'owner-cleared'):
                    raise ValueError('Review checkpoint must exist and await owner clearance')
                with _lease(repo, package, result['run']):
                    source, created = _checkout(repo, package)
                    if created:
                        owned.append(source)
                    package = _fresh(package, source)
                    package['source'], package['ref'] = source, None
                    probed, last_done, used_agent = set(), None, None
                    while count < max_tasks and time.monotonic() < deadline:
                        try:
                            task = _next_task(_fresh(package))
                        except ValueError as exc:
                            result['stops'].append(f"{package['package']}: {exc}")
                            break
                        if task is None:
                            result['stops'].append(f"{package['package']}: no unfinished task")
                            break
                        row = dict(package=package['package'], task=task['id'], worktree=str(source), attempts=[])
                        for index in range(agent_index, len(names)):
                            agent = names[index]
                            remaining = deadline - time.monotonic()
                            if remaining <= 0:
                                break
                            if agent not in probed:
                                failure, reason = _preflight(settings, package, agent,
                                    directory / f'{count + 1}-{agent}-auth.log', remaining)
                                if failure:
                                    result['status'] = failure
                                    result['errors'].append(reason)
                                    stop_run = True
                                    break
                                probed.add(agent)
                            remaining = deadline - time.monotonic()
                            if remaining <= 0:
                                break
                            if row not in result['items']:
                                row.update(outcome='error', reason='Worker attempt did not finalize')
                                result['items'].append(row)
                                _save(result)
                            attempt = _dispatch(settings, package, task, agent,
                                directory / f'{count + 1}-{agent}-task.log', min(task_timeout, remaining))
                            row['attempts'].append(attempt)
                            row.update({key: attempt[key] for key in ('outcome', 'reason', 'rejected_ref') if key in attempt})
                            _save(result)
                            if attempt['outcome'] != 'quota':
                                agent_index = index
                                break
                            # A fallback cannot repeat a task with partial commits or dirt.
                            if attempt['commits'] or _dirty(source) or index == len(names) - 1:
                                break
                            agent_index = index + 1
                        if not row['attempts']:
                            break
                        count += 1
                        _save(result)
                        if stop_run:
                            break
                        if row['outcome'] in ('auth', 'interrupted', 'quota'):
                            result['status'], stop_run = row['outcome'], True
                        if row['outcome'] != 'done':
                            result['errors'].append(f"{package['package']} {task['id']}: {row['outcome']}")
                            break
                        last_done, used_agent = task, row['attempts'][-1]['agent']
                    if review and last_done and not stop_run and all(
                            r['outcome'] == 'done' for r in result['items'] if r['package'] == package['package']):
                        if reviewer not in probed:
                            failure, reason = _preflight(settings, package, reviewer,
                                directory / f'{count}-{reviewer}-review-auth.log', max(.001, deadline-time.monotonic()))
                            if failure:
                                result['status'], stop_run = failure, True
                                result['errors'].append(reason)
                                continue
                        from . import reviews
                        phase_count = [0]
                        def dispatch(phase, agent, prompt, allowed_new_reviews=()):
                            if time.monotonic() >= deadline:
                                return dict(outcome='timeout', reason='Run time limit reached', commits=[])
                            phase_count[0] += 1
                            return _dispatch(settings, package, last_done, agent,
                                directory / f'{count}-{phase_count[0]}-{agent}-{phase}.log',
                                min(task_timeout, deadline-time.monotonic()), phase=phase, prompt=prompt,
                                allowed_new_reviews=allowed_new_reviews)
                        completed_task = next(t for t in _fresh(package)['tasks'] if t['id'] == last_done['id'])
                        reviewed = reviews.run(source, _fresh(package), completed_task, review_checkpoint,
                                               reviewer, used_agent, dispatch, result['run'])
                        result['reviews'].append(dict(package=package['package'], **reviewed))
                        if reviewed['outcome'] != 'accept':
                            result['errors'].append(f"Review: {reviewed['outcome']}: {reviewed.get('reason', '')}")
                            if reviewed['outcome'] in ('auth', 'interrupted'):
                                result['status'], stop_run = reviewed['outcome'], True
            except (ValueError, OSError) as exc:
                result['errors'].append(f"{package['package']}: {exc}")
                _save(result)
        if result['status'] == 'running':
            result['status'] = 'error' if result['errors'] else 'completed'
        if time.monotonic() >= deadline:
            result['stops'].append('Run time limit reached')
        elif count >= max_tasks:
            result['stops'].append('Task limit reached')
    except KeyboardInterrupt:
        result['status'] = 'interrupted'
        result['errors'].append('Run interrupted; committed and uncommitted work retained')
    except Exception as exc:
        result['status'] = 'error'
        result['errors'].append(f'{type(exc).__name__}: {exc}')
        if apply:
            (directory / 'crash.log').write_text(traceback.format_exc(), encoding='utf-8')
    finally:
        if old_term is not None:
            signal.signal(signal.SIGTERM, old_term)
        if apply:
            result['cleanup'] = _cleanup(repo, owned)
            _save(result)
    return result
