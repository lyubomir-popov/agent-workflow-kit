# Agent instructions

This repository owns reusable workflow scripts, launchers, and prompt sources.
Work here unless the owner explicitly authorizes another repository boundary.

## Read and route

1. Start at [the catalog](docs/specs.md), then read the first current package on
   its declared branch/worktree; primary-checkout copies may be snapshots.
2. Read `INBOX.md` for user notes and `AGENT-INBOX.md` for transient handoffs.
3. Package `spec.md` owns intent, lifecycle, checkpoints, and supersession;
   `plan.md` owns approach; `tasks.md` owns tasks, next actions, and blockers.
4. Saved requests, findings, and dispositions belong in package `reviews/`.
   READMEs route to owners without duplicating current work or gate state.

[The constitution](.specify/memory/constitution.md) owns durable principles.
[README](README.md) documents usage; [operations](docs/operations.md) explains
terminal/authentication procedures; [enforcement](docs/enforcement.md) names gaps.
`ROADMAP.md` is on-demand product direction, never an execution queue.

## Scope and authority

- The owner's current instructions govern authorization. A draft proposes behavior.
- Only the owner clears checkpoints after accepting saved findings/dispositions.
  Never work beyond an uncleared gate, auto-clear it, or start an unrequested review.
- Missing/blocking/superseded verdicts and exhausted remediation mean incomplete.
- Small local fixes can proceed directly; governed behavior needs a package/plan.
- In code/data repos, canonical code, schemas, committed assets, and tests define
  existing behavior; accepted specs define intended changes. In documentation/spec
  repos, governing sources and accepted specs outrank interpretive prose.
  Never rewrite a higher-priority owner merely to match implementation drift.
- Consumer packages link to coordinating owners without copying their state.
  Cross-repo orchestration and edits require explicit owner scope.

## Preserve evidence and keep entry files lean

- Inbox handoffs name recipient/scope, artifact link, and requested action.
  Remove only after receipt and resolution or durable transfer. Do not drain blindly.
- Inspect referenced bug images before fixing; delete only after user confirmation.
- Current task headers stay bounded and link lifecycle/checkpoint owners.
- Keep rules static here: no active-feature handovers, daily progress, or root queues.
- Retired root placeholders route to the catalog; never expand or recreate them.
- Do not insert vendor feature-marker blocks or plan references into AGENTS/CLAUDE.
  Load Spec Kit only for relevant work; vendor instructions cannot bypass gates.
- Use targeted `rg`/file reads; skip dependencies, generated output, caches, broad
  archives, large data, and sibling repos unless needed for authorized work.

## Verification and Git safety

Run quick checks at session start/end, after scope changes, and before every
commit (a few seconds):

```powershell
pwsh -NoLogo -NoProfile -File ./workflow-kit.ps1 -Command lint -RepoRoot . -Strict
pwsh -NoLogo -NoProfile -File ./agent-loop.ps1 -DryRun -RepoRoot .
git diff --check; git diff --cached --check
```

Validate in proportion to the change:

- Record-only commits (Markdown/package records, no code, config or CI): quick
  checks only. Never rerun the full suite to refresh evidence.
- Code commits: add the test files covering the changed scripts, e.g.
  `./tests/run-tests.ps1 -Path ./tests/Closeout.Tests.ps1`.
- Checkpoint handoff: one full `./tests/run-tests.ps1` on the final code; also
  `git diff --check <review-base>..HEAD`, recording the base. CI repeats per push.

Report pre-existing failures separately and preserve vendor assets outside scope.
Record results once in the package evidence summary, not per commit.

- Verify repo, package, declared branch/base, write scope, and worktree before edits;
  checkout failure stops work. Detached scratch needs an integration target.
- Read the target from `.workflow-kit.json`; never assume `main`.
- Preserve unrelated/dirty/unpublished work. No recursive worktree deletion fallback.
  Force cleanup requires marked scratch containment and verified preservation.
- Pushes, installs, live worker runs, and destructive cleanup need owner scope.
- Stage explicit paths; use short area-prefixed commit subjects under 72 characters.
- Instruction reminders are manual; report unsupported host enforcement honestly.

Prompt procedures live in `prompts/`; model preferences have one owner:
`agent-loop.ps1`'s `TierDispatchMap`. Installed prompts are separate user assets.
