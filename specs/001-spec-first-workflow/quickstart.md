# Slice A validation

From the kit repository:

```powershell
pwsh -NoLogo -NoProfile -File ./workflow-kit.ps1 -Command lint -RepoRoot . -Strict
pwsh -NoLogo -NoProfile -File ./agent-loop.ps1 -DryRun -RepoRoot .
pwsh -NoLogo -NoProfile -File ./tests/run-tests.ps1
git diff --check
git diff --cached --check
# Adversarial correction round starts at the reviewed revision:
git diff --check 53fc575..HEAD
```

Tests create local fixture repositories in a unique OS temporary directory;
workers are mocked and no real repo worker, network, installer or push runs.
The runner reports retained fixture paths if cleanup cannot safely finish.
Consult [host enforcement](../../docs/enforcement.md) for installed triggers/gaps.
Use the accepted starting revision for later rounds. A clean worktree alone does
not check committed content. This round's range is clean; 864cad5..HEAD includes
pre-existing vendor/integration whitespace, reported separately in the evidence.
