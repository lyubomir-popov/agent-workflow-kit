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
Rows include worktrees and landed local branches that have no checkout.

`wfk wt clean` previews cleanup. `wfk wt clean --apply` removes clean landed
worktrees through Git, deletes landed local branches when safe, and prunes
stale metadata. The primary and current checkouts, locked or unavailable paths,
tracked changes, untracked non-ignored files and uncertain landing evidence
keep the checkout. Ignored build output can be removed with a landed checkout.
Remote branches are never deleted. Orphans are reported under configured
scratch roots and kept for manual recovery when Git has no owner that can
remove them safely. `--orphans` is an explicit opt-in for orphan handling;
it does not enable recursive filesystem deletion.

## Automatic cleanup after local Git operations

Preview `wfk hooks install --repo <repo>` and apply it with `--apply`. This adds
`post-merge` and `post-rewrite` wrappers in Git's effective hooks directory,
including an existing relative or absolute `core.hooksPath`. Installation never
changes that setting. Both preview and apply support `--json`.

Existing hooks are backed up beside the wrapper without overwriting a previous
backup. They run first with their original arguments, stdin and working
directory. Cleanup still runs when an existing hook fails; wrapper failures
never fail the Git operation. Repeating installation leaves managed wrappers
unchanged. A non-executable existing hook on POSIX stays inactive.

The wrapper checks the branch in the checkout where Git fired the hook. Only
the resolved target branch runs `wfk wt clean --apply --quiet` for that repo.
The internal callback is `wfk hooks run --repo <checkout>`.

No local Git hook fires when a PR merges remotely. Cleanup runs after the next
local pull of the target branch, when Git invokes `post-merge` or `post-rewrite`.
An already up-to-date pull may not invoke either hook; run cleanup explicitly
when needed. Hook installation is local: generated wrappers remember the
current Python interpreter and kit checkout. After moving either, remove only
the managed wrapper, restore its original hook backup if present, then install
again from the new kit location.

## Configuration

The repo's `.workflow-kit.json` accepts `workflowModelVersion: 2`,
`targetBranch`, `worktreeRoot` and `scratchRoots`. User defaults live at
`~/.config/wfk/config.json`, or the path named by `WFK_CONFIG`; user `repoRoots`
set default discovery roots. Repo values override user defaults. Relative repo
paths resolve from the repo; relative user paths resolve from the config's
directory. `{temp}` expands to the platform's temporary directory.

The target comes from configuration, then `origin/HEAD`, then local `main` or
`master`. Unknown targets preserve work. Version 1 config keeps its shared
target setting and reports the legacy fields the Python kit ignores.
