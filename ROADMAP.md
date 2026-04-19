# Roadmap

## Purpose

This repo is the centralised process blueprint for AI-agent workflow conventions. Changes land here first, then get mirrored to active repos.

## What works well

1. **Single-file ownership.** Every fact lives in exactly one place. This prevents the most common AI-agent failure mode: status leaking into multiple files until the agent contradicts itself.

2. **The inbox pattern.** `INBOX.md` stays user-facing while `AGENT-INBOX.md` absorbs long machine handoffs and diagnostics. That keeps human notes easy to scan without giving up asynchronous agent coordination.

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

**Implemented.** Added `## Cross-repo coordination` section to `copilot-instructions.md` with the pattern: drop a machine-generated note in the target repo's `AGENT-INBOX.md` while reserving `INBOX.md` for user-authored notes. Documented the one-agent-per-repo-for-features / one-agent-across-repos-for-mirroring split.

## Research backlog

### Autonomous overnight runs ✅

Proven architecture using Copilot CLI as the worker and a PowerShell script as the scheduler. Tested successfully with 2 trivial tasks — both completed, committed, and checked off automatically.

#### Architecture

```
agent-loop.ps1 (PowerShell scheduler)
  └── copilot -p "<task>" --autopilot --allow-all --no-ask-user -s
        └── reads workflow files, implements one TODO item, commits
        └── scheduler verifies commit, marks task done, loops
```

#### Why Copilot CLI, not Claude Code or Codex

| Option | Verdict |
|--------|---------|
| **Copilot CLI** ✅ | Company-paid, CLI-scriptable, `--autopilot` mode, git-aware, fresh context per invocation |
| Claude Code | Requires separate API key / subscription |
| Codex (ChatGPT Plus) | Plus limits too tight for overnight loops (~20–100 msgs/5h); API is separate pay-as-you-go |
| Aider + Ollama | Free but lower code quality for complex tasks |

#### Prerequisites

1. Copilot CLI: `npm install -g @anthropic-ai/copilot-cli` (or accept VS Code prompt)
2. GitHub CLI auth: `gh auth login --web -h github.com` (one-time; Copilot reads this token)
3. PowerShell 7+

#### Key flags

- `--autopilot` — no human in the loop
- `--allow-all` — no file/tool permission prompts
- `--no-ask-user` — don't block on questions
- `--max-autopilot-continues 5` — safety cap per task
- `-p` — non-interactive prompt mode
- `-s` — silent output (agent response only)

#### Open questions

- Should the loop run on a branch and PR, or commit directly to master?
- How to handle failures: retry once, skip, or stop?
- Should the scheduler also update HISTORY.md, or leave that to the agent?
- Optimal `--max-autopilot-continues` for real tasks (5 may be low for complex work)

#### VS Code prompt files (implemented)

For the "don't type the same thing" problem, canonical prompt files now live in `prompts/` in this repo and can be installed into VS Code user prompt folders with `install-vscode-prompts.ps1`:

| Command | File | Purpose |
|---------|------|---------|
| `/whats-next` | `prompts/whats-next.prompt.md` | Session start: audit, triage inbox, recommend next task |
| `/overnight` | `prompts/overnight.prompt.md` | Launch the overnight `agent-loop.ps1` scheduler against the current repo |
| `/audit-workflow` | `prompts/audit-workflow.prompt.md` | Check all workflow files for staleness and drift |

`/proceed-autonomously` remains available as a legacy alias via `prompts/proceed-autonomously.prompt.md`, but `/overnight` is now the preferred shorter command.

After installation, these work inside VS Code Copilot Chat on any machine where this repo is cloned. The overnight scheduler itself is still driven by Copilot CLI via `agent-loop.ps1`.

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