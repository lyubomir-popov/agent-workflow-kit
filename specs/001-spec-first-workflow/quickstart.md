# Workflow validation

Tiers follow FR-038; run from the kit repository.

Quick checks, for every commit (seconds):

```powershell
pwsh -NoLogo -NoProfile -File ./workflow-kit.ps1 -Command lint -RepoRoot . -Strict
pwsh -NoLogo -NoProfile -File ./agent-loop.ps1 -DryRun -RepoRoot .
git diff --check; git diff --cached --check
```

Code changes also run the covering test files:

| Changed script | Test files |
|---|---|
| `workflow-closeout.ps1` | `Closeout`, `Carryover` |
| `workflow-preservation.ps1` | `Preservation`, `Closeout`, `Scheduler` |
| `workflow-scheduler.ps1` | `Scheduler`, `Worker`, `Preservation` |
| `agent-loop.ps1` | `Worker`, `Scheduler` |
| `workflow-hook.ps1` | `Hook`, `HookScope` |
| `workflow-model.ps1`, `workflow-checks.ps1`, `workflow-kit.ps1` | `Workflow`, `Hook`, `Carryover` |
| `.specify/scripts/powershell/*` | `SpecKit`, `Workflow` |
| `.github/**` | `CI` |

```powershell
pwsh -NoLogo -NoProfile -File ./tests/run-tests.ps1 -Path ./tests/Closeout.Tests.ps1, ./tests/Carryover.Tests.ps1
```

A model change touching shared parsing can widen this set. When in doubt, add
the next file, not the whole suite.

Checkpoint handoff, once on the final code:

```powershell
pwsh -NoLogo -NoProfile -File ./tests/run-tests.ps1
git diff --check <review-base>..HEAD   # record the base in the evidence summary
```

Tests create fixture repositories in a unique OS temporary directory; workers
and network are mocked. `864cad5..HEAD` includes pre-existing vendor whitespace,
reported separately. Closeout usage is in
[README](../../README.md#delivered-package-closeout); remote flags are frozen as
experimental. Gaps are listed in [host enforcement](../../docs/enforcement.md).
