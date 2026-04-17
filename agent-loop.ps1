<#
.SYNOPSIS
  Agent-loop scheduler: feeds Copilot CLI one TODO item at a time.

.DESCRIPTION
  Reads TODO.md, finds the first unchecked "- [ ]" item under "## Active TODO",
  builds a prompt, invokes Copilot CLI in non-interactive autopilot mode, and
  checks whether a new commit appeared. Repeats until no unchecked tasks remain
  or a failure is detected.

.PARAMETER MaxTasks
  Safety cap on how many tasks to process in one run. Default: 10.

.PARAMETER DryRun
  Parse and display tasks without invoking Copilot CLI.

.PARAMETER TaskSection
  The heading that marks the task section in TODO.md. Default: "## Active TODO".

.NOTES
  Prerequisites:
    - Copilot CLI installed: npm install -g @anthropic-ai/copilot-cli (or via VS Code)
    - GitHub auth: gh auth login --web -h github.com
    - Run from the repo root (or the script will cd to $PSScriptRoot)
#>

param(
    [int]$MaxTasks = 10,
    [switch]$DryRun,
    [string]$TaskSection = '## Active TODO',
    [string]$RepoRoot = $PWD
)

$ErrorActionPreference = 'Stop'
Set-Location $RepoRoot

# ── Helpers ──────────────────────────────────────────────────────────────────

function Get-NextTask {
    <# Returns the raw task line text (after "- [ ] "), or $null if none left. #>
    $inSection = $false
    $sectionPattern = [regex]::Escape($TaskSection)
    foreach ($line in (Get-Content TODO.md)) {
        if ($line -match "^$sectionPattern") { $inSection = $true; continue }
        if ($inSection -and $line -match '^## ') { break }  # hit next H2, stop
        if ($inSection -and $line -match '^\s*-\s\[ \]\s+(.+)$') {
            return $Matches[1]
        }
    }
    return $null
}

function Mark-TaskDone {
    param([string]$TaskText)
    <# Checks off a task in TODO.md by replacing "- [ ] <text>" with "- [x] <text>". #>
    $escaped = [regex]::Escape($TaskText)
    $content = Get-Content TODO.md -Raw
    $content = $content -replace "- \[ \] $escaped", "- [x] $TaskText"
    Set-Content TODO.md $content -NoNewline
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

    # Mark the task done in TODO.md (scheduler owns state, not the agent)
    Mark-TaskDone $task
    Write-Host "  ✓ New commit: $commitAfter" -ForegroundColor Green
    Write-Host "  ✓ Task marked done in TODO.md" -ForegroundColor Green
}

Write-Host "`n── Summary ──────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "  Tasks attempted: $taskCount"
Write-Host "  HEAD is now: $(Get-HeadCommit)"
$logCount = $taskCount + 2
git log --oneline -$logCount | ForEach-Object { Write-Host "  $_" }
