---
description: "Save bounded checkpoint review findings in the owning package."
agent: agent
---

# Review

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

Read `AGENTS.md`, `docs/specs.md`, and the selected package's `spec.md`,
`plan.md`, `tasks.md`, and existing checkpoint reviews. Resolve the package on
its declared branch. The owner's request defines the scope, checkpoint, reviewer
identity and reviewed revision. Resolve that revision to a full commit ID and
describe reviewed uncommitted changes separately. If an input is missing, report
it without inventing a verdict.

Review the actual changes, requirements, tests and evidence. Check correctness,
preservation of user work, failure paths, regressions and scope or checkpoint
violations. Verify material claims. Do not implement fixes or start another
round without authorization.

Save complete findings at
`reviews/<date>-<checkpoint>-<reviewer>-findings.md`, using the actual date and
filename-safe identifiers. Preserve prior evidence and use a round suffix when
needed.

Begin with:

```markdown
# Checkpoint review

Reviewer: <reviewer identity>
Reviewed revision: <full commit ID>
Verdict: <accept | changes | blocker>
```

Allowed verdict values are `accept`, `changes` and `blocker`; use exactly
one. Follow it with numbered findings explicitly marked `blocker`, `major`
or `minor`, with source references, consequence and requested correction. If
none exist, say so. Include validation and evidence limits.

The implementer answers every finding by number in
`reviews/<date>-<checkpoint>-<reviewer>-dispositions.md`. Blocker and major
findings must be fixed. Minor findings may be deferred to `Known limits` in
`tasks.md`, linked from dispositions.

A checkpoint gets at most two review rounds. Count saved records before starting.
After two, the owner accepts, cuts scope or reopens the plan. Missing findings,
required corrections or exhausted rounds leave the checkpoint incomplete. Only
the owner clears it. The checkpoint row links at most the latest findings and
latest owner decision; that decision links earlier records.

After saving, reply with only the findings file path and verdict.
