# CP4 owner decision: remediate with scratch-repo live qualification

**Checkpoint**: CP4
**Scope**: `003/spec-r1`
**Reviewer**: Repository owner
**Reviewed revision**: `8bd7e6a`
**Verdict**: changes

Date: 2026-10-19. CP4 stays pending on the [Opus findings](2026-10-19-cp4-opus-findings.md).
The owner authorized "scratch-repo live qualification" for finding 1.

## Authorized scope (GPT)

- Fix findings 1 and 2 test-first. Port the previous scheduler's
  non-interactive flags and `TierDispatchMap` models into the defaults, and
  resolve npm shims on Windows without passing prompts through `cmd.exe`.
- Live qualification: in a throwaway scratch repo created for this purpose,
  run `wfk run --apply --max-tasks 1` with a short `--task-timeout`, once for
  each of `codex`, `copilot` and `claude`, on one trivial task. Set
  `authCommand` only to probes confirmed there. Save the report and logs as
  evidence; never commit tokens or credentials. Report any agent that is
  unavailable or unauthenticated rather than working around it.
- Not authorized: workers in real project repositories, pushes, merges, hook
  installs, real cleanup, or slice D.
- Finding 3 becomes a slice D task that must pass before CP5. Finding 4 may be
  fixed or recorded.
- Record dispositions and validation, then stop for the owner's CP4 decision.
