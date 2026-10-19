# Current work

**Next tasks**: Consumer inventory, T015, T016, T017 per the [slice D handover](reviews/2026-10-19-slice-d-handover.md); T029 needs macOS evidence only.
**Blockers**: macOS execution evidence remains pending for T029/final acceptance; stop at CP5.
**Checkpoint links**: [gates](spec.md#checkpoints); [CP1 acceptance](reviews/2026-10-17-cp1-owner-acceptance.md).
**Entry checkpoint**: CP1
**Validation**: [slice D evidence](reviews/2026-10-19-cp5-validation.md).

## Planning

- [x] T001 [H] Write the four-slice plan/tasks and activate the accepted package (gate: CP1).

## Slice A: worktree hygiene

- [x] T002 [S] Write failing Python fixtures for landing styles, discovery and every cleanup keep reason (gate: CP1).
- [x] T003 [H] Implement config, Git metadata discovery, landing checks and `wt new|ls|clean` (FR-001-004, FR-010-014) (gate: CP1).
- [x] T004 [S] Add portable launchers, composing hooks and AGENTS template with fixture coverage (FR-002, FR-015-016) (gate: CP1).
- [x] T005 [X] Run fixture checks and read-only real inventory comparison; add the Python CI matrix (SC-002-003) (gate: CP1).
- [x] T006 [H] Save independent findings/dispositions, validation and CP2 request; commit locally and stop (gate: CP1).

## CP2 Opus remediation (owner-authorized, no third review)

- [x] T018 [H] Add failing fixtures and fix standalone branch opt-in/protection plus fresh/recent worktree preservation (findings 1-2) (gate: CP1).
- [x] T019 [S] Refuse automatic hook installation inside checkout files with a regression fixture (finding 3) (gate: CP1).
- [x] T020 [X] Disposition findings 4-6, run final validation, save evidence and stop for the CP2 owner decision (gate: CP1).
- [x] T021 [S] Fix aged checkout-only worktree eligibility and empty-log fallback with fixtures; update FR-013/manual-orphan wording and sizes per the owner decision (gate: CP1).
- [x] T022 [X] Record owner-change dispositions/validation and stop for explicit CP2 clearance (gate: CP1).

## Slice B: workflow core

- [x] T007 [H] Port config/catalog/package/gate parsing and offline lint with tests (FR-020, FR-023-024, FR-041) (gate: CP2).
- [x] T008 [S] Implement package creation and non-overwriting init with fixtures (FR-025-027) (gate: CP2).
- [x] T009 [S] Ship saved-review and installation prompts; retire root placeholders (FR-020-022, FR-028) (gate: CP2).
- [x] T010 [H] Validate slice B and save CP3 review request; stop (gate: CP2).

## CP3 Opus remediation (owner-authorized, no third review)

- [x] T023 [S] Add init's default file/host budgets with the 200-line regression and existing-file preservation/checklist coverage (finding 1) (gate: CP2).
- [x] T024 [X] Disposition findings 2–4, record validation and stop for the owner's CP3 decision (gate: CP2).

## Slice C: scheduler

- [x] T011 [H] Implement adapters, preflight, package worktree locks and task dispatch (FR-030-033) (gate: CP3).
- [x] T012 [H] Implement outcomes, fallback, process termination, protected edit rejection and durable reports (FR-034-039) (gate: CP3).
- [x] T013 [S] Exercise fake workers for every outcome and report exit path (SC-004-005) (gate: CP3).
- [x] T014 [H] Validate slice C and save CP4 review request; stop (gate: CP3).

## CP4 remediation (owner-authorized, no third review)

- [x] T025 [H] Restore unattended flags, tier models/efforts, legacy Codex alias compatibility and verified available-provider auth probes (Opus finding 1) (gate: CP3).
- [x] T026 [S] Resolve Windows npm shims to native Node/validated entrypoints with injection fixtures; print the primary-checkout recovery command (findings 2 and 4) (gate: CP3).
- [x] T027 [X] Attempt the authorized single bounded scratch run per provider and preserve reports, logs and unavailable/model-rejection results without retries (gate: CP3).
- [x] T028 [X] Record dispositions and final validation; commit locally and stop for the owner's CP4 decision, with no third review or slice D (gate: CP3).

## Slice D: retirement and docs

- [ ] T029 [S] Fix both Linux parent-file collisions in init and prompt installation; pass their regression tests and the full three-OS Python suite before CP5 (Opus finding 3) (gate: CP4).
- [x] T030 [S] Make the default reviewer Copilot running a Claude Opus model; qualify one review phase in a scratch repo; document the claude adapter as unqualified (gate: CP4).
- [ ] T015 [S] After the read-only consumer inventory, tag the last PowerShell revision locally, remove legacy tooling/tests/checker and migrate config (FR-040-041) (gate: CP4).
- [ ] T016 [S] Finish three-OS Python CI/lint and rewrite human README/reference docs (FR-042-043) (gate: CP4).
- [ ] T017 [H] Validate the full replacement and save CP5 review request; stop (gate: CP4).

## Known limits

- T029's two parent-file collisions are fixed with byte-preservation regressions.
  Full Windows and WSL suites pass (221 tests each). T029 remains open only for
  its macOS execution requirement: no macOS runner is available locally, and
  an unexecuted CI definition is not a passing three-OS run. See slice D evidence.

- CP4 remediation initially allowed one bounded scratch attempt per provider.
  Copilot completed a committed task; Codex initially rejected the Copilot alias.
  After the guard was restored, the owner explicitly authorized one additional
  Codex task: it authenticated, committed and passed exact-byte/scope checks in
  37.765 seconds. Both attempts are preserved in the linked validation evidence.
  Claude is unavailable; its probe stays unset
  until qualified. The original tier map/efforts and unattended flags are restored.
  Known npm wrappers now resolve to native Node; unknown wrappers still fail closed.
  See [scheduler reference](../../docs/scheduler.md) and
  [integration review](reviews/2026-10-19-cp4-integration-review.md).
- POSIX workers must keep descendants in their owned session; deliberate setsid
  escape is unsupported. Windows graceful interrupt is best effort, followed by
  authoritative Job termination. Forced OS termination can leave the initialized
  report marked running; stale locks and new foreign refs need manual inspection.
  Optional reviews require progress in the same run; follow-up review without
  another eligible task uses the saved-review prompt and explicit owner scope.

- CP3 Opus findings 2–4 remain deferred for the owner's decision:
  severity checks scan every numbered list in findings files (use bullets for
  validation); review labels scan the whole document (keep example headers inline);
  prompt installation creates both editor profiles even when an editor is absent
  (preview first or manually copy prompts only into the desired existing profile).
  See [the findings](reviews/2026-10-18-cp3-opus-findings.md).

- Ownerless orphans are sized and kept for manual removal, accepted at CP2.
  The obsolete `--orphans` flag is rejected. No recursive deletion fallback exists.
- Missing paths cannot be distinguished from unmounted drives. Keep their
  registrations and skip pruning in a repo with unavailable worktrees.
- Hooks inside checkout files are refused with manual composition instructions.
  Automatic hook failures are still silent (Opus finding 4); persistent logging
  and a listing warning are deferred, without claiming they were fixed.
- Missing registrations remain preserved even when a parent exists. There is
  no explicit prune opt-in yet (Opus finding 5); owner pruning is manual.
- Catalog-declared branches from the caller and configured target are protected,
  including from stale caller checkouts. Standalone branches still need explicit
  `--branches` before eligible deletion.
- Version 1 nonstandard review headers and historical checkpoint-link counts
  remain migration warnings; standard findings are strict. Version 2 enforces
  complete owner decisions and latest dated findings. Same-date review ordering
  produces an ambiguity warning and requires explicit owner selection.
- Earlier vendor/PowerShell integrations remain unchanged until slice D; Python
  reads project templates directly and does not inspect or modify vendor sources.
- Empty/expired HEAD logs use admin mtime; unreadable/malformed nonempty logs
  keep the checkout. Standalone branch deletion retains its branch-reflog
  movement check, including missing/reftable-only evidence. The grace clock is
  Git HEAD activity/admin mtime; ignored-file changes
  alone do not refresh it. All ignored files are deleted when removal applies,
  including secrets, notes and tmp evidence (documented for finding 6).
- Root discovery skips dependency/cache directories and directory symlinks;
  an excluded repository can be passed directly as a root. Ownership/access
  failures limit real-machine coverage; see the final validation evidence.
- macOS/Linux execution and Python 3.10 are covered by the added CI matrix;
  this local Windows session cannot claim those jobs have run.
