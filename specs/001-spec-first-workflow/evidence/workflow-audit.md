# Workflow source audit

Inspected locally on 2026-10-10 for the owner's kit renewal request.
This records sources and bounded observations. Historical product checks
were not rerun, and no efficiency improvement is claimed.

## Reference repositories

| Context | Sources | Observed advance |
|---|---|---|
| Diagram Generator, primary checkout | `AGENTS.md`, `docs/agent-index.md`, Spec 118 archive | Single-owner map, durable reviews, routes, preflight, proportional checks |
| Diagram Generator Planning, primary checkout | `AGENTS.md`, Copilot instructions, planning validator | Evidence boundaries, links/provenance checks, dated state; new Jira skill/rules include uncommitted edits |
| Diagram Registry, primary checkout | `AGENTS.md`, Copilot instructions, kit configuration | Saved reviews and inbox links, rapid content iteration, behavior-based tests, producer dependencies |
| Spacing, `docs/bottom-compensation-spec` worktree | Spec 024 plan/tasks, bucket prompts, October 10 handover | One programme owner, complete briefs, persistent workers, calibration, bounded reviews; no evidence ceremony |
| BF, primary and Spec 028 worktree | `AGENTS.md`, agent inbox, catalog | Root status/history removed, spec-local work, spacing worker role; main retains older handover |

Spacing's newest workflow is at
`H:/WSL_dev_projects/canonical-spacing-spec-worktrees/docs-bottom-compensation-spec`.
Its corresponding BF worker is at
`H:/WSL_dev_projects/baseline-foundry-worktrees/feat-028-shared-spacing-decisions`.
These are observed source locations, not portable configuration defaults.

## Direct observations

- Generator status: 618 lines; Planning status: 549 lines.
- Planning Copilot instructions: 342 lines; Planning history: 954 lines.
- BF main agent inbox: 152 lines. Spec 028 records the October 10 scope reset.
- Spacing's active Copilot contract shrank from main's 297 lines to 72;
  its active inbox has 3 lines. Coda procedures moved to scoped instructions.
- Spec 024's active README calls brief preparation next work, while its tasks
  record T109 complete. Duplicate state can drift within a package too.
- The four Git repositories list 32 additional worktrees; six are dirty.
  One was proved a clean ancestor of local `main`. Remote PR/squash records
  and ignored-content eligibility were not checked. Age is not abandonment.
- Current kit lint: kit 0 findings; Generator 2 errors/12 warnings; Planning
  5 warnings; Registry 3 warnings. Some reflect rigid old file/heading rules;
  others also expose inbox/history maintenance needs.
- Generator guidance check passed. Guidance/spec-number tests: 21 passes,
  one host-specific Bash skip. Product suites were not rerun.

## Kit behavior inspected

- `agent-loop.ps1` puts review bodies in the root inbox and requests AGENTS
  handover updates, contrary to the newer single-owner contracts.
- Catalog discovery recognizes exact `In Progress`; checkout failure can
  continue on the current branch.
- Inbox formatting substitutes for unresolved-review state; exhausted
  remediation can still reach a finished-package message.
- Spec 119 dry run offers its blocked Opus checkpoint as an implementation task.
- Cleanup uses forced worktree removal and recursive filesystem fallback.
- `workflow-kit.ps1` requires legacy files and a resume agent, checks guidance
  headings only in the Copilot file, and flags pending inbox links as undrained.

## Limits

No reference repository was edited and no worktree was deleted. Local state
does not establish remote acceptance or deployment. The owner's priorities
and these contracts inform the proposal; defaults remain subject to review.
