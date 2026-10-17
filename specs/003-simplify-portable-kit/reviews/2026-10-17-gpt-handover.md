# Handover: plan and implement Spec 003 slice A

**Recipient**: GPT implementer, using [orchestrate](../../../prompts/orchestrate.prompt.md)
**Scope**: `003/spec-r1`, branch `feat/003-simplify-portable-kit`
**Requested action**: plan the package, then implement slice A and stop at CP2.

## Read first

1. [Spec](../spec.md) – requirements and slice boundaries.
2. [CP1 acceptance](2026-10-17-cp1-owner-acceptance.md) – what is authorized.
3. [AGENTS](../../../AGENTS.md) – Git safety and validation rules.

## Steps

1. Write `plan.md` covering all four slices: Python package layout under the
   kit root, CLI shape, config v2, test approach (stdlib `unittest`, temporary
   Git fixture repos, a fake worker CLI for slice C) and CI matrix.
2. Write `tasks.md` with the bounded current-work header, tasks grouped by
   slice, entry checkpoint CP1, and a gate before each later slice (CP2 before
   slice B, CP3 before C, CP4 before D). Set lifecycle to `active` in the same
   commit.
3. Implement slice A (FR-001–004, FR-010–016) test-first: `wfk wt new|ls|clean`,
   `wfk hooks install`, launchers, and fixtures for every landing style and
   every keep reason in SC-003.
4. Read-only check on the owner's machine: run `wfk wt ls --root <parent of this repo>`
   and compare with per-repo `git worktree list` (SC-002). Do **not** run
   `clean --apply` or `hooks install` against real repos.
5. Save a CP2 review request in `reviews/` (under 30 lines) with the reviewed
   revision, then stop. Opus reviews; the owner clears CP2.

## Constraints

- The PowerShell kit stays in place and working until slice D. Its pre-commit
  hook and quick checks still apply to every commit here.
- Commit locally on the package branch only; no pushes, merges or rebases of
  `main`.
- Each review round follows FR-021–022; do not request extra review rounds.
- Keep code plain: no closeout-style proof machinery. If an edge case needs
  more than a clear "kept: reason", record it as a known limit instead.
- Record validation results once in the package, not per commit.
