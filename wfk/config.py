"""User defaults and per-repository settings, without migration side effects."""

import json
import os
import tempfile
from pathlib import Path

from .git import commit, git


def _read(path):
    if not path.exists():
        return {}
    try:
        value = json.loads(path.read_text(encoding='utf-8-sig'))
    except (OSError, ValueError) as exc:
        raise ValueError(f'Cannot read config {path}: {exc}') from exc
    if not isinstance(value, dict):
        raise ValueError(f'Config must be an object: {path}')
    version = value.get('workflowModelVersion', 2)
    if type(version) is not int or version not in (1, 2):
        raise ValueError(f'Unsupported workflowModelVersion in {path}: {version}')
    for key in ('repoRoots', 'scratchRoots'):
        if key in value and (not isinstance(value[key], list) or
                             any(not isinstance(p, str) for p in value[key])):
            raise ValueError(f'{key} must be a list of paths: {path}')
    for key in ('targetBranch', 'worktreeRoot'):
        if key in value and (not isinstance(value[key], str) or not value[key]):
            raise ValueError(f'{key} must be a nonempty string: {path}')
    return value


def _path(value, base):
    path = Path(value.replace('{temp}', tempfile.gettempdir())).expanduser()
    return str((base / path).resolve() if not path.is_absolute() else path.resolve())


def load(repo=None):
    user_path = Path(os.environ.get('WFK_CONFIG', '~/.config/wfk/config.json')).expanduser()
    user = _read(user_path)
    local = _read(Path(repo) / '.workflow-kit.json') if repo is not None else {}
    result = dict(user, **local)
    result['warnings'] = []
    for data, name in ((user, 'user config'), (local, 'repo config')):
        if data.get('workflowModelVersion') == 1:
            ignored = sorted(set(data) - {'workflowModelVersion', 'targetBranch'})
            if ignored:
                result['warnings'].append(f'{name}: ignored v1 fields: {", ".join(ignored)}')
    # Version-one-only fields never silently acquire version-two meaning.
    for key in ('repoRoots', 'scratchRoots', 'worktreeRoot'):
        source = local if key in local else user
        base = Path(repo) if source is local and repo is not None else user_path.parent
        raw = source.get(key) if source.get('workflowModelVersion', 2) == 2 else None
        if key == 'worktreeRoot':
            result.pop(key, None)
            if raw:
                result[key] = _path(raw, base)
        else:
            result[key] = [_path(p, base) for p in (raw or [])]
    defaults = [str(Path(tempfile.gettempdir()) / 'agent-loop-worktrees')]
    result['scratchRoots'] = list(dict.fromkeys(defaults + result['scratchRoots']))
    result['target_source'] = ('repo config' if 'targetBranch' in local else
                               'user config' if 'targetBranch' in user else None)
    return result


def resolve_target(repo):
    settings = load(repo)
    if settings.get('targetBranch'):
        target = settings['targetBranch']
        return (target if commit(repo, target) else None, settings['target_source'])
    remote = git(repo, 'symbolic-ref', '--quiet', 'refs/remotes/origin/HEAD', check=False)
    if remote.returncode == 0:
        target = remote.stdout.strip().removeprefix('refs/remotes/')
        return (target if commit(repo, target) else None, 'origin/HEAD')
    for name in ('main', 'master'):
        if commit(repo, f'refs/heads/{name}'):
            return name, name
    return None, 'unknown'
