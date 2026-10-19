# CP4 owner decision request after Opus remediation

Scope: `003/spec-r1`, T025–T028; T029 queued behind CP4 only.
Branch: `feat/003-simplify-portable-kit`; local commits only.
Reviewed revision: `fe50d7663893f115cd29cad66d3634defaa5e368`.
Review base: `298b3d3` (Opus findings and owner authorization).
Later changes are records only. CP4 stays pending; no third review starts.

Code restores unattended flags, shared tiers/efforts and the legacy Codex
Copilot-alias guard, verifies available auth probes and resolves Windows npm
shims through native Node. The primary refusal prints its recovery command.

Evidence: [dispositions](2026-10-19-cp4-opus-dispositions.md),
[validation](2026-10-19-cp4-remediation-validation.md),
[author integration review](2026-10-19-cp4-remediation-self-review.md),
[live reports/logs](evidence/2026-10-19-cp4-live/README.md).
Python: Windows 221 tests (6 skips), WSL remediation 109 (2 skips), all others pass.
Full legacy-suite and final lint/range results are recorded in validation.

Copilot authenticated and committed its one task. Codex's first attempt rejected
the Copilot alias; after the owner explicitly authorized one additional task,
the final guard passed live in 37.765 seconds with one exact-scope commit.
Both attempts are saved. Claude is unavailable and its probe stays unset.

Please decide CP4 from this evidence. Claude qualification needs an available
CLI and separate scope; a successful three-provider qualification is not claimed.
No further live task, third review, slice D, push/merge, hooks or real cleanup starts here.
