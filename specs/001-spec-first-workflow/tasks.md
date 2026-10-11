# Current work

**Next tasks**: T001, T002, T003.
**Blockers**: none within the owner-authorized slice A.
**Checkpoint links**: [CP1 and slice gates](spec.md#checkpoints).
**Entry checkpoint**: CP1
**Validation**: [commands and fixture scope](quickstart.md).

## Setup and foundation

- [ ] T001 Declare version, target master, scratch/disposable policies and host inventory in `.workflow-kit.json` (FR-035).
- [ ] T002 Build shared config/catalog/worktree/spec/task/checkpoint parsing in `workflow-model.ps1` (FR-002–004, 010, 015–017, 033).
- [ ] T003 Add compatible Pester fixture runner in `tests/run-tests.ps1` and fixture helpers under `tests/` (FR-013, 018).

## US1: Resume from one owner

Independent test: catalog order resolves the declared worktree; lifecycle and task
header supply action; off-branch edits fail; closed/superseded handoffs are detected.

- [ ] T004 [US1] Migrate static invariants/adapters/catalog and inbox templates in `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, `docs/specs.md`, `INBOX.md`, `AGENT-INBOX.md`; retire `.github/agents/agent.md` (FR-001–007, 010, 036).
- [ ] T005 [US1] Preserve open ideas in `docs/specs.md`/`ROADMAP.md`, preserve history in Git, and replace `STATUS.md`, `TODO.md`, `HISTORY.md` with 2–3 line placeholders (FR-006, 037).
- [ ] T006 [US1] Test resume, branch/worktree divergence, stable task IDs and stale handoffs in `tests/Workflow.Tests.ps1` (FR-002–005, 010–012, SC-001/003).

## US2: Detect mechanical drift

Independent test: fourteen simulated updates, long lines, split files and marker
injection fail at the next check; unread valid handoffs remain untouched.

- [ ] T007 [US2] Add read-only versioned lint, stable human/JSON findings, owners/links/router checks and per-file/host/header/request budgets to `workflow-kit.ps1` (FR-008–013, 034–035).
- [ ] T008 [US2] Test budgets, exceptions, inventory, marker injection, catalog consistency and non-destructive inboxes in `tests/Workflow.Tests.ps1` (FR-005, 008–013, SC-002/003).
- [ ] T009 [US2] Compose local commit checking in `.githooks/pre-commit`, add `.github/workflows/workflow.yml`, and record per-host triggers/gaps in `docs/enforcement.md` (FR-008.1–6).

## US3: Binding reviews and unattended safety

Independent test: no invocation passes an uncleared/missing/obsolete verdict,
checkout failure, unchanged task or exhausted remediation; partial work survives.

- [ ] T010 [US3] Consume lifecycle/catalog/gates, configured target and preflight in `agent-loop.ps1`; stop failed checkout/remediation/integration and route reviews to package `reviews/` (FR-014–018).
- [ ] T011 [US3] Mark contained scratch worktrees, verify integration/content before Git removal, remove recursive fallback and own model preferences in `agent-loop.ps1` (FR-017–018, 022–023 safety boundary, 036).
- [ ] T012 [US3] Test scheduler failure paths and scratch preservation with mocked workers in `tests/Scheduler.Tests.ps1` (FR-014–018, SC-004).

## US5: Kit self-hosting and Spec Kit alignment (slice A only)

Independent test: cursor cannot select work, reserved package numbers survive,
vendor skills stay unchanged, legacy config still selects legacy launcher/lint.

- [ ] T013 [US5] Ignore/untrack `.specify/feature.json`, align `.specify/scripts/powershell/common.ps1` and `create-new-feature.ps1`, and keep `.specify/memory/constitution.md` principles-only (FR-034).
- [ ] T014 [US5] Move FR-036 procedures into `prompts/` sources and `docs/operations.md`, update `README.md`, link script-owned model preferences, and test legacy/external compatibility in `tests/Workflow.Tests.ps1` (FR-007, 032, 034–037).

## Cross-cutting validation and handoff

- [ ] T015 Run `tests/run-tests.ps1`, lint, dry run and whitespace checks; save task/FR evidence and bounded CP2 request in `reviews/`, add one `AGENT-INBOX.md` handoff link, leave CP2 pending (FR-014–015, 037, SC-009).

## Deferred slices

- [ ] T016 Slice B: closeout in `workflow-kit.ps1`, detailed planning only after CP2 owner clearance (gate: CP2).
- [ ] T017 Slice C: migration tooling and dual-mode `prompts/`, detailed planning only after CP3 owner clearance (gate: CP3).

## Dependencies and execution strategy

T001–003 establish interfaces; US1/US2 share them; US3 follows model/lint;
US5 reconciles the operating contract; T015 validates A and stops at CP2.
US4 closeout belongs entirely to B; US6 belongs to the separately authorized
Spec 002 candidate. MVP is ownership plus quick lint, then scheduler and self-hosting.
After shared interfaces stabilize, independent fixture groups or adapter/README
edits can run in parallel; catalog and task header edits remain single-writer.
Full suite plus lint/dry run/diff check precede each implementation commit.
