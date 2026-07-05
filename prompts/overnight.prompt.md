---
description: "Unattended spec-kit overnight run: finish the active spec, adversarial review, address findings, then advance to the next in-progress spec."
mode: agent
model: gpt-5.4-mini
---

# Overnight run (spec-kit)

Launch the `agent-loop.ps1` scheduler in **SpecKit** mode. This is meant to run for hours unattended: implement the current spec package until `tasks.md` is complete, run an adversarial review, address findings, then move to the next **In Progress** spec from `docs/specs.md` until the queue is exhausted.

This replaces the legacy TODO.md one-commit-per-task loop.

## Pre-flight

1. Read `AGENTS.md` handover (or `STATUS.md` if present) and `docs/specs.md` to see which spec packages are **In Progress**.
2. Confirm you are on the intended `feat/<id>-<slug>` branch when working a specific spec, or let the scheduler check it out when the branch exists locally.
3. Run a dry run:

```powershell
pwsh -NoLogo -NoProfile -File "<path-to-agent-workflow-kit>/agent-loop.ps1" -Workflow SpecKit -Agent Auto -RepoRoot . -DryRun
```

4. If the working tree is dirty, commit or stash a checkpoint first when you want automatic cherry-picks into the primary worktree.
5. Verify GitHub CLI works (`gh auth status`) — do **not** use the old PowerShell `gh` git-grep alias; use `gg` for `git grep` if needed.
6. Report the dry-run queue only if something looks wrong (no in-progress specs, wrong branch, missing `tasks.md`). Otherwise proceed without asking.

## Launch

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
  -Model gpt-5.4 `
  -ReasoningEffort medium
```

### What the scheduler does

For each spec package (current `feat/*` branch first, then other **In Progress** rows in `docs/specs.md`):

1. **Implement** — repeated worker invocations until every `- [ ]` in `specs/<id>-<slug>/tasks.md` is checked off.
2. **Adversarial review** — one worker invocation; findings go to the current project's `AGENT-INBOX.md` at the repo root (or the repo's adversarial prompt template).
3. **Address** — up to `-MaxAddressRounds` invocations while active inbox findings remain.

The run stops when all queued spec packages finish, the invocation cap is hit, or unrecoverable failures occur.

## Overrides

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
| `-Model <name>` | `gpt-5.4` | Worker model. Copilot receives this directly; Codex ignores Copilot-style `gpt-5.4` aliases and uses its configured default unless a Codex-compatible model is passed. |
| `-ReasoningEffort low\|medium\|high\|xhigh` | `medium` | Reasoning level. Copilot receives `--effort`; Codex currently uses its configured reasoning behavior. |
| `-UseTierDispatch` | off | Optional `[H]`/`[S]`/`[L]` routing from task text |

Pass user overrides through to the command.

## After launch

The script runs in the foreground. Monitor per-phase output. `Ctrl+C` is safe; preserved worktrees are printed when cherry-pick or timeout recovery is needed.

Do not fall back to the legacy TODO.md scheduler unless the user explicitly asks for `-Workflow Todo`.
