# Adversarial CP2 delta review: Spec 001 slice A

- **Checkpoint**: CP2
- **Scope**: `001/spec-r2`, owner-amendment round (`207ddb4`, `fb8fec4`, `09a0c1f`, `53fc575`)
- **Reviewed revision**: `53fc575`
- **Reviewer**: Cline agent in VS Code; model identity not independently attested.
  Requested by the owner. Not an owner clearance.
- **Verdict**: accept with bounded corrections. CPA-r1/r2 and CPA-R3 are implemented
  as decided. ADV-1/ADV-2 leave gate checks fail-open: fix them before any
  unattended run. ADV-3 must land before the next package creation.

## Reproduced

- Full suite, sequential: `Passed: 124 Failed: 0 Skipped: 0` (453.91 s on this host).
- Strict lint: 0 errors/warnings, 1 semantic-limit info. Dry run: `target=main`,
  stops at T016 (manual), zero workers.
- Ancestry: `origin/main` (`a0f3bf4`) → `master` = `main` (`864cad5`) → feature.
  The remote is unchanged and the tree is clean.
- `git diff --check` is clean for `d4fa859..HEAD` (see ADV-5).

## Claim check

| Item | Result |
|---|---|
| CPA-R1/R2 | Still fixed. Task entry/gate/manual/ID and config protections hold; no regression found |
| CPA-R3 | Implemented as specified, but failure handling has gaps (ADV-3, ADV-4) |
| CPA-r1 | Fixed for `Verdict` only. Other gate labels still diverge (ADV-2) |
| CPA-r2 | Fixed: both messages are reported, both exceptions are kept, and a single failure is rethrown unchanged |
| CPA-r4, M5, m2, m5 | Deferred with a named owner; acceptable |

## Findings

### ADV-1 (major; fix before unattended runs). Workers can rewrite acceptance records

Refs: FR-015, CPA-B1/R1. Code: `Assert-WorkflowWorkerRange` (`workflow-scheduler.ps1:30`)
and `Get-WorkflowGateProblem` (`workflow-model.ps1:280,286`).

The range check rejects a review file only if its *new* content contains a
recognized verdict label. In a disposable repository at `53fc575`, these were
both accepted:
- deleting a `**Verdict**: superseded` line from an existing review;
- adding `**Accepted scope**: 001/spec-rN` to an existing verdict-less dispositions file.

The gate honors `Accepted scope` from any file linked in the checkpoint row, and
the kit's CP2 row links two dispositions files. A worker can therefore:
- skip the obsolete-scope stop after an owner scope supersession;
- remove a superseding verdict that should block.

This is the same bypass class as CPA-R1, moved into `reviews/`.

Correction: reject worker modification or deletion of existing files under `reviews/`.
Also reject new review files that carry any gate label: `Verdict`, `Accepted scope`,
`Checkpoint`, `Scope`, `Reviewer` or `Reviewed revision`. Add a fixture for each.

### ADV-2 (major). Gate labels parse inconsistently, and list-style headers bypass checks

Refs: FR-015. Code: `workflow-model.ps1:278,285,286` against `:261,282`.

`Verdict`, `Reviewer` and `Reviewed revision` accept a `- ` list prefix. `Checkpoint`,
`Scope` and `Accepted scope` require `^**Label**:` at column 0. Both saved Opus CP2
reviews use list-style headers, so for this kit's own CP2 records the
checkpoint-name and obsolete-scope checks are inert.

Probe results:
- A list-style review naming `CP9`, or scope `001/spec-r2` against package `001/spec-r3`,
  passes the gate.
- The bold column-0 control blocks.

Every fixture uses the bold column-0 form (`tests/Fixture.Helpers.ps1:65-69`), so
the suite cannot see this.

Correction: generalize `Get-WorkflowReviewVerdicts` into one label reader. Use it for
every gate field and for the ADV-1 range check. Add list-style fixtures.

### ADV-3 (major, operability). Failed creation leaves the checkout on the target

Refs: FR-034.3, FR-004. Code: `create-new-feature.ps1:376-388,410`.

After `checkout $target`, the config, override, duplicate-row and commit checks throw.
Branch creation failures also throw. None of these paths restores the original branch.

Probe in a disposable clone, run from the feature branch: creation threw `configured
target must contain the matching versioned workflow config` and left HEAD on `main`
(`864cad5`), which has no `AGENTS.md` or `workflow-model.ps1`.

Local main predates slice A. Until slice A reaches main, every versioned creation
in this kit (including Spec 002) fails this way. Neither handoff states this.
The new fixtures cover only failures before the switch (dirty target, blocked checkout).

Correction:
- Restore the original branch on every failure after the switch. Report both
  failures if restoring also fails, as in CPA-r2.
- Add a fixture where the target lacks config.
- Document the slice A prerequisite.

### ADV-4 (minor). On the target, missing branches are info even when they exist nowhere

Refs: FR-004 amendment. Code: `Get-WorkflowPackages` (`workflow-model.ps1`, show-ref branch).

On the target, any missing `refs/heads/<branch>` becomes info, and strict lint exits 0.
CI restores every `origin` branch locally, so in CI a missing branch is truly absent.
Such a row is still only info, so CI passes. That covers:
- deleted branches;
- typos;
- the retained registration after a branch-creation failure (`:410`).

Previously this was a `package-owner` error.

Correction: report info with a fetch hint only when some `refs/remotes/*/<branch>`
exists; otherwise report a warning or error. Add a fixture for an orphan row with no
remote ref.

### ADV-5 (nit). The whitespace check never inspects committed content

`git diff --check` with no range checks only uncommitted changes. That makes it
vacuous on a clean tree and in CI. Over `864cad5..HEAD` it reports trailing
whitespace, mostly in vendor `.agents/`, `.claude/` and `.specify/scripts/` files.
The delta range is clean. Consider a base-ranged check that excludes vendor paths.

## Confirmed non-issues

- The shared parser ignores `> **Verdict**:`, `__Verdict__:` and `Verdict :`. Both gate
  and range ignore them, so these fail closed: no accept is recognized.
- By code inspection (not executed): the scheduler and range check share one task
  parser, so indentation and fence moves cannot open a gap between them. A header
  split that drops the entry line, or a new `spec.md` carrying an owner block, is
  rejected.

## Owner decisions

1. ADV-1/ADV-2: land before CP2 clearance, or as the first attended slice B tasks.
2. ADV-3: accept that package creation is unavailable until slice A is on main,
   or authorize an earlier slice A merge to main.
3. ADV-4: choose the severity (warning or error) for orphan rows with no remote ref.

No gate was cleared, nothing was committed or pushed, and no slice B/C work was started.
