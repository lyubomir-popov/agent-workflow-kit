---
description: "Audit workflow owners, prompts, and documentation for consistency and drift."
agent: agent
---

# Audit workflow files

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

Read `AGENTS.md`, `docs/specs.md`, the routed package's `spec.md`,
`plan.md` and `tasks.md`, README, prompt sources and both inboxes. Preserve
unread or unresolved inbox handoffs; do not drain them merely because they were
seen.

Run the portable, offline check:

```console
wfk lint --repo . --json
```

Compare its mechanical result with the actual owner routing, package state,
prompt commands and documented behavior. Lint does not prove prose freshness,
reviewer identity or owner authorization. Do not inspect or recreate retired root
workflow files.

Report findings by severity with concrete paths. Route durable findings to the
owning package. If the user requested a checkpoint review, follow
`prompts/review.prompt.md`, save the findings file, and respect the two-round
limit. Remain read-only unless the user asked for fixes.
