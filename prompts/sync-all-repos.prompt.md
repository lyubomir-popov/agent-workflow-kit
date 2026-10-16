---
description: "Commit all dirty repos in the workspace and push to their remotes. Ensures every repo is clean and pushed for machine transfer."
mode: agent
model: gpt-5.4-mini
---

# Sync all repos

## Shared safety

Apply these rules in either mode: do not force-push, rebase, or amend existing
commits. Process repositories sequentially. If a push fails for reasons other
than a missing upstream, report the failure and continue only within authorized
repository scope; do not bypass authentication or diverged-history failures.
Before acting on each repository, select its mode from its own config and use
only that matching procedure; the caller's mode does not govern other repos.

## Workflow mode

Read `.workflow-kit.json` as JSON and inspect `workflowModelVersion`. If `.workflow-kit.json` is missing or `workflowModelVersion` is absent,
including when only `canonicalMirrorMode: external` is set, select legacy mode. Select spec-first mode only when `workflowModelVersion` is the JSON integer `1`;
do not coerce strings or other values. Stop if the JSON is
malformed, is not an object, or contains a present invalid or unsupported
version. Do not infer the mode from root files or placeholders. Execute only the
matching route below; version 1 must not execute Legacy procedure.

## Version 1 route

Inspect each repository's `AGENTS.md`, catalog, package owners, and versioned config. Summarize its dirty and unpublished state; make commits only within explicit owner scope, stage explicit paths, and push only when the user authorized publishing for that repository. Apply Shared safety and do not bypass package gates. Determine the workflow mode separately for each repository before choosing its procedure.

## Legacy procedure

Commit and push every repo in the current multi-root workspace so the full working state is available on another machine.


### Procedure

1. For each workspace folder, check `git status --short` and `git rev-list --count @{u}..HEAD` (to detect unpushed commits).
2. For any repo that has uncommitted changes (tracked or untracked), stage everything with `git add -A` and commit with the message `docs: sync all working state for machine transfer`.
3. For any repo that has unpushed commits (including the one just created), run `git push`. If the branch has no upstream, use `git push --set-upstream origin <branch>`.
4. After all repos are processed, run a final verification pass: check that every repo reports clean and pushed.
5. Print a summary table showing each repo and its final status.


### Rules

- Do not force-push.
- Do not rebase or amend existing commits.
- If a push fails for reasons other than missing upstream (e.g. auth, diverged remote), report the failure and move on to the next repo.
- Process repos sequentially to avoid interleaved terminal output.
- Use a single commit per repo covering all changes, not per-file commits.
