<#
.SYNOPSIS
  Agent-loop scheduler: feeds Copilot CLI one TODO item at a time.

.DESCRIPTION
    Reads TODO.md, finds the next actionable item under the configured or auto-detected
    task heading, builds a prompt, invokes Copilot CLI in non-interactive autopilot mode,
    and checks whether a new commit appeared. Repeats until no actionable tasks remain
    or a failure is detected.

.PARAMETER MaxTasks
  Safety cap on how many tasks to process in one run. Default: 10.

.PARAMETER DryRun
  Parse and display tasks without invoking Copilot CLI.

.PARAMETER TaskTimeoutSeconds
    Maximum runtime for one Copilot task before the scheduler kills it and stops.

.PARAMETER Model
    AI model passed through to Copilot CLI. Default: gpt-5.4.

.PARAMETER ReasoningEffort
    Copilot CLI reasoning effort level. Default: low.

.PARAMETER TaskSection
    The heading that marks the task section in TODO.md. Default: auto-detect from
    common workflow headings.

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
    [int]$TaskTimeoutSeconds = 900,
    [string]$Model = 'gpt-5.4',
    [ValidateSet('low', 'medium', 'high', 'xhigh')]
    [string]$ReasoningEffort = 'low',
    [string]$TaskSection = 'auto',
    [string]$RepoRoot = $PWD
)

$ErrorActionPreference = 'Stop'
Set-Location $RepoRoot

$DefaultTaskSectionCandidates = @(
    '## Active TODO',
    '## Active tasks',
    '## Active Tasks',
    '## Active Execution Queue',
    '## Short-term'
)

$TaskHistoryStopWords = @(
    'about', 'active', 'after', 'agent', 'agents', 'allow', 'before', 'being', 'branch', 'changes', 'clean', 'commit', 'completed',
    'current', 'design', 'directly', 'docs', 'entry', 'first', 'follow', 'future', 'history', 'inbox', 'item', 'items', 'later',
    'loop', 'mirror', 'notes', 'placeholder', 'queue', 'repo', 'repos', 'replace', 'roadmap', 'rules', 'self', 'session', 'should',
    'source', 'sources', 'specs', 'stage', 'status', 'still', 'task', 'tasks', 'todo', 'triage', 'update', 'workflow', 'worktree'
)

# ── Helpers ──────────────────────────────────────────────────────────────────

function Get-HeadingLevel {
    param([string]$Line)

    if ($Line -match '^\s*(#+)\s+\S') {
        return $Matches[1].Length
    }

    return $null
}

function Get-HeadingPattern {
    param([string]$HeadingText)

    return '^\s*' + [regex]::Escape($HeadingText.Trim()) + '\s*$'
}

function Get-SectionBoundsByStartIndex {
    param(
        [string[]]$Lines,
        [int]$StartIndex
    )

    $heading = $Lines[$StartIndex].Trim()
    $level = Get-HeadingLevel $Lines[$StartIndex]
    if (-not $level) {
        throw "Line at index $StartIndex is not a markdown heading."
    }

    $endIndex = $Lines.Count - 1
    for ($i = $StartIndex + 1; $i -lt $Lines.Count; $i++) {
        $candidateLevel = Get-HeadingLevel $Lines[$i]
        if ($candidateLevel -and $candidateLevel -le $level) {
            $endIndex = $i - 1
            break
        }
    }

    return [pscustomobject]@{
        Heading = $heading
        Level = $level
        StartIndex = $StartIndex + 1
        EndIndex = $endIndex
    }
}

function Find-SectionBounds {
    param(
        [string[]]$Lines,
        [string]$HeadingText
    )

    $pattern = Get-HeadingPattern $HeadingText
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match $pattern) {
            return (Get-SectionBoundsByStartIndex -Lines $Lines -StartIndex $i)
        }
    }

    return $null
}

function Convert-TableCells {
    param([string]$Line)

    $trimmed = $Line.Trim()
    if ($trimmed.StartsWith('|')) {
        $trimmed = $trimmed.Substring(1)
    }
    if ($trimmed.EndsWith('|')) {
        $trimmed = $trimmed.Substring(0, $trimmed.Length - 1)
    }

    if ($trimmed.Length -eq 0) {
        return @('')
    }

    return ($trimmed -split '\|').ForEach({ $_.Trim() })
}

function Format-TableRow {
    param([string[]]$Cells)

    return '| ' + ($Cells -join ' | ') + ' |'
}

function Split-StatusTableSummary {
    param([string]$Summary)

    $trimmed = $Summary.Trim()
    $nextMatch = [regex]::Match($trimmed, '(?is)\bNext:\s*(.+)$')

    if ($nextMatch.Success) {
        $progressSummary = $trimmed.Substring(0, $nextMatch.Index).Trim()
        $nextAction = $nextMatch.Groups[1].Value.Trim()

        return [pscustomobject]@{
            ProgressSummary = $progressSummary
            NextAction = $nextAction
        }
    }

    return [pscustomobject]@{
        ProgressSummary = $trimmed
        NextAction = ''
    }
}

function Get-ActiveLaneBounds {
    param(
        [string[]]$Lines,
        $SectionBounds
    )

    $activeLaneName = $null
    for ($i = $SectionBounds.StartIndex; $i -le $SectionBounds.EndIndex; $i++) {
        if ($Lines[$i] -match '^\s*Lane\s+(.+?)\s+is\s+active\.\s*$') {
            $activeLaneName = $Matches[1].Trim()
            break
        }
    }

    if (-not $activeLaneName) {
        return $SectionBounds
    }

    $lanePattern = '^\s*###\s+Lane\s+' + [regex]::Escape($activeLaneName) + '(?:\b|\s|\u2014|-)'
    for ($i = $SectionBounds.StartIndex; $i -le $SectionBounds.EndIndex; $i++) {
        if ($Lines[$i] -match $lanePattern) {
            return (Get-SectionBoundsByStartIndex -Lines $Lines -StartIndex $i)
        }
    }

    return $SectionBounds
}

function Get-CheckboxTasks {
    param(
        [string[]]$Lines,
        $SectionBounds
    )

    $tasks = @()
    for ($i = $SectionBounds.StartIndex; $i -le $SectionBounds.EndIndex; $i++) {
        if ($Lines[$i] -match '^\s*-\s\[ \]\s+(.+)$') {
            $tasks += [pscustomobject]@{
                Kind = 'checkbox'
                Text = $Matches[1]
                SectionHeading = $SectionBounds.Heading
                LineIndex = $i
            }
        }
    }

    return $tasks
}

function Test-IsActionableStatus {
    param([string]$Status)

    $normalized = $Status.Trim().ToLowerInvariant()
    if (-not $normalized) {
        return $false
    }

    $nonActionable = @(
        'done',
        'complete',
        'completed',
        'paused',
        'deferred',
        'blocked',
        'cancelled',
        'canceled',
        'archived'
    )

    return -not ($nonActionable -contains $normalized)
}

function Get-StatusTableTasks {
    param(
        [string[]]$Lines,
        $SectionBounds
    )

    $tasks = @()
    $scanBounds = Get-ActiveLaneBounds -Lines $Lines -SectionBounds $SectionBounds

    for ($i = $scanBounds.StartIndex; $i -le $scanBounds.EndIndex; $i++) {
        if ($Lines[$i] -notmatch '^\s*\|') {
            continue
        }

        if ($i + 1 -gt $scanBounds.EndIndex) {
            continue
        }

        $headerCells = Convert-TableCells $Lines[$i]
        if ($headerCells.Count -lt 2) {
            continue
        }

        if ($Lines[$i + 1] -notmatch '^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)+\|?\s*$') {
            continue
        }

        $headerLookup = @{}
        for ($cellIndex = 0; $cellIndex -lt $headerCells.Count; $cellIndex++) {
            $headerLookup[$headerCells[$cellIndex].ToLowerInvariant()] = $cellIndex
        }

        if (-not $headerLookup.ContainsKey('status')) {
            continue
        }

        $statusColumnIndex = $headerLookup['status']
        $summaryColumnIndex = if ($headerLookup.ContainsKey('summary')) { $headerLookup['summary'] } else { $null }
        $stepColumnIndex = if ($headerLookup.ContainsKey('step')) { $headerLookup['step'] } else { $null }

        $rowIndex = $i + 2
        while ($rowIndex -le $scanBounds.EndIndex -and $Lines[$rowIndex] -match '^\s*\|') {
            $cells = Convert-TableCells $Lines[$rowIndex]
            while ($cells.Count -lt $headerCells.Count) {
                $cells += ''
            }

            $status = $cells[$statusColumnIndex]
            if (Test-IsActionableStatus $status) {
                $step = if ($null -ne $stepColumnIndex) { $cells[$stepColumnIndex].Trim() } else { '' }
                $summary = if ($null -ne $summaryColumnIndex) { $cells[$summaryColumnIndex].Trim() } else { ($cells -join ' | ').Trim() }
                $summaryParts = Split-StatusTableSummary -Summary $summary

                $taskText = if ($summaryParts.NextAction) {
                    if ($step) { "$step — $($summaryParts.NextAction)" } else { $summaryParts.NextAction }
                } elseif ($step) {
                    "$step — $summary"
                } else {
                    $summary
                }

                $tasks += [pscustomobject]@{
                    Kind = 'status-table'
                    Text = $taskText
                    SectionHeading = $SectionBounds.Heading
                    LaneHeading = $scanBounds.Heading
                    LineIndex = $rowIndex
                    StatusColumnIndex = $statusColumnIndex
                    Cells = $cells
                    RowSummary = $summaryParts.ProgressSummary
                    NextAction = $summaryParts.NextAction
                }
            }

            $rowIndex++
        }

        $i = $rowIndex
    }

    return $tasks
}

function Get-TasksForSection {
    param(
        [string[]]$Lines,
        $SectionBounds
    )

    $checkboxTasks = Get-CheckboxTasks -Lines $Lines -SectionBounds $SectionBounds
    if ($checkboxTasks.Count -gt 0) {
        return $checkboxTasks
    }

    return (Get-StatusTableTasks -Lines $Lines -SectionBounds $SectionBounds)
}

function Get-TaskContext {
    param([string[]]$Lines)

    $requestedSection = $TaskSection.Trim()
    if ($requestedSection -and $requestedSection.ToLowerInvariant() -ne 'auto') {
        $sectionBounds = Find-SectionBounds -Lines $Lines -HeadingText $requestedSection
        if (-not $sectionBounds) {
            throw "Task section not found in TODO.md: $requestedSection"
        }

        return [pscustomobject]@{
            Section = $sectionBounds
            Tasks = @(Get-TasksForSection -Lines $Lines -SectionBounds $sectionBounds)
        }
    }

    foreach ($candidate in $DefaultTaskSectionCandidates) {
        $sectionBounds = Find-SectionBounds -Lines $Lines -HeadingText $candidate
        if (-not $sectionBounds) {
            continue
        }

        $tasks = @(Get-TasksForSection -Lines $Lines -SectionBounds $sectionBounds)
        if ($tasks.Count -gt 0) {
            return [pscustomobject]@{
                Section = $sectionBounds
                Tasks = $tasks
            }
        }
    }

    return [pscustomobject]@{
        Section = $null
        Tasks = @()
    }
}

function Get-TaskSummary {
    param($Task)

    return $Task.Text
}

function Get-TodoText {
    return (Get-Content TODO.md -Raw)
}

function Get-TaskSourceTexts {
    param($Task)

    $sourceTexts = [System.Collections.Generic.List[string]]::new()
    if ($Task.Text) {
        $sourceTexts.Add($Task.Text)
    }

    if ($Task.PSObject.Properties.Name -contains 'NextAction' -and $Task.NextAction) {
        $sourceTexts.Add($Task.NextAction)
    }

    if ($Task.PSObject.Properties.Name -contains 'RowSummary' -and $Task.RowSummary) {
        $sourceTexts.Add($Task.RowSummary)
    }

    return @($sourceTexts)
}

function Get-TaskSearchHints {
    param($Task)

    $sourceTexts = Get-TaskSourceTexts -Task $Task

    $hints = [System.Collections.Generic.List[string]]::new()
    foreach ($sourceText in $sourceTexts) {
        foreach ($match in [regex]::Matches($sourceText, '`([^`]+)`')) {
            $hint = $match.Groups[1].Value.Trim()
            if ($hint -and -not $hints.Contains($hint)) {
                $hints.Add($hint)
            }
        }
    }

    return @($hints | Select-Object -First 5)
}

function Get-TaskHistoryTokens {
    param($Task)

    $tokens = [System.Collections.Generic.List[string]]::new()
    $sourceTexts = Get-TaskSourceTexts -Task $Task

    foreach ($sourceText in $sourceTexts) {
        foreach ($match in [regex]::Matches($sourceText.ToLowerInvariant(), '[a-z0-9][a-z0-9._/-]*')) {
            $token = $match.Value.Trim('.', '/', '_', '-')
            if ($token.Length -lt 4) {
                continue
            }

            if ($token -match '^\d+$') {
                continue
            }

            if ($TaskHistoryStopWords -contains $token) {
                continue
            }

            if (-not $tokens.Contains($token)) {
                $tokens.Add($token)
            }
        }
    }

    return @($tokens | Select-Object -First 15)
}

function Get-LikelyStaleTaskWarnings {
    param(
        [string]$RepoPath,
        $Task,
        [int]$CommitCount = 25
    )

    $tokens = @(Get-TaskHistoryTokens -Task $Task)
    if ($tokens.Count -eq 0) {
        return @()
    }

    $recentLog = git -C $RepoPath log --oneline -$CommitCount
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to read recent commit history for $RepoPath"
    }

    if (-not $recentLog) {
        return @()
    }

    $warnings = @()
    foreach ($logLine in @($recentLog)) {
        if ($logLine -notmatch '^(\S+)\s+(.+)$') {
            continue
        }

        $subject = $Matches[2]
        $subjectLower = $subject.ToLowerInvariant()
        $matchedTokens = [System.Collections.Generic.List[string]]::new()

        foreach ($token in $tokens) {
            if ($subjectLower.Contains($token) -and -not $matchedTokens.Contains($token)) {
                $matchedTokens.Add($token)
            }
        }

        if ($matchedTokens.Count -ge 3) {
            $warnings += [pscustomobject]@{
                Commit = $logLine
                MatchedTokens = @($matchedTokens | Select-Object -First 5)
            }
        }
    }

    return @($warnings | Select-Object -First 3)
}

function Test-TaskStillPending {
    param($Task)

    $currentContext = Get-TaskContext -Lines (Get-Content TODO.md)
    foreach ($currentTask in $currentContext.Tasks) {
        if ($currentTask.Kind -eq $Task.Kind -and $currentTask.Text -eq $Task.Text) {
            return $true
        }
    }

    return $false
}

function Get-TaskSourceSummary {
    param($Task)

    $sourceLines = @(
        "- TODO section: $($Task.SectionHeading)",
        "- Task format: $($Task.Kind)"
    )

    if ($Task.PSObject.Properties.Name -contains 'LaneHeading' -and $Task.LaneHeading) {
        $sourceLines += "- Active lane: $($Task.LaneHeading)"
    }

    if ($Task.PSObject.Properties.Name -contains 'NextAction' -and $Task.NextAction) {
        $sourceLines += "- Explicit next slice from row: $($Task.NextAction)"
    }

    if ($Task.PSObject.Properties.Name -contains 'RowSummary' -and $Task.RowSummary) {
        $sourceLines += "- Current row context: $($Task.RowSummary)"
    }

    $searchHints = @(Get-TaskSearchHints -Task $Task)
    if ($searchHints.Count -gt 0) {
        $sourceLines += "- Search hints: $($searchHints -join ', ')"
    }

    return ($sourceLines -join [Environment]::NewLine)
}

function Get-NextTask {
    <# Returns the next actionable task object, or $null if none remain. #>
    $taskContext = Get-TaskContext -Lines (Get-Content TODO.md)
    if ($taskContext.Tasks.Count -gt 0) {
        return $taskContext.Tasks[0]
    }

    return $null
}

function Mark-TaskDone {
    param($Task)

    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in (Get-Content TODO.md)) {
        $lines.Add($line)
    }

    switch ($Task.Kind) {
        'checkbox' {
            $line = $lines[$Task.LineIndex]
            $prefixMatch = [regex]::Match($line, '^(\s*-\s)\[ \](\s+.+)$')
            if (-not $prefixMatch.Success) {
                throw "Could not rewrite checkbox task line for: $($Task.Text)"
            }

            $lines[$Task.LineIndex] = $prefixMatch.Groups[1].Value + '[x]' + $prefixMatch.Groups[2].Value
            Set-Content TODO.md -Value $lines
            return
        }

        'status-table' {
            $cells = Convert-TableCells $lines[$Task.LineIndex]
            while ($cells.Count -lt ($Task.Cells.Count)) {
                $cells += ''
            }

            $cells[$Task.StatusColumnIndex] = 'Done'
            $lines[$Task.LineIndex] = Format-TableRow $cells
            Set-Content TODO.md -Value $lines
            return
        }

        default {
            throw "Unsupported task kind: $($Task.Kind)"
        }
    }
}

function Get-HeadCommit {
    param([string]$RepoPath = (Get-Location).Path)

    return (git -C $RepoPath rev-parse HEAD 2>$null)
}

function Get-WorkingTreeStatus {
    param([string]$RepoPath = (Get-Location).Path)

    $statusOutput = git -C $RepoPath status --short
    if ($LASTEXITCODE -ne 0) {
        throw "git status failed for $RepoPath"
    }

    if (-not $statusOutput) {
        return @()
    }

    return @($statusOutput)
}

function Get-CommitCountBetween {
    param(
        [string]$RepoPath,
        [string]$BaseCommit,
        [string]$HeadCommit
    )

    $countText = git -C $RepoPath rev-list --count "$BaseCommit..$HeadCommit"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to count commits between $BaseCommit and $HeadCommit in $RepoPath"
    }

    return [int]($countText.Trim())
}

function Get-CommitSummariesBetween {
    param(
        [string]$RepoPath,
        [string]$BaseCommit,
        [string]$HeadCommit
    )

    $logOutput = git -C $RepoPath log --oneline "$BaseCommit..$HeadCommit"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to read commit log between $BaseCommit and $HeadCommit in $RepoPath"
    }

    if (-not $logOutput) {
        return @()
    }

    return @($logOutput)
}

function New-TemporaryWorktree {
    param([string]$RepoPath)

    $repoName = Split-Path $RepoPath -Leaf
    $worktreeRoot = Join-Path ([System.IO.Path]::GetTempPath()) 'agent-loop-worktrees'
    $null = New-Item -ItemType Directory -Force -Path $worktreeRoot

    git -C $RepoPath worktree prune --expire now | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to prune stale worktrees for $RepoPath"
    }

    $worktreePath = Join-Path $worktreeRoot "$repoName-$([guid]::NewGuid().ToString('N'))"
    git -C $RepoPath worktree add --detach $worktreePath HEAD | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create temporary worktree at $worktreePath"
    }

    return $worktreePath
}

function Remove-TemporaryWorktree {
    param(
        [string]$RepoPath,
        [string]$WorktreePath
    )

    $managedRoot = Join-Path ([System.IO.Path]::GetTempPath()) 'agent-loop-worktrees'
    $canForceDelete = $WorktreePath.StartsWith($managedRoot, [System.StringComparison]::OrdinalIgnoreCase)

    if (-not (Test-Path $WorktreePath)) {
        git -C $RepoPath worktree prune --expire now | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to prune stale worktrees for $RepoPath"
        }
        return
    }

    git -C $RepoPath worktree remove --force $WorktreePath | Out-Null
    if ($LASTEXITCODE -eq 0) {
        return
    }

    if (-not $canForceDelete) {
        throw "Failed to remove temporary worktree at $WorktreePath"
    }

    try {
        Remove-Item -LiteralPath $WorktreePath -Recurse -Force -ErrorAction Stop
    } catch {
        throw "Failed to remove temporary worktree contents at $WorktreePath"
    }

    git -C $RepoPath worktree prune --expire now | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to prune stale worktrees for $RepoPath"
    }
}

function Assert-CommandAvailable {
    param([string]$CommandName)

    if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
        throw "Required command not found on PATH: $CommandName"
    }
}

function Resolve-CommandPath {
    param([string]$CommandName)

    $commandInfo = Get-Command $CommandName -ErrorAction SilentlyContinue
    if (-not $commandInfo) {
        throw "Required command not found on PATH: $CommandName"
    }

    if ($commandInfo.Path) {
        return $commandInfo.Path
    }

    if ($commandInfo.Source) {
        return $commandInfo.Source
    }

    throw "Could not resolve executable path for command: $CommandName"
}

function Get-CommandPaths {
    param([string]$CommandName)

    $commands = Get-Command -All $CommandName -ErrorAction SilentlyContinue
    $paths = @()
    foreach ($command in $commands) {
        $path = if ($command.Path) { $command.Path } elseif ($command.Source) { $command.Source } else { $null }
        if ($path) {
            $paths += $path
        }
    }

    return $paths | Select-Object -Unique
}

function Test-IsCopilotBootstrapPath {
    param([string]$Path)

    $normalized = $Path.Replace('/', '\').ToLowerInvariant()
    return $normalized -like '*github.copilot-chat\copilotcli\*'
}

function Resolve-CopilotLaunchSpec {
    param([string[]]$CopilotArguments)

    $candidatePaths = @(Get-CommandPaths 'copilot')
    if ($candidatePaths.Count -eq 0) {
        throw 'Required command not found on PATH: copilot'
    }

    $nonBootstrapPaths = @($candidatePaths | Where-Object { -not (Test-IsCopilotBootstrapPath $_) })
    if ($nonBootstrapPaths.Count -gt 0) {
        $candidatePaths = $nonBootstrapPaths
    }

    if ($IsWindows -or $env:OS -eq 'Windows_NT') {
        $preferredOrder = @(
            @($candidatePaths | Where-Object { $_.ToLowerInvariant().EndsWith('copilot.cmd') }),
            @($candidatePaths | Where-Object { $_.ToLowerInvariant().EndsWith('copilot.exe') }),
            @($candidatePaths | Where-Object { $_.ToLowerInvariant().EndsWith('copilot.ps1') }),
            @($candidatePaths)
        )
    } else {
        $preferredOrder = @(@($candidatePaths))
    }

    $selectedPath = $null
    foreach ($group in $preferredOrder) {
        if ($group.Count -gt 0) {
            $selectedPath = $group[0]
            break
        }
    }

    if (-not $selectedPath) {
        throw 'Could not resolve a usable Copilot CLI path.'
    }

    $selectedDir = Split-Path $selectedPath -Parent
    $loaderPath = Join-Path $selectedDir 'node_modules\@github\copilot\npm-loader.js'
    if (-not (Test-Path $loaderPath)) {
        $loaderPath = Join-Path $selectedDir 'node_modules/@github/copilot/npm-loader.js'
    }

    if (Test-Path $loaderPath) {
        $localNodeWindows = Join-Path $selectedDir 'node.exe'
        $localNodePosix = Join-Path $selectedDir 'node'

        $nodePath = if (Test-Path $localNodeWindows) {
            $localNodeWindows
        } elseif (Test-Path $localNodePosix) {
            $localNodePosix
        } else {
            Resolve-CommandPath 'node'
        }

        return [pscustomobject]@{
            FileName = $nodePath
            ArgumentList = @($loaderPath) + $CopilotArguments
        }
    }

    $extension = [System.IO.Path]::GetExtension($selectedPath)
    if ($extension.Equals('.ps1', [System.StringComparison]::OrdinalIgnoreCase)) {
        return [pscustomobject]@{
            FileName = Resolve-CommandPath 'pwsh'
            ArgumentList = @('-NoLogo', '-NoProfile', '-File', $selectedPath) + $CopilotArguments
        }
    }

    return [pscustomobject]@{
        FileName = $selectedPath
        ArgumentList = $CopilotArguments
    }
}

function Assert-CleanWorkingTree {
    param(
        [string]$Context,
        [string]$RepoPath = (Get-Location).Path
    )

    $statusOutput = git -C $RepoPath status --porcelain
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        throw "git status failed while $Context in $RepoPath"
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

function Invoke-CopilotTask {
    param(
        [string]$Prompt,
        [int]$TimeoutSeconds,
        [string]$WorkingDirectory,
        [string]$ModelName,
        [string]$ReasoningEffortLevel
    )

    $copilotArguments = @('-p', $Prompt, '--model', $ModelName, '--effort', $ReasoningEffortLevel, '--autopilot', '--allow-all', '--no-ask-user', '--max-autopilot-continues', '5', '-s')
    $copilotLaunchSpec = Resolve-CopilotLaunchSpec -CopilotArguments $copilotArguments

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    $startInfo.FileName = $copilotLaunchSpec.FileName
    foreach ($argument in $copilotLaunchSpec.ArgumentList) {
        $null = $startInfo.ArgumentList.Add($argument)
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo

    try {
        if (-not $process.Start()) {
            throw 'Failed to start Copilot CLI process.'
        }

        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()

        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $nextHeartbeatSeconds = 30
        $timedOut = $false

        while (-not $process.WaitForExit(1000)) {
            $elapsedSeconds = [int][Math]::Floor($stopwatch.Elapsed.TotalSeconds)

            if ($elapsedSeconds -ge $TimeoutSeconds) {
                $timedOut = $true
                break
            }

            if ($elapsedSeconds -ge $nextHeartbeatSeconds) {
                Write-Host "  Still running... ${elapsedSeconds}s elapsed" -ForegroundColor DarkGray
                $nextHeartbeatSeconds += 30
            }
        }

        if ($timedOut) {
            try {
                $process.Kill($true)
            } catch {
                Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            }

            $null = $process.WaitForExit()
        } else {
            $null = $process.WaitForExit()
        }

        $stdoutText = $stdoutTask.GetAwaiter().GetResult()
        $stderrText = $stderrTask.GetAwaiter().GetResult()

        $stdoutLines = if ($stdoutText) { @($stdoutText -split "`r?`n" | Where-Object { $_ -ne '' }) } else { @() }
        $stderrLines = if ($stderrText) { @($stderrText -split "`r?`n" | Where-Object { $_ -ne '' }) } else { @() }

        return [pscustomobject]@{
            ExitCode = if ($timedOut) { -1 } else { $process.ExitCode }
            TimedOut = $timedOut
            ElapsedSeconds = [int][Math]::Floor($stopwatch.Elapsed.TotalSeconds)
            StdOut = @($stdoutLines)
            StdErr = @($stderrLines)
        }
    } finally {
        $process.Dispose()
    }
}

# ── Main loop ────────────────────────────────────────────────────────────────

Assert-CommandAvailable git

$taskCount = 0
$repoRoot = (Get-Location).Path

# Dry-run: list all tasks at once and exit
if ($DryRun) {
    $taskContext = Get-TaskContext -Lines (Get-Content TODO.md)
    $allTasks = @($taskContext.Tasks)
    if ($allTasks.Count -eq 0) {
        Write-Host "`n✓ No unchecked tasks found." -ForegroundColor Green
    } else {
        $cap = [Math]::Min($allTasks.Count, $MaxTasks)
        $sectionLabel = if ($taskContext.Section) { $taskContext.Section.Heading } else { 'auto-detect' }
        Write-Host "`n── Dry run: $($allTasks.Count) actionable task(s) found in $sectionLabel (cap: $MaxTasks) ──" -ForegroundColor Cyan
        for ($i = 0; $i -lt $cap; $i++) {
            Write-Host "  $($i + 1). $(Get-TaskSummary $allTasks[$i])" -ForegroundColor Yellow
        }
        if ($allTasks.Count -gt $MaxTasks) {
            Write-Host "  … and $($allTasks.Count - $MaxTasks) more beyond the cap" -ForegroundColor DarkGray
        }
    }
    return
}

Assert-CommandAvailable copilot
$primaryStatusAtStart = Get-WorkingTreeStatus -RepoPath $repoRoot
if ($primaryStatusAtStart.Count -gt 0) {
    Write-Host '  ! Primary worktree is already dirty. Tasks will run in disposable worktrees, but completed commits will be preserved for manual inspection instead of being applied automatically.' -ForegroundColor Yellow
    foreach ($line in $primaryStatusAtStart) {
        Write-Host "    $line" -ForegroundColor Yellow
    }
}

while ($taskCount -lt $MaxTasks) {
    $task = Get-NextTask
    if (-not $task) {
        Write-Host "`n✓ No more actionable tasks. Loop complete." -ForegroundColor Green
        break
    }

    $taskCount++
    Write-Host "`n── Task $taskCount ──────────────────────────────────────" -ForegroundColor Cyan
    Write-Host "  $(Get-TaskSummary $task)" -ForegroundColor Yellow

    $staleTaskWarnings = @(Get-LikelyStaleTaskWarnings -RepoPath $repoRoot -Task $task)
    if ($staleTaskWarnings.Count -gt 0) {
        Write-Host '  ! Recent commit subjects overlap strongly with this TODO item. Review before rerunning if the queue may be stale.' -ForegroundColor Yellow
        foreach ($warning in $staleTaskWarnings) {
            Write-Host "    $($warning.Commit)" -ForegroundColor Yellow
            Write-Host "      matched: $($warning.MatchedTokens -join ', ')" -ForegroundColor DarkYellow
        }
    }

    $commitBefore = Get-HeadCommit -RepoPath $repoRoot
    $todoBefore = Get-TodoText
    $worktreePath = $null
    $keepWorktree = $false

    # Build the prompt. The agent sees the repo, reads the workflow files,
    # does the task, and commits.
    $prompt = @"
You are working in the repo at the current directory.

Read .github/copilot-instructions.md for workflow rules.

Your ONE task:
$(Get-TaskSummary $task)

Task source:
$(Get-TaskSourceSummary $task)

Execution rules:
1. Keep planning short. After the initial repo read, move quickly to one concrete code or doc change.
2. If the task is broad, choose the smallest coherent slice that advances it safely and can be committed on its own.
3. If you have not edited a file after the initial investigation, narrow the task yourself to one specific sub-change and implement that.
4. Do not do a full repo audit or a full build before the first edit. Inspect only the files needed for this slice.
5. Run targeted validation after making the change. Use broad repo-wide validation only if the files you changed clearly require it.
6. If search hints are provided in the task source, start by searching for one of them instead of doing a broad repo scan.

After completing the task:
1. Stage and commit the changes. If the task text does not specify a commit message, choose one that follows the repo's commit message rules.
2. If you fully complete the task, you may leave TODO bookkeeping to the scheduler.
3. If the task is too large for one safe commit, complete one clearly scoped slice, update TODO.md to reflect the remaining work, and stop after that one commit.
4. Do not mark a task done unless it is truly complete.
5. Do NOT move on to other tasks — stop after that one commit.
"@

    try {
        $worktreePath = New-TemporaryWorktree -RepoPath $repoRoot
        $worktreeHeadBefore = Get-HeadCommit -RepoPath $worktreePath

        Write-Host "  Using temporary worktree: $worktreePath" -ForegroundColor DarkGray
        Write-Host "  Invoking Copilot CLI..." -ForegroundColor DarkGray

        # Invoke Copilot CLI in non-interactive autopilot mode.
        # --autopilot:              no human in the loop
        # --allow-all:              don't prompt for file/tool permissions
        # --no-ask-user:            don't block waiting for human input
        # --max-autopilot-continues 5: safety cap on continuation rounds
        # -p:                       non-interactive prompt (exits when done)
        # -s:                       silent (agent response only, no UI chrome)
        $copilotResult = Invoke-CopilotTask -Prompt $prompt -TimeoutSeconds $TaskTimeoutSeconds -WorkingDirectory $worktreePath -ModelName $Model -ReasoningEffortLevel $ReasoningEffort

        foreach ($line in $copilotResult.StdOut) {
            Write-Host "  $line"
        }

        foreach ($line in $copilotResult.StdErr) {
            Write-Host "  $line"
        }

        $exitCode = $copilotResult.ExitCode
        $worktreeHeadAfter = Get-HeadCommit -RepoPath $worktreePath
        $worktreeCommitCount = if ($worktreeHeadBefore -eq $worktreeHeadAfter) {
            0
        } else {
            Get-CommitCountBetween -RepoPath $worktreePath -BaseCommit $worktreeHeadBefore -HeadCommit $worktreeHeadAfter
        }

        if ($copilotResult.TimedOut) {
            Write-Host "  ✗ Copilot timed out after $($copilotResult.ElapsedSeconds)s. Stopping." -ForegroundColor Red
            if ($worktreeCommitCount -gt 0) {
                Write-Host "  Worktree contains unmerged commit(s):" -ForegroundColor Yellow
                foreach ($line in (Get-CommitSummariesBetween -RepoPath $worktreePath -BaseCommit $worktreeHeadBefore -HeadCommit $worktreeHeadAfter)) {
                    Write-Host "    $line" -ForegroundColor Yellow
                }
            }

            $statusAfterTimeout = Get-WorkingTreeStatus -RepoPath $worktreePath
            if ($statusAfterTimeout.Count -gt 0) {
                $keepWorktree = $true
                Write-Host "  Partial changes remain in preserved worktree:" -ForegroundColor Red
                foreach ($line in $statusAfterTimeout) {
                    Write-Host "    $line" -ForegroundColor Red
                }
                Write-Host "  Preserved worktree: $worktreePath" -ForegroundColor Yellow
            }

            break
        }

        if ($exitCode -ne 0) {
            Write-Host "  ✗ Copilot exited with code $exitCode. Stopping." -ForegroundColor Red
            if ($worktreeCommitCount -gt 0) {
                $keepWorktree = $true
                Write-Host "  Worktree contains unmerged commit(s):" -ForegroundColor Yellow
                foreach ($line in (Get-CommitSummariesBetween -RepoPath $worktreePath -BaseCommit $worktreeHeadBefore -HeadCommit $worktreeHeadAfter)) {
                    Write-Host "    $line" -ForegroundColor Yellow
                }
                Write-Host "  Preserved worktree: $worktreePath" -ForegroundColor Yellow
            }
            break
        }

        if ($worktreeCommitCount -eq 0) {
            Write-Host "  ✗ No new commit detected. Task may have failed. Stopping." -ForegroundColor Red
            $statusWithoutCommit = Get-WorkingTreeStatus -RepoPath $worktreePath
            if ($statusWithoutCommit.Count -gt 0) {
                $keepWorktree = $true
                Write-Host "  Partial changes remain in preserved worktree:" -ForegroundColor Red
                foreach ($line in $statusWithoutCommit) {
                    Write-Host "    $line" -ForegroundColor Red
                }
                Write-Host "  Preserved worktree: $worktreePath" -ForegroundColor Yellow
            }
            break
        }

        if ($worktreeCommitCount -gt 1) {
            $keepWorktree = $true
            Write-Host "  ✗ Expected one worker commit, found $worktreeCommitCount. Preserving worktree." -ForegroundColor Red
            foreach ($line in (Get-CommitSummariesBetween -RepoPath $worktreePath -BaseCommit $worktreeHeadBefore -HeadCommit $worktreeHeadAfter)) {
                Write-Host "    $line" -ForegroundColor Yellow
            }
            Write-Host "  Preserved worktree: $worktreePath" -ForegroundColor Yellow
            break
        }

        $primaryStatusBeforeApply = Get-WorkingTreeStatus -RepoPath $repoRoot
        if ($primaryStatusBeforeApply.Count -gt 0) {
            $keepWorktree = $true
            Write-Host '  ! Primary worktree is dirty; skipping automatic cherry-pick and TODO bookkeeping.' -ForegroundColor Yellow
            foreach ($line in $primaryStatusBeforeApply) {
                Write-Host "    $line" -ForegroundColor Yellow
            }
            Write-Host "  Worker commit to inspect manually: $worktreeHeadAfter" -ForegroundColor Yellow
            Write-Host "  Preserved worktree: $worktreePath" -ForegroundColor Yellow
            break
        }

        Write-Host "  Cherry-picking worker commit into primary worktree..." -ForegroundColor DarkGray
        git cherry-pick $worktreeHeadAfter | Out-Null
        if ($LASTEXITCODE -ne 0) {
            git cherry-pick --abort | Out-Null
            $keepWorktree = $true
            Write-Host '  ✗ Cherry-pick failed. Preserving worker worktree for inspection.' -ForegroundColor Red
            Write-Host "  Preserved worktree: $worktreePath" -ForegroundColor Yellow
            break
        }

        $commitAfter = Get-HeadCommit -RepoPath $repoRoot

        $primaryStatusBeforeBookkeeping = Get-WorkingTreeStatus -RepoPath $repoRoot
        if ($primaryStatusBeforeBookkeeping.Count -gt 0) {
            Write-Host '  ! Primary worktree became dirty before scheduler bookkeeping. Leaving TODO state untouched.' -ForegroundColor Yellow
            foreach ($line in $primaryStatusBeforeBookkeeping) {
                Write-Host "    $line" -ForegroundColor Yellow
            }
            Write-Host "  ✓ New commit: $commitAfter" -ForegroundColor Green
            break
        }

        $todoAfter = Get-TodoText
        $workerUpdatedTodo = $todoAfter -ne $todoBefore

        if ($workerUpdatedTodo) {
            if (Test-TaskStillPending $task) {
                Write-Host "  ! TODO.md changed during the worker commit, but the same task still appears actionable." -ForegroundColor Yellow
                Write-Host "  ! Scheduler is leaving TODO state untouched to avoid clobbering worker-authored task decomposition." -ForegroundColor Yellow
            } else {
                Write-Host "  ✓ TODO state updated by worker; skipping scheduler bookkeeping." -ForegroundColor Green
            }
        } else {
            # Mark the task done in TODO.md (scheduler owns TODO bookkeeping by default)
            Mark-TaskDone $task
            $bookkeepingCommit = Commit-Bookkeeping (Get-TaskSummary $task)
            Write-Host "  ✓ Task marked done in TODO.md" -ForegroundColor Green
            Write-Host "  ✓ Bookkeeping commit: $bookkeepingCommit" -ForegroundColor Green
        }

        Write-Host "  ✓ New commit: $commitAfter" -ForegroundColor Green
    } finally {
        if ($worktreePath -and -not $keepWorktree) {
            try {
                Remove-TemporaryWorktree -RepoPath $repoRoot -WorktreePath $worktreePath
            } catch {
                Write-Host "  ! Failed to remove temporary worktree $worktreePath" -ForegroundColor Yellow
                Write-Host "  ! $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }
}

Write-Host "`n── Summary ──────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "  Tasks attempted: $taskCount"
Write-Host "  HEAD is now: $(Get-HeadCommit -RepoPath $repoRoot)"
$logCount = $taskCount + 2
$recentLog = git log --oneline -$logCount
foreach ($line in $recentLog) {
    Write-Host "  $line"
}
