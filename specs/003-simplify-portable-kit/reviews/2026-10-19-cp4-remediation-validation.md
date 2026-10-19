# CP4 remediation validation

Authority: [owner decision](2026-10-19-cp4-owner-decision.md), extended by the
owner's explicit additional Codex-task approval recorded in the live archive.
Review base: `298b3d3` (saved Opus findings/owner decision).
Scope: T025–T028, findings 1–2, finding 4 and the gated T029 record only.
Final source: `fe50d7663893f115cd29cad66d3634defaa5e368`.
Subsequent changes contain handoff records only.
CP4 is pending; the owner decides. No third review or slice D work occurred.

## Test-first

- Initial runtime defaults/tiers run: 7 tests, one missing shared-tier error and
  two failed flag/effort assertions; the remainder passed. The new Codex
  compatibility regressions later produced two failures before restoring its
  existing Copilot-alias guard.
- Native launcher fixture first failed importing the absent module. Final
  launcher unit checks: 11 pass on Windows; WSL 10 pass/one Windows-only skip.
- Auth helper RED: 9 tests, 14 failure assertions before the script existed.
  Focused auth/process checks: 20 tests, OK, one POSIX-only skip on Windows.
- Primary refusal's new exact recovery-command assertion failed before the
  change. Integrated auth RPC regression now verifies that false status prevents
  task dispatch and only true status permits a committed fake task.
- Final focused runtime/auth/launcher/prompt checks: 40 tests, OK (2 existing
  Windows symlink capability skips).

## Scratch live qualification

Full archive: [evidence](evidence/2026-10-19-cp4-live/README.md).
The original scope allowed one run per provider with max tasks 1 and a 90-second
task timeout. Codex rejected a Copilot alias; Copilot committed its exact task;
Claude was unavailable. After the guard fix and the initial handoff, the owner
replied "Authorize one additional Codex scratch task". Exactly that task ran on
unchanged source `fe50d76`, authenticated and completed in 37.765 seconds with
one commit `e4f279578c50cfc71befc30d1f72117393d8c952`. Exact marker bytes,
checkbox-only task changes, two-path scope, clean worktree and unchanged/clean
scratch primary HEAD were independently asserted. There were two Codex worker
attempts total, one Copilot and zero Claude; no automatic retry or substitution.
The successful Codex run used its configured `gpt-6.1-sol` model/high effort,
approval never and danger-full-access. Its original failure is preserved.
Claude's probe remains unqualified/unset. These are not three provider passes.

The installed help confirmed the native permission flags and Copilot reasoning
syntax. Codex effort syntax was checked against [official OpenAI documentation](https://developers.openai.com/codex/config-reference);
Claude's permission flag is documented in its [CLI reference](https://code.claude.com/docs/en/cli-reference),
but documentation is not substituted for a missing installed CLI qualification.

## Final checks

| Check | Result |
|---|---|
| Windows full Python suite | 221 tests in 385.652 s, OK; 6 platform/capability skips |
| WSL slice C/remediation suites | 109 tests in 32.199 s, OK; 2 platform skips |
| Full legacy PowerShell suite | 284 passed, 0 failed/skipped/pending, in 1622.47 s |
| Python compilation | pass |
| Python lint | 0 errors, 18 existing compatibility/diagnostic warnings |
| Legacy strict lint | 0 errors, 0 warnings |
| Legacy scheduler dry run | 0 workers; completed remediation, pending CP4 stops T015 |
| Worktree/index whitespace | pass after normalizing evidence patch display whitespace |
| Review-range whitespace | `git diff --check 298b3d3..HEAD` passes |

Only evidence and prose changed after the additional scratch task; the earlier
full suites still cover the unchanged final source. Final record-only quick
checks were rerun; full suites were not repeated to refresh evidence.

The two previously reproduced Linux slice B errors remain under gated T029;
this remediation does not claim the whole Linux suite is green.

## Scope and integration

GPT-5.6 Sol implemented bounded native resolution and the auth helper; the
orchestrator inspected their source, integrated settings/dispatch and verified
their fake/live boundaries. This is author integration validation, not an
independent third review. No model name was silently replaced. Existing accepted
spec requirements, version 1 config, PowerShell and vendor files remain intact.
No project-repo workers, push, merge, installs/hooks, real cleanup, token capture
or slice D implementation occurred. The recorded fixture report/log paths and
commit preserve the qualification outcome, including the failures.
