---
description: "Inspect, commit, and push authorized repositories for machine transfer."
agent: agent
---

# Sync all repositories

## Safety

The request must explicitly authorize commits and pushes for each repository in
scope. Never force-push, rebase or amend. Stage explicit paths, preserve unrelated
work, and process repositories sequentially. A package gate still governs the
content being committed; synchronization does not clear it.

## Workflow routing

Read `.workflow-kit.json` as JSON before using the procedure below.

- JSON integer `2`: use the Python workflow procedure.
- JSON integer `1`: use the same Python procedure and run
  `wfk lint --repo . --json`; report its named ignored-v1-field diagnostics
  and do not assume ignored scheduler or workflow fields are active.
- Missing file or missing `workflowModelVersion`: run only the adoption preview
  `wfk init --repo . --json`, report its manual checklist, and wait for
  authorized adoption.
- Malformed JSON, a non-object root, a non-integer version, or an unsupported
  version: fail closed and report the configuration error.

Do not reconstruct retired commands or TODO scheduling. If old behavior is
still required, use a separate kit checkout pinned to `v1-powershell`; the tag
alone does not repoint a shared consumer.

## Procedure

For each authorized workspace repository:

1. Read its own `AGENTS.md`, config, catalog and active package owners.
2. Select its workflow route independently. For integer version 1, run
   `wfk lint --repo <repo> --json` and report ignored fields. For a missing
   version, preview `wfk init --repo <repo> --json` and require manual adoption;
   do not apply it as part of synchronization.
3. Inspect `git status --short`, the staged diff, current branch, upstream and
   unpublished commits.
4. Commit only coherent, owned changes within the user's scope, using explicit
   paths. Do not sweep unknown untracked files into a catch-all commit.
5. Push only when that repository was authorized. A missing upstream may be set
   to the intended remote branch; authentication, non-fast-forward or other
   failures are reported rather than bypassed.
6. Verify and report the final dirty and ahead/behind state.

Do not run the scheduler, cleanup, prompt installation or workflow adoption as a
side effect.
