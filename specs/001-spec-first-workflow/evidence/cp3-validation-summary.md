# CP3 validation summary

Production revision: `8569b125980cf2f630829ec71565df9909c7896a`.
T051 test-only update: the commit containing this summary, based on `3f9824c`.
Runtime: Windows, PowerShell 7.6.6, Git 2.52, Pester 3.4.

| Check | Final result |
|---|---|
| Final production full suite | 271 passed, 0 failed, 2396.89s; retained from [historical validation](slice-b-validation.md#cp3-corrected-code-handoff) |
| T051: `tests/run-tests.ps1 -Path @('tests/Hook.Tests.ps1','tests/HookScope.Tests.ps1')` | 19 passed, 0 failed, 60.65s |
| Actual helper bodies with mocked child output | Eight plain/wrapped/gutter/wrong-message checks pass; failure exit codes preserved |
| Strict lint | 0 errors, 0 warnings, 1 semantic-limit info |
| Scheduler dry run | target=main; manual T045; zero workers |
| Whitespace | Worktree, index and `3f9824c..HEAD` clean |

The reported seven wrapping failures did not reproduce in this environment.
The helper checks verify wrapping tolerance without weakening expected messages.
Only captured test output is normalized; production hook diagnostics are unchanged.
The quickstart multi-file example passes an actual PowerShell path array.
No full suite was rerun to refresh evidence. Historical review/evidence files remain
unchanged. Linux/remote CI remain unverified; BQA-06 belongs to the owner/provider.
Current gate and authority are owned by [spec.md](../spec.md#checkpoints) and
[AGENTS](../../../AGENTS.md).
