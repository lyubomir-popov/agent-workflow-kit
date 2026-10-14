# Workflow validation

From the kit repository:

```powershell
pwsh -NoLogo -NoProfile -File ./workflow-kit.ps1 -Command lint -RepoRoot . -Strict
pwsh -NoLogo -NoProfile -File ./agent-loop.ps1 -DryRun -RepoRoot .
pwsh -NoLogo -NoProfile -File ./tests/run-tests.ps1
git diff --check
git diff --cached --check
# Adversarial correction round starts at the reviewed revision:
git diff --check 53fc575..HEAD
# Slice B implementation starts at the accepted plan:
git diff --check dce8394..HEAD
# CP3 bounded corrections start at the reviewed handoff:
git diff --check 9e1819c..HEAD
```

Tests create local fixture repositories in a unique OS temporary directory;
workers are mocked and no real repo worker, network, installer or push runs.
The runner reports retained fixture paths if cleanup cannot safely finish.
Consult [host enforcement](../../docs/enforcement.md) for installed triggers/gaps.
Use the accepted starting revision for later rounds. A clean worktree alone does
not check committed content. This round's range is clean; 864cad5..HEAD includes
pre-existing vendor/integration whitespace, reported separately in the evidence.

Closeout preview/apply and required action authorizations are documented in
[README](../../README.md#delivered-package-closeout). Only delivered fixture
packages are cleaned up during validation; this session performs no live cleanup,
network push, merge, unattended worker run or slice C work. Read the saved
[slice B evidence](evidence/slice-b-validation.md) and
[CP3 correction request](reviews/2026-10-14-cp3-correction-review-request.md).
Implementation stops at pending CP3. Cline findings were received with model
identity unattested; no new external review has been launched after corrections.
