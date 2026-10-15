---
description: "Complexity routing: plan bounded work, delegate mechanical tasks, validate returns, and honor owner gates."
mode: agent
model: claude-opus-4.7
---

# Orchestrate

## Workflow mode

Read `.workflow-kit.json` as JSON and inspect `workflowModelVersion`. If `.workflow-kit.json` is missing or `workflowModelVersion` is absent,
including when only `canonicalMirrorMode: external` is set, select legacy mode. Select spec-first mode only when `workflowModelVersion` is the JSON integer `1`;
do not coerce strings or other values. Stop if the JSON is
malformed, is not an object, or contains a present invalid or unsupported
version. Do not infer the mode from root files or placeholders. Execute only the
matching route below; version 1 must not execute Legacy procedure.

## Version 1 route

Read `AGENTS.md`, `docs/specs.md`, and the relevant package `spec.md` and `tasks.md`. Decompose authorized work by complexity, dispatch bounded tasks with exact scope, validate returns, and respect lifecycle/checkpoint gates. Keep findings in package reviews. Do not inspect retired root workflow state.

## Legacy procedure

## Complexity and model ownership

| Tag | Work |
|---|---|
| [H] | Architectural choices, cross-file invariants, planning the next batch |
| [S] | Contained implementations following a written pattern |
| [L] | Mechanical text/data changes and bounded inbox triage |
| [X] | Read-only research or pass/fail validation commands |

Concrete model preferences have one owner: agent-loop.ps1's TierDispatchMap.
Read it when selecting a dispatch model; do not maintain another preference table.
Prefer the least-cost capable tier. Keep architectural decisions on the heavy
orchestrator; delegate bounded mechanical work with a written recipe.
Standard/light sessions execute their assigned tier directly and escalate heavy
decisions rather than dispatching a new orchestration tree.

## Triage and plan

Resolve the current work from its canonical owner. Inspect inboxes; preserve
unread/unresolved items and transfer durable facts before removing links.
Tag/decompose authorized open tasks into focused bursts. Check lifecycle,
entry/task checkpoints and write scope before selecting a batch. Candidate ideas
are not an implementation queue; age and task checkboxes do not clear gates.

Order independent work in parallel and dependent work sequentially. Write heavy
decisions first so dependent tasks have a concrete recipe. Owner authorization
persists within scope; ask only when a real missing decision prevents safe work.

## Dispatch contract

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

## Validate and continue

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
