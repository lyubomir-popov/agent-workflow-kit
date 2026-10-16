# Current work

**Next tasks**: T058 (bounded adoption corrections), then T057 (manual owner final acceptance).
**Blockers**: none for approved kit implementation; delivery prerequisites remain in [plan](plan.md#approval-and-delivery-boundaries).
**Checkpoint links**: [slice gates](spec.md#checkpoints); [lean direction and handover](reviews/2026-10-14-lean-direction-handover.md).
**Entry checkpoint**: CP3
**Validation**: [tiered commands](quickstart.md) (FR-038); [final adoption summary](evidence/slice-c-validation.md).

## Setup and foundation

- [x] T001 Declare version, configured target, scratch/disposable policies and host inventory in `.workflow-kit.json` (FR-035); owner amended this kit's target to main on 2026-10-12.
- [x] T002 Build shared config/catalog/worktree/spec/task/checkpoint parsing in `workflow-model.ps1` (FR-002–004, 010, 015–017, 033).
- [x] T003 Add compatible Pester fixture runner in `tests/run-tests.ps1` and fixture helpers under `tests/` (FR-013, 018).

## US1: Resume from one owner

Independent test: catalog order resolves the declared worktree; lifecycle and task
header supply action; off-branch edits fail; closed/superseded handoffs are detected.

- [x] T004 [US1] Migrate static invariants/adapters/catalog and inbox templates in `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, `docs/specs.md`, `INBOX.md`, `AGENT-INBOX.md`; retire `.github/agents/agent.md` (FR-001–007, 010, 036).
- [x] T005 [US1] Preserve open ideas in `docs/specs.md`/`ROADMAP.md`, preserve history in Git, and replace `STATUS.md`, `TODO.md`, `HISTORY.md` with 2–3 line placeholders (FR-006, 037).
- [x] T006 [US1] Test resume, branch/worktree divergence, stable task IDs and stale handoffs in `tests/Workflow.Tests.ps1` (FR-002–005, 010–012, SC-001/003).

## US2: Detect mechanical drift

Independent test: fourteen simulated updates, long lines, split files and marker
injection fail at the next check; unread valid handoffs remain untouched.

- [x] T007 [US2] Add read-only versioned lint, stable human/JSON findings, owners/links/router checks and per-file/host/header/request budgets to `workflow-kit.ps1` (FR-008–013, 034–035).
- [x] T008 [US2] Test budgets, exceptions, inventory, marker injection, catalog consistency and non-destructive inboxes in `tests/Workflow.Tests.ps1` (FR-005, 008–013, SC-002/003).
- [x] T009 [US2] Compose local commit checking in `.githooks/pre-commit`, add `.github/workflows/workflow.yml`, and record per-host triggers/gaps in `docs/enforcement.md` (FR-008.1–6).

## US3: Binding reviews and unattended safety

Independent test: no invocation passes an uncleared/missing/obsolete verdict,
checkout failure, unchanged task or exhausted remediation; partial work survives.

- [x] T010 [US3] Consume lifecycle/catalog/gates, configured target and preflight in `agent-loop.ps1`; stop failed checkout/remediation/integration and route reviews to package `reviews/` (FR-014–018).
- [x] T011 [US3] Mark contained scratch worktrees, verify integration/content before Git removal, remove recursive fallback and own model preferences in `agent-loop.ps1` (FR-017–018, 022–023 safety boundary, 036).
- [x] T012 [US3] Test scheduler failure paths and scratch preservation with mocked workers in `tests/Scheduler.Tests.ps1` (FR-014–018, SC-004).

## US5: Kit self-hosting and Spec Kit alignment (slice A only)

Independent test: cursor cannot select work, reserved package numbers survive,
vendor skills stay unchanged, legacy config still selects legacy launcher/lint.

- [x] T013 [US5] Ignore/untrack `.specify/feature.json`, align `.specify/scripts/powershell/common.ps1` and `create-new-feature.ps1`, and keep `.specify/memory/constitution.md` principles-only (FR-034).
- [x] T014 [US5] Move FR-036 procedures into `prompts/` sources and `docs/operations.md`, update `README.md`, link script-owned model preferences, and test legacy/external compatibility in `tests/Workflow.Tests.ps1` (FR-007, 032, 034–037).

## Cross-cutting validation and handoff

- [x] T015 Run `tests/run-tests.ps1`, lint, dry run and whitespace checks; save task/FR evidence and bounded CP2 request in `reviews/`, add one `AGENT-INBOX.md` handoff link (FR-014–015, 037, SC-009).

## CP2 remediation

Owner-authorized slice A corrections, 2026-10-11, under the slice A entry gate.

- [x] T018 Reject worker changes to owner spec blocks, review verdicts and unrelated task completions; preserve rejected scratch and test each case (CPA-B1) (gate: CP1).
- [x] T019 Repair scratch integration proof and clean failed-run cleanup; test the legacy TODO loop with bookkeeping and record intentional FR-018 changes (CPA-B2, CPA-m6) (gate: CP1).
- [x] T020 Resolve archived packages from the checkout, accept target-side delivery, stop manual tasks, restore scheduler branches, and fix inventory/redundant logic (CPA-M1, CPA-M2, CPA-m1, CPA-m3, CPA-m4) (gate: CP1).
- [x] T021 Detect missing Spec Kit integrations, author catalog/lifecycle on creation, test create → setup-plan, and repair CI branch restoration (CPA-M3, CPA-M4) (gate: CP1).
- [x] T022 Save finding dispositions and validation evidence, update checkpoint/inbox links, and hand back to the owner (gate: CP1).

## CP2 delta remediation

Owner-authorized slice A corrections, 2026-10-12. Target registration is the
owner's selected CPA-R3 design.

- [x] T023 Reject worker changes to task entry checkpoints, gate/manual declarations and task ID structure; reject all worker changes to `.workflow-kit.json`; test rejected ranges and allowed description/header edits (CPA-R1, CPA-R2) (gate: CP1).
- [x] T024 Record delta dispositions/evidence, retain CPA-R3 for the owner's decision and update the inbox handoff (gate: CP1).
- [x] T025 Owner selected target registration, main, fixes for CPA-r1/r2, and slice B deferral for CPA-r4 on 2026-10-12 (manual) (gate: CP1).
- [x] T026 Verify ancestry, create local main at master's commit without moving master, configure main and amend the governing creation contract (gate: CP1).
- [x] T027 Share verdict parsing between gate and range checks, report simultaneous worker/restore failures, and add fixtures (CPA-r1, CPA-r2) (gate: CP1).
- [x] T028 Register new draft catalog rows on the configured target before branching; handle unavailable local branches as target info findings; test creation, both checkouts and a fresh clone (CPA-R3) (gate: CP1).
- [x] T029 Record validation/dispositions, update checkpoint/inbox links, and report remaining owner remote steps (gate: CP1).

## CP2 adversarial remediation

The [saved adversarial review](reviews/2026-10-12-cp2-adversarial-delta-review.md)
reports ADV-1–5, corrected under the slice A entry gate.

- [x] T030 Restore the original branch/detached head after versioned creation failure; preserve recovery artifacts and report both creation/restore failures; add post-switch fixtures and document the slice A prerequisite (ADV-3) (manual) (gate: CP1).
- [x] T031 Owner confirmed the bounded correction route on 2026-10-12: attended ADV-1/2 fixes in slice A, wait for delivery without an early main merge, orphan errors with remote-ref evidence and explicit offline uncertainty; retain owner-only CP2 clearance (manual) (gate: CP1).
- [x] T032 Freeze existing review records, reject all gate metadata in new worker reviews, share every gate-label parser, and test verdict deletion, accepted-scope injection and list-style records (ADV-1, ADV-2) (manual) (gate: CP1).
- [x] T033 Diagnose orphan branches using cached ref evidence and distinguish offline uncertainty; allow only the transient new-row registration context through the creation hook; test each case (ADV-4) (manual) (gate: CP1).
- [x] T034 Record per-finding dispositions, meaningful ranged whitespace evidence and validation, update checkpoint/inbox links, and stop at the owner boundary (ADV-5) (manual) (gate: CP1).
- [x] T035 Record the owner's confirmation of the three correction choices in dispositions and the handoff (manual) (gate: CP1).

## Slice B planning

- [x] T016 Prepare the slice B closeout plan, including CPA-M5/CPA-m2/CPA-m5/CPA-r4/ADV-5, under the owner's planning-only acceptance of 75ddc89; subsequent implementation approval is recorded at T036 (manual) (gate: CP2).
- [x] T036 Owner approved the slice B plan at dce8394 by replying "continue" to the plan handoff on 2026-10-12; authorize code and fixture work only, retaining all operational restrictions (manual) (gate: CP2).

## Slice B implementation

All tasks are manual; slice C waits for its checkpoint in spec.md.

- [x] T037 Add closeout preview and exact accepted/base/landed merge proof, including tree modes/deletions/renames and final delivery records (FR-019/020) (manual) (gate: CP2).
- [x] T038 Share preservation inventory and scale disposable-directory inspection without skipping nested evidence or links (FR-021/022/023, CPA-M5) (manual) (gate: CP2).
- [x] T039 Add authorized local apply, annotated archive proof, immediate revalidation and resumable safe worktree/branch cleanup (FR-019–024) (manual) (gate: CP2).
- [x] T040 Restrict archived package edits to the configured target while preserving target delivery/squash and deleted-branch resolution (CPA-r4) (manual) (gate: CP2).
- [x] T041 Validate affected staged package contracts from the index without blocking unrelated unstaged package work (CPA-m2) (manual) (gate: CP2).
- [x] T042 Include hook assets and the new shared libraries in canonical mirror diagnostics; preserve external/legacy selection without consumer installation (CPA-m5) (manual) (gate: CP2).
- [x] T043 Check committed event ranges in CI, including PR/push/first-push/root and unavailable-base cases (ADV-5) (manual) (gate: CP2).
- [x] T044 Run full acceptance and integration checks; save B evidence, carryover dispositions and a bounded CP3 request; prepare the owner handoff (manual) (gate: CP2).

## CP3 slice B remediation

The [received Cline review](reviews/2026-10-13-opus-slice-b-review.md) (model
identity unattested; filename is historical) accepts with bounded corrections
CP3-R1/R2/R3, applied within slice B scope.

- [x] T046 Keep original landing proof valid under target advancement, lock a separate current target snapshot, reuse immutable archives and correct mocked remote leases/proof checks (CP3-R1/R2, FR-020/024) (manual) (gate: CP2).
- [x] T047 Document retry with the original base/accepted/landed tuple, current-tip reporting and preservation of conflicting archives (CP3-R3) (manual) (gate: CP2).
- [x] T049 Preserve independently authorized remote steps when selected local steps lack cleanup permission; report retained local actions and test the mixed-permission outcome (author QA CP3-Q1, FR-019) (manual) (gate: CP2).
- [x] T048 Run required acceptance checks, save correction dispositions/evidence and refresh the owner handoff (manual) (gate: CP2).
- [x] T050 Adopt the owner's lean direction: proportional validation and record economy (FR-038/039), flexible reviewer identity (FR-037), frozen remote closeout (FR-019/024), Git-based migration rollback (FR-030); tier AGENTS/quickstart; save the [handover](reviews/2026-10-14-lean-direction-handover.md) (manual) (gate: CP2).
- [x] T045 Record the [owner's acceptance of slice B at 8569b12](reviews/2026-10-15-cp3-owner-acceptance.md), actual reviewer identity and bounded planning authority (manual) (gate: CP2).
- [x] T051 Make hook test assertions robust to wrapped error output while preserving message and exit-code checks; run Hook/HookScope only ([validation](evidence/cp3-validation-summary.md)) (manual) (gate: CP2).

## Carryovers and later slices

CPA-M5, CPA-m2 and CPA-m5 are included in the accepted slice B plan. Named owner:
Codex (Spec 001 implementer). See [dispositions](reviews/2026-10-11-cp2-author-dispositions.md).
CPA-r4 archive edit restrictions are included in that plan, owned by
Codex (Spec 001 implementer); see the delta dispositions.
ADV-5 ranged CI checking is included in that plan. The older vendor/integration
whitespace baseline remains separate maintenance, owned by Codex (Spec 001
implementer); vendor skill edits remain outside scope.

- [x] T017 Prepare the bounded [Slice C adoption plan](plan.md#slice-c-adoption-plan-for-owner-approval): preview-only migration diagnostics, ordinary Git apply/rollback, prompt dual mode, focused fixtures and proportional validation (FR-030–032, 038–039, SC-010) (manual) (gate: CP3).

## Slice C adoption

- [x] T052 Record the [owner's approval of adoption implementation at 48ba3a5](reviews/2026-10-16-slice-c-plan-approval.md) and scope T053–T056 (manual) (gate: CP3).
- [x] T053 [US5] Add preview-only `migrate -Preview` routing/reporting in `workflow-kit.ps1` and read-only inventory in `workflow-migration.ps1`; reuse model/lint, register canonical mirror inventory, and report the [planned dispositions and mechanical blockers](plan.md#slice-c-adoption-plan-for-owner-approval) within the production budget (manual) (gate: CP3).
- [x] T054 [US5] Convert all 13 source prompts to explicit workflow-version dual mode and document the [ordinary Git adoption procedure](../../README.md#migrate-a-consumer-repository); preserve legacy procedures, external/product ownership, compatibility aliases and separate prompt activation (manual) (gate: CP3).
- [x] T055 [US5] Add `tests/Migration.Tests.ps1` with local fixture helpers for migrated, unmigrated and external-kit examples; validate the [planned cases and budgets](plan.md#slice-c-adoption-plan-for-owner-approval) plus directly affected coverage (manual) (gate: CP3).
- [x] T056 Complete local final-code validation and save the [single adoption summary](evidence/slice-c-validation.md) and [acceptance request](reviews/2026-10-16-cp4-acceptance-request.md); record CI as an owner-push follow-up (manual) (gate: CP3).
- [ ] T057 Owner final acceptance of the adoption component at c13d402: choose any reviewer or none, accept or name bounded corrections, and save the actual identity and accepted revision ([request](reviews/2026-10-16-cp4-acceptance-request.md)) (manual) (gate: CP3).

## CP4 bounded corrections and delivery follow-ups

- [ ] T058 Correct the [received CP4 findings](reviews/2026-10-16-cp4-adversarial-review.md): preserve legacy prompt behavior, make mode boundaries explicit, inspect migration blockers before activation, fix console-dependent Git decoding/assertions, restore task obligations, and update dispositions/evidence after focused coverage and one final full suite (manual) (gate: CP3).
- [ ] T059 Run and record CI after an owner-authorized push; retains the unfinished remote part of T056 (manual) (gate: CP3).
- [ ] T060 After separately authorized owner prompt installation, remove STATUS/TODO/HISTORY catalog placeholders and their temporary README wording, and record the tracked tmp/hello.txt and tmp/world.txt preserve/retire decision (FR-006/037) (manual) (gate: CP3).

## Dependencies and execution strategy

T001–003 establish interfaces; US1/US2 share them; US3 follows model/lint;
US5 reconciles the operating contract; T015 validates A and stops at CP2.
US4 closeout belongs entirely to B; US6 belongs to the separately authorized
Spec 002 candidate. MVP is ownership plus quick lint, then scheduler and self-hosting.
After shared interfaces stabilize, independent fixture groups or adapter/README
edits can run in parallel; catalog and task header edits remain single-writer.
Validation follows FR-038 tiers; see [quickstart](quickstart.md).
