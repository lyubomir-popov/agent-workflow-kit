# Status

## What this repo is

`agent-workflow-kit` is the centralised process blueprint for AI-agent workflow conventions across multiple repos (baseline-foundry, design-foundry, canonical-spacing-spec). It owns the canonical `agent-loop.ps1` scheduler, syncable prompt definitions, and the workflow file templates. Changes land here first, then get mirrored to active repos.

## Current state

- Active proposal: [Spec 001](specs/001-spec-first-workflow/spec.md), on `feat/001-spec-first-workflow`. Opus findings received and spec amended; owner acceptance is pending. CP1 remains uncleared.

- **Stage 1 (convention) and Stage 2 (refinements) are complete and the scheduler is now proven on real repo work, including this repo.** `agent-loop.ps1` successfully completed bounded tasks in `baseline-foundry`, `canonical-spacing-spec`, `design-foundry`, and one self-hosted task in this repo.
- **Agent-loop now runs tasks in disposable git worktrees.** The scheduler auto-detects checkbox queues or active-lane status tables, supports both Copilot and Codex worker launches, uses explicit model / reasoning settings, cherry-picks worker commits back when safe, and preserves the worker worktree when the primary repo is dirty or the run fails.
- **Windows temp-worktree cleanup is hardened.** The loop now prunes stale worktree registrations before creation and falls back to force-deleting managed temp dirs plus pruning if `git worktree remove --force` leaves residue.
- **The self-hosted proof is now recorded in git.** Worker commit `aa7a133` replaced the placeholder `docs/specs.md` entries, and scheduler bookkeeping commit `4fbda32` marked the task done.
- **The remaining workflow gap is tuning, not rollout.** The `AGENT-INBOX.md` split and stronger terminal guidance are now mirrored into `baseline-foundry`, `design-foundry`, and `canonical-spacing-spec`, while canonical still provides the real TODO-vs-history drift case for future tuning.
- **Inbox roles are now split.** `INBOX.md` is the user-facing note channel, while `AGENT-INBOX.md` is the machine-generated handoff channel for long agent notes, cross-repo follow-ups, and diagnostics awaiting triage.
- **VS Code slash commands are now repo-owned and syncable.** Canonical prompt files live in `prompts/`, and `install-vscode-prompts.ps1` installs them into the global VS Code user prompt folder on each machine so the same commands can be reused anywhere after cloning or pulling this repo.
- **Workflow validation is now executable.** `workflow-kit.ps1` provides `lint` and `diff` commands for checking workflow-file contract drift, prompt frontmatter, inbox drainage, TODO structure, validation sections, and copied canonical assets.
- **Diff now supports external-kit downstream repos.** A downstream repo can add `.workflow-kit.json` with `{"canonicalMirrorMode":"external"}` to suppress missing-file warnings for intentionally unmirrored prompt, launcher, installer, and scheduler assets while still reporting drift for any mirrored files that do exist locally.
- **The code/data repo extension backlog is implemented in the canonical kit.** Repo-type-aware precedence, token discipline, tiered validation, priority TODO sections, concise resume agent shape, roadmap scaling docs, and `/run-validation` / `/freshen-status` prompt files are now in place.
- **Prompt suite expanded and model-pinned.** The prompt set now covers workflow maintenance, SpecKit overnight runs, heavy audits, orchestration, plan tightening, sweep-style review, repo syncing, and targeted diagram-generator analysis. Prompt files declare `model:` frontmatter so the right tier runs each command regardless of the picker, and `workflow-kit lint` enforces that contract.

## Current execution plan

- Watch the new stale-TODO warning in real use and tighten or relax the token matching if it proves noisy.
- Decide later whether scheduler-owned bookkeeping should stop at `TODO.md` or also promote completions into `STATUS.md` and `HISTORY.md` automatically.
- Roll out the new canonical workflow-kit refinements to downstream repos when requested.

## Where to look

| What | Where |
|------|-------|
| Active work | `TODO.md` |
| Long-term direction | `ROADMAP.md` |
| Completed work | `HISTORY.md` |
| Source docs and upstream references | `docs/specs.md` |
| Async user notes | `INBOX.md` |
| Agent handoffs and diagnostics | `AGENT-INBOX.md` |

## Key files

| Path | Purpose |
|------|---------|
| `agent-loop.ps1` | Canonical scheduler — reads TODO, invokes Copilot CLI in a disposable worktree, verifies one worker commit, and applies safe bookkeeping |
| `install-vscode-prompts.ps1` | Copies the canonical prompt files from `prompts/` into the global VS Code user prompt directory |
| `workflow-kit.ps1` | Validates workflow files and reports drift between downstream repos and the canonical kit |
| `bin/agent-loop` | POSIX launcher that resolves the canonical script relative to `bin/` |
| `bin/agent-loop.cmd` | Windows launcher that resolves the canonical script relative to `bin/` |
| `bin/workflow-kit` | POSIX launcher for `workflow-kit.ps1` |
| `bin/workflow-kit.cmd` | Windows launcher for `workflow-kit.ps1` |
| `prompts/` | Canonical slash-command prompt definitions that can be synced through git and installed globally |
| `.github/copilot-instructions.md` | Agent workflow rules (boilerplate master copy) |
| `README.md` | Overview, agent-loop usage, mirroring instructions |
| `ROADMAP.md` | Stages, proven architecture, open questions |
| `AGENT-INBOX.md` | Agent-only handoff channel for long machine notes and cross-repo follow-ups |
| `docs/specs.md` | Source-of-truth references |

## Critical invariants

- `agent-loop.ps1` is the single canonical copy — no per-repo copies.
- Canonical slash-command prompt definitions live in this repo under `prompts/`, not only in machine-local user-data folders.
- Launchers must resolve the canonical script relative to the repo, not via hardcoded machine-local paths.
- `workflow-kit.ps1` is the executable contract check for downstream workflow-file drift.
- Real tasks run in disposable temp worktrees; the primary repo should only receive cherry-picked worker commits and explicit bookkeeping commits.
- `INBOX.md` is user-facing only; machine-generated handoffs belong in `AGENT-INBOX.md`.
- Every status fact lives in exactly one file.
- INBOX is drained every session start.
- `copilot-instructions.md` here is the master; active repos should converge to it.

## Next session should

- Start by reading this file.
- Drain `INBOX.md`.
- Drain `AGENT-INBOX.md`.
- Continue from `TODO.md`.
