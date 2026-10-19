# CP4 owner clearance: slice C scheduler

**Checkpoint**: CP4
**Scope**: `003/spec-r1`
**Reviewed revision**: `fe50d7663893f115cd29cad66d3634defaa5e368`
**Reviewer**: Repository owner
**Verdict**: accept
**Accepted scope**: `003/spec-r1`

Date: 2026-10-19. The owner chose "Clear CP4; Claude reviews via Copilot".

## Basis

- Opus [findings](2026-10-19-cp4-opus-findings.md) 1, 2 and 4 are resolved by
  `fe50d76`, as recorded in GPT's dispositions. Opus spot-checked the result:
  npm shims launch through native Node and a validated entry script, never
  `cmd.exe`, and the runtime and process tests pass (19 tests, 1 skip).
- Live qualification in a scratch repo: Copilot and Codex each completed one
  scoped task ([evidence](evidence/2026-10-19-cp4-live/README.md)).
- The `claude` CLI is not installed on Windows or WSL. Opus answering in VS Code
  chat cannot stand in for that adapter. It stays unqualified, with no
  `authCommand`, so dispatch refuses it.

## Conditions carried into slice D

- **T030**: make the default reviewer Copilot running a Claude Opus model
  (`copilot` adapter with `modelArgs`), and drop the unqualified `claude`
  default. Authorized live run: one review-phase run in a throwaway scratch
  repo, with the logs saved as evidence. Document that the `claude` adapter is
  unqualified until Claude Code is installed and qualified.
- **T029**: the Linux fix must pass on all three OS before CP5.

CP4 is cleared, and slice D (T015, T029, T030, T016, T017) is authorized on the
package branch with local commits, including the local `v1-powershell` tag.
Pushes, merging to `main`, hook installs, real cleanup, workers in real
repositories and consumer migration still need separate owner scope.
