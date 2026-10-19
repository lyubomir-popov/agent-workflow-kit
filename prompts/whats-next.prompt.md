---
description: "Resolve the active workflow package and report the next authorized task."
agent: agent
---

# Session start — what's next?

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

## Procedure

Read `AGENTS.md`, then `docs/specs.md`. Resolve the first current package on
its declared branch and read its `spec.md`, `plan.md`, `tasks.md` and
relevant saved reviews. Read both inboxes without deleting, emptying or blindly
triaging unresolved handoffs.

Use `wfk lint --repo . --json` when routing needs mechanical validation. It
cannot choose a task or clear a gate.

Report:

- the owning package and declared branch;
- lifecycle, entry checkpoint and the first incomplete task;
- whether that task is authorized by current owner decisions;
- blockers, manual steps and unresolved handoffs;
- the single bounded next action.

Do not start implementation.
