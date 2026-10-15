---
description: "Session start: audit workflow files, triage inbox, report what's next."
mode: agent
model: gpt-5.4-mini
---

# Session start — what's next?

## Workflow mode

Read `.workflow-kit.json` as JSON and inspect `workflowModelVersion`. If `.workflow-kit.json` is missing or `workflowModelVersion` is absent,
including when only `canonicalMirrorMode: external` is set, select legacy mode. Select spec-first mode only when `workflowModelVersion` is the JSON integer `1`;
do not coerce strings or other values. Stop if the JSON is
malformed, is not an object, or contains a present invalid or unsupported
version. Do not infer the mode from root files or placeholders. Execute only the
matching route below; version 1 must not execute Legacy procedure.

## Version 1 route

Read `AGENTS.md`, then `docs/specs.md`; inspect the routed package's `spec.md` and `tasks.md` and preserve unread inbox handoffs. Report the current owner, next authorized task, checkpoint or task gate, and blockers. Do not start work.

## Legacy procedure

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
