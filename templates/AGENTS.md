# Agent instructions

Read the repository's contribution instructions before making changes. Preserve
unrelated work and obey the owner's repository boundaries and checkpoint gates.

Start at [the catalog](docs/specs.md) and resolve each package on its declared
branch. Read `INBOX.md` and `AGENT-INBOX.md`. Package `spec.md` owns intent,
lifecycle and checkpoints; `plan.md` owns approach; `tasks.md` owns execution.
Save complete review findings and matching dispositions under package `reviews/`.
Only the owner clears gates; stop at the next uncleared checkpoint.

Create a task checkout with `wfk wt new <branch>` from the repository. This uses
the configured worktree root, defaulting to the sibling `<repo>-worktrees/`
directory. Use `--from <revision>` when the task needs a particular starting point.

Git metadata also tracks worktrees that a host creates elsewhere. Inspect them
with `wfk wt ls`; preview cleanup with `wfk wt clean` before applying it.
Keep dirty, untracked, locked and unlanded work until the owner resolves it.

Run the repository's required checks before handing off. Report what changed,
the checks run, unresolved limitations and any owner decision still required.
Use `wfk lint` for offline workflow checks alongside the project's own checks.
