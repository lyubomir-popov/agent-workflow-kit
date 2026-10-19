# Checkpoint review

Reviewer: GPT-5.6 Sol
Reviewed revision: 7d1b0a7acbbe2ecf90ade4609fb52ce5d7895d76
Verdict: changes

## Scope

Reviewed the committed Slice D range `2a38c29..7d1b0a7` for `003/spec-r1`,
including the Linux collision fixes, Copilot Opus reviewer profile and live
qualification evidence, consumer inventory, PowerShell retirement/config v2,
portable prompts, documentation and CI definition.

The implementation source was clean and frozen at the reviewed revision. I also
reviewed the later uncommitted record-only updates present when this file was
written: `AGENT-INBOX.md`, the CP5 row in `spec.md`, the T017/T029 state in
`tasks.md`, final validation, review request, author integration review and the
matching dispositions. Those records do not change the reviewed implementation.

## Findings

1. **Major — required three-OS execution evidence remains outstanding.** This
   is an acceptance-evidence gap, not an implementation defect. CP4 clearance
   explicitly requires the T029 Linux fix to pass on all three operating
   systems before CP5; T029 repeats that condition, and SC-001 requires the full
   suite and lint to pass in CI on Windows, macOS and Linux. The final Windows
   and WSL suites pass, and the six-job CI matrix is configured, but no macOS or
   remote CI job has run. Consequently CP5 cannot yet be claimed accepted.
   Complete an authorized CI/macOS run and preserve the successful job results,
   or obtain an explicit owner decision changing the condition. No arbitrary
   code change can substitute for the missing execution evidence.

No implementation, security, preservation, compatibility or scope defect was
found in the reviewed source. The initial primary-only consumer-inventory gap
identified during this same review round was corrected before these findings:
all 88 discovered checkout trees were scanned before repository deduplication,
with the chronology and preservation evidence recorded.

## Validation performed

- Inspected the governing spec, plan, tasks, CP4 clearance, Slice D handover,
  review procedure, final committed diff and the record-only CP5 handoff.
- Ran seven focused retirement/core regressions covering exact-byte parent-file
  collision preservation, Copilot Opus 4.8 selection, branch-source v1/v2 lint,
  invalid source config and portable pre-commit behavior: all passed.
- Ran the final prompt module: 13 tests passed with two Windows symlink-
  capability skips. Confirmed all 14 prompts use current `agent: agent`
  frontmatter and contain no retired PowerShell/TODO route, pinned model or
  deprecated `mode` header. Current official VS Code prompt documentation
  confirms omitted `model` inherits the invoking host's selection.
- Independently ran offline lint: zero errors and 17 documented historical or
  same-date-order warnings. `git diff --check 2a38c29..7d1b0a7` passed.
- Verified the annotated `v1-powershell` tag peels to
  `aa09890148e456f49d2fae5d2ad66df69d1de33c`, the 31 retired paths match the
  manifest, vendor `.specify/` content is unchanged, and the POSIX launcher and
  tracked pre-commit hook retain executable modes.
- Inspected the saved T030 evidence: `model.call_start` and usage events identify
  `claude-opus-4.8`; the scratch patch contains only the fake task checkbox and
  one new findings record, with the primary checkout unchanged. Standalone
  Claude remains explicitly unqualified.
- Verified the corrected read-only consumer evidence covers all 88 discovered
  checkout trees: 35 matched and 53 did not; repository grouping still yields
  the same ten active consumers, and the sampled linked/detached files remained
  byte-identical before and after the scan.
- The orchestrator's final frozen-source suites passed: Windows 227 tests in
  442.735 seconds with six skips; WSL 227 tests in 45.348 seconds with three
  skips. Its explicit-package scheduler preview was dry-run only and stopped at
  manual T029 without invoking a worker. My own attempt to repeat that preview
  was rejected by the managed command reviewer as potentially mutating, so I do
  not claim an independently executed preview.

## Evidence limits

- No macOS runner or remote CI job was available in the authorized local-only
  scope. The committed matrix is configuration, not passing execution evidence.
- I did not invoke an external Opus reviewer or any live AI tool. The owner's
  final Opus checkpoint remains pending; this file is one independent review
  round and does not clear CP5 or authorize another automatic round.
