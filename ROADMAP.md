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

## Improvement backlog — code/data-repo extensions

Items 7–14 came from a cross-repo audit (2026-04-24) against `gg` (PlantComposer), a data-heavy ontology repo that has independently evolved patterns the current downstream consumers (`baseline-foundry`, `brand-layout-ops`, `canonical-spacing-spec`) have not. They generalise the kit beyond docs/spec repos.

### 7. Repo-type-aware source-of-truth precedence - implemented

The kit's current precedence list (`specs → ROADMAP → instructions → STATUS → ...`) is correct for docs/spec repos. For code/data repos, `gg` correctly puts canonical repo data (`ontology.ttl`, `schema/**/*.ttl`, source code, committed assets) at position 1, above `ROADMAP.md`. The principle: drift in roadmap text never overrides what the schema or source code actually says.

**Implemented.** `.github/copilot-instructions.md` now includes docs/spec and code/data precedence examples.

### 8. Token discipline section template - implemented

Add an optional `## Token discipline` section to the `copilot-instructions.md` template with placeholders for large generated dirs and big data paths. Without it, every code/data consumer eventually rediscovers the same "don't read the whole `outputs/` tree" rule the hard way. `gg`'s working version:

> - Use `rg` / targeted reads; don't open the whole species library unless editing specific traits.
> - Avoid large reads of `<heavy-data-or-output-dir>`.
> - Keep explanations short; prefer pointers to files and sections.

**Implemented.** `.github/copilot-instructions.md` now includes a `## Token discipline` section with downstream placeholders for heavy generated/data paths.

### 9. `docs/roadmap/NN-topic.md` and `docs/vision/` patterns - implemented

The kit currently only documents `docs/specs.md`. `gg` has scaled past a single-file `ROADMAP.md` by using numbered thematic deep documents (`docs/roadmap/00-macro-audit.md`, `01-species-scoping.md`, `02-professional-benchmarking.md`, `03-minimal-ui-progression.md`, `04-strategic-audit-and-plan.md`) plus a `docs/vision/` directory for stable long-horizon vision content.

Action: formalise this in the kit's `README.md`. Recommended pattern:

- `ROADMAP.md` stays as navigation page + current direction summary.
- `docs/roadmap/NN-topic.md` for thematic deep documents (~300+ lines, standalone provenance) that the roadmap references but does not inline.
- `docs/vision/` for long-horizon product-vision content that changes on a slower clock than the roadmap.

**Implemented.** `README.md` now documents the scaling pattern.

### 10. Tiered validation: full + targeted - implemented

The kit's `## Validation` section shows a single command. `gg` does it better with a "broad command + narrower targeted command" pattern that matches how validation is actually used in practice (full suites are too slow to run after every change; per-task targeted checks get used). Restructure the kit's template so consumers fill in both:

```
## Validation

### Full validation (before merging substantial changes)
<full-test-or-build-command>

### Targeted validation (during incremental work)
<example-narrow-command>
```

**Implemented.** `.github/copilot-instructions.md` now separates full validation from targeted validation.

### 11. TODO.md with priority sections - implemented

The kit's `TODO.md` template is a flat checkbox list. `gg` uses Short-term / Medium-term / Long-term sections with P1–P3 priorities tagged inline, and an explicit "Maintaining this file" header noting *"Only open items. Git history is the record of completed work."* That last line is a useful anti-drift guard.

**Implemented.** `TODO.md` now uses Short-term / Medium-term / Long-term sections with inline P-tags and a maintenance header.

### 12. "What this repo is" header in `copilot-instructions.md` - implemented

`gg`'s instruction file opens with a four-line `## What this repo is` block (description, key namespaces, key entry-point scripts, repo quirks). This is the highest-bandwidth context an agent ever needs and putting it at the top means it lands in every session's first context window.

**Implemented.** `.github/copilot-instructions.md` now opens with a short repo-orientation block.

### 13. Concise `agent.md` template (the gg shape) - implemented

`gg`'s `.github/agents/agent.md` is the right size by construction — 18 lines, front-matter description, "first read" list, and a short "repo-specific notes" tail. It solves the "don't make this a second STATUS.md" problem because it's structurally short.

Action: replace the kit's reference example for `.github/agents/agent.md` with the `gg` shape:

```yaml
---
description: "Use when continuing work in <repo>..."
---
# <Repo> Resume Agent
All workflow rules and repo-specific notes live in `.github/copilot-instructions.md`.
## First read
1. STATUS.md ...
...
## Repo-specific notes
- <quirk 1>
- <quirk 2>
```

**Implemented.** `.github/agents/agent.md` is now a compact first-read prompt with repo-specific notes.

### 14. New prompts: `/run-validation` and `/freshen-status` - implemented

Two prompts the kit doesn't have that data/code repos benefit from:

- **`/run-validation`** — runs the repo's full validation command (whatever `copilot-instructions.md` says under `## Validation`), reports pass/fail, and surfaces any new warnings.
- **`/freshen-status`** — re-reads the actual repo state (file counts, test pass rate, key metrics from a specified script) and updates `STATUS.md` with current numbers. Catches the `gg`-style "outer date is fresh, inner subheader is months old" drift pattern automatically.

**Implemented.** Added `prompts/run-validation.prompt.md` and `prompts/freshen-status.prompt.md`; `README.md` now lists both commands.

### 15. `workflow-kit lint` and `workflow-kit diff` - implemented

Added `workflow-kit.ps1` plus `bin/workflow-kit` and `bin/workflow-kit.cmd`.

The linter checks required workflow files, frontmatter, inbox drainage, `TODO.md` priority sections, tiered validation, token discipline, concise resume-agent shape, history rotation, and placeholder spec references.

The diff mode also compares copied canonical scheduler, launcher, installer, and prompt files against the kit so downstream repos can detect drift.


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

#### Resolved decisions (2026-04-29)

- **Bookkeeping scope** — the scheduler updates `TODO.md` only. `HISTORY.md` and `STATUS.md` are synthesis artefacts (need framing across multiple commits, narrative grouping); a per-task auto-append produces noise. The `/orchestrate` and `/freshen-status` prompts handle these explicitly when an orchestrator returns. Separation of concerns wins.
- **Branch + PR vs direct commit** — direct commit to the current branch stays the default. The disposable worktree already provides isolation. For repos that want PR workflow, an opt-in `-Branch <name>` flag (and optional `gh pr create` hook) is additive and tracked as an `[S]` follow-up.
- **Failure handling** — stop by default. Retry rarely converges (same prompt → same failure) and silent skip risks blundering through compounding errors. An opt-in `-OnFailure skip|retry|stop` flag is tracked as an `[S]` follow-up for repos with many genuinely independent items.

#### Open questions

- Optimal `--max-autopilot-continues` for real tasks (5 may be low for complex work)

#### VS Code prompt files (implemented)

For the "don't type the same thing" problem, canonical prompt files now live in `prompts/` in this repo and can be installed into VS Code user prompt folders with `install-vscode-prompts.ps1`:

| Command | File | Purpose |
|---------|------|---------|
| `/whats-next` | `prompts/whats-next.prompt.md` | Session start: audit, triage inbox, recommend next task |
| `/overnight` | `prompts/overnight.prompt.md` | Launch the overnight `agent-loop.ps1` scheduler against the current repo |
| `/audit-workflow` | `prompts/audit-workflow.prompt.md` | Check all workflow files for staleness and drift |
| `/run-validation` | `prompts/run-validation.prompt.md` | Run the repo's declared validation command and report pass/fail |
| `/freshen-status` | `prompts/freshen-status.prompt.md` | Refresh `STATUS.md` from actual repo state |

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

- Canonical kit items 1-14 are implemented.
- Workflow lint/diff checks are implemented so downstream repos can detect drift from the canonical kit.
- Mirroring refinements to active repos remains a rollout task.

### Stage 3 — Cross-repo orchestration

- Formalise multi-repo coordination patterns.
- Consider whether a shared workspace-level config or prompt can enforce consistency without per-repo duplication.

## Notes

- Keep this file stable. Update rarely but intentionally.
- Promote items into `TODO.md` only when they become active work.
