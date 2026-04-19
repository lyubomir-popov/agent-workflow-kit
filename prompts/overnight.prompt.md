---
description: "Launch the agent-loop scheduler for an overnight TODO run using Copilot CLI."
mode: agent
---

# Overnight run

Launch the `agent-loop.ps1` scheduler to work through TODO items unattended. Each task gets a fresh Copilot CLI invocation in a disposable worktree.

## Pre-flight

1. Read `STATUS.md` and `TODO.md` to orient.
2. Run `agent-loop.ps1 -DryRun` to preview which tasks will be picked up.
3. If the working tree is dirty, commit a checkpoint first (the script requires a clean tree for real runs).
4. Report the dry-run output and ask for final go/no-go only if something looks wrong. Otherwise proceed.

## Launch

Run the scheduler from the current repo root. The script path should be resolved relative to a known workspace folder. Look for `agent-loop.ps1` in the workspace or in sibling folders:

```powershell
# If agent-workflow-kit is in the workspace:
pwsh -NoLogo -NoProfile -File "<path-to-agent-workflow-kit>/agent-loop.ps1" -RepoRoot . -MaxTasks 5 -TaskTimeoutSeconds 900
```

If the boilerplate repo is not at the expected path, search for `agent-loop.ps1` in sibling workspace folders or ask the user.

## Overrides

The user may specify:
- `-MaxTasks N` — cap how many tasks to attempt (default 10)
- `-TaskTimeoutSeconds N` — per-task timeout (default 900 = 15 min)
- `-Model <name>` — Copilot CLI model (default gpt-5.4)
- `-ReasoningEffort low|medium|high|xhigh` — reasoning level (default low)

Pass any user-specified overrides through to the command.

## After launch

The script runs in the foreground terminal. Monitor its output — it prints status per task. When it finishes or if you need to stop it, Ctrl+C is safe (worktrees are cleaned up or preserved for inspection).