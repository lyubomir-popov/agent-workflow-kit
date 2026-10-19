---
description: "Complexity routing: plan bounded work, delegate mechanical tasks, validate returns, and honor owner gates."
mode: agent
model: claude-opus-4.7
---

# Orchestrate

## Shared procedure

After selecting the workflow mode, apply this dispatch and validation procedure
using the canonical owners named by the matching route.

### Complexity and model ownership

| Tag | Work |
|---|---|
| [H] | Architectural choices, cross-file invariants, planning the next batch |
| [S] | Contained implementations following a written pattern |
| [L] | Mechanical text/data changes and bounded inbox triage |
| [X] | Read-only research or pass/fail validation commands |

Concrete model preferences have one owner selected by the workflow route.
For legacy and version 1, use agent-loop.ps1's TierDispatchMap; version 2 uses
its config owner as described below. Do not maintain another preference table.
Prefer the least-cost capable tier. Keep architectural decisions on the heavy
orchestrator; delegate bounded mechanical work with a written recipe.
Standard/light sessions execute their assigned tier directly and escalate heavy
decisions rather than dispatching a new orchestration tree.

### Triage and plan

Resolve the current work from its canonical owner. Inspect inboxes; preserve
unread/unresolved items and transfer durable facts before removing links.
Tag/decompose authorized open tasks into focused bursts. Check lifecycle,
entry/task checkpoints and write scope before selecting a batch. Candidate ideas
are not an implementation queue; age and task checkboxes do not clear gates.

Order independent work in parallel and dependent work sequentially. Write heavy
decisions first so dependent tasks have a concrete recipe. Owner authorization
persists within scope; ask only when a real missing decision prevents safe work.

### Dispatch contract

Every subagent call carries everything needed:
- Goal, repository, package/branch/worktree and exact allowed files.
- Task IDs, write scope, checkpoint constraints and integration target.
- Exact recipe/pattern, invariants and validation commands.
- Commit/push authorization if any; no implicit publishing permission.
- Required report: changes, validation, findings, recovery paths and deviations.

Read-only research can use an Explore-style worker; validation can use commands
without a model. Do not give multiple workers overlapping write ownership.
Do not assume stateless workers remember prior chat. Consumer/coordinator links
identify owners; cross-repository orchestration implementation remains separate.

### Validate and continue

Inspect actual diffs and substantive checks before accepting a return. Repair
or sharpen a failed recipe; do not repeatedly dispatch the unchanged failure.
Update only the owning task record/header and save durable findings in package
reviews. Preserve failed/unpublished work; exhausted remediation is incomplete.
Do not launch an automatic delta review or clear owner checkpoints.

With explicit autonomous authorization, continue focused batches until the
authorized scope completes or a real blocker/gate stops work. Re-read tasks and
checkpoints after each substantive chunk, make small validated commits when
authorized, and leave a bounded next action for fresh context. Prefer sequential
single-repo sessions to accumulating cross-repo context.

Report completed task IDs, validation, remaining work, gate/blocker and deviations.

## Workflow mode

Read `.workflow-kit.json` as JSON and inspect `workflowModelVersion`. If `.workflow-kit.json` is missing or `workflowModelVersion` is absent,
including when only `canonicalMirrorMode: external` is set, select legacy mode. Select spec-first mode only when `workflowModelVersion` is the JSON integer `1` or `2`;
do not coerce strings or other values. Stop if the JSON is
malformed, is not an object, or contains a present invalid or unsupported
version. Do not infer the mode from root files or placeholders. Execute only the
matching route below; versions 1 and 2 must not execute Legacy procedure.

## Version 1 route

Read `AGENTS.md`, `docs/specs.md`, and the relevant package `spec.md` and `tasks.md`. Apply Shared procedure, including its dispatch contract, `TierDispatchMap` model ownership, and validation rules. Decompose authorized work by complexity, dispatch bounded tasks with exact scope, validate returns, and respect lifecycle/checkpoint gates. Keep findings in package reviews. Do not inspect retired root workflow state.

## Version 2 route

Read `AGENTS.md`, `docs/specs.md`, and the declared package's `spec.md`,
`plan.md` and `tasks.md`. Apply Shared procedure within the authorized phase.
Version 2 worker templates and `tierModels` belong in config, seeded by
`templates/scheduler-defaults.json` in slice C. Until qualified, choose available
capable workers or report unavailable delegation; do not invent authentication
probes, model preferences or a second preference table.
Use `wfk wt new <branch>` for new worktrees and `wfk lint --repo . --json` for
portable ownership checks. Creation/adoption use `wfk new` and `wfk init` only
when requested, previewing rewrites before `--apply`. For authorized scheduled
execution follow `docs/scheduler.md`: preview `wfk run`, select explicit packages
and bounded profiles, and add `--apply` only within live-run authorization.
Fake-worker authorization never permits a real CLI invocation. Follow
`prompts/review.prompt.md` for saved findings, matching dispositions and the
two-round limit. Stop at the next owner checkpoint; never clear it yourself.

## Legacy procedure

Read the repository's existing workflow instructions and current work records,
then apply Shared procedure. Preserve its established execution queue and gates.
