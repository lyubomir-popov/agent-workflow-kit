# Implementation plan: Spec-first agent workflow

**Branch**: `feat/001-spec-first-workflow` | **Date**: 2026-10-11 | **Spec**: [spec.md](spec.md)

## Summary

Self-host a versioned, spec-owned workflow while retaining legacy launcher behavior
for repositories without the version. Deliver three slices with owner checkpoints;
only slice A is authorized by the owner's October 11 instruction.

## Technical context

PowerShell 7 and Git; no new runtime dependency, network, or model calls in lint.
Markdown packages and `.workflow-kit.json` are the owners. Pester 3.4 is installed;
use compatible disposable Git fixtures under the OS temporary directory. Windows
is verified locally; CI checks Windows and Linux. No performance claim is needed.

## Constitution check

| Principle | Before and after design |
|---|---|
| I Owner scope/review | CP1 accepted by owner; A only; stop at CP2, never clear it or launch a delta review. |
| II One owner per fact | Catalog routes; spec owns lifecycle/gates; tasks own execution; shared parser, no sidecar state. |
| III Preserve work | Read-only checks; preserve failed workers; marked, contained scratch only; Git history retains legacy content. |
| IV Proportional verification | Fixture acceptance/failure tests, parser checks, lint/dry run/diff check per commit. |
| V Canonical tooling | Kit only; external-mirror config survives; no prompt install or consumer edits. |

All pass. No constitution exception or unresolved technical decision.

## Structure and responsibilities

- `workflow-model.ps1`: shared config, catalog/worktree, lifecycle/checkpoint,
  task/gate parsing and local package selection. Library only, no execution state.
- `workflow-kit.ps1`: version switch, lean routing/budget/ownership diagnostics,
  human/JSON findings; preserve legacy lint and external-mirror diff.
- `agent-loop.ps1`: consume shared model, preflight and task gates, clean
  integration target, package review routing, marked contained scratch workers.
- `.specify/scripts/powershell/`: adapt resolution/numbering to declared owners;
  vendor skills stay untouched. `.specify/feature.json` becomes ignored/untracked.
- Root adapters/catalog, `docs/operations.md`, README, prompt sources and
  principles-only constitution: migrate every FR-036 section to its named owner.
- `.githooks/pre-commit`, `.github/workflows/workflow.yml`, `docs/enforcement.md`:
  compose local hooks, CI backstop and honest per-host gaps.
- `workflow-checks.ps1`, `workflow-scheduler.ps1`, `workflow-hook.ps1`: on-demand
  script libraries and commit entry point; they store no workflow state.
- `tests/`: compatible Pester runner and isolated Git fixtures.

## Slices and acceptance

**A** (FR-001–018, 033–036, A parts of 037): implement the above; tasks declare
an entry checkpoint and optional per-task `(gate: CPn)` overrides. Recheck before
each dispatch. Future pending checkpoints do not block earlier authorized tasks.
Keep root legacy files as 2–3 line catalog placeholders; preserve TODO ideas in
catalog candidates/roadmap and HISTORY in Git. Source prompt procedures receive
FR-036 rules; shared installation and full dual-mode prompt conversion await C.
Save a bounded CP2 request and transient inbox link after validated implementation.

**B**, after CP2 owner clearance: implement preview/apply closeout, delivery
commit/catalog archive, exact merge proof, annotated archive tags, preservation
and idempotent cleanup. `delivered` is terminal; no target documentation write.

**C**, after CP3 owner clearance: migration preview/apply/rollback, dual-mode
prompt tooling and adoption examples. Prompt installation needs separate owner
authorization; then remove kit placeholders. Stop at CP4 for owner acceptance.

## Validation and limits

CP2 carryovers for the future slice B plan: CPA-M5 scratch inspection scaling,
CPA-m2 staged hook package scoping, and CPA-m5 hook/mirror coverage for the later
rollout. Named owner: Codex (Spec 001 implementer), after CP2 owner clearance.
The [CP2 dispositions](reviews/2026-10-11-cp2-author-dispositions.md) record scope
and evidence; T018–T022 are the CP1-gated slice A remediation tasks.

Fixture tests cover resume, lifecycle states, declared worktrees/branch mismatch,
gates and verdicts, fourteen drift updates, lines/bytes/aggregate budgets, markers,
inboxes and stale IDs, reserved numbering, failed checkout/worker/integration,
exhausted remediation and scratch preservation. See [quickstart](quickstart.md).
Checks detect mechanical drift; semantic freshness and dishonest gate edits need
human judgment. Hook installation and host limitations are reported explicitly.
