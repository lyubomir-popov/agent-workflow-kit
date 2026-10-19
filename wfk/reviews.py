"""Bounded saved reviews in an isolated worker checkout; never clears gates.

The caller owns worker execution and protection.audit for every dispatch.
Only a sole validated new evidence file may be committed here after dispatch.
"""

import hashlib
import re
import tempfile
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath

from .git import git
from .workflow import labels


def _safe(value):
    if not isinstance(value, str) or not value:
        raise ValueError('Review identifiers must be nonempty strings')
    slug = re.sub(r'[^a-zA-Z0-9_-]+', '-', value).strip('-')[:48] or 'run'
    return slug + '-' + hashlib.sha256(value.encode()).hexdigest()[:12]


def _path(root, name):
    parts = PurePosixPath(name).parts
    if (not parts or '\\' in name or ':' in name or name.startswith('/') or
            any(part in ('.', '..') for part in parts)):
        raise ValueError('Review path must be repository-relative')
    path = root
    for part in parts:
        path = path / part
        if path.is_symlink():
            raise ValueError('Review path contains a symlink')
    if not path.resolve().is_relative_to(root):
        raise ValueError('Review path escapes the checkout')
    return path


def _snapshot(directory):
    result = {}
    if directory.exists():
        for path in directory.rglob('*'):
            if path.is_symlink():
                raise ValueError('Review evidence contains a symlink')
            if path.is_file():
                result[path.relative_to(directory).as_posix()] = path.read_bytes()
    return result


def _nonindependent(identity):
    return bool(re.search(r'\b(?:self|integration)[ -]review\b', identity, re.I))


def _count(snapshot, checkpoint):
    pattern = re.compile(r'^\d{4}-\d{2}-\d{2}-' + re.escape(checkpoint) +
                         r'-.+-findings\.md$', re.I)
    total = 0
    for name, data in snapshot.items():
        if not pattern.match(PurePosixPath(name).name):
            continue
        # Our two hashed identities and explicit round suffix mark dispatched
        # independent reviews. Even invalid/spoofed saved headers consume a
        # round; neither profile names nor run IDs may opt out of the cap.
        if re.search(r'-[0-9a-f]{12}-.+-[0-9a-f]{12}-r\d+-findings\.md$', name):
            total += 1
            continue
        # Only explicit header identities affect classification, never body prose.
        text = data.decode('utf-8-sig', errors='replace')
        try:
            identity = labels(text).get('reviewer', '')
        except ValueError:
            identity = ''  # Malformed independent evidence still consumes a round.
        if _nonindependent(identity):
            continue
        total += 1
    return total


def _head(repo):
    return git(repo, 'rev-parse', 'HEAD').stdout.strip()


def _dirty(repo):
    raw = git(repo, 'status', '--porcelain=v1', '-z', '--untracked-files=all').stdout
    entries = raw.split('\0')
    paths = []
    index = 0
    while index < len(entries):
        entry = entries[index]
        index += 1
        if not entry:
            continue
        if len(entry) < 4 or 'R' in entry[:2] or 'C' in entry[:2]:
            raise ValueError('Unexpected rename/copy in review checkout')
        paths.append(entry[3:])
    return paths


def _findings(path, revision, reviewer):
    if path.is_symlink() or not path.is_file():
        raise ValueError('Missing regular findings file')
    text = path.read_text(encoding='utf-8-sig')
    fields = labels(text)
    if (fields.get('reviewer') != reviewer or _nonindependent(fields['reviewer']) or
            fields.get('reviewed revision') != revision):
        raise ValueError('Findings must name the dispatched independent profile and full reviewed HEAD')
    verdict = fields.get('verdict')
    if verdict not in ('accept', 'changes', 'blocker'):
        raise ValueError('Missing or invalid findings verdict')
    for finding in re.findall(r'(?m)^\d+\.\s+(.+)$', text):
        if not re.match(r'\W*(blocker|major|minor)\b', finding, re.I):
            raise ValueError('Finding lacks blocker, major or minor severity')
    return verdict


def _dispositions(path, findings):
    if path.is_symlink() or not path.is_file():
        raise ValueError('Missing regular dispositions file')
    text = path.read_text(encoding='utf-8-sig')
    original = findings.read_text(encoding='utf-8-sig')
    numbers = set(re.findall(r'(?m)^(\d+)\.\s+', original))
    answers = set(re.findall(r'(?m)^(\d+)\.\s+\S.+$', text))
    if findings.name not in text or not numbers or not numbers.issubset(answers):
        raise ValueError('Dispositions must link findings and answer every numbered finding')


def _save(repo, relative):
    """Commit exactly the expected new record, bypassing repository hooks."""
    paths = _dirty(repo)
    if any(path != relative for path in paths):
        raise ValueError('Unexpected dirty files after review dispatch')
    if paths:
        with tempfile.TemporaryDirectory(prefix='wfk empty hooks ') as hooks:
            git(repo, 'add', '--', relative)
            git(repo, '-c', 'core.hooksPath=' + hooks, 'commit', '--only', '-m',
                'review: save scheduler evidence', '--', relative)
    if _dirty(repo):
        raise ValueError('Review evidence left unexpected dirty files')
    if git(repo, 'cat-file', '-e', 'HEAD:' + relative, check=False).returncode:
        raise ValueError('Review evidence was not committed')


def run(repo, package, task, checkpoint, reviewer, implementer, dispatch, run_id):
    """Review completed work with at most two independent rounds across runs.

    dispatch(phase, agent, prompt, allowed_new_reviews=()) returns an outcome
    dict. Failed outcomes are returned immediately without retry or fallback.
    """
    rounds, total = [], 0

    def result(outcome, reason):
        return dict(outcome=outcome, rounds=rounds, review_rounds=total, reason=reason)

    try:
        root = Path(repo).resolve()
        if not re.fullmatch(r'CP\d+', checkpoint):
            raise ValueError('Invalid checkpoint identifier')
        if package.get('source') is None or Path(package['source']).resolve() != root:
            raise ValueError('Review package source must be the worker checkout')
        state = package.get('checkpoints', {}).get(checkpoint, {}).get('state')
        if state not in ('pending', 'findings-received'):
            raise ValueError('Review requires an existing uncleared checkpoint')
        if not task.get('complete'):
            raise ValueError('Review requires a completed task')
        if _dirty(root):
            raise ValueError('Review requires a clean worker checkout')
        directory = _path(root, package['package'] + '/reviews')
        snapshot = _snapshot(directory)
        total = _count(snapshot, checkpoint)
        if total >= 2:
            return result('changes', 'Two independent review rounds already saved; owner action required')
        identity = _safe(reviewer)
        if _nonindependent(reviewer):
            raise ValueError('Configured reviewer must identify an independent review profile')
        run_identity = _safe(run_id)
        date = datetime.now(timezone.utc).date().isoformat()
        directory.mkdir(parents=True, exist_ok=True)
        while total < 2:
            total += 1
            name = f'{date}-{checkpoint}-{identity}-{run_identity}-r{total}-findings.md'
            relative = package['package'] + '/reviews/' + name
            findings = _path(root, relative)
            if findings.exists() or findings.is_symlink():
                raise ValueError('Review evidence path already exists')
            revision = _head(root)
            prompt = (f'Follow /review in prompts/review.prompt.md for {package["package"]}, '
                f'checkpoint {checkpoint}, completed task {task["id"]}. '
                f'Save only the new findings record at {relative}; never overwrite evidence.\n'
                f'Reviewer: {reviewer}\nReviewed revision: {revision}\n'
                'Verdict: <accept | changes | blocker>\n'
                'Use these exact header names; Reviewer must equal the dispatched profile ID '
                'shown above, without claiming an unverified CLI model. This is an independent '
                'review, never a self or integration review. Use numbered blocker/major/minor findings. '
                'Review actual code and validation; reply only with path and verdict. '
                'Only the owner clears gates; do not edit owners or implement fixes.')
            response = dispatch('review', reviewer, prompt, allowed_new_reviews=(relative,))
            rounds.append(dict(response, phase='review', path=relative, round=total))
            if response.get('outcome') != 'done':
                return result(response.get('outcome', 'error'), response.get('reason', 'Review dispatch failed'))
            try:
                _path(root, relative)
                verdict = _findings(findings, revision, reviewer)
            except (ValueError, OSError, UnicodeError) as exc:
                return result('review-missing', str(exc))
            after = _snapshot(directory)
            if any(after.get(key) != value for key, value in snapshot.items()):
                return result('gate-violation', 'Existing evidence changed')
            changed = git(root, 'diff', '--name-only', revision, 'HEAD').stdout.splitlines()
            if any(path != relative for path in changed):
                return result('gate-violation', 'Reviewer committed changes beyond its new findings')
            try:
                _save(root, relative)
            except ValueError as exc:
                return result('gate-violation', str(exc))
            if verdict == 'accept':
                return result('accept', 'Saved review accepts; checkpoint still requires owner clearance')
            if total >= 2:
                return result('changes', 'Required changes remain after two rounds; owner action required')
            snapshot = _snapshot(directory)
            disposition_relative = relative.removesuffix('-findings.md') + '-dispositions.md'
            disposition = _path(root, disposition_relative)
            if disposition.exists():
                raise ValueError('Dispositions evidence path already exists')
            before = _head(root)
            prompt = (f'Address every numbered finding in {relative} for task {task["id"]}. '
                f'Save matching dispositions at {disposition_relative}, linking findings and '
                'answering each number with fix and validation or justified minor deferral. '
                'Make at least one implementation commit before saving dispositions. '
                'Preserve existing evidence, completed task status, owners and checkpoints; '
                'do not clear gates or start a review.')
            response = dispatch('address', implementer, prompt,
                                allowed_new_reviews=(disposition_relative,))
            rounds.append(dict(response, phase='address', path=disposition_relative, round=total))
            if response.get('outcome') != 'done':
                return result(response.get('outcome', 'error'), response.get('reason', 'Address dispatch failed'))
            after = _snapshot(directory)
            if any(after.get(key) != value for key, value in snapshot.items()):
                return result('gate-violation', 'Existing evidence changed during remediation')
            try:
                _path(root, disposition_relative)
                _dispositions(disposition, findings)
                changed = git(root, 'diff', '--name-only', before, 'HEAD').stdout.splitlines()
                if not any(path != disposition_relative for path in changed):
                    raise ValueError('Address round requires an implementation commit')
            except (ValueError, OSError, UnicodeError) as exc:
                return result('review-missing', str(exc))
            try:
                _save(root, disposition_relative)
            except ValueError as exc:
                return result('gate-violation', str(exc))
            snapshot = _snapshot(directory)
    except (ValueError, OSError, UnicodeError) as exc:
        return result('error', str(exc))
