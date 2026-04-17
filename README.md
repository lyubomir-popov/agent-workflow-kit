# <repo-name>

This repo uses a standardized workflow boilerplate for human plus agent collaboration.

## What this is

Use this repo as a starter or reference whenever you create a new project and want the same lightweight operating model:

- one rules file
- one active plan
- one roadmap
- one inbox
- one cold-start status file
- one history log
- one source-doc index

The goal is simple: every important piece of project state lives in exactly one place.

## Workflow map

| File | Purpose |
|------|---------|
| `.github/copilot-instructions.md` | Agent rules, workflow conventions, precedence rules |
| `.github/agents/agent.md` | Optional resume-agent prompt for repo-specific continuation |
| `README.md` | Human-readable overview and workflow reminder |
| `ROADMAP.md` | Long-term direction and future stages |
| `TODO.md` | Active queue, principles, architecture notes |
| `INBOX.md` | Quick user notes to be triaged later |
| `STATUS.md` | Cold-start orientation for the next session |
| `HISTORY.md` | Archive of completed work |
| `docs/specs.md` | Upstream specs, source docs, sibling references |

## How to work in this repo

### If you are the user

1. Put interrupting ideas, reminders, and loose notes in `INBOX.md`.
2. Do not maintain separate handoff or backlog files elsewhere.
3. Read `README.md` and `STATUS.md` when returning after time away.
4. Use `ROADMAP.md` for long-term direction, not the active task queue.
5. Use `TODO.md` for the next real work items only.

### If you are the agent

1. Start with `STATUS.md`.
2. Drain `INBOX.md` into `TODO.md` or `ROADMAP.md`.
3. Read `TODO.md`.
4. Read `docs/specs.md` before changing spec-governed behavior.
5. Update `STATUS.md`, `TODO.md`, and `HISTORY.md` as work lands.

## Rules of thumb

- `TODO.md` is for active work, not ideas you might do someday.
- `ROADMAP.md` is for direction, not this week's execution queue.
- `HISTORY.md` only records finished work.
- `STATUS.md` should tell a new chat what matters right now.
- `docs/specs.md` should answer: what external sources govern this repo?

## How to turn this boilerplate into a real repo

1. Rename the title in this file from `<repo-name>` to the actual repo name.
2. Fill out `STATUS.md` with real orientation and key files.
3. Fill out `docs/specs.md` with the actual upstream docs, specs, or sibling repos.
4. Replace placeholder roadmap stages and TODO items with real ones.
5. Keep `.github/copilot-instructions.md` as the single repo-wide instruction file.
6. Use `.github/agents/agent.md` only for repo-specific resume guidance, not duplicate workflow rules.

## Recommended first edits

- `README.md`: replace placeholders and describe the repo in two or three paragraphs.
- `STATUS.md`: add the real current state, key paths, and invariants.
- `docs/specs.md`: list the real source-of-truth docs and stable paths.
- `TODO.md`: write the actual near-term work queue.
- `ROADMAP.md`: capture the long-term shape.

## Why this exists

Most repos decay because the project state gets spread across chat history, random markdown files, and people remembering things. This boilerplate keeps the workflow explicit and lightweight so a repo can be resumed cold without reconstructing context from scratch.