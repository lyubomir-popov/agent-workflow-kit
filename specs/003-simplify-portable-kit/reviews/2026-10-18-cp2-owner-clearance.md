# CP2 owner clearance: slice A worktree hygiene

**Checkpoint**: CP2
**Scope**: `003/spec-r1`
**Reviewed revision**: `f735439fa2e5025edcff889df20c5c916a208bad`
**Reviewer**: Repository owner
**Verdict**: accept
**Accepted scope**: `003/spec-r1`

Date: 2026-10-18. The owner chose "Clear CP2" after Opus confirmed the
[owner-requested correction](2026-10-17-cp2-owner-decision.md). Read-only
cross-repo preview: the landed review checkout is now eligible, and 7 of 133
worktrees would be removed.

Acceptance covers slice A code and records, the FR-013–015 amendments, and the
FR-014 orphan amendment: orphans are listed with size, and removal is manual.
Leftover note for slice B: the `--orphans` flag no longer does anything; remove
it or reject it.

CP2 is cleared and slice B (T007–T010) is authorized on the package branch with
local commits. Pushing, merging, installing real hooks, `clean --apply` on real
repositories and later slices still need separate owner scope.
