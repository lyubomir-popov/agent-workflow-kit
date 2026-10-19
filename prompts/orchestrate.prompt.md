---
description: "Plan bounded work, delegate independent tasks, validate returns, and honor owner gates."
agent: agent
---

# Orchestrate

## Workflow routing

Read `.workflow-kit.json` as JSON before using the procedure below.

- JSON integer `2`: use the Python workflow procedure.
- JSON integer `1`: use the same Python procedure and run
  `wfk lint --repo . --json`; report its named ignored-v1-field diagnostics
  and do not assume ignored scheduler or workflow fields are active.
- Missing file or missing `workflowModelVersion`: run only the adoption preview
  `wfk init --repo . --json`, report its manual checklist, and wait for
  authorized adoption.
- Malformed JSON, a non-object root, a non-integer version, or an unsupported
  version: fail closed and report the configuration error.

Do not reconstruct retired commands or TODO scheduling. If old behavior is
still required, use a separate kit checkout pinned to `v1-powershell`; the tag
alone does not repoint a shared consumer.

## Complexity and model ownership

| Tag | Work |
|---|---|
| `[H]` | Architecture, cross-file invariants and planning |
| `[S]` | Contained implementation following a written pattern |
| `[L]` | Mechanical text/data changes and bounded triage |
| `[X]` | Read-only research or pass/fail validation |

Reusable prompts inherit the invoking host's selected model. Scheduler profiles,
tiers and reviewer preference belong to `templates/scheduler-defaults.json`
plus explicit config overrides. The configured automated reviewer is
`copilot-opus`, which uses Copilot with `claude-opus-4.8`; this does not
qualify the standalone Claude Code adapter. Record actual identities and do not
invent another model table.

## Triage and plan

Resolve `AGENTS.md`, the catalog and current package owners on the declared
branch. Preserve unresolved inbox handoffs. Decompose only authorized tasks,
check lifecycle and entry/task gates, and give each unit exact file ownership.
Write architectural decisions before dependent mechanical work.

Order independent, non-overlapping tasks in parallel only when the user or
repository procedure authorizes delegation. Keep dependent work sequential.
Candidate ideas and task age do not create an execution queue or clear a gate.

## Dispatch contract

Each delegated task must name:

- repository, package, branch/worktree and exact allowed files;
- task IDs, checkpoint constraints and integration target;
- concrete recipe, invariants and validation;
- commit and publication authority;
- required return: changes, checks, findings, recovery paths and deviations.

Do not give two workers overlapping write ownership. A worker permission mode is
not extra scope. Cross-repository implementation requires explicit scope for
each repository.

## Validate and continue

Inspect returned diffs and substantive checks. Repair a failed recipe before
redispatching; repetition is not progress. Update only the owning task record and
save durable findings in package `reviews/`. Do not auto-clear checkpoints or
launch an unrequested review.

For automated execution, preview
`wfk run --repo . --package <catalog-package> --json` and add `--apply` only
when the explicit package, profiles and bounds are authorized. Review phases use
`prompts/review.prompt.md` and stop after two rounds for an owner decision.

Report completed task IDs, validation, remaining work, the next gate or blocker,
and any deviation from the dispatch contract.
