# History

Completed work belongs here so `TODO.md` stays lean.

## Short-term

### 2026-04-17 — Session: workflow normalisation + agent loop

- Implemented all 6 improvement-backlog items (HISTORY rotation, specs.md, validation gate, session resilience, README quick-start, cross-repo coordination).
- Added `### Maximising autonomous run length` guidance to copilot-instructions.md.
- Created 3 user-level VS Code prompt files (`/whats-next`, `/proceed-autonomously`, `/audit-workflow`).
- Documented Claude Code overnight-loop architecture in ROADMAP, then replaced it with proven Copilot CLI architecture.
- Built `agent-loop.ps1` scheduler — tested with 2 trivial tasks, both completed and committed automatically.
- Made agent-loop global via PowerShell profile function (no per-repo copies).
- Fixed dry-run to list all tasks at once.
- Added agent environment rules (VS Code terminals, Chrome not Edge).
- Codex diagnostic exchange concluded — Codex recommended Copilot CLI over itself for overnight loops.
- Triaged INBOX: user notes extracted into rules and TODO, Codex exchange archived.
- Hardened `agent-loop.ps1`: clean-tree guard, reliable Copilot exit-code capture, section-aware heading parsing, and separate bookkeeping commits.
- Replaced the machine-local profile wrapper approach with repo-contained cross-platform launchers in `bin/`.

## Long-term