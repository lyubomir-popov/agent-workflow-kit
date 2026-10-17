"""Git-metadata inventory and conservative, explicit worktree cleanup."""

import os
import re
import tempfile
from pathlib import Path

from . import config
from .git import GitError, commit, common_dir, git, repo_root


def records(repo):
    output = git(repo, 'worktree', 'list', '--porcelain', '-z').stdout
    result, row = [], {}
    for field in output.split('\0'):
        if not field:
            if row:
                result.append(row)
                row = {}
            continue
        key, _, value = field.partition(' ')
        row[key] = value
    if row:
        result.append(row)
    # With --separate-git-dir Git reports the metadata directory as its first
    # worktree. The invoking primary checkout supplies the actual root.
    directory = Path(git(repo, 'rev-parse', '--absolute-git-dir').stdout.strip()).resolve()
    if result and directory == common_dir(repo):
        result[0]['worktree'] = str(repo_root(repo))
    return result


def primary(repo):
    return Path(records(repo)[0]['worktree']).resolve()


def discover(roots):
    """Walk requested roots; deduplicate linked and separate-git-dir repos."""
    repos, seen, warnings = [], set(), []

    def add(path):
        try:
            root = repo_root(path)
            key = os.path.normcase(str(common_dir(root)))
            if key not in seen:
                seen.add(key)
                repos.append(primary(root))
        except (GitError, OSError) as exc:
            warnings.append(f'{path}: {exc}')

    for raw in roots:
        root = Path(raw).expanduser().resolve()
        if not root.is_dir():
            warnings.append(f'Root unavailable: {root}')
            continue
        if (root / '.git').exists():
            add(root)
        for folder, dirs, files in os.walk(root, followlinks=False,
                                           onerror=lambda e: warnings.append(str(e))):
            path = Path(folder)
            if '.git' in dirs or '.git' in files:
                add(path)
            dirs[:] = [d for d in dirs if d not in {
                '.git', 'node_modules', '__pycache__', '.venv', '.pytest_cache',
            } and not (path / d).is_symlink()]
    return repos, warnings


def landed(repo, revision, target):
    if not target or not revision:
        return False
    tip = commit(repo, target)
    rev = commit(repo, revision)
    if not tip or not rev:
        return False
    if git(repo, 'merge-base', '--is-ancestor', rev, tip, check=False).returncode == 0:
        return True
    target_tree = git(repo, 'rev-parse', f'{tip}^{{tree}}').stdout.strip()
    # merge-tree writes tree objects even when only asked to inspect landing.
    # Isolate those objects instead of changing the owner's object database.
    objects = git(repo, 'rev-parse', '--path-format=absolute', '--git-path',
                  'objects').stdout.strip()
    with tempfile.TemporaryDirectory(prefix='wfk-merge-') as temporary:
        result = git(repo, 'merge-tree', '--write-tree', tip, rev, check=False,
                     env={'GIT_OBJECT_DIRECTORY': temporary,
                          'GIT_ALTERNATE_OBJECT_DIRECTORIES': objects})
    return result.returncode == 0 and result.stdout.splitlines()[0] == target_tree


def _size(path):
    total = 0
    try:
        for folder, dirs, files in os.walk(path, followlinks=False):
            dirs[:] = [d for d in dirs if not (Path(folder) / d).is_symlink()]
            for name in files:
                file = Path(folder) / name
                if not file.is_symlink():
                    total += file.stat().st_size
    except OSError:
        return None
    return total


def _base(repo, target, source):
    return dict(kind='worktree', repo=str(repo), path=None, branch=None, commit=None,
                tracked=False, untracked=False, locked=False, prunable=False,
                landed=False, target=target, target_source=source, last_commit=None,
                size_bytes=None, status='unknown', reason='')


def _worktree(repo, record, target, source, size=False):
    row = _base(repo, target, source)
    row.update(path=record['worktree'], branch=record.get('branch', '').removeprefix(
        'refs/heads/') or None, commit=record.get('HEAD'),
        locked='locked' in record, prunable='prunable' in record)
    path = Path(row['path'])
    row['last_commit'] = git(repo, 'show', '-s', '--format=%cI', row['commit'],
                             check=False).stdout.strip() or None
    row['landed'] = landed(repo, row['commit'], target)
    if not path.is_dir():
        row.update(status='unavailable', reason='directory unavailable; registration preserved')
        return row
    try:
        if common_dir(path) != common_dir(repo) or repo_root(path) != path.resolve():
            row.update(status='unknown', reason='worktree Git link does not match repository')
            return row
        result = git(path, 'status', '--porcelain=v1', '-z', '--untracked-files=all',
                     '--ignore-submodules=none')
        # Rename entries have a second NUL-delimited path; skip that path.
        entries = iter(result.stdout.split('\0'))
        for entry in entries:
            if not entry:
                continue
            if entry.startswith('??'):
                row['untracked'] = True
            else:
                row['tracked'] = True
                if 'R' in entry[:2] or 'C' in entry[:2]:
                    next(entries, None)
        row['status'] = 'dirty' if row['tracked'] or row['untracked'] else 'clean'
        if size:
            row['size_bytes'] = _size(path)
    except (GitError, OSError) as exc:
        row.update(status='unknown', reason=f'cannot inspect: {exc}')
    return row


def _orphans(scratch_roots):
    result, seen = [], set()
    for scratch in scratch_roots:
        root = Path(scratch).resolve()
        if not root.is_dir():
            continue
        for folder, dirs, files in os.walk(root, followlinks=False):
            path = Path(folder)
            dirs[:] = [d for d in dirs if d != '.git' and not (path / d).is_symlink()]
            if '.git' not in files or (path / '.git').is_symlink():
                continue
            dirs[:] = []
            try:
                link = (path / '.git').read_text(encoding='utf-8').strip()
                if not link.startswith('gitdir: '):
                    continue
                metadata = (path / link[8:]).resolve()
                orphan = not metadata.is_dir()
                if not orphan:
                    try:
                        known = records(path)
                        orphan = not any(Path(r['worktree']).resolve() == path.resolve()
                                         for r in known)
                    except GitError:
                        orphan = True
                key = os.path.normcase(str(path.resolve()))
                if orphan and key not in seen:
                    seen.add(key)
                    row = _base(None, None, 'unknown')
                    row.update(kind='orphan', repo=None, path=str(path), status='orphan',
                               reason='orphan has no Git owner; manual removal required')
                    result.append(row)
            except (OSError, ValueError):
                continue
    return result


def inventory(repos, size=False, scratch_roots=None):
    items, warnings, scratch = [], [], list(scratch_roots or [])
    for repo in repos:
        repo = Path(repo).resolve()
        settings = config.load(repo)
        warnings.extend(settings['warnings'])
        scratch.extend(settings['scratchRoots'])
        target, source = config.resolve_target(repo)
        checkout_records = records(repo)
        checked = {r.get('branch') for r in checkout_records}
        for record in checkout_records:
            items.append(_worktree(repo, record, target, source, size))
        refs = git(repo, 'for-each-ref', '--format=%(refname) %(objectname) %(committerdate:iso-strict)',
                   'refs/heads/').stdout.splitlines()
        for line in refs:
            ref, sha, *date = line.split(' ', 2)
            if ref in checked or not landed(repo, sha, target):
                continue
            row = _base(repo, target, source)
            row.update(kind='branch', branch=ref.removeprefix('refs/heads/'), commit=sha,
                       landed=True, last_commit=date[0] if date else None, status='no worktree')
            items.append(row)
    items.extend(_orphans(list(dict.fromkeys(scratch))))
    return dict(items=items, warnings=list(dict.fromkeys(warnings)))


def new(repo, branch, start=None):
    repo = primary(repo_root(repo))
    git(repo, 'check-ref-format', '--branch', branch)
    slug = re.sub(r'[^A-Za-z0-9._-]+', '-', branch).strip('.')
    if not slug or slug in ('.', '..'):
        raise ValueError('Branch has no usable path slug')
    settings = config.load(repo)
    root = Path(settings.get('worktreeRoot', repo.parent / (repo.name + '-worktrees')))
    path = root / slug
    exists = commit(repo, 'refs/heads/' + branch)
    if exists and start:
        raise ValueError('--from cannot reset an existing branch')
    args = ['worktree', 'add']
    if not exists:
        args += ['-b', branch]
    args += ['--', str(path), branch if exists else (start or 'HEAD')]
    git(repo, *args)
    return dict(path=str(path), branch=branch, warnings=settings['warnings'])


def _contains(parent, child):
    return child == parent or parent in child.parents


def _keep_reason(row, primary_path, cwd):
    if Path(row['path']).resolve() == primary_path:
        return 'primary checkout'
    if _contains(Path(row['path']).resolve(), cwd):
        return 'current directory is inside this worktree'
    if row['locked']:
        return 'locked'
    if row['status'] not in ('clean', 'dirty'):
        return row['reason'] or row['status']
    if row['tracked']:
        return 'tracked changes'
    if row['untracked']:
        return 'untracked files'
    if not row['target']:
        return 'unknown target'
    if not row['landed']:
        return 'unlanded commits'
    return ''


def _delete_branch(repo, row):
    branch = row['branch']
    target, _ = config.resolve_target(repo)
    if not branch or branch == config.local_target_branch(repo, target) or not landed(repo, branch, target):
        return 'branch is target or no longer landed'
    if any(r.get('branch') == 'refs/heads/' + branch for r in records(repo)):
        return 'branch is checked out elsewhere'
    if commit(repo, branch) != row['commit']:
        return 'branch changed during cleanup'
    git(repo, 'branch', '-D', '--', branch)
    return ''


def clean(repos, apply=False, quiet=False, orphans=False, scratch_roots=None):
    result = inventory(repos, scratch_roots=scratch_roots)
    result['dry_run'] = not apply
    cwd = Path.cwd().resolve()
    touched = set()
    for row in result['items']:
        row['action'] = 'keep'
        if row['kind'] == 'orphan':
            if not orphans:
                row['reason'] = 'orphan; --orphans required (manual removal if no Git owner)'
            continue
        repo = Path(row['repo'])
        if row['kind'] == 'branch':
            if row['branch'] == config.local_target_branch(repo, row['target']):
                row['reason'] = 'target branch'
                continue
            row.update(action='delete-branch', reason='landed local branch without worktree')
            if apply:
                reason = _delete_branch(repo, row)
                if reason:
                    row.update(action='keep', reason=reason)
            continue
        reason = _keep_reason(row, primary(repo), cwd)
        if reason:
            row['reason'] = reason
            continue
        row.update(action='remove', reason='clean and landed')
        if not apply:
            continue
        try:
            # Re-read registration, status and landing immediately before Git removal.
            record = next((r for r in records(repo) if Path(r['worktree']).resolve() ==
                           Path(row['path']).resolve()), None)
            if record is None:
                row.update(action='keep', reason='registration changed during cleanup')
                continue
            target, source = config.resolve_target(repo)
            fresh = _worktree(repo, record, target, source)
            reason = _keep_reason(fresh, primary(repo), cwd)
            if reason or fresh['commit'] != row['commit']:
                row.update(action='keep', reason=reason or 'commit changed during cleanup')
                continue
            # --force permits ignored build output; dirty/untracked files were excluded.
            git(repo, 'worktree', 'remove', '--force', '--', row['path'])
            touched.add(repo)
            if row['branch']:
                reason = _delete_branch(repo, row)
                if reason:
                    row['reason'] += '; branch kept: ' + reason
        except (GitError, OSError) as exc:
            row.update(action='keep' if Path(row['path']).exists() else 'remove',
                       reason=f'cleanup incomplete: {exc}')
            result['warnings'].append(row['reason'])
    for repo in touched:
        # Git cannot distinguish a deleted path from an unmounted drive. Never
        # prune registrations for unavailable checkouts automatically.
        if any(not Path(r['worktree']).is_dir() for r in records(repo)):
            result['warnings'].append(f'{repo}: prune skipped; unavailable worktree registered')
        else:
            git(repo, 'worktree', 'prune')
    return result
