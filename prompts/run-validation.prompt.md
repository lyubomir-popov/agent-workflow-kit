---
description: "Run the repository's declared validation and report pass/fail with warnings."
agent: agent
---

# Run validation

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

Read `AGENTS.md`, README and the relevant package validation guidance. Run:

```console
wfk lint --repo . --json
```

Then run the narrowest declared tests appropriate to the authorized change, or
the exact command the user supplied. Use a full suite only when the repository
or checkpoint procedure calls for it.

Report the commands, pass/fail results, material warnings and any gap. Validation
does not authorize edits, a scheduler execution, a review round or checkpoint
clearance. Do not fix failures unless requested.
