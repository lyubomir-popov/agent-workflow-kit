---
description: "Run the repo's declared validation commands and report pass/fail with warnings."
mode: agent
model: gpt-5.4-mini
---

# Run validation

## Retired root-state guard

Before this legacy procedure, read the repository's AGENTS.md. If STATUS.md,
TODO.md, or HISTORY.md is a 2–3 line retirement placeholder pointing to
`docs/specs.md`, stop the legacy procedure and follow AGENTS/catalog/package
owners instead. Never recreate or expand retired files, drain unread handoffs,
write feature handovers into instructions, or bypass an owner checkpoint.
Full shared dual-mode conversion and installation remain a later authorized step.

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
