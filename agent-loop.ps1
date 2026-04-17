<#
.SYNOPSIS
  Agent-loop scheduler: feeds Copilot CLI one TODO item at a time.

.DESCRIPTION
    Reads TODO.md, finds the first unchecked "- [ ]" item under the configured task heading,
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
        - PowerShell 7+ available as `pwsh` on macOS, Ubuntu, and Windows
        - Start from a clean git working tree for real runs; the script aborts if the repo is dirty
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

function Get-TaskSectionLevel {
    <# Returns the markdown heading level for the configured task section. #>
    if ($TaskSection -match '^(#+)\s+\S') {
        return $Matches[1].Length
    }

    throw "TaskSection must be a markdown heading, e.g. '## Active TODO' or '### Batch tasks'."
}

function Get-TaskSectionPattern {
    return '^\s*' + [regex]::Escape($TaskSection) + '\s*$'
}

function Get-SectionTasks {
    <# Returns all unchecked task texts under the configured task section. #>
    $tasks = @()
    $inSection = $false
    $sectionPattern = Get-TaskSectionPattern
    $sectionLevel = Get-TaskSectionLevel

    foreach ($line in (Get-Content TODO.md)) {
        if (-not $inSection -and $line -match $sectionPattern) {
            $inSection = $true
            continue
        }

        if (-not $inSection) {
            continue
        }

        if ($line -match '^(#+)\s+') {
            $currentLevel = $Matches[1].Length
            if ($currentLevel -le $sectionLevel) {
                break
            }
        }

        if ($line -match '^\s*-\s\[ \]\s+(.+)$') {
            $tasks += $Matches[1]
        }
    }

    return $tasks
}

function Get-NextTask {
    <# Returns the next unchecked task text, or $null if none remain. #>
    $tasks = Get-SectionTasks
    if ($tasks.Count -gt 0) {
        return $tasks[0]
    }

    return $null
}

function Mark-TaskDone {
    param([string]$TaskText)
    <# Checks off the first matching unchecked task inside the configured section. #>
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in (Get-Content TODO.md)) {
        $lines.Add($line)
    }

    $inSection = $false
    $sectionPattern = Get-TaskSectionPattern
    $sectionLevel = Get-TaskSectionLevel

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        if (-not $inSection -and $line -match $sectionPattern) {
            $inSection = $true
            continue
        }

        if (-not $inSection) {
            continue
        }

        if ($line -match '^(#+)\s+') {
            $currentLevel = $Matches[1].Length
            if ($currentLevel -le $sectionLevel) {
                break
            }
        }

        if ($line -match '^\s*-\s\[ \]\s+(.+)$' -and $Matches[1] -eq $TaskText) {
            $prefixMatch = [regex]::Match($line, '^(\s*-\s)\[ \](\s+.+)$')
            if (-not $prefixMatch.Success) {
                throw "Could not rewrite task line for: $TaskText"
            }

            $lines[$i] = $prefixMatch.Groups[1].Value + '[x]' + $prefixMatch.Groups[2].Value
            Set-Content TODO.md -Value $lines
            return
        }
    }

    throw "Could not find unchecked task in section '$TaskSection': $TaskText"
}

function Get-HeadCommit {
    return (git rev-parse HEAD 2>$null)
}

function Assert-CommandAvailable {
    param([string]$CommandName)

    if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
        throw "Required command not found on PATH: $CommandName"
    }
}

function Assert-CleanWorkingTree {
    param([string]$Context)

    $statusOutput = git status --porcelain
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        throw "git status failed while $Context"
    }

    if ($statusOutput) {
        throw "Working tree must be clean before $Context. Commit, stash, or discard local changes first."
    }
}

function Commit-Bookkeeping {
    param([string]$TaskText)

    $taskSummary = $TaskText.Trim()
    if ($taskSummary.Length -gt 180) {
        $taskSummary = $taskSummary.Substring(0, 177) + '...'
    }

    git add -- TODO.md
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to stage TODO.md for bookkeeping commit.'
    }

    git commit -m 'chore: mark TODO task done' -m "Task: $taskSummary"
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to create bookkeeping commit.'
    }

    return (Get-HeadCommit)
}

# ── Main loop ────────────────────────────────────────────────────────────────

Assert-CommandAvailable git

$taskCount = 0

# Dry-run: list all tasks at once and exit
if ($DryRun) {
    $allTasks = Get-SectionTasks
    if ($allTasks.Count -eq 0) {
        Write-Host "`n✓ No unchecked tasks found." -ForegroundColor Green
    } else {
        $cap = [Math]::Min($allTasks.Count, $MaxTasks)
        Write-Host "`n── Dry run: $($allTasks.Count) unchecked task(s) found (cap: $MaxTasks) ──" -ForegroundColor Cyan
        for ($i = 0; $i -lt $cap; $i++) {
            Write-Host "  $($i + 1). $($allTasks[$i])" -ForegroundColor Yellow
        }
        if ($allTasks.Count -gt $MaxTasks) {
            Write-Host "  … and $($allTasks.Count - $MaxTasks) more beyond the cap" -ForegroundColor DarkGray
        }
    }
    return
}

Assert-CommandAvailable copilot
Assert-CleanWorkingTree 'starting agent-loop'

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
2. Do not mark TODO items done yourself — the scheduler handles TODO bookkeeping.
3. Do NOT move on to other tasks — stop after this one commit.
"@

    Write-Host "  Invoking Copilot CLI..." -ForegroundColor DarkGray

    # Invoke Copilot CLI in non-interactive autopilot mode.
    # --autopilot:              no human in the loop
    # --allow-all:              don't prompt for file/tool permissions
    # --no-ask-user:            don't block waiting for human input
    # --max-autopilot-continues 5: safety cap on continuation rounds
    # -p:                       non-interactive prompt (exits when done)
    # -s:                       silent (agent response only, no UI chrome)
    $copilotOutput = & copilot -p $prompt --autopilot --allow-all --no-ask-user --max-autopilot-continues 5 -s 2>&1

    $exitCode = $LASTEXITCODE
    foreach ($line in $copilotOutput) {
        Write-Host "  $line"
    }

    $commitAfter = Get-HeadCommit

    if ($exitCode -ne 0) {
        Write-Host "  ✗ Copilot exited with code $exitCode. Stopping." -ForegroundColor Red
        break
    }

    if ($commitBefore -eq $commitAfter) {
        Write-Host "  ✗ No new commit detected. Task may have failed. Stopping." -ForegroundColor Red
        break
    }

    Assert-CleanWorkingTree 'recording scheduler bookkeeping'

    # Mark the task done in TODO.md (scheduler owns TODO bookkeeping)
    Mark-TaskDone $task
    $bookkeepingCommit = Commit-Bookkeeping $task

    Write-Host "  ✓ New commit: $commitAfter" -ForegroundColor Green
    Write-Host "  ✓ Task marked done in TODO.md" -ForegroundColor Green
    Write-Host "  ✓ Bookkeeping commit: $bookkeepingCommit" -ForegroundColor Green
}

Write-Host "`n── Summary ──────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "  Tasks attempted: $taskCount"
Write-Host "  HEAD is now: $(Get-HeadCommit)"
$logCount = $taskCount + 2
$recentLog = git log --oneline -$logCount
foreach ($line in $recentLog) {
    Write-Host "  $line"
}
