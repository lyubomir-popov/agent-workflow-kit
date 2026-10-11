---
description: "Complexity routing: plan bounded work, delegate mechanical tasks, validate returns, and honor owner gates."
mode: agent
model: claude-opus-4.7
---

# Orchestrate

Read the repository's AGENTS and owning work record before dispatch. If root
STATUS/TODO/HISTORY are 2–3 line retirement placeholders pointing to docs/specs.md,
their procedures are retired: follow AGENTS and the package owners; never
recreate them. Shared full dual-mode conversion/installation remains later work.

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
