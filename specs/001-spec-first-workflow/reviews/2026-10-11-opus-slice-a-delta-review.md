# Opus slice A delta review: Spec 001

- **Checkpoint**: CP2
- **Scope**: `001/spec-r2`, slice A remediation of the [CP2 findings](2026-10-11-opus-slice-a-review.md)
- **Reviewed revision**: `60a4f00` (code delta `ae0af49..d0c80af`; dispositions and evidence at `60a4f00`)
- **Reviewer**: GitHub Copilot agent in VS Code Insiders; host-reported model Claude Opus 5.5.
  Identity is host-reported, not independently attested. Requested by the owner.
- **Verdict**: accept with bounded corrections. B2, M1–M4 and m1/m3/m4/m6 are fixed.
  B1 is only partly closed (CPA-R1): fix R1 before any unattended slice B run.
  The deferrals (M5, m2, m5) have a named owner and are acceptable.

## Reproduced

- Strict lint: 0 errors/warnings. The dry run reports `T016 is manual` and starts zero workers.
- Fixture suite reproduced on a clean run: 106 passed, 0 failed, 0 skipped
  (232 s, exit 0). Two earlier overlapping reruns stopped inside
  `Workflow.Tests.ps1` with no failures; treat that as a concurrency artifact.
  Remote CI is still unverified.
- The review file is unchanged since `3303e4f`.

## Disposition check

| Finding | Result |
|---|---|
| CPA-B1 | Partly fixed: the spec block, verdict files and unrelated completions are protected; task gating is not (R1) |
| CPA-B2 | Fixed: changed-path proof replaces whole-tree equality; clean failures removed; legacy changes recorded |
| CPA-M1 | Fixed: archived rows resolve from the checkout and are exempt from the off-branch rule |
| CPA-M2 | Fixed: `(manual)` stops the scheduler and Spec Kit prerequisites |
| CPA-M3 | Fixed: sentinel lint; creation writes the catalog row and lifecycle block |
| CPA-M4 | Fixed: the current branch is skipped and each ref is checked |
| CPA-m1, m3, m4, m6 | Fixed |
| CPA-M5, m2, m5 | Deferred to the slice B plan with a named owner – accepted |

## Findings

### CPA-R1 (blocking for unattended slice B). Workers can still remove task gating

Refs: FR-015, FR-016, CPA-B1; `Assert-WorkflowWorkerRange`, `Get-WorkflowTasks`.

A task's gate and manual stop are declared in `tasks.md`: `**Entry checkpoint**`,
`(gate: CPn)` and `(manual)`. Workers may edit `tasks.md`, and the range check only
compares the set of completed tasks. A worker can:
- remove `(gate: CP3)` or `(manual)` from a later task;
- change the entry checkpoint;
- add new unchecked tasks.

The next loop iteration then gates those tasks on the cleared entry checkpoint and
dispatches beyond the owner's gate. That is the B1 bypass, moved from `spec.md` into
`tasks.md`.

Correction: in each worker revision, reject:
- changes to the `**Entry checkpoint**` line;
- changes to any existing task's gate or `(manual)` annotation;
- added or removed task IDs.

Add a fixture for each. Workers may still edit task text below the ID and the
current-work header.

### CPA-R2 (major). Owner policy outside `spec.md` is still writable by workers

Refs: FR-009, FR-035, FR-017; `.workflow-kit.json`.

A worker can add a `budgetExceptions` entry with any `authorization` text, or change
`targetBranch` or `hostBudgets`, and lint accepts it. The range check does not cover
`.workflow-kit.json`.

Correction: reject worker changes to `.workflow-kit.json`. Owner-run sessions remain
free to edit it.

### CPA-R3 (major, owner decision). In-flight packages are invisible from the target branch

Refs: FR-004, SC-001; `Add-WorkflowCatalogPackage`.

Creation adds the catalog row on the new feature branch only. A session opened in a
primary checkout on `master` finds no row for in-flight work until delivery merges.
The kit avoids this today only because its primary checkout is on the feature branch.

Options:
- (a) creation also commits the row (lifecycle `draft`, branch) to the target, a small
  creation-time target write; or
- (b) document that sessions resume from the package's worktree or branch, with lint
  on the target listing local package branches that have no row.

Recommendation: (a), since the decision against target writes covered closeout only.

## Minor findings

- **CPA-r1**: the range check's verdict pattern (`Verdict(?:\*\*)?:`) is narrower
  than the gate parser (`\*?\*?Verdict\*?\*?:`). For example, `*Verdict*: accept`
  slips past the check but satisfies the gate. Impact is low while the spec block is
  protected; share one parser.
- **CPA-r2**: the scheduler's branch restore in `finally` can throw and mask the
  original worker failure. Report both.
- **CPA-r3**: when self-hosting, a worker can change `workflow-checks.ps1` and
  `workflow-scheduler.ps1`, and the next preflight child process loads the changed
  code. State this limit in `docs/enforcement.md`, or run preflight from the code
  as it was at the start of the run.
- **CPA-r4**: archived packages are now editable on any branch. Consider limiting
  this to the configured target.

## Owner decisions

1. R3: option (a) or (b).
2. Accept the recorded legacy-mode behaviour changes as intended FR-018 fixes. They
   reach unmigrated consumers only when slice C mirrors scripts.
3. Clear CP2 now with R1/R2 as the first attended slice B tasks, or after they land.

No gate was cleared and no slice B/C work was started.
