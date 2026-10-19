---
description: "Refresh the active package's bounded current-work summary from repository evidence."
agent: agent
---

# Freshen current work

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

Follow `prompts/whats-next.prompt.md` to resolve the current package and check
its branch, lifecycle, checkpoint and task list. Update only that package's
bounded current-work header when the user asked for a refresh. Keep active work
in `tasks.md`, lifecycle and checkpoints in `spec.md`, and durable evidence
in `reviews/`.

Do not recreate or edit retired root status, TODO or history files. Preserve
inbox entries until receipt and resolution or durable transfer. Report the
evidence used, the field changed, and any mismatch that needs an owner decision.
