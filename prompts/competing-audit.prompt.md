---
description: "Run a 'no-stones-unturned' audit of a target artifact (talk, doc, design, codebase area) by dispatching two competing heavy-tier subagents in parallel, then synthesise their findings into a triaged plan."
mode: agent
model: claude-opus-4.7
---

# Competing audit — two subagents, one synthesis

## Workflow mode

Read `.workflow-kit.json` as JSON and inspect `workflowModelVersion`. If `.workflow-kit.json` is missing or `workflowModelVersion` is absent,
including when only `canonicalMirrorMode: external` is set, select legacy mode. Select spec-first mode only when `workflowModelVersion` is the JSON integer `1`;
do not coerce strings or other values. Stop if the JSON is
malformed, is not an object, or contains a present invalid or unsupported
version. Do not infer the mode from root files or placeholders. Execute only the
matching route below; version 1 must not execute Legacy procedure.

## Version 1 route

Resolve the target and its governing `AGENTS.md`, catalog entry, and package records first. Run two independent reviews of the requested artifact and synthesize a deduplicated plan. Respect package lifecycle, checkpoint, and write scope, and keep findings in the authorized owner record.

## Legacy procedure

Run a high-stakes review of a single target artifact (a talk script, a spec, a design proposal, an architectural decision, a feature plan, anything where one perspective is not enough) by **dispatching two heavy-tier subagents in parallel on different model families**, collecting their independent reports, and synthesising the result into a triaged, deduplicated, prioritised action plan.

The point is not to ask the same model twice. It's to weaponise the disagreement between two strong models that fail in different ways.


## When to use this

- The artifact is high-stakes (CEO-facing talk, foundational spec, architectural pivot, public-facing copy).
- A single review pass would not be trusted by the user.
- The cost of getting it wrong is materially higher than the cost of two heavy-tier runs.
- You have at least two heavy-tier models available; use agent-loop.ps1's TierDispatchMap as the preference owner and choose distinct model families when available.

If only one heavy model is available, run this prompt as a single-subagent audit instead and note it in the synthesis. Don't run two copies of the same model — the divergence is the value.


## Pre-flight — orchestrator does this before dispatching

1. **Identify the target.** Confirm exactly which file or set of files is the artifact under review. Write the absolute path(s) into the dispatch prompt verbatim.
2. **Identify the supporting context.** Which sibling files (planning notes, prior drafts, audience notes, source material, sibling-repo references) the subagents must read to do an *informed* audit, not a surface one. List them with absolute paths.
3. **Identify the verifiable surface.** Any concrete claims in the artifact that can be checked against the actual codebase, repo, or external source. Tell the subagents to spot-check.
4. **Decide the report shape.** What sections you need from each subagent — at minimum: things to fix (priority-tagged), things to add, things to cut, open questions for the user, and a one-line verdict. Add domain-specific sections as needed.
5. **Choose the two models.** Read agent-loop.ps1's TierDispatchMap; select capable heavy-tier reviewers from distinct families where available. Record the actual pairing in the synthesis.
6. **Decide where the synthesis lands.** A new dated file under `docs/` or equivalent, or appended to an existing planning doc. Don't let the subagent reports themselves become the plan — they are inputs to a synthesis the orchestrator writes.


## Dispatch — two parallel subagent calls

Send both at the same time, in a single tool-use block. Do not wait for one before sending the other.

For each subagent, the prompt must include:

1. **Mission line.** *"You are doing a no-stones-unturned audit of [TARGET]. You are competing in parallel with another reviewer ([OTHER MODEL]). Produce your strongest independent report. Do not coordinate."*
2. **What to read, in order.** Absolute paths. Top-priority artifacts first; supporting context next; spot-check sources last. Be explicit that **token budget is not a constraint** for this run.
3. **What the artifact is supposed to do.** Audience, purpose, format, constraints, hard limits (time, length, scope). Without this, the audit drifts toward generic critique.
4. **What "no stones unturned" means here.** Spell it out — every sentence challenged on register, every concrete claim spot-checked, every implicit assumption surfaced. *"Treat anything you find unconvincing as worth flagging, even if you suspect the speaker meant it that way."*
5. **The report shape.** Use the headings you decided in pre-flight. Require:
   - **Verdict** — one paragraph, brutally honest.
   - **P0 / must-fix** — items where shipping as-is would be a problem.
   - **P1 / strongly recommend** — items that would materially improve the artifact.
   - **P2 / consider** — items the user can decide to ignore.
   - **Open questions for the user** — places where the subagent could not decide and needs a call.
   - **What's actually working** — at least 3 things you would not change. (Forces honesty in both directions.)
   - **One sentence you'd defend in print** — the strongest single take-away.
6. **Spot-check requirement.** *"Before you assert any concrete claim about [the codebase / the repos / the external source], read the actual file and quote the line. If you can't verify it, say so."*
7. **Where to write the report.** Each subagent writes its own file with its model name in the filename, e.g. `docs/audit-opus47.md` and `docs/audit-gpt55.md`. Don't have them edit the target artifact itself.
8. **Return-message contract.** *"Return a short message back to me with: where you wrote the report, your one-sentence verdict, the single thing you most want me to challenge the other reviewer on, and the single thing you are least confident about."*


## Synthesis — orchestrator does this once both reports return

This is the heavy work. Do not skip steps.

1. **Read both reports in full.** No skimming.
2. **Triage every finding** into one of:
   - **Convergent** — both reports raised it. Highest signal. These are P0 by default unless one report explicitly justified leaving it.
   - **Divergent agreement-on-target** — both reports flagged the same passage but proposed different fixes. Surface both fixes; pick one or merge.
   - **Single-source insight** — only one report raised it. Evaluate on merit, not vote count. A unique insight from one strong model often beats a consensus point.
   - **Disagreement** — the two reports contradict each other. Flag explicitly; let the user decide.
3. **Deduplicate.** If three findings are facets of one underlying issue, collapse them.
4. **Re-rank.** P0/P1/P2 from the merged set, not from either source's individual rankings.
5. **Write the synthesis as a new dated file.** Sections:
   - **TL;DR** — three sentences. What's the verdict, what's the one most important change, what's the open question.
   - **P0 must-fix** — short, actionable, with a one-line rationale and a "from: opus / from: gpt5 / from: both" attribution.
   - **P1 strongly recommend** — same shape.
   - **P2 consider** — same shape.
   - **Disagreements** — where the two reports contradicted; what each said; what you (the orchestrator) think and why.
   - **Open questions for the user** — explicit list. Each one needs a yes/no or pick-an-option resolution before the next step.
   - **What's working** — short list. Both reports' positive observations merged.
   - **Provenance** — which models, which dates, which input artifacts, paths to the two raw reports.
6. **Surface the open questions to the user before doing anything destructive.** Do not edit the target artifact based on the synthesis until the user has answered the open questions. The point of the audit is to make the user better-informed, not to ship a fix on the strength of two model votes.


## Optional follow-up — competing rewrite

Once the user has resolved the open questions, you can run a parallel competing rewrite using the same two models. Same dispatch shape, but the prompt now says *"first full rewrite of [TARGET]"* and includes the synthesis as the contract. Each subagent writes to a separate `*.draft.md` file. The orchestrator then merges the best lines from each, tracking provenance.

This is a separate prompt run; do not chain it into the audit run automatically. The user should decide whether the audit warrants a competing rewrite or a single careful pass.


## Cost discipline

Two heavy-tier runs is expensive. Use this prompt only when the artifact justifies it. For routine review, dispatch a single heavy subagent or use the standard tier. The honest test: if the user would not personally review both reports word-for-word, don't run two of them.


## Report back to the user

After the synthesis lands, return a short message:

- Path to the synthesis file.
- Paths to the two raw reports.
- Model pairing used.
- The single most important open question for the user to answer first.
- Estimated cost (qualitative — "two heavy-tier runs plus synthesis on heavy tier").

Do not start the rewrite step in the same turn. Wait for the user to decide.
