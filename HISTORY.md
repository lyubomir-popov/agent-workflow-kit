# History

Completed work belongs here so `TODO.md` stays lean.

## Short-term

### 2026-04-19 — Session: prompt syncability

- Moved the canonical VS Code user prompt definitions into `prompts/` so they can live in git and sync through GitHub.
- Added `install-vscode-prompts.ps1` plus `bin/` wrappers so a cloned boilerplate repo can install or refresh global slash commands on any machine.
- Promoted `/overnight` as the preferred short alias while keeping `/proceed-autonomously` as a legacy compatibility prompt.

### 2026-04-18 — Session: cross-repo proof + worktree isolation

- Reworked `agent-loop.ps1` to run each task in a disposable git worktree instead of in-place.
- Added task timeouts, explicit Copilot model / reasoning controls, and support for both checkbox queues and active-lane status tables.
- Tightened the worker prompt so broad tasks get narrowed to one safe slice instead of spending the whole run planning.
- Proved real loop-driven task execution in `baseline-foundry`, `canonical-spacing-spec`, and `brand-layout-ops`.
- Added dirty-primary preservation mode so worker results are kept for manual inspection instead of being applied unsafely.
- Hardened temp-worktree cleanup on Windows by pruning stale registrations before creation and force-deleting managed temp dirs if `git worktree remove --force` leaves residue.
- Cleaned stale temp-worktree registrations left behind in `brand-layout-ops` by the earlier cleanup failure.
- Split the user-facing inbox from a new `AGENT-INBOX.md` channel so machine handoffs stop burying user notes.
- Added stale-TODO warnings against recent commit subjects so already-landed work is easier to spot before the loop reruns it.
- Replaced the placeholder entries in `docs/specs.md` with real in-repo source docs and downstream repo references.
- Proved one real self-hosted loop run in this repo via worker commit `aa7a133` (`docs: fill in specs references`) followed by scheduler bookkeeping commit `4fbda32`.
- Tightened the terminal-hygiene rule: prefer foreground integrated terminals, reuse a small number of shells, and close any hung terminals you created.
- Mirrored the `AGENT-INBOX.md` workflow split and stronger foreground-terminal guidance into `baseline-foundry`, `brand-layout-ops`, and `canonical-spacing-spec`.

### 2026-04-17 — Session: workflow normalisation + agent loop

- Implemented all 6 improvement-backlog items (HISTORY rotation, specs.md, validation gate, session resilience, README quick-start, cross-repo coordination).
- Added `### Maximising autonomous run length` guidance to copilot-instructions.md.
- Created 3 user-level VS Code prompt files (`/whats-next`, `/proceed-autonomously`, `/audit-workflow`), then later promoted `/overnight` as the preferred short alias for the autonomous scheduler.
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