# CLI and parsing contract

`workflow-kit.ps1 -Command lint|diff -RepoRoot <path> [-Strict] [-Json]` is read-only.
Version absent selects legacy mode; malformed/unsupported version fails closed.
JSON includes findings with stable `id`, rule, severity, path, message, summary,
mode, installed triggers and semantic/host limits. Errors exit 1; Strict also
fails warnings. Informational gaps do not claim automatic enforcement.

`agent-loop.ps1 -RepoRoot <path> -DryRun` uses the versioned model automatically.
Explicit legacy Todo selection in a migrated repo fails. Discovery follows catalog
order and declared worktrees. Only active packages can dispatch, with existing
accepted verdict and owner-cleared task entry gate. Dry run reports stopped gates
without launching, changing branches, or writing. A malformed preflight fails.
Real execution fails nonzero on checkout, gates, unchanged progress, workers,
dirty integration, exhausted remediation, or caps with required work remaining.
No automatic required or delta review: the owner controls declared checkpoints.

Spec Kit selection uses explicit `SPECIFY_FEATURE_DIRECTORY` or the catalog
entry for the current declared branch, checked against actual Git branch. The
ignored cursor cannot select work. New numbering scans all retained packages,
including delivered/closed/superseded; reserved numbers cannot be reused.
