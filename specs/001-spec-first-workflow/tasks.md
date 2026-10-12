# Current work

**Next tasks**: T036 (manual).
**Blockers**: Owner approval of the slice B plan before implementation, unattended runs, merging or pushing. New package creation requires slice A on main.
**Checkpoint links**: [slice gates](spec.md#checkpoints); [planning-only acceptance](reviews/2026-10-12-cp2-owner-planning-acceptance.md); [proposed slice B plan](plan.md#slice-b-plan-for-owner-approval).
**Entry checkpoint**: CP1
**Validation**: [commands](quickstart.md); [author results and FR map](evidence/slice-a-validation.md).

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

- [x] T015 Run `tests/run-tests.ps1`, lint, dry run and whitespace checks; save task/FR evidence and bounded CP2 request in `reviews/`, add one `AGENT-INBOX.md` handoff link, leave CP2 pending (FR-014–015, 037, SC-009).

## CP2 remediation

Owner-authorized slice A corrections, 2026-10-11. Entry gate remains CP1;
CP2 stays pending. The owner subsequently requested the saved delta review;
this round fixes CPA-R1/R2 under the existing slice A entry gate.

- [x] T018 Reject worker changes to owner spec blocks, review verdicts and unrelated task completions; preserve rejected scratch and test each case (CPA-B1) (gate: CP1).
- [x] T019 Repair scratch integration proof and clean failed-run cleanup; test the legacy TODO loop with bookkeeping and record intentional FR-018 changes (CPA-B2, CPA-m6) (gate: CP1).
- [x] T020 Resolve archived packages from the checkout, accept target-side delivery, stop manual tasks, restore scheduler branches, and fix inventory/redundant logic (CPA-M1, CPA-M2, CPA-m1, CPA-m3, CPA-m4) (gate: CP1).
- [x] T021 Detect missing Spec Kit integrations, author catalog/lifecycle on creation, test create → setup-plan, and repair CI branch restoration (CPA-M3, CPA-M4) (gate: CP1).
- [x] T022 Save finding dispositions and validation evidence, update pending CP2/inbox links, and hand back to the owner (gate: CP1).
## CP2 delta remediation

Owner-authorized slice A corrections, 2026-10-12; entry gate remains CP1.
CP2 stays pending. Target registration is the owner's selected CPA-R3 design.

- [x] T023 Reject worker changes to task entry checkpoints, gate/manual declarations and task ID structure; reject all worker changes to `.workflow-kit.json`; test rejected ranges and allowed description/header edits (CPA-R1, CPA-R2) (gate: CP1).
- [x] T024 Record delta dispositions/evidence, retain CPA-R3 for the owner's decision and update the pending CP2/inbox handoff (gate: CP1).
- [x] T025 Owner selected target registration, main, fixes for CPA-r1/r2, and slice B deferral for CPA-r4 on 2026-10-12 (manual) (gate: CP1).
- [x] T026 Verify ancestry, create local main at master's commit without moving master, configure main and amend the governing creation contract (gate: CP1).
- [x] T027 Share verdict parsing between gate and range checks, report simultaneous worker/restore failures, and add fixtures (CPA-r1, CPA-r2) (gate: CP1).
- [x] T028 Register new draft catalog rows on the configured target before branching; handle unavailable local branches as target info findings; test creation, both checkouts and a fresh clone (CPA-R3) (gate: CP1).
- [x] T029 Record validation/dispositions, update pending CP2/inbox links, and report remaining owner remote steps (gate: CP1).

## CP2 adversarial remediation

The [saved adversarial review](reviews/2026-10-12-cp2-adversarial-delta-review.md)
reports ADV-1–5. Entry gate remains CP1; CP2 stays pending. No unattended run,
early main merge or slice B/C work is part of the current remediation.

- [x] T030 Restore the original branch/detached head after versioned creation failure; preserve recovery artifacts and report both creation/restore failures; add post-switch fixtures and document the slice A prerequisite (ADV-3) (manual) (gate: CP1).
- [x] T031 Owner confirmed the bounded correction route on 2026-10-12: attended ADV-1/2 fixes in slice A, wait for delivery without an early main merge, orphan errors with remote-ref evidence and explicit offline uncertainty; retain owner-only CP2 clearance (manual) (gate: CP1).
- [x] T032 Freeze existing review records, reject all gate metadata in new worker reviews, share every gate-label parser, and test verdict deletion, accepted-scope injection and list-style records (ADV-1, ADV-2) (manual) (gate: CP1).
- [x] T033 Diagnose orphan branches using cached ref evidence and distinguish offline uncertainty; allow only the transient new-row registration context through the creation hook; test each case (ADV-4) (manual) (gate: CP1).
- [x] T034 Record per-finding dispositions, meaningful ranged whitespace evidence and validation, update CP2/inbox links, and stop at the owner boundary (ADV-5) (manual) (gate: CP1).
- [x] T035 Record the owner's confirmation of the three correction choices in dispositions and the handoff; retain CP2 pending and the existing slice B/C boundary (manual) (gate: CP1).

## Slice B planning

- [x] T016 Prepare the slice B closeout plan, including CPA-M5/CPA-m2/CPA-m5/CPA-r4/ADV-5, under the owner's planning-only acceptance of 75ddc89; implementation remains unapproved (manual) (gate: CP2).
- [ ] T036 Owner approves the proposed slice B plan and explicitly authorizes its implementation scope; retain this manual stop and do not enqueue implementation tasks until approval (manual) (gate: CP2).

## Carryovers and later slices

CPA-M5, CPA-m2 and CPA-m5 are included in the proposed slice B plan. Named owner:
Codex (Spec 001 implementer). See [dispositions](reviews/2026-10-11-cp2-author-dispositions.md).
CPA-r4 archive edit restrictions are included in that plan, owned by
Codex (Spec 001 implementer); see the delta dispositions.
ADV-5 ranged CI checking is included in that plan. The older vendor/integration
whitespace baseline remains separate maintenance, owned by Codex (Spec 001
implementer); vendor skill edits remain outside scope.

- [ ] T017 Slice C: migration tooling and dual-mode `prompts/`, detailed planning only after CP3 owner clearance (manual) (gate: CP3).

## Dependencies and execution strategy

T001–003 establish interfaces; US1/US2 share them; US3 follows model/lint;
US5 reconciles the operating contract; T015 validates A and stops at CP2.
US4 closeout belongs entirely to B; US6 belongs to the separately authorized
Spec 002 candidate. MVP is ownership plus quick lint, then scheduler and self-hosting.
After shared interfaces stabilize, independent fixture groups or adapter/README
edits can run in parallel; catalog and task header edits remain single-writer.
Full suite plus lint/dry run/diff check precede each implementation commit.
