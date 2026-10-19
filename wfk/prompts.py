"""Preview or install shipped user prompts without following destination links."""

import os
import stat
import sys
import tempfile
from pathlib import Path


SOURCES = Path(__file__).resolve().parents[1] / 'prompts'


def default_destinations() -> list[Path]:
    """Return stable and Insiders prompt directories for the current platform."""
    home = Path.home()
    if sys.platform == 'win32':
        root = Path(os.environ.get('APPDATA') or home / 'AppData' / 'Roaming')
    elif sys.platform == 'darwin':
        root = home / 'Library' / 'Application Support'
    else:
        root = Path(os.environ.get('XDG_CONFIG_HOME') or home / '.config')
    return [root / name / 'User' / 'prompts' for name in ('Code', 'Code - Insiders')]


def _linked(path: Path) -> bool:
    if path.is_symlink():
        return True
    try:
        attributes = getattr(path.lstat(), 'st_file_attributes', 0)
    except (FileNotFoundError, NotADirectoryError):
        return False
    return bool(attributes & getattr(stat, 'FILE_ATTRIBUTE_REPARSE_POINT', 0))


def _obstruction(path: Path) -> Path | None:
    for directory in (path.parent, *path.parent.parents):
        if _linked(directory) or (directory.exists() and not directory.is_dir()):
            return directory
    if _linked(path) or (path.exists() and not path.is_file()):
        return path
    return None


def _write(path: Path, content: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix='.wfk-prompt-', dir=path.parent)
    try:
        with os.fdopen(descriptor, 'wb') as stream:
            stream.write(content)
        os.replace(temporary, path)
    finally:
        if Path(temporary).exists():
            Path(temporary).unlink()


def install(apply: bool = False, destinations: list[Path] | None = None) -> dict:
    """Preview all shipped prompts; apply authorizes replacing differing files.

    Unrelated files are untouched. Links, reparse points and non-file collisions
    require manual composition, including when apply is requested. Injected
    destinations support isolated fixtures without touching user installations.
    """
    folders = default_destinations() if destinations is None else destinations
    sources = sorted(SOURCES.glob('*.prompt.md'))
    if not sources:
        raise ValueError(f'No shipped prompt sources found: {SOURCES}')
    contents = [(source.name, source.read_bytes()) for source in sources]
    items, warnings, checklist = [], [], []
    seen = set()
    for folder in folders:
        folder = Path(folder)
        key = os.path.normcase(os.path.abspath(folder))
        if key in seen:
            continue
        seen.add(key)
        for name, content in contents:
            target = folder / name
            obstruction = _obstruction(target)
            if obstruction is not None:
                items.append({'action': 'kept', 'path': str(target)})
                warnings.append(f'Kept {target}: link or non-file collision at {obstruction}.')
                checklist.append(f'Manually compare and install {SOURCES / name} at {target}; '
                                 'the existing destination was preserved.')
                continue
            original = target.read_bytes() if target.exists() else None
            if original == content:
                action = 'unchanged'
            else:
                action = 'install' if original is None else 'rewrite'
                if not apply:
                    action = 'would-' + action
                    if original is not None:
                        warnings.append(f'Existing prompt differs: {target}; --apply replaces '
                                        'its contents. Preserve customizations before applying.')
                else:
                    _write(target, content)
            items.append({'action': action, 'path': str(target)})
    return {'items': items, 'warnings': warnings, 'dry_run': not apply,
            'checklist': checklist}
