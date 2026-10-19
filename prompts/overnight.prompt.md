---
description: "Select the repository scheduler by workflow version; versioned runs stop at manual review and owner gates."
mode: agent
model: gpt-5.4-mini
---

# Overnight run (spec-kit)

## Workflow mode

Read `.workflow-kit.json` as JSON and inspect `workflowModelVersion`. If `.workflow-kit.json` is missing or `workflowModelVersion` is absent,
including when only `canonicalMirrorMode: external` is set, select legacy mode. Select spec-first mode only when `workflowModelVersion` is the JSON integer `1` or `2`;
do not coerce strings or other values. Stop if the JSON is
malformed, is not an object, or contains a present invalid or unsupported
version. Do not infer the mode from root files or placeholders. Execute only the
matching route below; versions 1 and 2 must not execute Legacy procedure.


## Version 1 route

Read `docs/operations.md` when available before an authorized launch. Keep the
scheduler foreground in a reused integrated terminal; verify CLI authentication,
stop on unauthenticated output, use interactive `copilot` `/login` when needed,
and do not repeat unattended authentication retries. Inspect preserved worktrees
on failure and retain the repository's terminal and recovery safeguards.

Read `AGENTS.md` and `docs/specs.md`, then inspect one active package's
`spec.md` and `tasks.md`. Confirm there is an authorized unchecked implementation task. Only active
packages with cleared entry gates are unattended implementation candidates. Review its declared branch and task gate.

Run a read-only preview first:

```powershell
pwsh -NoLogo -NoProfile -File "<path-to-agent-workflow-kit>/agent-loop.ps1" -Workflow SpecKit -RepoRoot . -MaxSpecs 1 -MaxTasks 1 -OnFailure stop -DryRun
```

When the user has authorized a live run, use their bounded SpecKit scope.
This example allows one worker invocation for that package:

```powershell
pwsh -NoLogo -NoProfile -File "<path-to-agent-workflow-kit>/agent-loop.ps1" -Workflow SpecKit -RepoRoot . -MaxSpecs 1 -MaxTasks 1 -OnFailure stop
```

The example defaults to one invocation. Honor explicitly authorized user bounds
for `-MaxTasks` and `-MaxSpecs`, keeping execution within the approved phase.
Stop at the authorized bound. Required reviews and owner
dispositions are handled manually; do not launch automatic adversarial review,
address rounds, or advance to another package. Authorization to continue never
clears a checkpoint or task gate.

## Version 2 route

Read `AGENTS.md`, `docs/specs.md`, and the selected package's `spec.md` and
`tasks.md` to identify scope and checkpoint blockers. Read `docs/scheduler.md`
for qualified worker profiles, auth probes, bounds and recovery. Preview with
`wfk run --repo . --package <catalog-package> --agents <ordered-profiles> --json`.
Only an explicitly authorized live run adds `--apply`; use the owner's positive
`--max-tasks`, `--max-hours` and `--task-timeout` bounds. Defaults cap one task.
Authentication probes fail closed; use the qualified provider defaults or a
verified override, and do not invent login checks or substitute another scheduler.
Do not launch real workers when only fake workers
are authorized. Preserve the printed common-directory report and worktrees.
Optional `--review --review-checkpoint <gate>` requires review authorization and
never clears an owner gate. Stop at the next checkpoint or supplied bound.

## Legacy procedure

### Retired root-state guard

Before this legacy procedure, read the repository's AGENTS.md. If STATUS.md,
TODO.md, or HISTORY.md is a 2–3 line retirement placeholder pointing to
`docs/specs.md`, stop the legacy procedure and follow AGENTS/catalog/package
owners instead. Never recreate or expand retired files, drain unread handoffs,
write feature handovers into instructions, or bypass an owner checkpoint.
Prompt installation remains separately authorized.

Launch the `agent-loop.ps1` scheduler in **SpecKit** mode. This is meant to run for hours unattended: implement the current spec package until `tasks.md` is complete, run an adversarial review, address findings, then move to the next **In Progress** spec from `docs/specs.md` until the queue is exhausted.

This replaces the legacy TODO.md one-commit-per-task loop.

Read docs/operations.md when available for terminal hygiene, authentication,
and bounded autonomy. For legacy consumers retain those safeguards: foreground
integrated terminals, a small reused terminal set, stop on unauthenticated CLI
output, interactive copilot /login, and no repeated unattended auth retries.
Authorization to continue never clears an owner gate or starts a delta review.

### Pre-flight

1. Read `AGENTS.md` handover (or `STATUS.md` if present) and `docs/specs.md` to see which spec packages are **In Progress**.
2. Confirm you are on the intended `feat/<id>-<slug>` branch when working a specific spec, or let the scheduler check it out when the branch exists locally.
3. Run a dry run:

```powershell
pwsh -NoLogo -NoProfile -File "<path-to-agent-workflow-kit>/agent-loop.ps1" -Workflow SpecKit -Agent Auto -RepoRoot . -DryRun
```

4. If the working tree is dirty, commit or stash a checkpoint first when you want automatic cherry-picks into the primary worktree.
5. Verify GitHub CLI works (`gh auth status`) — do **not** use the old PowerShell `gh` git-grep alias; use `gg` for `git grep` if needed.
6. Report the dry-run queue only if something looks wrong (no in-progress specs, wrong branch, missing `tasks.md`). Otherwise proceed without asking.

### Launch

Resolve `agent-loop.ps1` from the workspace. Prefer `agent-workflow-kit` when it is open; otherwise search sibling folders.

```powershell
pwsh -NoLogo -NoProfile -File "<path-to-agent-workflow-kit>/agent-loop.ps1" `
  -Workflow SpecKit `
  -Agent Auto `
  -RepoRoot . `
  -MaxTasks 0 `
  -TaskTimeoutSeconds 3600 `
  -MaxContinues 25 `
  -MaxAddressRounds 3 `
  -OnFailure skip `
  -ReasoningEffort medium
```

#### What the scheduler does

For each spec package (current `feat/*` branch first, then other **In Progress** rows in `docs/specs.md`):

1. **Implement** — repeated worker invocations until every `- [ ]` in `specs/<id>-<slug>/tasks.md` is checked off.
2. **Adversarial review** — one worker invocation; findings go to the current project's `AGENT-INBOX.md` at the repo root (or the repo's adversarial prompt template).
3. **Address** — up to `-MaxAddressRounds` invocations while active inbox findings remain.

The run stops when all queued spec packages finish, the invocation cap is hit, or unrecoverable failures occur.

### Overrides

The user may specify:

| Flag | Default (overnight) | Meaning |
|------|---------------------|---------|
| `-MaxTasks N` | `0` (unlimited) | Cap total worker invocations across the whole run |
| `-MaxSpecs N` | `0` (all queued) | Cap how many in-progress spec packages to process |
| `-TaskTimeoutSeconds N` | `3600` | Per-invocation timeout (1 hour) |
| `-MaxContinues N` | `25` | Copilot `--max-autopilot-continues` per invocation |
| `-MaxAddressRounds N` | `3` | Address-review rounds per spec after adversarial review |
| `-OnFailure skip\|stop` | `skip` | Continue to next invocation/spec vs halt |
| `-Agent Auto\|Codex\|Copilot` | `Auto` | Worker CLI. `Auto` uses Codex when launched from Codex, otherwise Copilot. |
| `-Model <name>` | Script default / owner override | Concrete preferences are owned by agent-loop.ps1's TierDispatchMap; pass explicit user overrides without duplicating a model table. |
| `-ReasoningEffort low\|medium\|high\|xhigh` | `medium` | Reasoning level. Copilot receives `--effort`; Codex currently uses its configured reasoning behavior. |
| `-UseTierDispatch` | off | Optional `[H]`/`[S]`/`[L]` routing from task text |

Pass user overrides through to the command.

### After launch

The script runs in the foreground. Monitor per-phase output. `Ctrl+C` is safe; preserved worktrees are printed when cherry-pick or timeout recovery is needed.

Do not fall back to the legacy TODO.md scheduler unless the user explicitly asks for `-Workflow Todo`.
