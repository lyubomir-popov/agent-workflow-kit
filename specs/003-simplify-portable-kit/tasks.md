# Current work

**Next tasks**: owner's CP3 decision; T011–T014 remain gated. No third review round.
**Blockers**: CP3 pending; [owner decision request](reviews/2026-10-18-cp3-owner-decision-request.md).
**Checkpoint links**: [gates](spec.md#checkpoints); [CP1 acceptance](reviews/2026-10-17-cp1-owner-acceptance.md).
**Entry checkpoint**: CP1
**Validation**: [CP3 evidence](reviews/2026-10-18-cp3-validation.md).

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

- [ ] T011 [H] Implement adapters, preflight, package worktree locks and task dispatch (FR-030-033) (gate: CP3).
- [ ] T012 [H] Implement outcomes, fallback, process termination, protected edit rejection and durable reports (FR-034-039) (gate: CP3).
- [ ] T013 [S] Exercise fake workers for every outcome and report exit path (SC-004-005) (gate: CP3).
- [ ] T014 [H] Validate slice C and save CP4 review request; stop (gate: CP3).

## Slice D: retirement and docs

- [ ] T015 [S] Tag the last PowerShell revision locally, remove legacy tooling/tests/checker and migrate config (FR-040-041) (gate: CP4).
- [ ] T016 [S] Finish three-OS Python CI/lint and rewrite human README/reference docs (FR-042-043) (gate: CP4).
- [ ] T017 [H] Validate the full replacement and save CP5 review request; stop (gate: CP4).

## Known limits

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
