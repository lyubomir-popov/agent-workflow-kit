# TODO

## Purpose

This is the active execution queue for the workflow boilerplate repo.

## Active TODO

- [x] Replace the placeholder entries in `docs/specs.md` with real source docs and sibling-repo references for this boilerplate repo.
- [ ] Mirror Stage 2 refinements to active repos (baseline-foundry, brand-layout-ops, canonical-spacing-spec). Each repo's `.github/copilot-instructions.md` and workflow docs should be updated to match the boilerplate, including `AGENT-INBOX.md` handling.
- [ ] Run one real self-hosted task in `repo-workflow-boilerplate` after the scheduler/docs changes are committed or the repo is otherwise clean.

## Open questions

- Should scheduler-owned bookkeeping stop at `TODO.md`, or also record `HISTORY.md` / `STATUS.md` after each completed task?
- Optimal `--max-autopilot-continues` for real tasks (5 may be low for complex work).
- Should the loop run on a branch and PR, or commit directly to master?
- How to handle loop failures: retry once, skip, or stop?
