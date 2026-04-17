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

### 1. HISTORY.md rotation

HISTORY.md will grow unbounded. After 6 months of active work it becomes too long for agents to usefully scan.

**Proposal:** Add a rotation rule — archive entries older than N months to `docs/archive/YYYY.md`, or keep only the last 20 entries in HISTORY.md.

### 2. docs/specs.md template

The boilerplate version is a placeholder header. Repos with real spec linkage (like baseline-foundry) need a table format. New repos won't know what to put here.

**Proposal:** Add a two-line template showing the expected table format: spec name, path, upstream source, version.

### 3. Validation gate

The instructions say "run `npm test`" but there's no explicit checkpoint in the session workflow. The autonomous-continuation rule says "make validated checkpoint commits" without defining what validated means per repo.

**Proposal:** Add a `## Validation` section to `copilot-instructions.md` with the exact commands to run before committing, scoped per repo.

### 4. Session-end resilience

Agents forget or run out of context before reaching session-end steps. The rules say update STATUS, ensure INBOX is empty — but in practice the agent's last turn often gets cut short.

**Proposal:** Make session-start do double duty. Step 1 should also verify that STATUS isn't stale from a previous session, rather than relying on the prior session's cleanup.

### 5. Quick-start prominence

The `AGENTS.md` → `.github/copilot-instructions.md` migration was expensive across 4 repos. This suggests the naming convention should be more prominent in the README — first thing under "Quick start" rather than buried in a list.

**Proposal:** Restructure the README so the `.github` file convention is the first thing a new-repo creator sees.

### 6. Cross-repo coordination

Multiple repos reference each other but there's no explicit cross-repo handoff pattern. The boundary rules say "work in this repo only" but don't cover the case where one repo's work creates a dependency on another.

**Proposal:** Add a convention like "drop a note in the target repo's INBOX.md" to formalize what currently happens ad hoc.

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