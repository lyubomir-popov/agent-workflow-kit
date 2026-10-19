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

Pending the authorized package-branch push and actual six-job results.
No operating-system pass is inferred from configuration or a queued job.
