---
description: "Commit all dirty repos in the workspace and push to their remotes. Ensures every repo is clean and pushed for machine transfer."
mode: agent
model: gpt-5.4-mini
---

# Sync all repos

## Retired root-state guard

Before this legacy procedure, read the repository's AGENTS.md. If STATUS.md,
TODO.md, or HISTORY.md is a 2–3 line retirement placeholder pointing to
`docs/specs.md`, stop the legacy procedure and follow AGENTS/catalog/package
owners instead. Never recreate or expand retired files, drain unread handoffs,
write feature handovers into instructions, or bypass an owner checkpoint.
Full shared dual-mode conversion and installation remain a later authorized step.

Commit and push every repo in the current multi-root workspace so the full working state is available on another machine.

## Procedure

1. For each workspace folder, check `git status --short` and `git rev-list --count @{u}..HEAD` (to detect unpushed commits).
2. For any repo that has uncommitted changes (tracked or untracked), stage everything with `git add -A` and commit with the message `docs: sync all working state for machine transfer`.
3. For any repo that has unpushed commits (including the one just created), run `git push`. If the branch has no upstream, use `git push --set-upstream origin <branch>`.
4. After all repos are processed, run a final verification pass: check that every repo reports clean and pushed.
5. Print a summary table showing each repo and its final status.

## Rules

- Do not force-push.
- Do not rebase or amend existing commits.
- If a push fails for reasons other than missing upstream (e.g. auth, diverged remote), report the failure and move on to the next repo.
- Process repos sequentially to avoid interleaved terminal output.
- Use a single commit per repo covering all changes, not per-file commits.
