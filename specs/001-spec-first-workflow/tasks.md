# Current work

**Next tasks**: T020.
**Blockers**: Owner acceptance of CP2 dispositions before slice B.
**Checkpoint links**: [slice gates](spec.md#checkpoints); [CP2 findings](reviews/2026-10-11-opus-slice-a-review.md).
**Entry checkpoint**: CP1
**Validation**: [commands](quickstart.md); [author results and FR map](evidence/slice-a-validation.md).

## Setup and foundation

- [x] T001 Declare version, target master, scratch/disposable policies and host inventory in `.workflow-kit.json` (FR-035).
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
CP2 stays pending and no delta review is authorized.

- [x] T018 Reject worker changes to owner spec blocks, review verdicts and unrelated task completions; preserve rejected scratch and test each case (CPA-B1) (gate: CP1).
- [x] T019 Repair scratch integration proof and clean failed-run cleanup; test the legacy TODO loop with bookkeeping and record intentional FR-018 changes (CPA-B2, CPA-m6) (gate: CP1).
- [ ] T020 Resolve archived packages from the checkout, accept target-side delivery, stop manual tasks, restore scheduler branches, and fix inventory/redundant logic (CPA-M1, CPA-M2, CPA-m1, CPA-m3, CPA-m4) (gate: CP1).
- [ ] T021 Detect missing Spec Kit integrations, author catalog/lifecycle on creation, test create → setup-plan, and repair CI branch restoration (CPA-M3, CPA-M4) (gate: CP1).
- [ ] T022 Save finding dispositions and validation evidence, update pending CP2/inbox links, and hand back to the owner (gate: CP1).

## Deferred slices

- [ ] T016 Slice B: closeout in `workflow-kit.ps1`, detailed planning only after CP2 owner clearance (manual) (gate: CP2).
- [ ] T017 Slice C: migration tooling and dual-mode `prompts/`, detailed planning only after CP3 owner clearance (manual) (gate: CP3).

## Dependencies and execution strategy

T001–003 establish interfaces; US1/US2 share them; US3 follows model/lint;
US5 reconciles the operating contract; T015 validates A and stops at CP2.
US4 closeout belongs entirely to B; US6 belongs to the separately authorized
Spec 002 candidate. MVP is ownership plus quick lint, then scheduler and self-hosting.
After shared interfaces stabilize, independent fixture groups or adapter/README
edits can run in parallel; catalog and task header edits remain single-writer.
Full suite plus lint/dry run/diff check precede each implementation commit.
