# Slice A validation

From the kit repository:

```powershell
pwsh -NoLogo -NoProfile -File ./workflow-kit.ps1 -Command lint -RepoRoot . -Strict
pwsh -NoLogo -NoProfile -File ./agent-loop.ps1 -DryRun -RepoRoot .
pwsh -NoLogo -NoProfile -File ./tests/run-tests.ps1
git diff --check
```

Tests create local fixture repositories in a unique OS temporary directory;
workers are mocked and no real repo worker, network, installer or push runs.
The runner reports retained fixture paths if cleanup cannot safely finish.
Consult [host enforcement](../../docs/enforcement.md) for installed triggers/gaps.
