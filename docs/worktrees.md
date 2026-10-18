# Worktree commands

The Python kit requires Git 2.38 or newer and Python 3.10 or newer, using only
the standard library. Run `python -m wfk` from the kit checkout, or add its `bin`
directory to PATH and run `wfk` from any directory. The POSIX and Windows
launchers try `python3`, `python`, then `py -3`, checking the Python version.

Create a checkout with `wfk wt new feature/example`. Its default path is
`<repo-parent>/<repo>-worktrees/<branch-slug>`; repo configuration can override
`worktreeRoot`. Use `--from <revision>` to select a starting revision.

`wfk wt ls` reads the current repository's Git metadata, including checkouts in
host-specific folders. Use `--root <folder>` to discover repositories beneath
one or more folders, `--size` for disk usage, and `--json` for structured output.
Rows include worktrees and local branches contained in the target that have no
checkout. Worktree landing depends on the commit's inclusion in the target;
cleanup eligibility also applies the activity grace period.
Discovery skips Git internals, `node_modules`, `.venv`, `__pycache__` and
`.pytest_cache`, and does not follow directory symlinks. Pass an excluded
repository itself as `--root` to inspect it explicitly. Access errors are
reported; listing does not change Git ownership trust settings.

`wfk wt clean` previews cleanup. `wfk wt clean --apply` removes eligible landed
worktrees through Git and their unprotected local branches, then prunes when
safe. Standalone branches are listed only; `wfk wt clean --branches` previews
their deletion and `--branches --apply` opts in. Hooks never request `--branches`.
The target, `main`, `master`, `develop`, `trunk`, `release/*` and additional
`protectedBranches` patterns are always kept, including their worktrees.

The primary and current checkouts, locked or unavailable paths, tracked changes,
untracked non-ignored files and uncertain landing evidence keep the checkout.
Checkout-only worktrees on existing branches or fixed commits become eligible
once landed and outside the grace period, even when their HEAD never moved.

The default 24-hour activity grace also keeps recently active worktrees. Activity
is the newer of the newest HEAD reflog event and the Git admin directory's mtime.
An empty or expired HEAD reflog uses the admin-directory mtime alone. Unreadable
or malformed nonempty logs keep the checkout. Reftable timestamps are not read,
so absent file logs use the admin mtime. Standalone branch deletion retains its
separate branch-reflog movement requirement.
`cleanupGraceHours` changes the interval, with `0` explicitly disabling this age
guard, allowing even fresh landed worktrees to become eligible. Activity,
status, landing and protection are rechecked before
removal. Uncommitted activity visible only in ignored files does not refresh this
Git activity clock.

**Removal deletes ALL ignored files inside the worktree**, including `.env*`,
secrets, local notes, `tmp/` evidence and build output. Ignored does not mean
disposable. Both human and JSON preview reasons state this consequence.
Remote branches are never deleted. Orphans are reported under configured
scratch roots with their disk size, and kept for manual recovery/removal.
Unavailable size is reported as unknown. `--orphans` remains accepted for
compatibility; it never authorizes orphan deletion.

## Automatic cleanup after local Git operations

Preview `wfk hooks install --repo <repo>` and apply it with `--apply`. This adds
`post-merge` and `post-rewrite` wrappers in Git's effective administrative or
external hooks directory. Shared directories are updated once. Installation
never changes `core.hooksPath`. Both preview and apply support `--json`.

Installation refuses when any effective hooks directory is inside a registered
checkout's ordinary files, including relative `.husky`/`.githooks` paths and
absolute paths inside another checkout. It refuses the whole operation before
writing a wrapper or backup. Git's own `.git/hooks` storage is allowed. The error
prints a target-guarded manual composition line for an existing hook, such as
`[ "$(git symbolic-ref --quiet --short HEAD)" = main ] && wfk wt clean --apply --quiet || :`.
Adapt `main` to the resolved target; keep machine-specific paths out of tracked
hook files. Unavailable checkouts are skipped and reported.

Existing hooks are backed up beside the wrapper without overwriting a previous
backup. They run first with their original arguments, stdin and working
directory. Cleanup still runs when an existing hook fails; wrapper failures
never fail the Git operation. Repeating installation leaves managed wrappers
unchanged. A non-executable existing hook on POSIX stays inactive.
Automatic hook failures are currently silent; the callback can be run explicitly
with `--json` for its status. Persistent hook logging is a known limit.

The wrapper checks the branch in the checkout where Git fired the hook. Only
the resolved target branch runs `wfk wt clean --apply --quiet` for that repo.
The callback command `wfk hooks run --repo <checkout>` previews that action;
only `--apply` performs cleanup. Installed wrappers explicitly apply cleanup.

No local Git hook fires when a PR merges remotely. Cleanup runs after the next
local pull of the target branch, when Git invokes `post-merge` or `post-rewrite`.
An already up-to-date pull may not invoke either hook; run cleanup explicitly
when needed. Hook installation is local: generated wrappers remember the
current Python interpreter and kit checkout. After moving either, remove only
the managed wrapper, restore its original hook backup if present, then install
again from the new kit location.

## Configuration

The repo's `.workflow-kit.json` accepts `workflowModelVersion: 2`,
`targetBranch`, `worktreeRoot`, `scratchRoots`, `protectedBranches` (additional
glob patterns) and `cleanupGraceHours` (a finite nonnegative number, default 24).
Protected defaults cannot be removed by configuration. User defaults live at
`~/.config/wfk/config.json`, or the path named by `WFK_CONFIG`; user `repoRoots`
set default discovery roots. Repo values override user defaults. Relative repo
paths resolve from the repo; relative user paths resolve from the config's
directory. `{temp}` expands to the platform's temporary directory.

The target comes from configuration, then `origin/HEAD`, then local `main` or
`master`. Unknown targets preserve work. Version 1 config keeps its shared
target setting and reports the legacy fields the Python kit ignores.
