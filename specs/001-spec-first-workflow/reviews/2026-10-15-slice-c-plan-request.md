# Adoption implementation plan approval request

Scope: `001/spec-r2`, slice C planning.
Planning base: `0d2bda7`; review the commit containing this request.
Authority: [owner planning-only acceptance](2026-10-15-cp3-owner-acceptance.md).
Read the [bounded adoption plan](../plan.md#slice-c-adoption-plan-for-owner-approval) and [tasks](../tasks.md#slice-c-adoption).
Decision requested: approve the proposed kit code, source-prompt and isolated-fixture implementation, or name specific changes.
The plan provides a read-only migration checklist, ordinary Git-branch apply/rollback, and config-selected prompt behavior.
Budgets: under 400 new production PowerShell lines; focused migration tests under five minutes; existing helpers reused.
Validation follows [quickstart](../quickstart.md): covering files during code work, one final full suite before the eventual CP4 handoff.
Current validation: documentation tier only; strict lint clean, dry run target=main/manual T052/zero workers, worktree/index and `0d2bda7..HEAD` whitespace clean.
No production code changed and no tests were rerun for this planning handoff.
Current checkpoint state and authority remain in [spec](../spec.md#checkpoints) and [AGENTS](../../../AGENTS.md); operational boundaries follow the [lean direction](2026-10-14-lean-direction-handover.md).
