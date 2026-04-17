# Status

## What this repo is

`repo-workflow-boilerplate` is the centralised process blueprint for AI-agent workflow conventions across multiple repos (baseline-foundry, brand-layout-ops, canonical-spacing-spec). It owns the canonical `agent-loop.ps1` scheduler and the boilerplate file templates. Changes land here first, then get mirrored to active repos.

## Current state

- **Stage 1 (convention) and Stage 2 (refinements) are complete.** All 6 improvement-backlog items implemented. ROADMAP reflects this.
- **Agent-loop scheduler is production-ready.** `agent-loop.ps1` lives here; a PowerShell profile function (`agent-loop`) makes it callable from any repo directory. Tested with trivial tasks. Not yet tested with complex real-world tasks.
- **Mirroring to active repos is the next step.** The boilerplate copilot-instructions.md is ahead of the active repos' copies. `TODO.md` tracks this.
- **INBOX pattern needs rethinking.** The Codex exchange proved that long agent-to-agent messages bury user notes. A cleaner channel is on the TODO.

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
| `agent-loop.ps1` | Canonical scheduler — reads TODO, invokes Copilot CLI, verifies commits |
| `.github/copilot-instructions.md` | Agent workflow rules (boilerplate master copy) |
| `README.md` | Overview, agent-loop usage, mirroring instructions |
| `ROADMAP.md` | Stages, proven architecture, open questions |
| `docs/specs.md` | Source-of-truth references |

## Critical invariants

- `agent-loop.ps1` is the single canonical copy — no per-repo copies.
- Every status fact lives in exactly one file.
- INBOX is drained every session start.
- `copilot-instructions.md` here is the master; active repos should converge to it.

## Next session should

- Start by reading this file.
- Drain `INBOX.md`.
- Continue from `TODO.md` — next up is mirroring Stage 2 refinements to active repos.