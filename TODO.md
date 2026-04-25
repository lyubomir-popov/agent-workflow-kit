# TODO

## Purpose

This is the active execution queue for the workflow boilerplate repo.

## Maintaining this file

Only open items belong here. Git history and `HISTORY.md` are the record of completed work.

Use priority tags inline:

- `P1` - next important work
- `P2` - useful soon
- `P3` - later or opportunistic

## Short-term

- [ ] P2 Observe the stale-TODO warning across a few more real loop runs and tighten or relax the token matching if it proves noisy.

## Medium-term

- [ ] P2 Decide whether scheduler-owned bookkeeping should stop at `TODO.md`, or also record `HISTORY.md` / `STATUS.md` after each completed task.

## Long-term

- [ ] P3 Decide whether the loop should run on a branch and PR, or commit directly to the current branch.
- [ ] P3 Decide how to handle loop failures: retry once, skip, or stop.

## Open questions

- Optimal `--max-autopilot-continues` for real tasks (5 may be low for complex work).
