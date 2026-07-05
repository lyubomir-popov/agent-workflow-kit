# agent-workflow-kit

This repo packages a standardized agent workflow kit for human plus agent collaboration.

## Quick start: file convention

Agent instructions live under `.github`, not the repo root:

- **`.github/copilot-instructions.md`** — the single repo-wide instruction file (rules, precedence, workflow)
- **`.github/agents/agent.md`** — optional repo-specific resume prompt

Everything else lives at the repo root as operational workflow files:

```
README.md        — human-readable overview
ROADMAP.md       — long-term direction
TODO.md          — active execution queue
INBOX.md         — async user notes (agent drains these)
AGENT-INBOX.md   — agent-only handoffs and diagnostics
STATUS.md        — cold-start orientation
HISTORY.md       — completed work archive
docs/specs.md    — upstream specs and sibling-repo references
```

The rule: every important piece of project state lives in exactly one place.

## What this is

Use this repo as a starter or reference whenever you create a new project and want the same lightweight operating model.

## Workflow map

| File | Purpose |
|------|---------|
| `.github/copilot-instructions.md` | Agent rules, workflow conventions, precedence rules |
| `.github/agents/agent.md` | Optional resume-agent prompt for repo-specific continuation |
| `README.md` | Human-readable overview and workflow reminder |
| `ROADMAP.md` | Long-term direction and future stages |
| `TODO.md` | Active queue, principles, architecture notes |
| `INBOX.md` | Quick user notes to be triaged later |
| `AGENT-INBOX.md` | Machine-generated handoffs and long diagnostics awaiting triage |
| `STATUS.md` | Cold-start orientation for the next session |
| `HISTORY.md` | Archive of completed work |
| `docs/specs.md` | Upstream specs, source docs, sibling references |

`INBOX.md` and `AGENT-INBOX.md` have different jobs. User notes stay in `INBOX.md` so they remain easy to scan. Long agent-to-agent handoffs, cross-repo follow-ups, and automation diagnostics go in `AGENT-INBOX.md` instead.

## How to work in this repo

### If you are the user

1. Put interrupting ideas, reminders, and loose notes in `INBOX.md`.
2. Do not put agent-to-agent handoff text in `INBOX.md`; that belongs in `AGENT-INBOX.md` and is maintained by the agent.
3. Do not maintain separate handoff or backlog files elsewhere.
4. Read `README.md` and `STATUS.md` when returning after time away.
5. Use `ROADMAP.md` for long-term direction, not the active task queue.
6. Use `TODO.md` for the next real work items only.

## LLM efficiency notes

These habits are more valuable than prompt cleverness when you are using a coding LLM on a real project.

- Pick one model per task. Model switches often invalidate caches and force the tool to reprocess the same context again.
- Keep permanent instructions short. Long standing instructions cost tokens repeatedly, so reserve them for durable rules and move one-off task detail into the current prompt, `TODO.md`, or `STATUS.md`.
- Store project memory in files, not only in chat. `STATUS.md`, `TODO.md`, `HISTORY.md`, and `docs/specs.md` exist so the agent can reload state cheaply and accurately after a restart.
- Prefer markdown, plain text, and lists over complex pages and tables. Retrieval and HTML-to-markdown pipelines often flatten layout, drop metadata, and distort tables.
- Search in small deliberate passes. Several narrow searches with verification are usually better than one broad query that misses the right slice.
- Checkpoint and restart freely. Short resumable sessions are usually more reliable than trying to preserve one huge conversation forever.
- Treat workflow as part of the product. Memory, verification, tools, and repo structure usually matter more than squeezing slightly better wording out of a prompt.

Educational notes:

- Good repo state beats long chat history. If a new session can recover by reading a few markdown files, your workflow scales.
- Durable rules should stay stable. Temporary context should be disposable. Mixing those two is a common source of token waste.
- Verification is part of efficient prompting. A fast wrong answer that is never checked is more expensive than a slower answer with a narrow validation step.
- If the model seems inconsistent, reduce moving parts first: same model, same task boundary, same source files, smaller context.

### If you are the agent

1. Start with `STATUS.md`.
2. Drain `INBOX.md` into `TODO.md` or `ROADMAP.md`.
3. Drain `AGENT-INBOX.md` into canonical files.
4. Read `TODO.md`.
5. Read `docs/specs.md` before changing spec-governed behavior.
6. Update `STATUS.md`, `TODO.md`, and `HISTORY.md` as work lands.

## Rules of thumb

- `TODO.md` is for active work, not ideas you might do someday.
- `ROADMAP.md` is for direction, not this week's execution queue.
- `HISTORY.md` only records finished work.
- `STATUS.md` should tell a new chat what matters right now.
- `docs/specs.md` should answer: what external sources govern this repo?

## Scaling roadmap and vision docs

Most repos should start with one root `ROADMAP.md`. When a repo grows past that, keep the root roadmap as a navigation page and current direction summary.

Recommended extensions:

- `docs/roadmap/NN-topic.md` for thematic deep documents that are too long to inline in `ROADMAP.md`
- `docs/vision/` for stable long-horizon product vision that changes less often than the roadmap

Do not create extra status, handoff, or TODO files. Deep roadmap and vision docs are for durable direction only.

## How to use this kit in a new repo

1. Rename the title in this file from `agent-workflow-kit` to the actual repo name.
2. Fill out `STATUS.md` with real orientation and key files.
3. Fill out `docs/specs.md` with the actual upstream docs, specs, or sibling repos.
4. Replace placeholder roadmap stages and TODO items with real ones.
5. Keep `.github/copilot-instructions.md` as the single repo-wide instruction file.
6. Use `.github/agents/agent.md` only for repo-specific resume guidance, not duplicate workflow rules.
7. Run `workflow-kit lint` and fix any findings before treating the repo as initialized.

## Recommended first edits

- `README.md`: replace placeholders and describe the repo in two or three paragraphs.
- `STATUS.md`: add the real current state, key paths, and invariants.
- `docs/specs.md`: list the real source-of-truth docs and stable paths.
- `TODO.md`: write the actual near-term work queue.
- `ROADMAP.md`: capture the long-term shape.

## Why this exists

Most repos decay because the project state gets spread across chat history, random markdown files, and people remembering things. This boilerplate keeps the workflow explicit and lightweight so a repo can be resumed cold without reconstructing context from scratch.

## Reusable VS Code slash commands

This repo can act as the GitHub-synced source of truth for your global VS Code Copilot slash commands. The canonical prompt definitions live in `prompts/`, and `install-vscode-prompts.ps1` copies them into VS Code's user prompt directory on the current machine.

### Command catalog

| Command | Purpose | Suggested model tier |
|---------|---------|----------------------|
| `/whats-next` | Session-start orientation: read `STATUS.md`, drain inboxes, recommend the next task. Reports back without starting work. | `[L]` — `gpt-5.4-mini` or `claude-haiku-4.5` |
| `/freshen-status` | Refresh `STATUS.md` from the actual repo state (git status, key files, validation output). Mechanical sync. | `[L]` — `gpt-5.4-mini` or `claude-haiku-4.5` |
| `/audit-workflow` | Check all workflow markdown files for drift, staleness, and convention compliance. Auto-fixes safe issues. | `[L]`–`[S]` — `gpt-5.4-mini` for spot-checks, `gpt-5.4` if drift is widespread |
| `/run-validation` | Run the repo's declared `## Validation` commands and report pass/fail. Read-only by default. | `[L]` — `gpt-5.4-mini` (or `[X]` if dispatched as a subagent) |
| `/overnight` | Launch `agent-loop.ps1` in **SpecKit** mode: finish the active spec's `tasks.md`, run adversarial review, address findings, then advance to the next **In Progress** spec from `docs/specs.md`. Unattended multi-hour runs. Uses `-Agent Auto`, so Codex-launched runs use Codex and Copilot-launched runs use Copilot. | Orchestrator: `[L]` — `gpt-5.4-mini` to launch from Copilot surfaces. Per-phase model via `-Model` for Copilot; Codex uses its configured default unless a Codex-compatible model is supplied. |
| `/proceed-autonomously` | Legacy alias for `/overnight`. Kept installed for muscle memory. | Same as `/overnight`. |
| `/audit-diagram-generator` | Read-only **diagram-generator** audit: health, staleness, architectural drift, Python legacy traces, double-work, duplicate sources of truth, and force-layout restoration status. Reports in chat; can persist to `docs/architecture/repo-health-audit-*.md`. | `[H]` — `claude-opus-4.7` or `gpt-5.5` preferred; `gpt-5.4 --effort high` as fallback. |
| `/competing-audit` | Run two competing heavy-tier review passes in parallel on one target artifact, then synthesize a single prioritized action plan. | `[H]` — `claude-opus-4.7` plus `gpt-5.5` or `gpt-5.4 --effort xhigh` |
| `/repo-health-audit` | Strategic dual-perspective audit (domain expert + software architect). Persists a dated report under `docs/analyses/` and routes findings into `TODO.md` / `ROADMAP.md`. Run periodically (every 1–2 months or after major milestones). | `[H]` — `claude-opus-4.7` or `gpt-5.5` preferred; `gpt-5.4 --effort high` as fallback. The follow-up TODO/ROADMAP edits can defer to `[S]` `gpt-5.4` or `[L]` `gpt-5.4-mini`. |
| `/orchestrate` | Heavy-tier orchestrator workflow. Triages `TODO.md` with `[H]/[S]/[L]/[X]` tier tags, then dispatches `[S]/[L]/[X]` items to cheaper subagents (gpt-5.4 / gpt-5.4-mini / Explore) while keeping `[H]` decisions on the orchestrator thread. Preserves token budget by never letting Opus do mechanical text shuffling. | `[H]` — pinned to `claude-opus-4.7`. Subagents it dispatches use `gpt-5.4` and `gpt-5.4-mini`. |
| `/simo-plan-sweep` | Tighten an existing implementation plan into safer phases with validation, commit checkpoints, and per-phase sweep instructions before any coding starts. | `[S]` — `gpt-5.4` |
| `/simo-sweep` | Run a broad post-change sweep using parallel critical reviewers, then synthesize verified findings and residual risks. | `[H]` — `claude-opus-4.7` |
| `/sync-all-repos` | Commit and push every dirty repo in the current multi-root workspace so the full working state is available on another machine. | `[L]` — `gpt-5.4-mini` |

### Model tier conventions

These mirror the `[H] [S] [L] [X]` tags used in `TODO.md` and described in `.github/copilot-instructions.md`:

- **`[H]` Heavy** — `claude-opus-4.7` or `gpt-5.5` (preferred), `gpt-5.4 --effort xhigh` (fallback). Use for cross-file refactors, architectural decisions, strategic analysis. Cost class: ~7.5x.
- **`[S]` Standard** — `gpt-5.4` (with `--effort high` for nontrivial work). Use for contained code swaps following an established pattern. Cost class: 1x.
- **`[L]` Light** — `gpt-5.4-mini` or `claude-haiku-4.5`. Use for mechanical text shuffling, housekeeping, INBOX triage, status freshes. Cost class: ~0.33x.
- **`[X]` Subagent / no model** — runs as a dispatch (`Explore`, validation commands, Playwright). Cost class: 0x at the orchestrator level.

**Hard rule**: use the lowest-cost model that is likely to work. Older 1x-tier models (`claude-sonnet-4.5/4.6`, `gpt-4.1`, `gpt-4o`) are allowed when they are the cheapest workable option or when you want model-diverse review, but do not pay 1x for them by default when a clearly stronger 1x model is available.

### How model deferral works

Each prompt file in `prompts/` pins its model in YAML frontmatter:

```yaml
---
description: "..."
mode: agent
model: claude-opus-4.7
---
```

When you invoke the slash command (e.g. `/repo-health-audit`), VS Code Copilot Chat **automatically switches to the pinned model for that run** regardless of what's selected in the model picker. After the prompt finishes, your previous model selection returns. This is the [`model` frontmatter field](https://code.visualstudio.com/docs/copilot/customization/prompt-files#_prompt-file-format) documented by VS Code.

Current pinning in this repo:

| Prompt | Pinned model | Why |
|--------|--------------|-----|
| `/audit-diagram-generator` | `claude-opus-4.7` | diagram-generator architecture and drift synthesis |
| `/competing-audit` | `claude-opus-4.7` | competing dual-heavy audit and synthesis |
| `/repo-health-audit` | `claude-opus-4.7` | Heavy synthesis, dual-perspective reasoning |
| `/orchestrate` | `claude-opus-4.7` | Heavy-tier orchestration; subagent dispatch |
| `/simo-plan-sweep` | `gpt-5.4` | plan tightening and phased implementation prep |
| `/simo-sweep` | `claude-opus-4.7` | deep post-change sweep with parallel reviewers |
| `/sync-all-repos` | `gpt-5.4-mini` | mechanical commit-and-push across workspace repos |
| `/audit-workflow` | `gpt-5.4` | Standard-tier scan + safe auto-fixes |
| `/whats-next` | `gpt-5.4-mini` | Mechanical triage and report-back |
| `/freshen-status` | `gpt-5.4-mini` | Mechanical sync from repo state |
| `/run-validation` | `gpt-5.4-mini` | Read-only validation runner |
| `/overnight` | `gpt-5.4-mini` | Just launches the scheduler from Copilot surfaces; `-Agent Auto` uses Codex when launched from Codex |
| `/proceed-autonomously` | `gpt-5.4-mini` | Same as `/overnight` |

To override per-invocation, edit the prompt file's `model:` line, or pick a different model in the picker before invoking (the frontmatter wins for the invocation but the picker selection returns afterwards).

To add a new prompt with model pinning:

```yaml
---
description: "What this command does"
mode: agent
model: gpt-5.4
tools: ['codebase', 'editFiles', 'runCommands']   # optional restriction
agent: agent                                       # optional: 'ask' / 'agent' / 'plan' / custom
---

# Body of the prompt...
```

If the pinned model isn't available on the current Copilot plan, VS Code falls back to the picker selection and surfaces a notice. There's no need to write fallback logic in the prompt body itself.

### Install or refresh on any machine

The prompts install to **VS Code's global user prompt directory**, not any workspace. Once installed they are available as slash commands in every project you open on that machine, regardless of which folder is the workspace root.

#### First-time setup on a new machine

```powershell
# 1. Clone this repo anywhere convenient (it does not need to be a workspace).
git clone git@github.com:lyubomir-popov/agent-workflow-kit.git
cd agent-workflow-kit

# 2. Run the installer.
pwsh -NoLogo -NoProfile -File ./install-vscode-prompts.ps1
```

Restart or reload VS Code if it was already running; the slash commands then appear in Copilot Chat in every workspace.

#### Refresh after pulling new prompts

```powershell
cd agent-workflow-kit
git pull
pwsh -NoLogo -NoProfile -File ./install-vscode-prompts.ps1
```

Re-running the installer is idempotent — it overwrites existing prompt files in place, never duplicates.

#### Where the prompts land

| OS | Stable | Insiders (auto-detected) |
|----|--------|--------------------------|
| Windows | `%APPDATA%\Code\User\prompts` | `%APPDATA%\Code - Insiders\User\prompts` |
| macOS | `~/Library/Application Support/Code/User/prompts` | `~/Library/Application Support/Code - Insiders/User/prompts` |
| Linux | `~/.config/Code/User/prompts` | `~/.config/Code - Insiders/User/prompts` |

The installer also targets Insiders automatically if that profile already exists. Override the default targets with `-TargetPath <path>` (one or more), or force Insiders inclusion with `-IncludeInsiders`.

#### Wrapper command

If `agent-workflow-kit/bin` is on `PATH`:

```powershell
install-vscode-prompts
```

#### One-liner for fresh machines

```powershell
git clone git@github.com:lyubomir-popov/agent-workflow-kit.git "$env:USERPROFILE\code\agent-workflow-kit"; pwsh -NoLogo -NoProfile -File "$env:USERPROFILE\code\agent-workflow-kit\install-vscode-prompts.ps1"
```

## Workflow validation and drift checks

`workflow-kit.ps1` validates that a repo still follows the kit contract. It is intentionally small and local: no network calls, no dependency install, and JSON output when another tool needs to consume findings.

```powershell
# If agent-workflow-kit/bin is on PATH:
workflow-kit lint               # validate the current repo
workflow-kit lint -Strict       # fail on warnings as well as errors
workflow-kit diff               # validate and compare copied canonical assets
workflow-kit lint -Json         # machine-readable findings

# Direct invocation:
pwsh -NoLogo -NoProfile -File /path/to/agent-workflow-kit/workflow-kit.ps1 -Command lint -RepoRoot $PWD
pwsh -NoLogo -NoProfile -File /path/to/agent-workflow-kit/workflow-kit.ps1 -Command diff -RepoRoot $PWD -KitRoot /path/to/agent-workflow-kit
```

If a downstream repo intentionally keeps `agent-workflow-kit` as an external source of truth instead of copying `agent-loop.ps1`, `install-vscode-prompts.ps1`, `bin/`, or `prompts/`, add a repo-root `.workflow-kit.json` file:

```json
{
  "canonicalMirrorMode": "external"
}
```

In `external` mode, `workflow-kit diff` suppresses missing-file warnings for those canonical mirrored assets while still reporting drift for any mirrored files that do exist locally.

Checks currently cover:

- required workflow files
- prompt and agent frontmatter
- empty `INBOX.md` / `AGENT-INBOX.md` templates
- concise `.github/agents/agent.md`
- `TODO.md` priority sections
- tiered validation and token-discipline sections in `.github/copilot-instructions.md`
- `HISTORY.md` rotation threshold
- placeholder references in `docs/specs.md`
- copied scheduler, launcher, installer, and prompt drift against the canonical kit

## Autonomous agent loop

`agent-loop.ps1` is a PowerShell scheduler that feeds a selected worker CLI in disposable worktrees. `-Agent Auto` uses Codex when launched from a Codex environment and Copilot otherwise. It supports two workflows:

- **`-Workflow SpecKit`** (default for `/overnight`) — implement in-progress spec packages from `docs/specs.md` until `tasks.md` is complete, adversarial review, address findings, next spec.
- **`-Workflow Todo`** (legacy) — one `TODO.md` checkbox per worker invocation.

### Prerequisites

1. **Worker CLI** installed: `codex` for Codex-launched runs, or `copilot` for Copilot-launched runs
2. **GitHub CLI** authenticated (`gh auth login --web -h github.com`) — use the real `gh.exe`; do not shadow it with a PowerShell `gh` git-grep function (use `gg` for `git grep` instead)
3. **PowerShell 7+** (works on Windows, WSL, or macOS)

### How it works (SpecKit / overnight)

```
agent-loop discovers in-progress specs (current feat/* branch first, then docs/specs.md)
  → implement phase: repeat the selected worker until specs/<id>/tasks.md has no unchecked items
  → adversarial-review phase: one worker run; findings → AGENT-INBOX.md
  → address-review phase: up to MaxAddressRounds while active inbox findings remain
  → advance to the next in-progress spec until the queue is exhausted
```

### How it works (Todo / legacy)

```
agent-loop reads TODO.md and finds the next actionable item under the target heading
  → builds a prompt for the selected worker CLI
  → creates a disposable git worktree at the target repo's current HEAD
  → runs the selected worker non-interactively inside that worktree
  → verifies the worker produced exactly one new commit
  → cherry-picks that commit back when the primary repo is clean
  → updates TODO.md and creates a separate bookkeeping commit when scheduler-owned bookkeeping is still safe
  → preserves the worker worktree for manual inspection if the task times out, the worker does not produce a usable commit, or the primary repo is dirty
  → repeats until no items remain or a failure occurs
```

### Usage

```powershell
# SpecKit overnight (unlimited invocations by default):
pwsh -NoLogo -NoProfile -File /path/to/agent-workflow-kit/agent-loop.ps1 -Workflow SpecKit -RepoRoot $PWD -DryRun
pwsh -NoLogo -NoProfile -File /path/to/agent-workflow-kit/agent-loop.ps1 -Workflow SpecKit -Agent Auto -RepoRoot $PWD -MaxTasks 0 -TaskTimeoutSeconds 3600 -MaxContinues 25 -OnFailure skip

# Legacy TODO mode:
agent-loop -Workflow Todo -DryRun
agent-loop -Workflow Todo -MaxTasks 3
agent-loop -Agent Auto                 # use Codex when launched from Codex, otherwise Copilot
agent-loop -Model gpt-5.4              # choose the worker model explicitly; Codex ignores Copilot-style aliases
agent-loop -ReasoningEffort low        # bias the worker toward faster, narrower action where supported
agent-loop -TaskTimeoutSeconds 600     # stop a hung task after 10 minutes
agent-loop -TaskSection "### Batch tasks"  # target a subsection heading

# Direct invocation also works from any OS with pwsh installed:
pwsh -NoLogo -NoProfile -File /path/to/agent-workflow-kit/agent-loop.ps1 -RepoRoot $PWD -DryRun
```

### Installation

The canonical script lives in this repo at `agent-loop.ps1`. Cross-platform launchers live in `bin/` and resolve the canonical script relative to their own location, so they do not depend on a hardcoded checkout path.

Included launchers:

- `bin/agent-loop` — bash/zsh launcher for macOS and Ubuntu
- `bin/agent-loop.cmd` — Windows launcher for PowerShell, cmd, and VS Code terminals
- `bin/workflow-kit` — bash/zsh launcher for workflow validation and drift checks
- `bin/workflow-kit.cmd` — Windows launcher for workflow validation and drift checks
- `bin/install-vscode-prompts` — bash/zsh wrapper for the prompt installer
- `bin/install-vscode-prompts.cmd` — Windows wrapper for the prompt installer

Recommended setup on each machine: add `agent-workflow-kit/bin` to `PATH`.

```powershell
# PowerShell profile example
$agentLoopBin = '<path-to-agent-workflow-kit>/bin'
$env:PATH = "$agentLoopBin$([System.IO.Path]::PathSeparator)$env:PATH"
```

```bash
# bash / zsh profile example
export PATH="/path/to/agent-workflow-kit/bin:$PATH"
```

To update the loop, edit `agent-loop.ps1` in this repo. All repos pick up the change immediately.

### Target repo requirements

- `TODO.md` using one of the supported active-task formats:
  - `## Active TODO` or `## Active tasks` with `- [ ]` checkbox items
  - `## Short-term` / `## Medium-term` / `## Long-term` with `- [ ]` checkbox items
  - `## Active Execution Queue` with an active-lane status table
- `.github/copilot-instructions.md` for the agent to read as context
- `git`, `copilot`, and PowerShell 7+ (`pwsh`) available on PATH
- A primary git worktree where completed commits can be cherry-picked back cleanly

### Safety

- Each task runs in a disposable git worktree rooted at the target repo's current `HEAD`
- If the primary repo is dirty, the loop still runs the worker task in isolation but preserves the completed worker worktree for manual inspection instead of cherry-picking it back automatically
- The loop stops on any worker CLI non-zero exit or if no new worker commit is detected
- The loop warns when recent commit subjects overlap strongly with the current TODO item so stale queue entries are easier to spot before rerunning work
- The loop kills a task that exceeds the per-task timeout (`-TaskTimeoutSeconds`, default `900`)
- For Copilot runs, the loop passes an explicit model (`-Model`, default `gpt-5.4`) instead of relying on the CLI default; for Codex runs, Copilot-style model aliases are ignored unless a Codex-compatible model is supplied
- For Copilot runs, the loop passes an explicit reasoning effort (`-ReasoningEffort`, default `low`) so automation favors a quick narrow slice over long speculative planning; Codex uses its configured reasoning behavior
- Automatic cherry-pick and scheduler TODO bookkeeping only happen when the primary repo is clean
- Every completed task produces a separate bookkeeping commit for the TODO.md change
- `--max-autopilot-continues` caps each Copilot task's thinking rounds; Codex does not expose the same continuation flag
- `--no-ask-user` prevents the agent from blocking on questions
- `-DryRun` lets you preview what would execute
- `--allow-all` grants file/tool permissions — run on a branch if concerned
