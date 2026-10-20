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
- Local Windows full suite at the first remediation source `0b0ec5d`: 231 tests,
  OK, six skips, 557.092 seconds. Final-source full-suite evidence comes from
  the actual matrix below.
- Whitespace checks pass. Only the authorized package branch will be pushed;
  no force, `main`, tag push, merge, consumer write, worker or cleanup is authorized.

## Published CI evidence

Pushed only `feat/003-simplify-portable-kit` at
`0b0ec5d3038177e5020549efaaa530ec55b4e908`, using an explicit refspec,
`--no-follow-tags`, no force and no submodule recursion.
[Initial CI run](https://github.com/lyubomir-popov/agent-workflow-kit/actions/runs/39343581282)
passed both Ubuntu jobs but exposed real macOS failures in both Python versions:
nine failures and one error per job. Windows 3.10 failed four path-alias
assertions; Windows current failed those four plus one Node fixture timeout.
The [initial job metadata](evidence/2026-10-20-cp5-ci-initial.json) retains all
six actual outcomes. The Node fixture took exactly timeout plus grace (12
seconds), passed locally in 0.079 seconds and passed on the initial Windows
3.10 job. No unproven runtime workaround or `process.exit` was added. It also
passed unchanged in the corrected-source Windows current job. The cause of that
single startup timeout remains unproven and is recorded as a CI reliability limit,
not a demonstrated launcher bug.

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

Follow-up source: `7bdb029ca0ccd915ec820eba82b5847ef602a97c`.
[Follow-up CI](https://github.com/lyubomir-popov/agent-workflow-kit/actions/runs/39344201394)
completed successfully against that exact revision. Each job passed its full
233-test suite, CLI help and offline lint (zero errors, 17 existing warnings).
The vendor prerequisite regression also ran successfully on macOS with `pwsh`.

| OS | Actual Python | Tests | Skips | Result |
|---|---|---|---|---|
| Windows | 3.10.11 | 233 in 627.108s | 2 | [pass](https://github.com/lyubomir-popov/agent-workflow-kit/actions/runs/39344201394/job/118372755043) |
| Windows | 3.14.8 | 233 in 338.949s | 2 | [pass](https://github.com/lyubomir-popov/agent-workflow-kit/actions/runs/39344201394/job/118372754885) |
| macOS | 3.10.11 | 233 in 91.093s | 3 | [pass](https://github.com/lyubomir-popov/agent-workflow-kit/actions/runs/39344201394/job/118372754810) |
| macOS | 3.14.8 | 233 in 109.355s | 3 | [pass](https://github.com/lyubomir-popov/agent-workflow-kit/actions/runs/39344201394/job/118372754967) |
| Ubuntu | 3.10.22 | 233 in 50.989s | 3 | [pass](https://github.com/lyubomir-popov/agent-workflow-kit/actions/runs/39344201394/job/118372754661) |
| Ubuntu | 3.14.8 | 233 in 51.604s | 3 | [pass](https://github.com/lyubomir-popov/agent-workflow-kit/actions/runs/39344201394/job/118372754875) |

[Saved successful run metadata](evidence/2026-10-20-cp5-ci-success.json) includes
the exact revision, run/event timestamps, job URLs and step conclusions. T029's
three-OS condition and SC-001 now have actual execution evidence. Final edits
after `7bdb029` contain records only; these do not change the tested source.
Git whitespace checks pass for the full slice range from `2a38c29`. The original
fallback tag remains local at `aa09890`, and all five vendor scripts still match
`059405a`. Spec 001 review files are unchanged from the remediation base.

The [author integration check](2026-10-20-cp5-remediation-author-review.md) is
explicitly self-review. Two checkpoint rounds are exhausted; CP5 remains
uncleared for the owner's decision. Consumer pinning/migration and merging
remain separate owner actions. Final evidence/handoff records are committed
locally after the successful branch CI; no additional source push is needed.
