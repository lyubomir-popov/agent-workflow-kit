# CP4 validation

Review base: `9a3e38aca7f28855ebf02cf0d0699811faedf9ef` (CP3 owner clearance).
Scope: T011–T014, fake workers only; local commits only. CP4 is pending.
Final source commit and legacy-suite result will be recorded at handoff.

## Test-first and integration evidence

- Scheduler, process, protection and saved-review fixtures each failed importing
  their absent module before implementation. New regression failures reproduced
  hidden gate dispatch, strict reviewer identity and explicit-ref quarantine.
- First scheduler run: 11 tests, 3 failures exposed over-broad own-run cleanup;
  the correction retains activity grace/catalog branch protection.
- Independent review round 1 saved six major findings and one minor. Repairs and
  per-finding regressions are in [dispositions](2026-10-19-cp4-gpt-dispositions.md).
  No automatic delta or third review was started.
- Focused integrated suite: 85 tests in 130.771 s, OK (2 Windows capability/OS
  skips). Prompt route suite: 12 tests, OK (2 existing symlink skips).
- Process worker's focused cross-platform runs: Windows 11 tests in 6.589 s and
  WSL Ubuntu 24.04 11 tests in 8.401 s; one platform-specific skip each. Actual
  POSIX SIGINT isolation, Windows Job containment, signal-ignoring child timeout,
  normal-parent descendant cleanup, large log streaming and UTF-8 stdin passed.

## Final checks

| Check | Result |
|---|---|
| Windows `python -m unittest discover -s tests_python -v` | 197 tests, 310.633 s, OK; 6 skips |
| Windows current protection fixtures | 21 tests, 18.734 s, OK |
| WSL Ubuntu 24.04 / Python 3.12 slice C suites | 85 tests, 24.313 s, OK; 1 Windows-only skip |
| Complete legacy PowerShell suite | still running; result pending |
| Python compilation | pass |
| Python lint | 0 errors; 17 existing compatibility/diagnostic warnings |
| Legacy strict lint | 0 errors, 0 warnings |
| Legacy scheduler dry run | 0 workers; T014 only, then pending CP4 stops T015 |
| Worktree/index whitespace | pass |

Windows skips: four existing launcher/symlink capability cases, the review
symlink case and POSIX-only SIGINT session test. WSL ran the POSIX case and
skipped only Windows batch-launcher rejection in the slice C suite.

The first WSL slice C run exposed a mode-only fixture issue: its helper's
`git add -A` reset an index-only chmod on a filemode-aware filesystem. Committing
the staged mode directly fixes the fixture, without changing production code.
The current 21 Windows protection tests and all 85 WSL slice C tests passed after
that correction; the full Windows run covered the same final production code.

Broader WSL discovery ran all 197 tests in 38.528 s: 193 passed, 2 skipped and
2 existing errors, in init's and prompt installation's parent-file collision
guards (`NotADirectoryError` from `lstat` below a non-directory). A temporary
archive of CP3 commit `9a3e38a` reproduced both errors unchanged in the exact two
tests (2 errors, 0.031 s). These are not slice C regressions. They remain explicit
portability work before final acceptance, to be handled under T016 once CP4 is
cleared; no claim is made that the full Linux suite is green.

## Scope and limitations

GPT-6.1 Sol implemented bounded process/review work and performed the independent
review; GPT-5.6 Sol implemented commit protection. The orchestrator implemented
runtime/scheduling, CLI integration and repairs. Configured GPT-5.4 tiers were
unavailable; substitutions were disclosed. The separate integration review is
self-review, not independent round 2 or Opus.

No real Codex/Copilot/Claude command was run, even for help/login. Default live
auth is deliberately unverified and fails closed. No push, merge, hooks or user
prompt installation, real cleanup application, consumer edit, vendor edit,
PowerShell retirement, config migration or slice D work occurred. Fixture Git
mutations and scoped local source/record commits are the only authorized writes.
Known limits and qualification needs are recorded in tasks and the integration
review; GitHub CI/macOS/Python 3.10 execution is not claimed.
