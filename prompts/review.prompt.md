---
description: "Save bounded checkpoint review findings in the owning package."
mode: agent
model: claude-opus-4.7
---

# Review

Read `AGENTS.md`, `docs/specs.md`, and the selected package's `spec.md`,
`plan.md`, `tasks.md`, and existing checkpoint reviews. Resolve the package on
its declared branch. The owner's request defines the review scope, checkpoint,
reviewer identity and reviewed revision. Resolve that revision to a full commit
ID; describe any reviewed uncommitted changes separately. If these inputs cannot
be established, report the missing input without inventing a verdict.

Review the actual changes and relevant requirements, tests and evidence. Check
for correctness, preservation of user work, missing failure paths, regressions,
and scope or checkpoint violations. Verify material claims against the sources.
Do not implement fixes or start another review without owner authorization.

Save the complete findings in the owning package at
`reviews/<date>-<checkpoint>-<reviewer>-findings.md`, using the actual date
(`YYYY-MM-DD`) and filename-safe checkpoint and reviewer identifiers. Preserve
earlier evidence; use a round suffix in the reviewer identifier when necessary
(for example `opus-r1` and `opus-r2`), never overwrite earlier findings.

Begin the file with these header fields:

```markdown
# Checkpoint review

Reviewer: <reviewer identity>
Reviewed revision: <full commit ID>
Verdict: <accept | changes | blocker>
```

Use exactly one verdict: `accept` when no required changes remain, `changes`
when required corrections remain, or `blocker` when the review cannot accept
the work due to blocking defects. Follow the header with numbered findings,
each explicitly marked `blocker`, `major` or `minor`, with concrete source
references, consequence, and requested correction. If there are no findings,
state that plainly. Include validation performed and any evidence limitations.

The implementer answers every finding by number in the matching
`reviews/<date>-<checkpoint>-<reviewer>-dispositions.md`, linking the findings
and recording the fix and validation or justified deferral. The implementer
must fix blocker and major findings before presenting the checkpoint for
acceptance. Minor findings may be deferred to the `Known limits` list in
`tasks.md`, with a link from their dispositions.

A checkpoint gets at most two review rounds. Check existing saved records
before starting; after two rounds the owner accepts, cuts scope or reopens the
plan. Do not start a third or extra adversarial round without an explicit owner
request. Missing findings, remaining required corrections and exhausted rounds
mean the checkpoint is incomplete. Only the owner clears a checkpoint after
accepting the saved findings and dispositions; never auto-clear it. A checkpoint
row links at most its latest findings and latest owner decision; the decision
links earlier records so evidence remains reachable.

After saving, reply in chat with only the findings file path and verdict.
