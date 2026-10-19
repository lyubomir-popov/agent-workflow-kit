---
description: "Dual-perspective repository health audit saved under the owning package."
agent: agent
---

# Repository health audit

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

Resolve `AGENTS.md`, the catalog, current package owners, product direction and
actual source. Keep the audit read-only until the user authorizes a report or
fixes. Do not infer state from retired root workflow files.

Use two complementary perspectives when capable reviewers are available:

- a domain/product reviewer checks purpose, user value, conceptual coherence and
  stale direction;
- a software-architecture reviewer checks boundaries, duplication, testability,
  error handling, dependencies and maintenance risk.

Choose reviewers from the invoking host or configured scheduler profiles and
record their actual identities. Do not invent model names. If the work is a
checkpoint review, count existing rounds before dispatch and follow
`prompts/review.prompt.md`; two rounds require an owner decision.

Synthesize a dated report with an executive verdict, concrete evidence, strengths,
findings ordered by severity, disagreements, and ranked actions tagged by
complexity. Save it in the package's authorized `reviews/` or another existing
report destination named by the user. Route actionable work into the package's
`tasks.md` only when authorized; do not create a parallel queue or blindly
empty inboxes.

Do not commit or push unless the user explicitly included those actions in scope.
Report the saved path, reviewer identities, validation performed and unresolved
owner decisions.
