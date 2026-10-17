# CP2 Opus delta check: slice A remediation

**Checkpoint**: CP2
**Scope**: `003/spec-r1`
**Reviewer**: Opus (GitHub Copilot, Claude Opus 5.5)
**Reviewed revision**: `6ed3022` (records at `cf7ea19`)
**Verdict**: accept

Date: 2026-10-17. Owner-requested targeted check of [round-2 findings](2026-10-17-cp2-opus-findings.md)
1–3; not a new review round. I reran the suite (46 tests, 1 skip, OK) and a
read-only `wt clean --root H:/WSL_dev_projects` dry run (133 worktrees).

## Resolution of findings 1–3

1. **Resolved.** Standalone branches are listed only unless `--branches` is
   given; the hook never passes it; target plus `main`, `master`, `develop`,
   `trunk`, `release/*` and configured patterns are protected.
2. **Resolved.** A worktree needs reflog movement and must be outside a 24-hour
   activity grace period. `wt new` then `clean` keeps it.
3. **Resolved.** Installation refuses any hooks directory inside checkout files,
   before writing, and prints manual composition instructions.

## New findings

1. **Minor – movement rule over-retains checkout-only worktrees.** Worktrees
   created on an existing branch or a detached commit (PR and review checkouts)
   never show movement, so landed ones are never cleaned. Reflogs older than
   90 days can also expire. Today this affects 1 of 133
   (`baseline-foundry/tmp/vanilla-main`). Suggested later fix: unmoved but
   landed worktrees become eligible once outside the grace period, using the
   admin-directory mtime when the reflog is empty. Acceptable as a known limit.
2. **Minor – process.** The implementer amended accepted FR-013–015 in
   `spec.md` and replaced the CP2 request link. The text matches findings 1–3,
   but spec amendments need owner acceptance; include them in the CP2 decision.

## Observation for the owner

The dry run would remove 6 worktrees. Most worktrees are kept correctly: 55 are
primary checkouts, 44 have unlanded commits and 19 have local changes. That bulk
needs your triage; the listing is the tool for it. A stale-age report could be a
catalog candidate, not slice A work.

## Recommendation

Clear CP2, accepting the FR-013–015 amendments and the orphan amendment to
FR-014 ("orphans are listed with size; removal is manual").
