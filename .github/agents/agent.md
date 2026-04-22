---
description: "Use when continuing work in agent-workflow-kit. Read the workflow files first, then resume scheduler, prompt, or template work without creating duplicate status tracking."
---

# agent-workflow-kit Resume Agent

Use this agent when continuing work in `agent-workflow-kit`.

## What belongs here

- A short repo-specific resume prompt for future agents.
- The first files to read in this repo.
- Brief continuation hints about the most important work surfaces.
- Narrow repo-specific guidance that would be awkward to place in the generic workflow rules.

Keep this file short enough that reading it at session start is cheap.

## What does not belong here

- Stable workflow rules that apply repo-wide. Those belong in `.github/copilot-instructions.md`.
- Current state, progress notes, or cold-start facts. Those belong in `STATUS.md`.
- Active tasks, decision notes, or architecture notes. Those belong in `TODO.md`.
- Long-term direction. That belongs in `ROADMAP.md`.
- Source-of-truth references. Those belong in `docs/specs.md`.
- User-facing overview text. That belongs in `README.md`.
- Long agent handoffs or diagnostics. Those belong in `AGENT-INBOX.md`.

If this file starts accumulating extra detail, move that detail to the canonical workflow file instead of growing this prompt into a second status document.

## First read

1. `.github/copilot-instructions.md`
2. `STATUS.md`
3. `TODO.md`
4. `ROADMAP.md`
5. `docs/specs.md`
6. `README.md`

## Canonical discipline

- Treat `.github/copilot-instructions.md` as the source of truth for workflow rules.
- Keep `.github/agents/agent.md` focused on resume guidance only.
- Keep status in the canonical workflow files: `STATUS.md`, `TODO.md`, `ROADMAP.md`, `HISTORY.md`, and `INBOX.md`.
- Do not create parallel TODO, handoff, or status files.
- Update `STATUS.md` when the current state changes.
- Update `TODO.md` when active work or architecture notes change.
- Move completed items to `HISTORY.md`.
- Update `ROADMAP.md` only when long-term direction changes.
- Check and drain `INBOX.md` at session start.
- Put long machine-generated notes in `AGENT-INBOX.md`, not in this file.

## Working stance

- Follow the active queue in `TODO.md`.
- Use `docs/specs.md` whenever behavior is governed by upstream docs or sibling repos.
- Keep the repo's important facts in canonical files, not in chat-only memory.

## Resume focus

- Prefer work that keeps `agent-loop.ps1`, `prompts/`, and the workflow-file conventions aligned.
- When prompt behavior changes, update `prompts/` first and then reinstall user prompts with `install-vscode-prompts.ps1`.