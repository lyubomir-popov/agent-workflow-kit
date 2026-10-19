---
description: "Run two independent high-stakes audits and synthesize verified findings."
agent: agent
---

# Competing audit

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

## When to use it

Use this for an artifact whose review cost is justified by material risk and
where two genuinely independent perspectives are available. Otherwise run one
strong audit and state the limitation. Repeated copies of the same perspective
do not provide useful independence.

Reusable prompts inherit the invoking host's selected model. When using the
scheduler, model tiers and reviewer profiles come only from
`templates/scheduler-defaults.json` and explicit config overrides. Record each
actual reviewer identity; do not infer one from prose or frontmatter.

## Preflight

1. Identify the exact target and absolute paths.
2. List supporting context and verifiable claims.
3. State audience, purpose, format, hard limits and accepted requirements.
4. Define a common report shape and authorized destination.
5. Check package checkpoint state and existing review rounds.

For checkpoint work, both perspectives form one bounded review round and feed
one compliant findings record. Never exceed two rounds before an owner decision.

## Independent audits

Dispatch both at the same time when parallel delegation is available and
authorized. Each reviewer receives the same target contract but works
independently. Require:

- a concise verdict;
- blocker/major/minor or P0/P1/P2 findings with evidence;
- additions, cuts and open owner questions;
- at least three strengths;
- the claim it considers most important and the claim it is least certain about;
- concrete source references for verifiable assertions.

Raw reports go to separate new files in the authorized package/report
destination. They do not edit the target.

## Synthesis

Read both reports fully. Classify every finding as convergent, different fixes
for the same issue, a single-source insight, or a disagreement. Verify it,
deduplicate shared causes and rerank by consequence.

Write one synthesis containing the verdict, required changes, optional changes,
disagreements, owner questions, strengths and provenance. For a checkpoint,
follow `prompts/review.prompt.md` for the findings filename, headers,
dispositions and severities. Do not claim an unattested identity or clear the
gate.

Return the synthesis path, raw report paths, actual reviewers and the most
important owner question. Do not start a rewrite or implementation in the same
procedure unless separately authorized.
