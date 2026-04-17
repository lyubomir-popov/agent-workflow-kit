---
description: "Use when continuing work in <repo-name>. Read the repo workflow files first, then resume active implementation without creating duplicate status tracking."
---

# <repo-name> Resume Agent

Use this agent when continuing work in `<repo-name>`.

## First read

1. `.github/copilot-instructions.md`
2. `STATUS.md`
3. `TODO.md`
4. `ROADMAP.md`
5. `docs/specs.md`
6. `README.md`

## Canonical discipline

- Treat `.github/copilot-instructions.md` as the source of truth for workflow rules.
- Keep status in the canonical workflow files: `STATUS.md`, `TODO.md`, `ROADMAP.md`, `HISTORY.md`, and `INBOX.md`.
- Do not create parallel TODO, handoff, or status files.
- Update `STATUS.md` when the current state changes.
- Update `TODO.md` when active work or architecture notes change.
- Move completed items to `HISTORY.md`.
- Update `ROADMAP.md` only when long-term direction changes.
- Check and drain `INBOX.md` at session start.

## Working stance

- Follow the active queue in `TODO.md`.
- Use `docs/specs.md` whenever behavior is governed by upstream docs or sibling repos.
- Keep the repo's important facts in canonical files, not in chat-only memory.

## Resume focus

- Replace this section with the repo's current continuation guidance once the boilerplate becomes a real project.