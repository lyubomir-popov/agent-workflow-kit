# Workspace Instructions

## Documentation structure

| File | Role | Who writes |
|------|------|-----------|
| `.github/copilot-instructions.md` | Rules. Workflow rules, source precedence, planning rules. | Agent maintains |
| `.github/agents/agent.md` | Optional resume-agent prompt for repo-specific continuation. | Agent maintains |
| `README.md` | Overview. Repo summary and workflow map. | User + agent maintain |
| `ROADMAP.md` | Long-term. Product direction, stages, future ideas. | Agent updates rarely |
| `TODO.md` | Active plan. Current execution queue, principles, architecture notes. | Agent updates every session |
| `INBOX.md` | Inbox. User drops notes without interrupting the workflow. | User writes, agent drains |
| `STATUS.md` | Cold start. Repo orientation, current state, key files, invariants. | Agent updates when state changes |
| `HISTORY.md` | Archive. Completed work log. | Agent appends when tasks complete |
| `docs/specs.md` | Specs. Linked source docs, upstream references, and path summary. | Agent updates when source paths change |

No other files should carry duplicate TODO lists, handoff notes, or parallel status tracking. Session scratch in Copilot memory is fine, but the repo itself should keep status in one place only.

## Source-of-truth precedence

When sources disagree, use this order unless a higher-priority source explicitly narrows it further:

1. Linked specs, upstream docs, or explicitly referenced source material
2. `ROADMAP.md`
3. `.github/copilot-instructions.md`
4. `STATUS.md` and `HISTORY.md`
5. `README.md` and `docs/specs.md`
6. `INBOX.md`
7. Local implementation details that are not clearly intentional or documented

Do not rewrite higher-priority docs to match lower-priority implementation drift.

## Planning threshold

- Small task: act directly.
- Medium task: write a short plan in `STATUS.md` before execution.
- Large, architectural, or cross-repo task: create or update a dedicated plan section before broad changes.

## History rules

- Record completed short-term items under a short-term section.
- Record completed long-term items under a long-term section.
- Move items to history only when actually complete.
- Do not use history as a backlog or scratchpad.
- When `HISTORY.md` exceeds ~200 lines, move older entries to `docs/archive/YYYY.md` and keep only recent entries in the root file.

### The inbox pattern

`INBOX.md` is the user's write-only channel. At session start, the agent must:

1. Read the inbox.
2. Triage each item into `TODO.md` (near-term) or `ROADMAP.md` (longer-term).
3. Empty the file back to its header template.

### What goes where

| Information | Goes in |
|-------------|---------|
| What should the next chat do? | `TODO.md` |
| Why was an architectural decision made? | `TODO.md` |
| What does the product become long-term? | `ROADMAP.md` |
| What source documents govern this repo? | `docs/specs.md` |
| What has been completed? | `HISTORY.md` |
| Cold-start orientation and resume notes | `STATUS.md` |
| Async user notes | `INBOX.md` |

## Agent workflow

### Session start

1. Read `STATUS.md` for orientation. If it looks stale or references work that is clearly finished, update it before proceeding — do not assume the previous session cleaned up.
2. Check `INBOX.md`, triage items into plan or roadmap, then empty it.
3. Read `TODO.md` for current tasks.
4. Read `docs/specs.md` before changing spec-governed behavior.

### During work

- Mark tasks done in `TODO.md` as you complete them.
- Move completed items to `HISTORY.md`.

### Session end

1. Update `STATUS.md` if the current-state section is stale.
2. Update `TODO.md` with any new tasks that emerged.
3. Ensure `INBOX.md` is empty.
4. Do not create new markdown files to document status unless explicitly requested.

## Validation

Before committing, run the repo's validation commands to confirm nothing is broken. Replace the placeholder below with the real commands for this repo.

```bash
# Example: npm test
# Example: npm run lint
```

If there are no automated checks, at minimum verify that the files you changed are syntactically valid and consistent with the rest of the repo.

## Repo boundary

- Work in this repo only unless the user explicitly redirects elsewhere.
- If sibling repos are used as references, list them in `docs/specs.md` or `STATUS.md`.

## Commit message discipline

Use a short area prefix such as `docs:`, `workflow:`, `build:`, `types:`, `test:`, or a repo-specific equivalent. Keep the first line under 72 characters.

## Autonomous continuation rule

If the user explicitly says to proceed autonomously, treat that as standing approval to keep executing the best available plan without pausing for small confirmations.

In that mode:

1. Work through the current plan until you hit a real blocker, not a minor ambiguity.
2. Make small validated checkpoint commits after substantive chunks if commits are allowed.
3. Re-read `TODO.md` after major chunks and periodically re-audit alignment.
4. Update the canonical docs as work lands so the next chat can continue cold.
5. Do not stop just to ask whether to continue unless the next best move is genuinely unclear or risky.

### Maximising autonomous run length

Current LLM agents lose coherence after extended autonomous runs because context fills up. To get the longest useful runs:

- **Narrow the scope per burst.** "Complete all items in TODO.md section X" works better than open-ended "work through the roadmap."
- **Checkpoint and resume.** After each substantive chunk, commit + update STATUS + update TODO so a fresh session can continue cold. A shell loop or CI job can restart the agent automatically.
- **Keep TODO items small.** Each item should be completable in one focused burst. If an item needs decomposition, break it down before starting the autonomous run.
- **Prefer sequential single-repo sessions** over multi-repo autonomous runs. Cross-repo context bloats fast and causes mistakes.

## Cross-repo coordination

When work in one repo creates a dependency or follow-up in another:

1. Drop a note in the **target repo's** `INBOX.md` describing what changed and what the target repo needs to do.
2. Do not attempt the cross-repo change in the same session unless the user explicitly redirects there.
3. Use one agent per repo for feature work. Use one agent across repos only for mirroring convention changes or small coordinated edits.
4. For larger features, prefer sequential single-repo sessions with INBOX handoffs over one agent trying to hold multi-repo context.

## How to use this boilerplate in a new repo

1. Copy these files into the new repo root.
2. Keep the file names unchanged.
3. Replace placeholder text such as `<repo-name>` and `<upstream-spec>`.
4. Delete any old handoff, todo, or inbox files that would duplicate this structure.
5. Update `README.md`, `STATUS.md`, and `docs/specs.md` first so the repo can be resumed cleanly.

## Agent file roles

- `.github/copilot-instructions.md` is the single repo-wide instruction file.
- `.github/agents/agent.md` is optional and should contain only repo-specific resume or subagent guidance.
- Do not duplicate the full workflow rules in both places.

The key rule: every piece of status information should live in exactly one place.