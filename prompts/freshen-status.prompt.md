---
description: "Refresh STATUS.md by checking the actual repo state and current workflow files."
mode: agent
model: gpt-5.4-mini
---

# Freshen status

## Workflow mode

Read `.workflow-kit.json` as JSON and inspect `workflowModelVersion`. If `.workflow-kit.json` is missing or `workflowModelVersion` is absent,
including when only `canonicalMirrorMode: external` is set, select legacy mode. Select spec-first mode only when `workflowModelVersion` is the JSON integer `1`;
do not coerce strings or other values. Stop if the JSON is
malformed, is not an object, or contains a present invalid or unsupported
version. Do not infer the mode from root files or placeholders. Execute only the
matching route below; version 1 must not execute Legacy procedure.

## Version 1 route

This command is deprecated in version 1. Route to `/whats-next` for current package and gate orientation. Do not create or update `STATUS.md`.

## Legacy procedure

Refresh `STATUS.md` from actual repo state.

1. Read `.github/copilot-instructions.md`, `STATUS.md`, `TODO.md`, `HISTORY.md`, and `docs/specs.md`.
2. Check the current git status, key file list, active TODO queue, and declared validation commands.
3. If the repo has a build, test, metrics, or validation command under `## Validation`, run the targeted command unless it is clearly expensive or destructive.
4. Update `STATUS.md` so it accurately reflects:
   - what the repo is
   - current state
   - current execution plan
   - key files
   - critical invariants
   - what the next session should do

Keep `STATUS.md` concise. Do not move active tasks into status; put those in `TODO.md`.
