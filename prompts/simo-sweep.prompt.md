---
description: "Perform a bounded post-change review and save verified findings."
agent: agent
---

# Post-change sweep

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

Resolve the changed work's package, accepted requirements, actual diff, tests and
checkpoint records. Review for incorrect behavior, missed integration points,
error propagation, races, data-shape changes, preservation failures and
regressions in dependent paths. Verify every material concern against source or
executable evidence before asking for a fix.

Use one focused review round by default. Multiple perspectives may be used within
that round when the owner requested them, but they still produce one saved
findings record. Count existing checkpoint rounds before dispatch. At most two
rounds are allowed; after that the owner accepts, cuts scope or reopens the plan.

Save checkpoint findings and matching dispositions through
`prompts/review.prompt.md`. Do not modify existing review evidence, invent a
reviewer identity, create a parallel execution queue, auto-clear a gate, or launch
an automatic reviewer swarm. Implement fixes only when authorized, then run
proportionate validation and report remaining limits.
