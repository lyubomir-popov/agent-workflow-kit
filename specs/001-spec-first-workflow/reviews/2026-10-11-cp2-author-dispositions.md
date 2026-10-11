# CP2 author dispositions: Spec 001 slice A

Date: 2026-10-11. Author: Codex, Spec 001 implementer.
Scope: `001/spec-r2`, slice A corrections authorized by the owner's 2026-10-11 decisions.
Findings: [saved Opus review](2026-10-11-opus-slice-a-review.md).
Validation: [slice A evidence](../evidence/slice-a-validation.md#cp2-remediation-validation).
This is the initial author disposition record at `60a4f00`. CP2 stays pending;
only the owner clears it. The owner subsequently requested the saved delta review;
[delta dispositions](2026-10-12-cp2-delta-author-dispositions.md) amend CPA-B1's
closure through CPA-R1 and record remaining decisions. Rejected findings: none.

- **CPA-B1**: fixed at `691b668` / `tests/Worker.Tests.ps1`: rejects owner-block edits, added/modified review verdicts, unrelated task completions and an edit later reverted; retains scratch before cherry-pick; `docs/enforcement.md` states the launcher checks and base-authorship limit.
- **CPA-B2**: fixed at `bc6f0f5` / `tests/Worker.Tests.ps1`: legacy TODO cherry-pick plus separate bookkeeping removes scratch, clean zero-commit failures remove scratch, ignored evidence survives; `tests/Scheduler.Tests.ps1` preserves patch-equivalent scratch when a changed path diverges; legacy review/remediation changes are recorded as intended FR-018 fixes in the evidence.
- **CPA-M1**: fixed at `95be292` / `tests/Workflow.Tests.ps1`: archived package resolves after branch deletion; a staged delivery squash passes the hook and commits on the configured target; archived Branch is retained metadata; tag creation stays in slice B.
- **CPA-M2**: fixed at `95be292` / `tests/Scheduler.Tests.ps1`: manual entry tasks dispatch zero workers and a manual boundary stops after only the preceding task; T016/T017 are manual; `d0c80af` / `tests/SpecKit.Tests.ps1` also blocks manual implementation prerequisites.
- **CPA-M3**: fixed at `d0c80af` / `tests/Workflow.Tests.ps1`: missing/overwritten sentinels fail versioned lint for all three scripts; `tests/SpecKit.Tests.ps1` creates a catalog-owned draft with the override lifecycle/checkpoint/scope block and successfully runs setup-plan.
- **CPA-M4**: fixed at `d0c80af` / `tests/CI.Tests.ps1`: actual CI pwsh step skips the current branch even when its ref sorts last and stops at a failed ref before a later ref can mask the exit code; remote CI execution remains unverified.
- **CPA-M5**: deferred to the slice B plan; named owner: **Codex (Spec 001 implementer)**; plan directory-level disposable inspection and a large dependency-tree fixture after owner clearance of CP2.
- **CPA-m1**: fixed at `95be292` / `tests/Workflow.Tests.ps1`: requires CLAUDE.md in copilot-chat inventory; `.workflow-kit.json` declares full loading and the host matrix reflects it.
- **CPA-m2**: deferred to the slice B plan; named owner: **Codex (Spec 001 implementer)**; plan staged-diff package scoping for the hook, with unrelated-package edits covered by fixtures.
- **CPA-m3**: fixed at `95be292` / strict lint and the existing lifecycle/lint regression suite in `tests/Workflow.Tests.ps1`; the redundant active/ready conjunction is removed without changing its active-only behavior.
- **CPA-m4**: fixed at `95be292` / `tests/Scheduler.Tests.ps1`: reports the original primary branch and restores it after both worker failure and authorized task completion.
- **CPA-m5**: deferred to the slice B plan; named owner: **Codex (Spec 001 implementer)**; reconcile hook/mirror coverage as input to the future slice C rollout; no mirror or prompt installation is performed here.
- **CPA-m6**: fixed at `bc6f0f5` / `evidence/slice-a-validation.md#legacy-mode-behavior-changes-accepted-for-cp2-remediation`; intended FR-018 changes and the FR-030.7 exception are explicit, backed by the legacy bookkeeping/failure fixtures in `tests/Worker.Tests.ps1`.
