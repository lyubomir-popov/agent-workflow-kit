---
description: "Run the repo's declared validation commands and report pass/fail with warnings."
mode: agent
model: gpt-5.4-mini
---

# Run validation

## Workflow mode

Read `.workflow-kit.json` as JSON and inspect `workflowModelVersion`. If `.workflow-kit.json` is missing or `workflowModelVersion` is absent,
including when only `canonicalMirrorMode: external` is set, select legacy mode. Select spec-first mode only when `workflowModelVersion` is the JSON integer `1` or `2`;
do not coerce strings or other values. Stop if the JSON is
malformed, is not an object, or contains a present invalid or unsupported
version. Do not infer the mode from root files or placeholders. Execute only the
matching route below; versions 1 and 2 must not execute Legacy procedure.

## Version 1 route

Read `AGENTS.md`, `README.md`, and the relevant package validation guidance. Select targeted or full validation according to the current authorized task and report the commands, results, and gaps. Respect package gates; validation does not authorize edits.

## Version 2 route

Read `AGENTS.md`, README and the relevant package's validation guidance.
Run `wfk lint --repo . --json` for portable ownership checks, then the declared
targeted or full tests appropriate to the authorized change. Report actual
commands, results, warnings and gaps. Respect package gates; validation does
not authorize edits or a scheduler run.

## Legacy procedure

Read `.github/copilot-instructions.md` and find the repo's `## Validation` section.

Run the most appropriate validation command for the current task:

1. Use **Targeted validation** for a narrow in-progress change.
2. Use **Full validation** before committing or after substantial changes.
3. If the user specifies a command, run that exact command.

Then report:

- command run
- pass/fail status
- important errors or warnings
- any validation gap if the repo has no declared command

Do not edit files unless the user explicitly asks you to fix failures.
