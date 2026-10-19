"""Fail-closed worker commit auditing and recoverable branch quarantine."""

import codecs
import re
from datetime import datetime, timezone
from pathlib import PurePosixPath

from .git import git


_NO_REPLACE = {'GIT_NO_REPLACE_OBJECTS': '1'}
_SPEC = re.compile(r'^specs/[^/]+/spec\.md$')
_TASKS = re.compile(r'^specs/[^/]+/tasks\.md$')
_REVIEWS = re.compile(r'^specs/[^/]+/reviews/.+$')
_TASK_LINE = re.compile(r'^\s*- \[([ xX])\] (T\d{3,})\s+(.+)$')
_CHECKBOX = re.compile(r'^\s*- \[[ xX]\]')
_GATE_LABEL = re.compile(
    r'(?im)^[ \t]*(?:[-*][ \t]+)?\*{0,2}'
    r'(?:Reviewed revision|Accepted scope|Checkpoint|Reviewer|Verdict|Scope)'
    r'\*{0,2}:[ \t]*\*{0,2}[^\r\n]*'
)
_RAW = re.compile(
    r':(?P<oldmode>[0-7]{6}) (?P<newmode>[0-7]{6}) '
    r'(?P<old>[0-9a-f]+) (?P<new>[0-9a-f]+) (?P<status>[A-Z])\d*'
)


def _git(repo, *args, check=True):
    return git(repo, *args, check=check, env=_NO_REPLACE)


def _resolve_commit(repo, value):
    result = _git(repo, 'rev-parse', '--verify', '--end-of-options',
                  f'{value}^{{commit}}', check=False)
    return result.stdout.strip() if result.returncode == 0 else None


def _safe_relative(value):
    if not isinstance(value, str) or not value or '\\' in value or value.startswith('/'):
        return False
    parts = PurePosixPath(value).parts
    return bool(parts) and all(part not in ('', '.', '..') for part in parts)


def _linear_commits(repo, base, tip):
    ancestry = _git(repo, 'merge-base', '--is-ancestor', base, tip, check=False)
    if ancestry.returncode == 1:
        return None, [f'history uncertainty: tip {tip} does not descend from base {base}']
    if ancestry.returncode:
        return None, ['history uncertainty: ancestry could not be verified']
    if base == tip:
        return [], []
    result = _git(repo, 'rev-list', '--reverse', '--parents', f'{base}..{tip}',
                  check=False)
    if result.returncode:
        return None, ['history uncertainty: worker commits could not be enumerated']
    commits = []
    expected_parent = base
    for line in result.stdout.splitlines():
        fields = line.split()
        if len(fields) != 2 or fields[1] != expected_parent:
            revision = fields[0] if fields else tip
            return None, [f'history uncertainty: merge/non-linear history at {revision}']
        revision, parent = fields
        commits.append((parent, revision))
        expected_parent = revision
    if not commits or commits[-1][1] != tip:
        return None, ['history uncertainty: enumerated range did not end at tip']
    return commits, []


def _changes(repo, parent, revision):
    result = _git(repo, 'diff-tree', '--no-commit-id', '--raw', '-r', '-z',
                  '--no-renames', parent, revision, check=False)
    if result.returncode:
        raise ValueError('changed paths could not be inspected')
    fields = result.stdout.split('\0')
    if fields and fields[-1] == '':
        fields.pop()
    if len(fields) % 2:
        raise ValueError('malformed NUL-delimited Git diff')
    changes = []
    for index in range(0, len(fields), 2):
        metadata = fields[index].lstrip('\n')
        match = _RAW.fullmatch(metadata)
        if not match:
            raise ValueError('malformed raw Git diff record')
        changes.append(dict(match.groupdict(), path=fields[index + 1]))
    return changes


def _blob(repo, revision, path):
    result = _git(repo, 'show', f'{revision}:{path}', check=False)
    if result.returncode:
        return None
    # git.py uses surrogateescape, so arbitrary committed bytes remain reversible.
    return result.stdout.encode('utf-8', errors='surrogateescape')


def _text(blob):
    if blob is None:
        return ''
    if blob.startswith((codecs.BOM_UTF32_LE, codecs.BOM_UTF32_BE)):
        return blob.decode('utf-32')
    if blob.startswith((codecs.BOM_UTF16_LE, codecs.BOM_UTF16_BE)):
        return blob.decode('utf-16')
    return blob.decode('utf-8-sig', errors='surrogateescape')


def _header(blob):
    return re.split(r'(?m)^##\s', _text(blob), maxsplit=1)[0]


def _task_declarations(blob, path):
    text = _text(blob)
    header = re.split(r'(?m)^##\s', text, maxsplit=1)[0]
    entries = tuple(re.findall(r'(?im)^\*\*Entry checkpoint\*\*:[^\r\n]*', header))
    tasks = []
    seen = set()
    for line in text.splitlines():
        match = _TASK_LINE.match(line)
        if not match:
            if _CHECKBOX.match(line):
                raise ValueError(f'checklist lacks a stable task identity in {path}')
            continue
        checked, identity, description = match.groups()
        if identity in seen:
            raise ValueError(f'duplicate task identity {identity} in {path}')
        seen.add(identity)
        tasks.append({
            'id': identity,
            'complete': checked != ' ',
            'gates': tuple(re.findall(r'(?i)\(\s*gate\b[^)]*\)', description)),
            'manual': tuple(re.findall(r'(?i)\(\s*manual\s*\)', description)),
        })
    return entries, tasks


def _task_reasons(parent_blob, current_blob, path, package, task_id):
    reasons = []
    try:
        old_entries, old_tasks = _task_declarations(parent_blob, path)
        new_entries, new_tasks = _task_declarations(current_blob, path)
    except (UnicodeError, ValueError) as error:
        return [f'task declarations cannot be verified in {path}: {error}']
    if old_entries != new_entries:
        reasons.append(f'task entry checkpoint changed: {path}')
    old_ids = [task['id'] for task in old_tasks]
    new_ids = [task['id'] for task in new_tasks]
    if old_ids != new_ids:
        reasons.append(f'task IDs added, removed or reordered: {path}')
    old_by_id = {task['id']: task for task in old_tasks}
    new_by_id = {task['id']: task for task in new_tasks}
    for identity in old_by_id.keys() & new_by_id.keys():
        old = old_by_id[identity]
        new = new_by_id[identity]
        if old['gates'] != new['gates']:
            reasons.append(f'task gate annotation changed for {identity}: {path}')
        if old['manual'] != new['manual']:
            reasons.append(f'task manual annotation changed for {identity}: {path}')
        if old['complete'] == new['complete']:
            continue
        allowed = (path == f'{package}/tasks.md' and identity == task_id and
                   not old['complete'] and new['complete'])
        if allowed:
            continue
        if not old['complete'] and new['complete']:
            reasons.append(f'unrelated task {identity} newly completed: {path}')
        else:
            reasons.append(
                f'task {identity} checkbox changed outside dispatched completion: {path}'
            )
    return reasons


def _mode_reason(change, kind):
    if change['oldmode'] != change['newmode']:
        return f'{kind} mode changed {change["oldmode"]}->{change["newmode"]}'
    return None


def audit(repo, base, tip, package, task_id, allowed_new_reviews=()):
    """Return every reason a worker commit range must be rejected.

    The range is inspected commit by commit so an owner-file change remains a
    violation even when a later worker commit restores its original bytes.
    """
    if not _safe_relative(package) or not re.fullmatch(r'specs/[^/]+', package):
        return [f'audit uncertainty: unsafe package path {package!r}']
    if not re.fullmatch(r'T\d{3,}', task_id or ''):
        return [f'audit uncertainty: unsafe task identity {task_id!r}']
    try:
        allowed = frozenset(allowed_new_reviews)
    except TypeError:
        return ['audit uncertainty: allowed review paths are not iterable strings']
    for path in allowed:
        if not _safe_relative(path) or not _REVIEWS.fullmatch(path):
            return [f'audit uncertainty: unsafe allowed review path {path!r}']

    base_commit = _resolve_commit(repo, base)
    tip_commit = _resolve_commit(repo, tip)
    if not base_commit or not tip_commit:
        return ['history uncertainty: base or tip is not a commit']
    commits, problems = _linear_commits(repo, base_commit, tip_commit)
    if problems:
        return problems

    reasons = []
    base_reviews = {}
    for parent, revision in commits:
        try:
            changes = _changes(repo, parent, revision)
        except ValueError as error:
            reasons.append(f'{revision}: audit uncertainty: {error}')
            break
        for change in changes:
            path = change['path']
            prefix = f'{revision}: '
            if path == '.workflow-kit.json':
                reasons.append(prefix + f'owner workflow policy changed: {path}')
                mode = _mode_reason(change, 'owner workflow policy')
                if mode:
                    reasons.append(prefix + f'{mode}: {path}')
                continue
            if path == 'docs/specs.md':
                reasons.append(prefix + f'catalog authorization changed: {path}')
                mode = _mode_reason(change, 'catalog authorization')
                if mode:
                    reasons.append(prefix + f'{mode}: {path}')
                continue
            if _SPEC.fullmatch(path):
                mode = _mode_reason(change, 'owner spec')
                if mode:
                    reasons.append(prefix + f'{mode}: {path}')
                if _header(_blob(repo, parent, path)) != _header(_blob(repo, revision, path)):
                    reasons.append(prefix +
                        f'owner spec header/checkpoint table changed: {path}')
                continue
            if _REVIEWS.fullmatch(path):
                if path not in base_reviews:
                    base_reviews[path] = _blob(repo, base_commit, path)
                if base_reviews[path] is not None:
                    reasons.append(prefix +
                        f'existing review record changed, deleted, or renamed: {path}')
                    continue
                current = _blob(repo, revision, path)
                if current is not None and change['newmode'] not in ('100644', '100755'):
                    reasons.append(prefix + f'new review has unsafe mode {change["newmode"]}: {path}')
                    continue
                if path not in allowed and current is not None and _GATE_LABEL.search(_text(current)):
                    reasons.append(prefix + f'new review gate metadata added: {path}')
                continue
            if _TASKS.fullmatch(path):
                mode = _mode_reason(change, 'task owner file')
                if mode:
                    reasons.append(prefix + f'{mode}: {path}')
                for reason in _task_reasons(
                        _blob(repo, parent, path), _blob(repo, revision, path),
                        path, package, task_id):
                    reasons.append(prefix + reason)
    return reasons


def quarantine(repo, base, tip, task_id, branch=None):
    """Preserve *tip*, then atomically rewind a local branch.

    Only refs move. The index and worktree are intentionally left untouched so
    rejected tracked, staged, unstaged, ignored, and untracked bytes remain for
    inspection. With no explicit branch, the caller's symbolic HEAD is used and
    rechecked before the CAS. An explicit branch must be a full ``refs/heads/``
    ref and permits recovery after a worker switches or detaches HEAD.
    """
    if not re.fullmatch(r'T\d{3,}', task_id or ''):
        raise ValueError(f'unsafe task identity: {task_id!r}')
    base_commit = _resolve_commit(repo, base)
    tip_commit = _resolve_commit(repo, tip)
    if not base_commit or not tip_commit:
        raise ValueError('base and tip must resolve to commits')

    implicit = branch is None
    if implicit:
        symbolic = _git(repo, 'symbolic-ref', '--quiet', 'HEAD', check=False)
        if symbolic.returncode:
            raise ValueError('cannot quarantine from detached HEAD')
        branch = symbolic.stdout.strip()
    valid = _git(repo, 'check-ref-format', branch, check=False)
    if (not isinstance(branch, str) or not branch.startswith('refs/heads/') or
            valid.returncode or
            '\n' in branch or '\r' in branch):
        raise ValueError(f'cannot quarantine unsafe HEAD ref: {branch!r}')
    branch_symbolic = _git(repo, 'symbolic-ref', '--quiet', branch, check=False)
    if branch_symbolic.returncode == 0:
        raise ValueError(f'cannot quarantine unsafe symbolic branch ref: {branch!r}')

    timestamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    recovery = None
    zero = '0' * len(tip_commit)
    for suffix in range(100):
        candidate = f'refs/wfk/rejected/{task_id}-{timestamp}'
        if suffix:
            candidate += f'-{suffix}'
        created = _git(repo, 'update-ref', '--no-deref', '-m', f'wfk quarantine {task_id}',
                       candidate, tip_commit, zero, check=False)
        if created.returncode == 0:
            recovery = candidate
            break
    if recovery is None:
        raise RuntimeError('could not create a unique quarantine recovery ref')

    if implicit:
        current_symbolic = _git(repo, 'symbolic-ref', '--quiet', 'HEAD', check=False)
        if current_symbolic.returncode or current_symbolic.stdout.strip() != branch:
            raise RuntimeError(
                f'HEAD changed during quarantine; recovery ref preserved at {recovery}'
            )
    rewound = _git(repo, 'update-ref', '--no-deref', '-m', f'wfk reject {task_id}',
                   branch, base_commit, tip_commit, check=False)
    if rewound.returncode:
        raise RuntimeError(
            f'branch changed before quarantine CAS; recovery ref preserved at {recovery}'
        )
    return recovery
