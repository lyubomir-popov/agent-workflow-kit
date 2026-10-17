"""Small argument-vector Git adapter. Read commands disable optional locks."""

import os
import subprocess
from pathlib import Path


class GitError(ValueError):
    pass


def git(repo, *args, check=True, env=None):
    environment = dict(os.environ, GIT_OPTIONAL_LOCKS='0', GIT_TERMINAL_PROMPT='0')
    # A hook may inherit repository-local variables. Explicit -C must select
    # the requested checkout, including when inventory spans multiple repos.
    for key in ('GIT_DIR', 'GIT_WORK_TREE', 'GIT_COMMON_DIR', 'GIT_INDEX_FILE',
                'GIT_OBJECT_DIRECTORY', 'GIT_ALTERNATE_OBJECT_DIRECTORIES'):
        environment.pop(key, None)
    if env:
        environment.update(env)
    result = subprocess.run(
        ['git', '-C', str(repo), *map(str, args)], capture_output=True,
        encoding='utf-8', errors='surrogateescape', env=environment,
    )
    if check and result.returncode:
        raise GitError(result.stderr.strip() or result.stdout.strip() or
                       f'Git failed ({result.returncode}): {args[0]}')
    return result


def repo_root(path):
    return Path(git(path, 'rev-parse', '--show-toplevel').stdout.strip()).resolve()


def common_dir(repo):
    return Path(git(repo, 'rev-parse', '--path-format=absolute',
                    '--git-common-dir').stdout.strip()).resolve()


def commit(repo, rev):
    result = git(repo, 'rev-parse', '--verify', '--end-of-options',
                 f'{rev}^{{commit}}', check=False)
    return result.stdout.strip() if result.returncode == 0 else None
