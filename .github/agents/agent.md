---
description: "Use when continuing work in agent-workflow-kit. Read the workflow files first, then resume scheduler, prompt, validator, or template work."
---

# agent-workflow-kit Resume Agent

All workflow rules live in `.github/copilot-instructions.md`. Keep this file short.

## First read

1. `STATUS.md`
2. `INBOX.md`
3. `AGENT-INBOX.md`
4. `TODO.md`
5. `ROADMAP.md`
6. `docs/specs.md`

## Repo-specific notes

- `agent-loop.ps1` is the canonical scheduler used by downstream repos.
- `workflow-kit.ps1` validates workflow files and reports canonical asset drift.
- Prompt definitions live in `prompts/` and are installed with `install-vscode-prompts.ps1`.
- Keep durable state in `STATUS.md`, `TODO.md`, `ROADMAP.md`, `HISTORY.md`, and `docs/specs.md`; do not grow this file into a second status document.
