# CP5 Opus findings: slice D retirement and docs

**Checkpoint**: CP5
**Scope**: `003/spec-r1`
**Reviewer**: Opus (GitHub Copilot, Claude Opus 5.5)
**Reviewed revision**: `7d1b0a7acbbe2ecf90ade4609fb52ce5d7895d76` (records at `b0fa3e5`)
**Verdict**: changes

Date: 2026-10-20. Round 2 of 2 for CP5 under FR-022.

## Summary

Slice D does what was planned. It removes about 11,600 lines and adds about
3,700. All root PowerShell is gone, `bin/` holds only `wfk` and `wfk.cmd`, and
`v1-powershell` points at `aa09890`. Config is v2 with entry-file budgets, and
AGENTS.md is 99 lines. The README is now written for a person, and the CI
matrix covers Windows, macOS and Ubuntu. The pre-commit hook runs `wfk lint`.
One regression breaks the owner's main method, Spec Kit, in this repository.

## Findings

1. **Major – Spec Kit scripts fail after the retirement.** The kit's earlier
   customizations of `.specify/scripts/powershell/common.ps1`,
   `check-prerequisites.ps1` and `create-new-feature.ps1` dot-source the
   removed `workflow-model.ps1`. Reproduced:
   `check-prerequisites.ps1 -Json -PathsOnly` exits 1 with "versioned
   configuration requires workflow-model.ps1". Every `speckit-*` skill that
   runs these scripts (plan, tasks, implement, analyze, specify) now fails.
   FR-026 requires unmodified vendor scripts.
   *Fix*: restore the five scripts from the Spec Kit initialization commit
   `059405a`. A temporary copy of those versions ran successfully here. Add a
   test that no file under `.specify/` references removed kit files. Record
   that Spec Kit's own scripts still need PowerShell 7. On macOS and Linux,
   either install `pwsh` or reinitialize Spec Kit with its `sh` scripts; that
   is vendor-owned and outside the kit.

2. **Major – SC-001 lacks real three-OS evidence.** CI is configured but has
   not run. macOS has never executed the suite. Running it needs the branch
   pushed (not merged), which is an owner decision.

3. **Minor – Spec 001 is still listed as current and active.** Its next tasks
   (T059/T060) are PowerShell push and install steps that no longer exist.
   At or before merge, the owner should record 001 as superseded by 003 and
   move its catalog row to Archive.

4. **Minor – the Spec Kit feature cursor points at 001.**
   `.specify/feature.json` still selects `specs/001-spec-first-workflow`, so
   vendor scripts resolve Spec 001 by default. Point it at the active package,
   or have `wfk new` update it.

## Merge prerequisites (owner)

This checkout is also where consumers find the kit. Once `main` moves past
`v1-powershell`, any of the ten listed consumer repositories that call
`agent-loop.ps1`, `workflow-kit.ps1` or the old `bin/` launchers from this path
will break. Before merging, keep a `v1-powershell` worktree at a stable
sibling path and point those consumers at it, or migrate them.

## Remediation scope

Finding 1 is required before CP5. Finding 2 needs the owner to authorize a
branch push for CI. Findings 3–4 may be fixed or recorded. No third review
round starts automatically.
