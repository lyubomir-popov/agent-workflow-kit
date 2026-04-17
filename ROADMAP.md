# Roadmap

## Purpose

This repo is the centralised process blueprint for AI-agent workflow conventions. Changes land here first, then get mirrored to active repos.

## What works well

1. **Single-file ownership.** Every fact lives in exactly one place. This prevents the most common AI-agent failure mode: status leaking into multiple files until the agent contradicts itself.

2. **The inbox pattern.** `INBOX.md` lets the user drop async notes without derailing the agent. Simple, effective buffer between human thinking and agent execution.

3. **Cold-start resume.** `STATUS.md` + `.github/agents/agent.md` means any agent in any session can pick up the thread without reading full history. This is the right shape for stateless LLM conversations.

4. **Planning threshold.** Explicit rules for when to plan vs. act prevent the two most common failure modes: over-planning trivial tasks and cowboying architectural changes.

5. **Source-of-truth precedence.** Numbered priority order eliminates ambiguity when docs disagree.

## Improvement backlog

### 1. HISTORY.md rotation ✅

**Implemented.** Rule added to `copilot-instructions.md`: archive when HISTORY.md exceeds ~200 lines. Ceiling chosen because that's roughly the amount an agent can scan in one read without it becoming noise.

### 2. docs/specs.md template ✅

**Implemented.** Added wording: "If a spec or specs exist, they are the source of truth, linked here. If not, ROADMAP.md assumes the role of the source of truth."

### 3. Validation gate ✅

**Implemented.** Added `## Validation` section to `copilot-instructions.md` with placeholder commands and a rule to validate before committing.

### 4. Session-start resilience ✅

**Implemented.** Session-start step 1 now says: "If STATUS looks stale or references work that is clearly finished, update it before proceeding — do not assume the previous session cleaned up."

### 5. Quick-start prominence ✅

**Implemented.** README restructured so the `.github` file convention is the first section under the title, before the workflow map.

### 6. Cross-repo coordination ✅

**Implemented.** Added `## Cross-repo coordination` section to `copilot-instructions.md` with the pattern: drop a note in the target repo's INBOX.md. Documented the one-agent-per-repo-for-features / one-agent-across-repos-for-mirroring split.

## Research backlog

### Autonomous overnight runs

Current LLM agents lose coherence after ~30–60 minutes of autonomous work because context fills up. The user wants genuine overnight autonomous operation. No established best practice exists yet. Current best mitigations documented in `copilot-instructions.md` under "Maximising autonomous run length":

- Narrow scope per burst
- Checkpoint-and-resume via shell loop or CI
- Keep TODO items small and decomposed
- Prefer sequential single-repo sessions

**Open question:** Can a shell loop or CI pipeline reliably restart fresh agent sessions that pick up from STATUS.md? This needs experimentation.

## Maturity stages

### Stage 1 — Convention established ✅

- File naming and placement standardised.
- `.github/copilot-instructions.md` as canonical instruction file.
- `.github/agents/agent.md` as resume prompt.
- Core workflow rules: inbox pattern, planning threshold, history discipline, source precedence.
- Boilerplate repo created as reference.

### Stage 2 — Refinements

- Address items 1–6 from the improvement backlog above.
- Mirror refinements to active repos (baseline-foundry, brand-layout-ops, canonical-spacing-spec).

### Stage 3 — Cross-repo orchestration

- Formalise multi-repo coordination patterns.
- Consider whether a shared workspace-level config or prompt can enforce consistency without per-repo duplication.

## Notes

- Keep this file stable. Update rarely but intentionally.
- Promote items into `TODO.md` only when they become active work.