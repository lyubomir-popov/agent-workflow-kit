# CP2 owner decision: fix delta finding 1, then clear

**Checkpoint**: CP2
**Scope**: `003/spec-r1`
**Reviewer**: Repository owner
**Reviewed revision**: `79aa90a`
**Verdict**: changes

Date: 2026-10-17. The owner chose "fix minor finding 1 first, then clear" for
the [Opus delta check](2026-10-17-cp2-opus-delta-check.md). CP2 stays pending.
Slice B is not authorized yet.

## Requested change (GPT)

- Landed worktrees with no reflog movement become eligible once outside the
  grace period. Movement is no longer required when the activity time is older
  than `cleanupGraceHours`.
- Activity time is the newer of the HEAD reflog timestamp and the admin
  directory mtime; use the mtime alone when the reflog is empty or expired.
- Keep everything else: protected branches, `--branches` opt-in, the hook
  refusal, and re-validation before removal.
- Fixtures: an unmoved landed detached checkout and an existing-branch checkout
  are kept inside the grace period and removed after it, and an empty reflog
  falls back to the mtime.
- Update the FR-013 wording to match. In FR-014, replace the orphan removal
  sentence with "Orphan directories are listed with size; removal is manual."
- Record dispositions and validation, then stop. The owner then clears CP2,
  accepting the FR-013–015 amendments with it. No further review round.
