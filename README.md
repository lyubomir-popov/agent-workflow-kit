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

## How to use this kit in a new repo

1. Rename the title in this file from `agent-workflow-kit` to the actual repo name.
2. Fill out `STATUS.md` with real orientation and key files.
3. Fill out `docs/specs.md` with the actual upstream docs, specs, or sibling repos.
4. Replace placeholder roadmap stages and TODO items with real ones.
5. Keep `.github/copilot-instructions.md` as the single repo-wide instruction file.
6. Use `.github/agents/agent.md` only for repo-specific resume guidance, not duplicate workflow rules.

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

Canonical commands:

- `/whats-next` — session-start audit and next-task recommendation
- `/overnight` — preferred short command for launching the overnight `agent-loop.ps1` scheduler
- `/audit-workflow` — workflow file drift audit
- `/proceed-autonomously` — legacy alias for `/overnight`

Install or refresh them on any machine after pulling this repo:

```powershell
pwsh -NoLogo -NoProfile -File ./install-vscode-prompts.ps1
```

If `agent-workflow-kit/bin` is already on `PATH`, the wrapper also works:

```powershell
install-vscode-prompts
```

By default the installer targets the stable VS Code prompt directory and also updates Insiders if that profile already exists. You can pass one or more explicit paths with `-TargetPath`.

## Autonomous agent loop

`agent-loop.ps1` is a PowerShell scheduler that feeds Copilot CLI one TODO item at a time. It enables unattended overnight runs.

### Prerequisites

1. **Copilot CLI** installed (`npm install -g @anthropic-ai/copilot-cli` or via VS Code prompt)
2. **GitHub CLI** authenticated (`gh auth login --web -h github.com`) — Copilot CLI reads this token
3. **PowerShell 7+** (works on Windows, WSL, or macOS)

### How it works

```
agent-loop reads TODO.md and finds the next actionable item under the target heading
  → builds a prompt for Copilot CLI
  → creates a disposable git worktree at the target repo's current HEAD
  → runs: copilot -p <prompt> --autopilot --allow-all --no-ask-user -s inside that worktree
  → verifies the worker produced exactly one new commit
  → cherry-picks that commit back when the primary repo is clean
  → updates TODO.md and creates a separate bookkeeping commit when scheduler-owned bookkeeping is still safe
  → preserves the worker worktree for manual inspection if the task times out, the worker does not produce a usable commit, or the primary repo is dirty
  → repeats until no items remain or a failure occurs
```

### Usage

```powershell
# If agent-workflow-kit/bin is on PATH:
agent-loop -DryRun                     # preview tasks without running
agent-loop                             # run (default: up to 10 tasks)
agent-loop -MaxTasks 3                 # limit to 3 tasks
agent-loop -Model gpt-5.4              # choose the Copilot model explicitly
agent-loop -ReasoningEffort low        # bias the worker toward faster, narrower action
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
  - `## Active Execution Queue` with an active-lane status table
- `.github/copilot-instructions.md` for the agent to read as context
- `git`, `copilot`, and PowerShell 7+ (`pwsh`) available on PATH
- A primary git worktree where completed commits can be cherry-picked back cleanly

### Safety

- Each task runs in a disposable git worktree rooted at the target repo's current `HEAD`
- If the primary repo is dirty, the loop still runs the worker task in isolation but preserves the completed worker worktree for manual inspection instead of cherry-picking it back automatically
- The loop stops on any Copilot CLI non-zero exit or if no new worker commit is detected
- The loop warns when recent commit subjects overlap strongly with the current TODO item so stale queue entries are easier to spot before rerunning work
- The loop kills a task that exceeds the per-task timeout (`-TaskTimeoutSeconds`, default `900`)
- The loop passes an explicit Copilot model (`-Model`, default `gpt-5.4`) instead of relying on the CLI default
- The loop passes an explicit reasoning effort (`-ReasoningEffort`, default `low`) so automation favors a quick narrow slice over long speculative planning
- Automatic cherry-pick and scheduler TODO bookkeeping only happen when the primary repo is clean
- Every completed task produces a separate bookkeeping commit for the TODO.md change
- `--max-autopilot-continues 5` caps each task's thinking rounds
- `--no-ask-user` prevents the agent from blocking on questions
- `-DryRun` lets you preview what would execute
- `--allow-all` grants file/tool permissions — run on a branch if concerned