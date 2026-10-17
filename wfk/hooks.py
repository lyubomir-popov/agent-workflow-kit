"""Install non-failing Git hook wrappers without changing core.hooksPath."""
from pathlib import Path
import os
import shlex
import stat
import subprocess
import sys
import tempfile

from . import config, git


MARKER = "# wfk managed hook v1"
HOOKS = ("post-merge", "post-rewrite")
KIT = Path(__file__).resolve().parents[1]


def _backup_path(hook: Path) -> Path:
    candidate = hook.with_name(hook.name + ".wfk-original")
    index = 1
    while candidate.exists() or candidate.is_symlink():
        candidate = hook.with_name(hook.name + f".wfk-original.{index}")
        index += 1
    return candidate


def _wrapper(backup: Path | None, executable: bool) -> str:
    lines = ["#!/bin/sh", MARKER]
    # Existing hooks execute first, so they still work if Python or the kit moves.
    # The separate process inherits every argument and the original hook stdin.
    if backup is not None and executable:
        lines.append(f"{shlex.quote(backup.as_posix())} \"$@\" || :")
    program = (f"import sys; sys.path.insert(0, {str(KIT)!r}); "
               "from pathlib import Path; from wfk.hooks import run; run(Path.cwd(), apply=True)")
    lines.append(f"{shlex.quote(Path(sys.executable).as_posix())} -c {shlex.quote(program)} >/dev/null 2>&1 || :")
    lines.append("exit 0")
    return "\n".join(lines) + "\n"


def _install_directory(hooks_dir: Path, apply: bool) -> list[dict]:
    items = []
    for name in HOOKS:
        hook = hooks_dir / name
        if hook.exists() and not hook.is_file():
            raise ValueError(f"Existing hook is not a regular file: {hook}")
        if hook.is_symlink() and not hook.exists():
            raise ValueError(f"Existing hook is a broken symlink: {hook}")
        original = hook.read_bytes() if hook.exists() else None
        if original is not None and original.startswith(f"#!/bin/sh\n{MARKER}\n".encode()):
            items.append({"hook": name, "path": str(hook), "action": "unchanged"})
            continue
        backup = _backup_path(hook) if original is not None else None
        executable = bool(original is not None and
                          (os.name == "nt" or hook.stat().st_mode & 0o111))
        item = {"hook": name, "path": str(hook), "action": "install" if apply else "would-install"}
        if backup is not None:
            item["backup"] = str(backup)
        if apply:
            hooks_dir.mkdir(parents=True, exist_ok=True)
            if backup is not None:
                # Exclusive creation protects both owner backups and concurrent installs.
                with backup.open("xb") as stream:
                    stream.write(original)
                backup.chmod(stat.S_IMODE(hook.stat().st_mode))
            wrapper = _wrapper(backup, executable)
            descriptor, temporary = tempfile.mkstemp(prefix=".wfk-hook-", dir=hooks_dir)
            try:
                with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as stream:
                    stream.write(wrapper)
                Path(temporary).chmod(0o755)
                os.replace(temporary, hook)
            finally:
                if Path(temporary).exists():
                    Path(temporary).unlink()
        items.append(item)
    return items


def install(repo: Path, apply: bool = False) -> dict:
    """Compose effective hooks, refusing checkout files before any writes."""
    from . import worktrees

    repo = git.repo_root(Path(repo))
    common = git.common_dir(repo)
    registrations = worktrees.records(repo)
    checkouts = [Path(record["worktree"]).resolve() for record in registrations]
    directories, diagnostics = {}, []
    for record in registrations:
        checkout = Path(record["worktree"])
        if not checkout.is_dir():
            diagnostics.append(f"Skipped unavailable checkout: {checkout}")
            continue
        try:
            if git.common_dir(checkout) != common:
                diagnostics.append(f"Skipped checkout belonging to another repository: {checkout}")
                continue
            path = Path(git.git(checkout, "rev-parse", "--git-path", "hooks").stdout.strip())
            directory = (path if path.is_absolute() else checkout / path).resolve()
            directories.setdefault(os.path.normcase(str(directory)), directory)
        except (git.GitError, OSError) as error:
            diagnostics.append(f"Skipped checkout {checkout}: {error}")
    # Validate the whole installation before creating any hooks or backups.
    # The common Git directory is administrative storage, even when the primary
    # checkout contains it as .git; checkout files must never receive wrappers.
    for directory in directories.values():
        for checkout in checkouts:
            administrative = common.is_relative_to(checkout) and directory.is_relative_to(common)
            if directory.is_relative_to(checkout) and not administrative:
                target, _ = config.resolve_target(repo)
                target_branch = config.local_target_branch(repo, target) or "<target-branch>"
                manual = ('[ "$(git symbolic-ref --quiet --short HEAD)" = '
                          f'{shlex.quote(target_branch)} ] && wfk wt clean --apply --quiet || :')
                raise ValueError(
                    f"Refusing hook installation: effective hooks directory {directory} "
                    "is inside a registered checkout; generated wrappers contain machine paths.\n"
                    f"Manually compose into the existing hook, running from the checkout: {manual}")
    items = []
    for directory in directories.values():
        items.extend(_install_directory(directory, apply))
    paths = [str(path) for path in directories.values()]
    return {"repo": str(repo), "hooks_dir": paths[0] if paths else None,
            "hooks_dirs": paths, "apply": apply, "items": items,
            "diagnostics": diagnostics, "warnings": diagnostics}


def _cleanup(repo: Path) -> None:
    env = os.environ.copy()
    env["PYTHONPATH"] = str(KIT) + (os.pathsep + env["PYTHONPATH"] if env.get("PYTHONPATH") else "")
    subprocess.run([sys.executable, "-m", "wfk", "wt", "clean", "--repo", str(repo),
                    "--apply", "--quiet"], cwd=repo, env=env,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)


def run(repo: Path, apply: bool = False) -> dict:
    """Best-effort callback using the checkout where Git fired the hook."""
    try:
        repo = git.repo_root(Path(repo))
        target, source = config.resolve_target(repo)
        branch = git.git(repo, "symbolic-ref", "--quiet", "--short", "HEAD", check=False)
        target_branch = config.local_target_branch(repo, target)
        if target is None or branch.returncode or branch.stdout.strip() != target_branch:
            return {"repo": str(repo), "status": "skipped", "reason": "not on target", "target": target}
        if not apply:
            return {"repo": str(repo), "status": "would-clean", "dry_run": True,
                    "target": target, "target_source": source}
        _cleanup(repo)
        return {"repo": str(repo), "status": "completed", "target": target, "target_source": source}
    except Exception as error:
        # A post-operation cleanup failure must never turn a successful Git action into failure.
        return {"repo": str(repo), "status": "skipped", "reason": str(error)}
