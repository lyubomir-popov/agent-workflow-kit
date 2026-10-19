---
description: "Read-only diagram-generator audit of health, architecture drift, and duplicate sources of truth."
agent: agent
---

# diagram-generator repo audit

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

Work only in the diagram-generator repository or its folder in a multi-root
workspace. Read `AGENTS.md`, the catalog, active package owners, README,
`DIAGRAM.md`, relevant architecture docs, and the actual implementation. Note
dirty or in-flight work without modifying it.

Use this intended direction as a benchmark:

1. A reference image or description becomes frame YAML.
2. TypeScript in `packages/layout-engine/` produces editable SVG in the browser.
3. Python narrows to preview hosting, YAML save helpers and transitional parity,
   rather than owning new layout or rendering behavior.

Audit repo health, stale paths, architectural drift, Python layout/render/API
ownership, duplicated Python/TypeScript work, competing sources of truth and the
force-layout lane. Verify claims against current files. Treat product-specific
paths as evidence to inspect, not guaranteed current locations.

Report:

- a short verdict and the largest risk;
- force-layout status and the intended TypeScript recovery path;
- intended versus actual architecture;
- a table of legacy/double-work locations and severity;
- canonical versus derived sources of truth;
- stale documentation and concrete file references;
- strengths and ranked next actions tagged `[H]`, `[S]`, `[L]` or `[X]`.

Stay read-only unless the user asks to persist the report. Save an authorized
report in the owning package or established architecture-report destination;
do not create a root TODO queue. A checkpoint review must follow
`prompts/review.prompt.md` and the two-round limit.
