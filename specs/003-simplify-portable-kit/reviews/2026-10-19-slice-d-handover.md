# Handover: slice D retirement and docs

**Recipient**: GPT implementer, using [orchestrate](../../../prompts/orchestrate.prompt.md)
**Scope**: `003/spec-r1`, branch `feat/003-simplify-portable-kit`
**Authority**: [CP4 clearance](2026-10-19-cp4-owner-clearance.md)
**Requested action**: implement T015, T029, T030, T016 and T017, then stop at CP5.

## Order

1. **T029 first**: fix both Linux parent-file collisions in `init` and prompt
   installation, test-first. Rerun the full Python suite on Windows and WSL.
2. **T030**: make the default reviewer the `copilot` adapter with a Claude Opus
   model. Run one review-phase qualification in a throwaway scratch repo and
   save the logs under `evidence/`. Document that the `claude` adapter stays
   unqualified.
3. **Consumer check before T015**: list the repos under the owner's projects
   folder that still reference `agent-loop.ps1`, `workflow-kit.ps1`, the `bin/`
   launchers or `canonicalMirrorMode`. Read-only; record the list in the CP5
   evidence so the owner knows which repos must pin `v1-powershell`.
4. **T015**: tag the last PowerShell revision `v1-powershell` locally. Remove
   the PowerShell scripts, tests, staged-snapshot checker, closeout, migrate,
   mirror diff and legacy TODO mode. Migrate this kit's own config to v2. Keep
   vendor Spec Kit assets.
5. **T016**: three-OS CI and lint; rewrite README for humans (what it is,
   install, main commands with one example each, one workflow diagram). Move
   reference detail into `docs/`. Update AGENTS.md quick checks to `wfk`
   commands and keep it within its budget.
6. **T017**: validate, save a CP5 request (under 30 lines) and stop.

## Constraints

- Local commits on the package branch only; no push or merge.
- After step 4, the pre-commit hook and quick checks are the Python ones.
  Verify that commits still pass before removing the PowerShell checker.
- Do not modify other repositories; the consumer check is read-only.
- Each review round follows the `/review` procedure; no third round.
