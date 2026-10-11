# CP2 delta author dispositions: Spec 001 slice A

Date: 2026-10-12. Author: Codex, Spec 001 implementer.
Scope: `001/spec-r2`; R1/R2 corrections to the
[owner-requested delta findings](2026-10-11-opus-slice-a-delta-review.md).
Code revision: `fcca278`. This is author evidence, not an independent verdict.
CP2 remains pending; only the owner accepts dispositions and clears it.
The saved review and current owner message establish R1/R2 scope. The original
handover's slice A restrictions still apply.

- **CPA-R1**: fixed at `fcca278` / `tests/Worker.Tests.ps1`: entry-checkpoint edits/removal, existing gate/manual edits, added/removed/reordered IDs and a gate edit later reverted all return worker-incomplete before cherry-pick and retain scratch; the positive integration fixture still permits focused completion, task description edits and non-entry header edits. Scheduling and range validation share the task declaration parser. ID order is protected so a worker cannot move work ahead of a manual boundary.
- **CPA-R2**: fixed at `fcca278` / `tests/Worker.Tests.ps1`: budget-exception, target, host-budget and config-deletion changes are rejected, as is a policy edit later reverted. Owner sessions can still change config; the restriction applies only to versioned worker commit integration.
- **CPA-R3**: owner decision pending, owner: repository owner. Select (a) creation-time target catalog registration or (b) worktree/branch resume plus target diagnostics. The delta review recommends (a); neither option is implemented or treated as approved here. No target write is performed.
- **CPA-r1**: deferred to owner triage, owner: repository owner; the single-emphasis verdict-label mismatch remains unmodified and is explicitly reported in `docs/enforcement.md`. Parser unification requires a separately scoped correction.
- **CPA-r2**: deferred to owner triage, owner: repository owner; simultaneous worker and branch-restoration failures can still mask the original failure. No behavior change or completion claim is made in this R1/R2 round.
- **CPA-r3**: documented at `fcca278` / `docs/enforcement.md`: self-hosted preflight loads current-checkout scripts; worker edits can change later preflight behavior. Code is not pinned to the run's starting revision. Source inspection plus the full suite validate this documentation; no code-integrity sandbox is claimed.
- **CPA-r4**: deferred to owner triage, owner: repository owner; archived rows remain editable on any branch under the prior CPA-M1 decision. Narrowing to the configured target is not implemented in this R1/R2 round.

Rejected findings: none. Original CPA-M5/CPA-m2/CPA-m5 carryovers retain their
named owner and future slice B planning disposition. No slice B/C implementation,
prompt installation, push, vendor skill edit or live worker run occurred.

Validation: [delta evidence](../evidence/slice-a-validation.md#cp2-delta-remediation-validation).
The full code-validation run passed **115 tests, 0 failed, 0 skipped**, Pester 3.4,
391.02 seconds; the focused worker run passed 18/18. Strict lint and dry run pass;
dry run starts zero workers and stops for manual owner action.
