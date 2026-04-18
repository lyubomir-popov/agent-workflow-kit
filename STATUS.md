# Status

## What this repo is

`repo-workflow-boilerplate` is the centralised process blueprint for AI-agent workflow conventions across multiple repos (baseline-foundry, brand-layout-ops, canonical-spacing-spec). It owns the canonical `agent-loop.ps1` scheduler and the boilerplate file templates. Changes land here first, then get mirrored to active repos.

## Current state

- **Stage 1 (convention) and Stage 2 (refinements) are complete and the scheduler is now proven on real repo work, including this repo.** `agent-loop.ps1` successfully completed bounded tasks in `baseline-foundry`, `canonical-spacing-spec`, `brand-layout-ops`, and one self-hosted task in `repo-workflow-boilerplate`.
- **Agent-loop now runs tasks in disposable git worktrees.** The scheduler auto-detects checkbox queues or active-lane status tables, uses explicit Copilot model / reasoning settings, cherry-picks exactly one worker commit back when safe, and preserves the worker worktree when the primary repo is dirty or the run fails.
- **Windows temp-worktree cleanup is hardened.** The loop now prunes stale worktree registrations before creation and falls back to force-deleting managed temp dirs plus pruning if `git worktree remove --force` leaves residue.
- **The self-hosted proof is now recorded in git.** Worker commit `aa7a133` replaced the placeholder `docs/specs.md` entries, and scheduler bookkeeping commit `4fbda32` marked the task done.
- **The remaining workflow gap is rollout and tuning, not basic viability.** The next work is mirroring the `AGENT-INBOX.md` split and scheduler refinements into the active repos, while canonical still provides the real TODO-vs-history drift case for future tuning.
- **Inbox roles are now split.** `INBOX.md` is the user-facing note channel, while `AGENT-INBOX.md` is the machine-generated handoff channel for long agent notes, cross-repo follow-ups, and diagnostics awaiting triage.

## Current execution plan

- Mirror the `AGENT-INBOX.md` split and scheduler refinements to the active repos.
- Watch the new stale-TODO warning in real use and tighten or relax the token matching if it proves noisy.
- Decide later whether scheduler-owned bookkeeping should stop at `TODO.md` or also promote completions into `STATUS.md` and `HISTORY.md` automatically.

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