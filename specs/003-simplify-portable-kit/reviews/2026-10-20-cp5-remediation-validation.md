# CP5 remediation validation

Authority: [owner decision](2026-10-20-cp5-owner-decision.md).
Findings: [Opus round 2 of 2](2026-10-20-cp5-opus-findings.md).
Remediation base: `437a8dd`; original slice base: `2a38c29`.
CP5 remains uncleared. No third review starts automatically.

## Vendor restoration and cursor

- Reproduced `check-prerequisites.ps1 -Json -PathsOnly` failing with the missing
  `workflow-model.ps1` exception before edits.
- New regression red: two tests, three failures (three vendor asset references
  plus both prerequisite modes). Restored all five scripts from `059405a`;
  only three differed, while `setup-plan.ps1` and `setup-tasks.ps1` already matched.
- `git diff --exit-code 059405a -- .specify/scripts/powershell` passes. Vendor
  source was restored, not patched with replacement kit calls. The static test
  scans every `.specify/` asset for retired kit script/launcher references.
- Functional fixture copies the actual scripts into a v2 repository without
  retired kit files and runs both paths-only and required-tasks modes. `pwsh`
  is optional for this test; the static regression runs without it.
- The intentionally ignored, local `.specify/feature.json` now selects Spec 003;
  it was not force-added to Git. Both actual read-only prerequisite
  commands return that package, and required-tasks lists `tasks.md`.
- Docs distinguish Python kit requirements from this checkout's vendor scripts:
  PowerShell 7, or vendor `sh` reinitialization on macOS/Linux. No vendor
  reinitialization, installation or mutating vendor command was run.

## Spec 001 supersession and preservation

- A bounded GPT-5.6 Sol worker updated only the catalog and Spec 001 spec/tasks
  records; preferred Terra 5.6 was unavailable. This was implementation, not a
  third independent review. The root agent integrated the changes.
- Spec 001 is archived and `superseded` by 003; T059/T060 remain unchecked
  historical entries with no execution authority. Its original branch is retained
  only as catalog metadata. No historical review or checkpoint was rewritten.
- Initial archive lint correctly exposed a compatibility gap: current v2 config
  reinterpreted preserved v1 evidence as errors. Two new tests failed before repair.
- Explicit `Review format version: 1` applies only to lint for terminal archived
  packages. Tests prove branch-independent archive resolution, byte preservation,
  no executable superseded task, rejection on active packages/invalid formats,
  strict standard findings and unchanged runtime v2 semantics.

## Local checks

- Focused workflow/retirement suite: 34 tests, OK, 38.088 seconds, no skips.
- Offline lint: zero errors, 17 existing compatibility/date-order warnings.
- Full final-source Windows suite: in progress; result will be recorded here.
- Whitespace checks pass. Only the authorized package branch will be pushed;
  no force, `main`, tag push, merge, consumer write, worker or cleanup is authorized.

## Published CI evidence

Pushed only `feat/003-simplify-portable-kit` at
`0b0ec5d3038177e5020549efaaa530ec55b4e908`, using an explicit refspec,
`--no-follow-tags`, no force and no submodule recursion.
[Initial CI run](https://github.com/lyubomir-popov/agent-workflow-kit/actions/runs/39343581282)
passed both Ubuntu jobs but exposed real macOS failures in both Python versions:
nine failures and one error per job. Windows results were still pending when
the follow-up was prepared. The initial failed run is retained as evidence.

### CI-driven macOS repair

- Existing assertions used macOS's `/var` temp alias while configuration, Git and
  child processes report `/private/var`. Canonicalized fixture roots in config,
  hooks, prompts and process tests. Product symlink refusal remains unchanged;
  prompt fixtures now test a direct path rather than an accidental system alias.
- The process close path signalled an unreaped session leader after interrupt.
  It now polls/reaps before group kill and retries an `EPERM` race only after
  confirming leader exit. A live leader or failed retry still raises; descendants
  are still targeted even after normal parent exit. No permission failure is
  silently ignored and unrelated process groups are never selected.
- A bounded GPT-5.6 Sol implementation worker owned the process module/tests;
  no independent review round was started. Its deterministic regression failed
  before the repair; 13 Windows process tests then passed with one POSIX skip.
- Root integration checked the diff and ran 41 config/hook/prompt tests: OK,
  three Windows platform/capability skips, 45.471 seconds. WSL process/scheduler:
  40 tests, OK, one Windows-only skip, 23.998 seconds. A new actual matrix run
  verifies the follow-up below.

No operating-system pass is inferred from configuration or a queued job.
