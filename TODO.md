# TODO

## Purpose

This is the active execution queue for the workflow boilerplate repo.

## Active TODO

- [ ] Observe the stale-TODO warning across a few more real loop runs and tighten or relax the token matching if it proves noisy.

## Open questions

- Should scheduler-owned bookkeeping stop at `TODO.md`, or also record `HISTORY.md` / `STATUS.md` after each completed task?
- Optimal `--max-autopilot-continues` for real tasks (5 may be low for complex work).
- Should the loop run on a branch and PR, or commit directly to master?
- How to handle loop failures: retry once, skip, or stop?
