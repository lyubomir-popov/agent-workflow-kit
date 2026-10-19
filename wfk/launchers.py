"""Resolve configured workers to native process argument vectors.

Windows npm commands are represented by shell wrappers.  This module uses a
small package/entrypoint allowlist and package metadata to locate the JavaScript
entrypoint without reading, interpreting, or executing wrapper text.
"""

import json
import os
import shutil
from pathlib import Path, PurePosixPath


_NPM_ENTRYPOINTS = {
    'codex': ('@openai/codex', 'bin/codex.js'),
    'copilot': ('@github/copilot', 'npm-loader.js'),
    'claude': ('@anthropic-ai/claude-code', 'cli.js'),
}
_WINDOWS_SUFFIXES = ('.exe', '.cmd', '.bat', '.ps1')
_MAX_PACKAGE_JSON = 1024 * 1024


def _arguments(argv):
    if (not isinstance(argv, list) or not argv
            or any(not isinstance(arg, str) or '\0' in arg for arg in argv)):
        raise ValueError('worker argv must be a nonempty list of strings without NUL')
    if not argv[0]:
        raise ValueError('worker executable must not be empty')
    return list(argv)


def _path_directories():
    for value in os.environ.get('PATH', '').split(os.pathsep):
        if value:
            yield Path(value)


def _windows_candidates(command, cwd):
    path = Path(command)
    explicit = path.is_absolute() or path.parent != Path('.')
    bases = [path if path.is_absolute() else cwd / path] if explicit else [
        directory / path for directory in _path_directories()
    ]
    has_suffix = bool(path.suffix)
    for base in bases:
        paths = [base] if has_suffix else [Path(f'{base}{suffix}')
                                           for suffix in _WINDOWS_SUFFIXES]
        for candidate in paths:
            if candidate.is_file():
                yield candidate.resolve(), explicit


def _read_package_json(path):
    try:
        with path.open('rb') as stream:
            raw = stream.read(_MAX_PACKAGE_JSON + 1)
    except OSError as exc:
        raise ValueError(f'npm package metadata unavailable: {path}') from exc
    if len(raw) > _MAX_PACKAGE_JSON:
        raise ValueError(f'npm package metadata is too large: {path}')
    try:
        value = json.loads(raw.decode('utf-8'))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValueError(f'invalid npm package metadata: {path}') from exc
    if not isinstance(value, dict):
        raise ValueError(f'invalid npm package metadata: {path}')
    return value


def _declared_entry(metadata, command):
    bins = metadata.get('bin')
    if not isinstance(bins, dict) or not isinstance(bins.get(command), str):
        raise ValueError(f'npm package metadata does not declare {command!r}')
    declared = bins[command].replace('\\', '/')
    path = PurePosixPath(declared)
    if path.is_absolute() or not path.parts or '..' in path.parts:
        raise ValueError(f'npm package metadata has an unsafe entry for {command!r}')
    return PurePosixPath(*[part for part in path.parts if part != '.'])


def _native_node(shim_directory):
    local = shim_directory / 'node.exe'
    if local.is_file():
        return local.resolve()
    for directory in _path_directories():
        candidate = directory / 'node.exe'
        if candidate.is_file():
            return candidate.resolve()
    raise ValueError('npm worker requires a native Node executable; node.cmd and node.ps1 are unsafe')


def _npm_launch(shim, arguments):
    command = shim.stem.casefold()
    known = _NPM_ENTRYPOINTS.get(command)
    if known is None:
        return None
    package_name, expected_text = known
    package = shim.parent / 'node_modules'
    for part in package_name.split('/'):
        package /= part
    if not package.is_dir():
        return None

    metadata = _read_package_json(package / 'package.json')
    if metadata.get('name') != package_name:
        raise ValueError(f'npm package metadata name mismatch for {command!r}')
    declared = _declared_entry(metadata, command)
    expected = PurePosixPath(expected_text)
    if declared != expected:
        raise ValueError(f'npm package metadata entry mismatch for {command!r}')

    package_root = package.resolve()
    entry = package.joinpath(*expected.parts).resolve()
    if not entry.is_relative_to(package_root) or not entry.is_file():
        raise ValueError(f'npm worker entrypoint is missing or unsafe: {entry}')
    node = _native_node(shim.parent)
    return [str(node), str(entry), *arguments]


def _windows(argv, cwd):
    wrappers_found = False
    for candidate, explicit in _windows_candidates(argv[0], cwd):
        suffix = candidate.suffix.casefold()
        if suffix == '.exe':
            return [str(candidate), *argv[1:]]
        wrappers_found = True
        if suffix in ('.cmd', '.bat', '.ps1'):
            resolved = _npm_launch(candidate, argv[1:])
            if resolved is not None:
                return resolved
        if explicit:
            break
    if wrappers_found:
        raise ValueError('Windows shell wrapper has no validated native launcher')
    raise ValueError(f'Worker executable unavailable: {argv[0]}')


def resolve(argv, cwd=None, platform=None):
    """Return a native process argv, preserving every configured argument.

    ``platform`` exists for deterministic cross-platform fixture coverage; normal
    callers omit it.  POSIX vectors remain unchanged, with explicit executable
    paths checked before dispatch.  Windows vectors resolve to an absolute native
    executable or to native Node plus a validated known npm entrypoint.
    """
    arguments = _arguments(argv)
    selected_platform = os.name if platform is None else platform
    if selected_platform not in ('nt', 'posix'):
        raise ValueError('platform must be nt or posix')
    working_directory = Path.cwd() if cwd is None else Path(cwd)
    if selected_platform == 'nt':
        return _windows(arguments, working_directory.resolve())

    executable = Path(arguments[0])
    candidate = None
    if executable.is_absolute():
        candidate = executable
    elif executable.parent != Path('.'):
        candidate = working_directory / executable
    if candidate is not None:
        if not candidate.is_file():
            raise ValueError(f'Worker executable unavailable: {arguments[0]}')
        if not os.access(candidate, os.X_OK):
            raise ValueError(f'Worker executable unavailable: {arguments[0]}')
    elif shutil.which(arguments[0], path=os.environ.get('PATH')) is None:
        raise ValueError(f'Worker executable unavailable: {arguments[0]}')
    return arguments
