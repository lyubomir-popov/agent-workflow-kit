# CP4 remediation author integration review

Reviewer: GPT orchestrator (self-review, not independent or Opus)
Reviewed revision: fe50d7663893f115cd29cad66d3634defaa5e368
Verdict: changes

Scope: T025–T028. This author check is not an independent third round or a gate
clearance. The owner decides from [dispositions](2026-10-19-cp4-opus-dispositions.md),
[validation](2026-10-19-cp4-remediation-validation.md) and the saved live evidence.

## Findings

1. **Major — resolved by the explicitly authorized final-source Codex check.**
   The original attempt failed on the Copilot alias. After the compatibility
   guard was restored and the first handoff saved, the owner replied "Authorize
   one additional Codex scratch task". That task authenticated, completed in
   37.765 seconds and made exactly one scoped commit. Independent byte/checkbox,
   clean-checkout and unchanged-primary assertions passed. Its configured
   `gpt-6.1-sol` model/high effort was used; no model override was substituted.
   Both attempts remain saved. This is author verification, not a third review.
2. **Major — Claude could not be qualified on this machine.** The CLI is absent
   from PATH and checked standard locations. Its permission flag has an official
   source, but neither a real auth probe nor an editing/commit task is verified.
   Its probe remains unset in accordance with the owner decision's requirement
   to configure only probes confirmed in scratch. No installation/login or
   provider substitution is permitted by the current scope.
3. **Minor — the earlier Linux errors remain gated portability work.** The owner
   explicitly permits finding 3 in slice D. T029 names both repairs and requires
   green regressions/full suite before CP5; no repair was made through this gate.

## Integration checks

- Inspected both delegated implementations, their red/green evidence and actual
  live boundaries. Windows wrappers are ignored in favor of validated metadata
  plus native Node; prompts stay argument vectors and never cmd.exe text.
- The Copilot auth helper sends only `auth.getStatus`, requires literal boolean
  true, bounds frames/notifications and discards raw identity/credential payloads.
  False, missing/malformed/error replies and zero-exit-without-reply fail closed.
  The scheduler's fake integration permits task dispatch only after true status.
- Actual Codex and Copilot auth and committed marker proofs passed. Scratch primary HEAD
  stayed at its initial commit, its tree stayed clean and no remotes appeared.
  The silent empty task log is preserved as empty, with the commit patch as proof.
- The original H/S/L preference map remains in one default data table; Codex
  retains legacy alias compatibility and tier effort. Claude never receives GPT
  model IDs accidentally. No model was silently substituted after the failure.
- Full Windows Python and WSL remediation suites pass. Final legacy/lint/range
  results are recorded once in validation. Version 1 config, PowerShell, vendor
  assets and consumer repos remain unchanged; CP4 and slice D authority remain
  with the owner.
