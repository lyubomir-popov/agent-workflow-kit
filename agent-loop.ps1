<#
.SYNOPSIS
  Minimal agent-loop scheduler that feeds Copilot CLI one TODO item at a time.

.DESCRIPTION
  Reads TODO.md, finds the first unchecked task under "### Loop test tasks",
  builds a prompt, invokes Copilot CLI in autopilot mode, and checks whether
  a new commit appeared. Repeats until no unchecked tasks remain.

.NOTES
  This is a proof-of-concept. Run from the repo root.
#>

param(
    [int]$MaxTasks = 10,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$repoRoot = $PSScriptRoot
Set-Location $repoRoot

# ── Helpers ──────────────────────────────────────────────────────────────────

function Get-NextTask {
    <# Returns the raw task line text (after "- [ ] "), or $null if none left. #>
    $inSection = $false
    foreach ($line in (Get-Content TODO.md)) {
        if ($line -match '^### Loop test tasks') { $inSection = $true; continue }
        if ($inSection -and $line -match '^###?\s') { break }  # left section
        if ($inSection -and $line -match '^\s*-\s\[ \]\s+(.+)$') {
            return $Matches[1]
        }
    }
    return $null
}

function Get-HeadCommit {
    return (git rev-parse HEAD 2>$null)
}

# ── Main loop ────────────────────────────────────────────────────────────────

$taskCount = 0

while ($taskCount -lt $MaxTasks) {
    $task = Get-NextTask
    if (-not $task) {
        Write-Host "`n✓ No more unchecked tasks. Loop complete." -ForegroundColor Green
        break
    }

    $taskCount++
    Write-Host "`n── Task $taskCount ──────────────────────────────────────" -ForegroundColor Cyan
    Write-Host "  $task" -ForegroundColor Yellow

    $commitBefore = Get-HeadCommit

    # Build the prompt. The agent sees the repo, reads the workflow files,
    # does the task, and commits.
    $prompt = @"
You are working in the repo at the current directory.

Read .github/copilot-instructions.md for workflow rules.

Your ONE task:
$task

After completing the task:
1. Stage and commit the changes (use the commit message described in the task).
2. Do NOT move on to other tasks — stop after this one commit.
"@

    if ($DryRun) {
        Write-Host "  [DRY RUN] Would invoke copilot with:" -ForegroundColor DarkGray
        Write-Host "  $prompt" -ForegroundColor DarkGray
        # Simulate success for dry-run
        continue
    }

    Write-Host "  Invoking Copilot CLI..." -ForegroundColor DarkGray

    # Invoke Copilot CLI in non-interactive autopilot mode.
    # --autopilot:              no human in the loop
    # --allow-all:              don't prompt for file/tool permissions
    # --no-ask-user:            don't block waiting for human input
    # --max-autopilot-continues 5: safety cap on continuation rounds
    # -p:                       non-interactive prompt (exits when done)
    # -s:                       silent (agent response only, no UI chrome)
    copilot -p $prompt --autopilot --allow-all --no-ask-user --max-autopilot-continues 5 -s 2>&1 | ForEach-Object { Write-Host "  $_" }

    $exitCode = $LASTEXITCODE
    $commitAfter = Get-HeadCommit

    if ($exitCode -ne 0) {
        Write-Host "  ✗ Copilot exited with code $exitCode. Stopping." -ForegroundColor Red
        break
    }

    if ($commitBefore -eq $commitAfter) {
        Write-Host "  ✗ No new commit detected. Task may have failed. Stopping." -ForegroundColor Red
        break
    }

    Write-Host "  ✓ New commit: $commitAfter" -ForegroundColor Green
}

Write-Host "`n── Summary ──────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "  Tasks attempted: $taskCount"
Write-Host "  HEAD is now: $(Get-HeadCommit)"
git log --oneline -($taskCount + 2) | ForEach-Object { Write-Host "  $_" }
