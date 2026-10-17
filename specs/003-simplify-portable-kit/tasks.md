# Current work

**Next tasks**: T005-T006, slice A verification/handoff only; stop at CP2.
**Blockers**: none; later slices require owner checkpoint clearance.
**Checkpoint links**: [gates](spec.md#checkpoints); [CP1 acceptance](reviews/2026-10-17-cp1-owner-acceptance.md).
**Entry checkpoint**: CP1
**Validation**: package review evidence will record results once at CP2.

## Planning

- [x] T001 [H] Write the four-slice plan/tasks and activate the accepted package (gate: CP1).

## Slice A: worktree hygiene

- [x] T002 [S] Write failing Python fixtures for landing styles, discovery and every cleanup keep reason (gate: CP1).
- [x] T003 [H] Implement config, Git metadata discovery, landing checks and `wt new|ls|clean` (FR-001-004, FR-010-014) (gate: CP1).
- [x] T004 [S] Add portable launchers, composing hooks and AGENTS template with fixture coverage (FR-002, FR-015-016) (gate: CP1).
- [ ] T005 [X] Run fixture checks and read-only real inventory comparison; add the Python CI matrix (SC-002-003) (gate: CP1).
- [ ] T006 [H] Save independent findings/dispositions, validation and CP2 request; commit locally and stop (gate: CP1).

## Slice B: workflow core

- [ ] T007 [H] Port config/catalog/package/gate parsing and offline lint with tests (FR-020, FR-023-024, FR-041) (gate: CP2).
- [ ] T008 [S] Implement package creation and non-overwriting init with fixtures (FR-025-027) (gate: CP2).
- [ ] T009 [S] Ship saved-review and installation prompts; retire root placeholders (FR-020-022, FR-028) (gate: CP2).
- [ ] T010 [H] Validate slice B and save CP3 review request; stop (gate: CP2).

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

- Orphans without a Git owner are listed and kept even with `--orphans`:
  removal cannot use the required `git worktree remove`; manual recovery/removal
  is needed. No recursive filesystem deletion fallback is implemented. This is
  a limit for CP2 review, not an owner-accepted change to FR-014.
- Missing paths cannot be distinguished from unmounted drives. Keep their
  registrations and skip pruning in a repo with unavailable worktrees.
- Relative hooks directories need installation in future host-created checkouts.
  If those files are untracked, cleanup keeps the checkout; installation does
  not hide owner hook files with new ignore rules.
- Root discovery skips dependency/cache directories and directory symlinks;
  an excluded repository can be passed directly as a root. Ownership/access
  failures limit real-machine coverage; see the final validation evidence.
- macOS/Linux execution and Python 3.10 are covered by the added CI matrix;
  this local Windows session cannot claim those jobs have run.
