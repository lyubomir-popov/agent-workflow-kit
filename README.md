# <repo-name>

This repo uses a standardized workflow boilerplate for human plus agent collaboration.

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
| `STATUS.md` | Cold-start orientation for the next session |
| `HISTORY.md` | Archive of completed work |
| `docs/specs.md` | Upstream specs, source docs, sibling references |

## How to work in this repo

### If you are the user

1. Put interrupting ideas, reminders, and loose notes in `INBOX.md`.
2. Do not maintain separate handoff or backlog files elsewhere.
3. Read `README.md` and `STATUS.md` when returning after time away.
4. Use `ROADMAP.md` for long-term direction, not the active task queue.
5. Use `TODO.md` for the next real work items only.

### If you are the agent

1. Start with `STATUS.md`.
2. Drain `INBOX.md` into `TODO.md` or `ROADMAP.md`.
3. Read `TODO.md`.
4. Read `docs/specs.md` before changing spec-governed behavior.
5. Update `STATUS.md`, `TODO.md`, and `HISTORY.md` as work lands.

## Rules of thumb

- `TODO.md` is for active work, not ideas you might do someday.
- `ROADMAP.md` is for direction, not this week's execution queue.
- `HISTORY.md` only records finished work.
- `STATUS.md` should tell a new chat what matters right now.
- `docs/specs.md` should answer: what external sources govern this repo?

## How to turn this boilerplate into a real repo

1. Rename the title in this file from `<repo-name>` to the actual repo name.
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

## Autonomous agent loop

`agent-loop.ps1` is a PowerShell scheduler that feeds Copilot CLI one TODO item at a time. It enables unattended overnight runs.

### Prerequisites

1. **Copilot CLI** installed (`npm install -g @anthropic-ai/copilot-cli` or via VS Code prompt)
2. **GitHub CLI** authenticated (`gh auth login --web -h github.com`) — Copilot CLI reads this token
3. **PowerShell 7+** (works on Windows, WSL, or macOS)

### How it works

```
agent-loop.ps1 reads TODO.md
  → extracts first unchecked "- [ ]" item under "## Active TODO"
  → builds a prompt for Copilot CLI
  → runs: copilot -p <prompt> --autopilot --allow-all --no-ask-user -s
  → verifies a new commit appeared
  → marks the item [x] in TODO.md
  → repeats until no items remain or a failure occurs
```

### Usage

```powershell
# From any repo directory (after profile is loaded):
agent-loop -DryRun          # preview tasks without running
agent-loop                   # run (default: up to 10 tasks)
agent-loop -MaxTasks 3       # limit to 3 tasks
agent-loop -TaskSection "### Batch tasks"  # target a different heading
```

### Installation

The canonical script lives in this repo at `agent-loop.ps1`. A wrapper function in the PowerShell profile (`$PROFILE`) makes it callable from any directory:

```powershell
# In $PROFILE:
function agent-loop {
    param(
        [int]$MaxTasks = 10,
        [switch]$DryRun,
        [string]$TaskSection = '## Active TODO'
    )
    $script = 'H:\WSL_dev_projects\repo-workflow-boilerplate\agent-loop.ps1'
    & $script -MaxTasks $MaxTasks -DryRun:$DryRun -TaskSection $TaskSection -RepoRoot $PWD
}
```

To update the loop, edit `agent-loop.ps1` in this repo. All repos pick up the change immediately.

### Target repo requirements

- `TODO.md` with a `## Active TODO` section containing `- [ ]` checkbox items
- `.github/copilot-instructions.md` for the agent to read as context
- A clean git working tree (the loop checks for new commits as success signals)

### Safety

- The loop stops on any Copilot CLI non-zero exit or if no new commit is detected
- `--max-autopilot-continues 5` caps each task's thinking rounds
- `--no-ask-user` prevents the agent from blocking on questions
- `-DryRun` lets you preview what would execute
- `--allow-all` grants file/tool permissions — run on a branch if concerned