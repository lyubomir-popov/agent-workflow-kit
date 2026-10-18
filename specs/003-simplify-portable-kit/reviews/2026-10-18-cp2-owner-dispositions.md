# CP2 owner-requested correction dispositions

**Author**: GPT implementer
**Checkpoint**: CP2
**Scope**: `003/spec-r1`, owner-directed slice A correction only
**Requested change**: [owner decision](2026-10-17-cp2-owner-decision.md)
**Base revision**: `95b1dee54ad13402cb28bb49d28e6b6b8f4a34b4`
**Integrated revision**: `1a36ab0d040c70e267f71494e288894b35d1802d`

1. **Fixed: aged checkout-only worktrees.** A worktree's landing status now
   depends on target inclusion, while cleanup independently enforces activity
   grace. An unmoved landed existing-branch or detached checkout is kept while
   recent and becomes eligible when older than `cleanupGraceHours`. Movement
   remains informational for worktrees; standalone branch deletion retains its
   existing separate movement/protection/explicit-opt-in checks.
2. **Fixed: empty/expired HEAD logs.** Use admin-directory mtime alone when the
   log is empty or missing. Otherwise use the newer of its newest timestamp and
   admin mtime. Unreadable/malformed nonempty logs still keep the worktree.
   Existing re-validation immediately before removal reads these same guards.
3. **Implemented: manual orphan removal with size.** Orphan rows now include
   disk size (unknown on a failed scan) and always state manual removal. Neither
   `--orphans` nor `--apply` deletes them; the former stays as compatibility
   syntax. Size scans do not follow directory/file symlinks.
4. **Wording reconciled as explicitly requested.** FR-013 describes the grace
   rule and mtime fallback. FR-014 says "Orphan directories are listed with
   size; removal is manual." Plan, tasks and usage now match. These amendments
   are proposed for the owner's CP2 acceptance, not silently marked accepted.

## Verification and scope

The existing-branch and detached fixtures first reproduced permanent retention
after aging their activity outside 24 hours. Empty/missing-log fixtures also
failed before repair; orphan listing initially lacked the required size.
The corrected fixtures test preservation inside grace and removal outside it,
including the mtime fallback. All destructive checks use temporary repos only.
[Validation](2026-10-17-cp2-validation.md) owns aggregate results and commands.

Self-verification only: no subagent or new independent review was needed for
this small directed change. No live cleanup, hook installation, push, merge or
slice B implementation. Both review rounds remain used; CP2 remains pending
for explicit owner clearance, including acceptance of the spec amendments.
