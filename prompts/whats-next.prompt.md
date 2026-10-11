---
description: "Session start: audit workflow files, triage inbox, report what's next."
mode: agent
model: gpt-5.4-mini
---

# Session start — what's next?

## Retired root-state guard

Before this legacy procedure, read the repository's AGENTS.md. If STATUS.md,
TODO.md, or HISTORY.md is a 2–3 line retirement placeholder pointing to
`docs/specs.md`, stop the legacy procedure and follow AGENTS/catalog/package
owners instead. Never recreate or expand retired files, drain unread handoffs,
write feature handovers into instructions, or bypass an owner checkpoint.
Full shared dual-mode conversion and installation remain a later authorized step.

Follow the session-start workflow from `.github/copilot-instructions.md`:

1. Read `STATUS.md`. If it looks stale or references finished work, update it first.
2. Read `INBOX.md`. Triage items into `TODO.md` (near-term) or `ROADMAP.md` (longer-term). Empty the inbox back to its template.
3. Read `AGENT-INBOX.md`. Triage durable machine notes into canonical files. Empty the agent inbox back to its template.
4. Read `TODO.md` for the active queue.
5. Read `docs/specs.md` if spec-governed work is in the queue.

Then report back:
- **Current state** (one sentence from STATUS)
- **Inbox items triaged** (if any)
- **Agent inbox items triaged** (if any)
- **Recommended next task** from TODO.md, with a brief explanation of why it's the right one to do now
- **Blockers or questions** (if any)

Do not start working yet — just report what's next and wait for approval.
