# CP2 delta author dispositions: Spec 001 slice A

Date: 2026-10-12. Author: Codex, Spec 001 implementer.
Scope: `001/spec-r2`; R1/R2 corrections and the 2026-10-12 owner amendment to the
[owner-requested delta findings](2026-10-11-opus-slice-a-delta-review.md).
Code revisions: `fcca278`, `207ddb4`, `fb8fec4`, `09a0c1f`.
This is author evidence, not an independent verdict.
CP2 remains pending; only the owner accepts dispositions and clears it.
The complete 2026-10-12 owner reply supersedes the earlier handover. Slice A
restrictions remain; no checkpoint was cleared by the implementer.

## Initial R1/R2 round

The pending triage below describes that earlier round and is superseded by the
owner amendment and final dispositions below.

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

## Owner amendment, 2026-10-12

This complete scope supersedes the earlier pending triage above.

1. Target is main. Verified origin/main is an ancestor of master and master is an
   ancestor of the feature branch. Local main was created at master's unchanged
   commit `864cad5`; config now selects main. No remote was changed. Owner steps:
   push main, switch the remote default branch, then retire master.
2. CPA-R3: owner selected option (a), target registration. First commit the draft
   row on the configured target, then create the declared branch from that commit.
   Dirty target or failed checkout stops incomplete; never push. Missing local
   declared branches on the target give an info fetch finding. FR-004/034 amended;
   implementation and creation/clone fixtures are tracked by T028.
3. CPA-r1: authorized shared verdict parser and single-emphasis range fixture (T027).
4. CPA-r2: authorized reporting of both worker and restore failures (T027).
5. CPA-r4: deferred to the slice B plan, owner: Codex (Spec 001 implementer).

CP2 remains pending; these owner decisions do not clear it.

## Implementation and final dispositions, 2026-10-12

These are the final author dispositions for the owner's complete scope, items 1–5:

1. **Target main**: fixed at `207ddb4` / verified Git ancestry (`origin/main` → `master` → feature, `main` → feature), unchanged master hash `864cad5`, strict lint and dry run reporting target=main. Generic master fixtures remain intentional. FR-035/edge cases and kit docs/plan/evidence reflect the owner decision.
2. **CPA-R3**: owner decision option (a), fixed at `09a0c1f` / `tests/SpecKit.Tests.ps1`: target registration commit changes only the catalog; the new branch inherits that commit; create → setup-plan authors a draft from the override and lint passes on both branches; a fresh clone with only remote package refs passes strict lint with info "fetch the declared branch". Real-hook registration runs before the feature ref exists. Dirty/blocked target checkout stops incomplete; missing refs away from the target still fail; target-side package edits still fail even when the declared branch is unavailable. FR-004/034 amendments are in `207ddb4`.
3. **CPA-r1**: fixed at `fb8fec4` / `tests/Worker.Tests.ps1` single-emphasis verdict rejection with scratch retained; `tests/Scheduler.Tests.ps1` accepts that label in an owner-saved gate record. Gate/range checks use `Get-WorkflowReviewVerdicts`.
4. **CPA-r2**: fixed at `fb8fec4` / `tests/Scheduler.Tests.ps1` reports both worker failure and failed restoration, retaining both exceptions and the recoverable-work path. Existing successful-restoration fixtures still pass.
5. **CPA-r4**: deferred to the slice B plan, owner: Codex (Spec 001 implementer). Archive edit restrictions are unchanged by this round.

CPA-R1/R2 remain fixed at `fcca278` / Worker.Tests task declaration and config
range fixtures. CPA-r3 remains documented as a self-hosted code-integrity limit.
Rejected findings: none. Original CPA-M5/CPA-m2/CPA-m5 deferrals retain the Spec 001
implementer as owner. CP2 stays pending; only the owner clears it.

The owner still must push main, switch the remote default branch to main and
retire master. Local main/master remain at `864cad5`; no remote was changed.
No slice B/C work, prompt installation, vendor skill edit, live worker run or
additional review occurred.

Validation: [owner-amendment evidence](../evidence/slice-a-validation.md#owner-delta-implementation-validation-2026-10-12).
