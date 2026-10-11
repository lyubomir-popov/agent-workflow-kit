# Specs

## Purpose

List the external sources that govern this repo.

If a spec or specs exist, they are the source of truth and should be linked here. If no formal spec exists, `ROADMAP.md` assumes the role of the source of truth for product direction, and this file can be kept minimal or used to list sibling-repo references only.

Use this file to answer two questions quickly:

1. What upstream docs or specs control behavior here?
2. Which sibling repos are references versus sources of truth?

## Current packages

| Spec | Package | Branch | Status |
|---|---|---|---|
| 001 Spec-first agent workflow | [001-spec-first-workflow](../specs/001-spec-first-workflow/spec.md) | `feat/001-spec-first-workflow` | Review findings received; amendments await owner acceptance. CP1 not cleared; implementation has not started. |

## Candidates

| Spec | Proposed scope | Sources |
|---|---|---|
| 002 Cross-repository orchestration | Bounded briefs, worker ownership, revision-aware returns, sequencing, calibration; package not created | `canonical-spacing-spec` with `baseline-foundry`, and the Jira bridge; starts after Spec 001 slice A on separate authorization |

## Existing governing sources

| Source | Path or URL | Role |
|--------|-------------|------|
| Workflow rules | `.github/copilot-instructions.md` | Canonical workflow and precedence rules for the boilerplate |
| Product direction | `ROADMAP.md` | Source of truth for long-term direction when no external product spec exists |
| Scheduler and prompt installer contract | `README.md` | Canonical usage and behavioral description for `agent-loop.ps1`, the `bin/` launchers, `prompts/`, and `install-vscode-prompts.ps1` |
| Workflow validation contract | `workflow-kit.ps1` and `README.md` | Executable checks and documented usage for linting workflow files and detecting downstream asset drift |

## Related repos

| Repo | Relationship | Notes |
|------|--------------|-------|
| `baseline-foundry` | Downstream consumer | Active repo that mirrors workflow-file refinements from this boilerplate and has already been used for real loop-driven tasks |
| `design-foundry` | Downstream consumer | Active repo that mirrors workflow-file refinements from this boilerplate and surfaced the stale temp-worktree cleanup case |
| `canonical-spacing-spec` | Downstream consumer | Active repo that mirrors workflow-file refinements from this boilerplate and has already been used for real loop-driven tasks |

## Notes

- Prefer stable paths where possible.
- If a draft path is the canonical latest path, note that explicitly.
- If old snapshots exist, identify them as legacy or archive rather than active source.
- Spec 001 proposes the next operating model. Existing instructions remain active until its reviewed implementation lands.
- The related repos above are references and rollout targets, not sources of truth for this repo's workflow rules.
