# CP2 GPT finding dispositions

**Author**: GPT implementer/orchestrator
**Checkpoint**: CP2
**Scope**: `003/spec-r1`, slice A
**Reviewed revision**: `178bb95` plus the remediation diff; final integrated revision in the CP2 request.

Response to the [independent findings](2026-10-17-cp2-gpt-findings.md).

1. **Fixed**: public `hooks run` now previews by default and requires `--apply`.
   The generated installed hook explicitly opts in; callback regression fixtures
   verify that default invocation preserves the worktree and branch.
2. **Fixed**: install resolves effective hook paths for all available registered
   checkouts and deduplicates shared directories. A linked target fixture checks
   relative hook composition and automatic cleanup without changing hooksPath.
3. **Fixed**: Git resolves the local counterpart of the target ref. Both preview
   and fresh branch deletion preserve it, including detached-primary and full
   remote-ref cases. Hooks use the same resolution for configured remote targets.
4. **Deferred to owner at CP2**: ownerless orphans remain a documented FR-014
   gap. Keep them rather than introducing the forbidden recursive deletion
   fallback. [Known limits](../tasks.md#known-limits) records manual recovery.
5. **Deferred minor**: unavailable registrations and pruning stay conservative;
   the known limit preserves unmounted-drive metadata.
6. **Deferred minor**: future relative-hooksPath checkouts require installation;
   untracked hook directories keep their checkout. No implicit ignore rules.
7. **Deferred minor**: dependency/cache and child-symlink exclusions are named;
   pass the excluded repository directly as a root. Access failures are reported
   without changing trust settings. Actual inventory coverage is in validation.

The [integration findings](2026-10-17-cp2-integration-findings.md) record two
additional resolved discovery defects. No blocker or major remains from the
single GPT review round. Opus review and owner clearance are still outstanding;
no third review round is authorized automatically.
