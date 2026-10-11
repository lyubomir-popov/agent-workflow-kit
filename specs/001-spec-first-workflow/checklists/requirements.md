# Specification quality checklist: Spec-first agent workflow

**Created**: 2026-10-10
**Feature**: [Spec 001](../spec.md)
**Revised**: 2026-10-11
**Purpose**: Author quality check after Opus review and binding owner decisions.

## Content quality

- [x] Mandatory Spec Kit sections contain concrete user journeys.
- [x] Requirements describe workflow behavior without choosing implementation architecture.
- [x] The owner's four concerns are covered; orchestration moves to Spec 002.
- [x] Observed evidence is separated from proposed defaults and future outcomes.

## Requirement completeness

- [x] No unresolved template or clarification markers remain.
- [x] Requirements have observable success and failure conditions.
- [x] Acceptance covers resume, drift, reviews, cleanup, and migration; moved IDs remain stubs.
- [x] Line and byte budgets prevent long-line evasion; their values are proposed defaults.
- [x] Aggregate host and current-work-header budgets prevent split-file and task-header growth.
- [x] Lifecycle/checkpoints have one lifelong owner; only the owner clears gates.
- [x] Catalog is the single resume pointer; declared branches outrank checkout snapshots.
- [x] Spec Kit, configuration, instruction destinations, and upgrade safety are explicit.
- [x] Shared prompts/launchers keep legacy mode; installer activation is separate.
- [x] Closeout preserves paths/numbers, has squash and owner proof, and never writes to target.
- [x] Checks do not claim arbitrary semantic freshness or universal host enforcement.
- [x] Unknown merge proof, ignored evidence, holds, and interrupted closeout are covered.
- [x] Compatibility, unmigrated consumers, branch differences, and archive links are covered.
- [x] Downstream edits, worktree purges, publication, and worker launches are excluded.

## Readiness

- [x] Success criteria are measurable workflow outcomes without invented efficiency claims.
- [x] Assumptions and the current-versus-proposed contract boundary are explicit.
- [x] Saved request, Opus findings, source inventory, and per-finding dispositions exist.
- [x] Slices A/B/C each stop at an owner-run checkpoint.
- [ ] Owner-run Opus review received and blocking findings resolved.

## Notes

This is author validation, not an independent verdict or implementation evidence.
Opus findings are received and author-dispositioned, but the readiness item stays
unchecked pending owner acceptance. The authoritative gate is CP1 in `spec.md`,
still `findings-received`; this checklist cannot clear it. Planning and coding wait.

The closeout-to-`closed` documentation timing is stated in the dispositions for
owner acceptance. Vendor skill files, constitution, scripts, and prompts are
unchanged by this revision.

Revision checks: kit lint has zero findings; 18 local Markdown links resolve;
FR-001–FR-037 and SC-001–SC-009 are unique and ordered; all 20 review findings
have dispositions; no template markers remain. Authored whitespace checks pass.
