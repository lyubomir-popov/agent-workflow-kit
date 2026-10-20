# Spec catalog

Start with the first current package below, resolved on its declared branch.
Its `spec.md` owns lifecycle/checkpoints; its `tasks.md` owns execution state.
Catalog order is the resume pointer, not unattended-work authorization.
This kit's configured target is `main`. Python creation prepares a resolvable
draft ref, commits complete owners and registration on the configured target,
then advances the package branch to that commit. A target
session with only a cached remote ref reports "fetch the declared branch"; fetch
and package-branch checkout remain operator steps. Missing refs are errors when
the available inventory lacks the branch; uncached remote inventory is unknown.

## Current packages

| Spec | Package | Branch |
|---|---|---|

## Candidates

Candidates are unpromoted ideas, not executable tasks (maximum ten entries).

| Idea | Scope/source |
|---|---|
| 002 Cross-repository orchestration | Bounded briefs, worker ownership, revision-aware returns, sequencing, calibration; sources: canonical-spacing-spec/baseline-foundry and Jira bridge. Separate owner authorization after the workflow's first slice. |
| Legacy stale-task warning calibration | Observe real legacy loop runs; tune commit-subject matching if noisy. Former `[X] P2` TODO. |
| Prompt frontmatter enforcement | Promote missing `model:` from warning to error after a consumer observation cycle without false positives. Former `[S] P2` TODO. |
| Optional branch/PR workflow | Add `-Branch <name>` and consider separately authorized `-OpenPR`; retain direct-commit legacy default. Former `[S] P3` TODO. |
| Failure-policy refinement | Evaluate skip/retry/stop for independent queues and transient failures; retain gate stops and incomplete reporting. Former `[S] P3` TODO; inspect existing flags first. |
| Continuation-budget tuning | Determine useful `--max-autopilot-continues` for real tasks; five may be low for complex work. Former TODO open question. |

## Governing references

| Source | Role |
|---|---|
| [AGENTS](../AGENTS.md) | Static ownership, precedence, scope, and verification rules |
| [Constitution](../.specify/memory/constitution.md) | Durable principles |
| [README](../README.md) | Script, launcher, installer, and prompt usage |
| [ROADMAP](../ROADMAP.md) | On-demand direction and resolved design history |
| [Operations](operations.md) | Terminal and authentication procedure |
| [Enforcement](enforcement.md) | Host triggers and gaps |

## Related repositories

`baseline-foundry`, `design-foundry`, and `canonical-spacing-spec` are consumer
references, not workflow owners here. No consumer modification or rollout
is implied by this catalog.

## Archive

Delivered packages stay at their original `specs/` paths and retain their numbers.
Move their catalog rows here at delivery; do not copy lifecycle into this catalog.
Archived rows resolve from the current checkout; Branch retains the original
delivery branch name as metadata even after that branch is deleted.

| Spec | Package | Branch |
|---|---|---|
| 001 Spec-first agent workflow | [001-spec-first-workflow](../specs/001-spec-first-workflow/spec.md) | `feat/001-spec-first-workflow` |
| 003 Simplify and port the kit | [003-simplify-portable-kit](../specs/003-simplify-portable-kit/spec.md) | `feat/003-simplify-portable-kit` |
