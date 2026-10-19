---
description: "Alias for the bounded Python scheduler procedure."
agent: agent
---

# Proceed autonomously

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

Follow `prompts/overnight.prompt.md` exactly. Use explicit package selections,
preview first, and add `--apply` only when execution is authorized. Keep the
same finite task, time and review bounds. Autonomy continues only within the
declared scope and stops at owner gates, manual tasks, authentication failures,
interruptions or exhausted review rounds.
