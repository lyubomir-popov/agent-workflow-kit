# Status

## What this repo is

`repo-workflow-boilerplate` is the centralised process blueprint for AI-agent workflow conventions across multiple repos (baseline-foundry, brand-layout-ops, canonical-spacing-spec). It owns the canonical `agent-loop.ps1` scheduler and the boilerplate file templates. Changes land here first, then get mirrored to active repos.

## Current state

- **Stage 1 (convention) and Stage 2 (refinements) are complete and the scheduler is now proven on real repo work.** `agent-loop.ps1` successfully completed bounded tasks in `baseline-foundry`, `canonical-spacing-spec`, and `brand-layout-ops`.
- **Agent-loop now runs tasks in disposable git worktrees.** The scheduler auto-detects checkbox queues or active-lane status tables, uses explicit Copilot model / reasoning settings, cherry-picks exactly one worker commit back when safe, and preserves the worker worktree when the primary repo is dirty or the run fails.
- **Windows temp-worktree cleanup is hardened.** The loop now prunes stale worktree registrations before creation and falls back to force-deleting managed temp dirs plus pruning if `git worktree remove --force` leaves residue.
- **Two workflow gaps remain.** This repo still has no real self-hosted task run yet, and canonical work exposed a TODO-vs-history drift case where a task can still look pending even though related work already landed in git history.
- **Inbox roles are now split.** `INBOX.md` is the user-facing note channel, while `AGENT-INBOX.md` is the machine-generated handoff channel for long agent notes, cross-repo follow-ups, and diagnostics awaiting triage.

## Current execution plan

- Land the `AGENT-INBOX.md` split across the boilerplate docs and instructions.
- Add a stale-TODO warning in `agent-loop.ps1` so recent overlapping commit subjects are surfaced before rerunning likely-finished work.
- Commit the scheduler/docs changes, then prove one real self-hosted loop run on a small in-repo task.

## Where to look

| What | Where |
|------|-------|
| Active work | `TODO.md` |
| Long-term direction | `ROADMAP.md` |
| Completed work | `HISTORY.md` |
| Source docs and upstream references | `docs/specs.md` |
| Async user notes | `INBOX.md` |

## Key files

| Path | Purpose |
|------|---------|
| `agent-loop.ps1` | Canonical scheduler — reads TODO, invokes Copilot CLI in a disposable worktree, verifies one worker commit, and applies safe bookkeeping |
| `bin/agent-loop` | POSIX launcher that resolves the canonical script relative to `bin/` |
| `bin/agent-loop.cmd` | Windows launcher that resolves the canonical script relative to `bin/` |
| `.github/copilot-instructions.md` | Agent workflow rules (boilerplate master copy) |
| `README.md` | Overview, agent-loop usage, mirroring instructions |
| `ROADMAP.md` | Stages, proven architecture, open questions |
| `AGENT-INBOX.md` | Agent-only handoff channel for long machine notes and cross-repo follow-ups |
| `docs/specs.md` | Source-of-truth references |

## Critical invariants

- `agent-loop.ps1` is the single canonical copy — no per-repo copies.
- Launchers must resolve the canonical script relative to the repo, not via hardcoded machine-local paths.
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