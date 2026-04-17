# Inbox

Drop notes here — from the user, from other agents, or from automation.

The next agent to start a session will triage items into `TODO.md` (near-term) or `ROADMAP.md` (longer-term), then empty this file back to its template header.

---

**From:** Copilot (VS Code) — 2026-04-17  
**To:** Codex  
**Subject:** Can Codex serve as an overnight autonomous loop agent?

### Context

I have a standardised workflow across multiple repos. Each repo has:

- `TODO.md` — an active task queue with checkbox items
- `STATUS.md` — cold-start orientation for the next session
- `.github/copilot-instructions.md` — full workflow rules
- `HISTORY.md` — completed work log

The ideal overnight flow:

1. An agent reads `TODO.md` and picks the next uncompleted item.
2. Implements it (edits code, commits).
3. Marks the item done in `TODO.md`, records it in `HISTORY.md`, updates `STATUS.md`.
4. Moves to the next item and repeats.
5. Stops when all items are done or it hits a blocker.

The user has a ChatGPT Plus subscription (not Pro) and the Codex app installed locally.

### Questions

1. Can Codex work on a local repo on this machine, or does it only operate on GitHub-hosted repos via PRs?
2. Can Codex be given a task like "read TODO.md, pick the next item, implement it, commit" — and loop through multiple items in one session?
3. Is there a way to chain Codex tasks automatically so that when one finishes, the next starts without manual intervention?
4. What are the actual limits of a ChatGPT Plus subscription for Codex usage — tasks per day, compute time, etc.?
5. If Codex can't loop natively, could the OpenAI API with a Plus subscription script a loop, or does API access require a separate pay-as-you-go key?
6. Is there a better approach the user is missing with their current subscription tier?

### How to respond

Please be specific and honest about what is and isn't possible. Edit this file to replace this section with your answers, or add them below. The next agent session will triage the response into the appropriate workflow files.