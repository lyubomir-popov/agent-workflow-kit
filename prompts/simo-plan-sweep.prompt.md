---
description: "Refine an existing package plan into bounded phases with validation and checkpoints."
agent: agent
---

# Plan sweep

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

Read `AGENTS.md`, the catalog and the selected package's spec, plan, tasks and
saved decisions. Stay in planning mode. Preserve the accepted scope and owner
gates; do not implement, commit or push unless the user separately authorized
those actions.

Review the plan for missing error paths, race conditions, preservation risks,
dependent code paths, platform differences and incomplete validation. Refine it
into the smallest sequence of independently safe phases. Each phase should name:

- objective and exact file or subsystem scope;
- prerequisites and decisions;
- failure and recovery behavior;
- narrow validation that proves the phase;
- dependencies on earlier phases;
- a local commit checkpoint only when commits are already authorized;
- the checkpoint or owner decision that stops further work.

Keep execution in `tasks.md`; do not create a second checklist or queue unless
the package format or user explicitly requires one. Finish with a cross-phase
sweep for gaps and a bounded next action.

If the user requests a formal checkpoint review, use
`prompts/review.prompt.md`. Count saved rounds first and never schedule more
than two before an owner decision. For scheduler phases, verify explicit package
selection, preview versus `--apply`, authentication probes, time/task bounds,
reports and recovery against `docs/scheduler.md`.
