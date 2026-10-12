<#
.SYNOPSIS
  Agent-loop scheduler: feeds the selected worker CLI one TODO item at a time.

.DESCRIPTION
    Reads TODO.md, finds the next actionable item under the configured or auto-detected
    task heading, builds a prompt, invokes the selected worker CLI in non-interactive mode,
    and checks whether a new commit appeared. Repeats until no actionable tasks remain
    or a failure is detected.

.PARAMETER MaxTasks
  Safety cap on how many tasks to process in one run. Default: 10.

.PARAMETER DryRun
  Parse and display tasks without invoking the worker CLI.

.PARAMETER TaskTimeoutSeconds
    Maximum runtime for one worker task before the scheduler kills it and stops.

.PARAMETER Model
    AI model passed through to the worker CLI. Default: gpt-5.4 for Copilot.
    Codex runs ignore Copilot-style gpt-5.4 model names and use the local Codex
    default unless a Codex-compatible model name is provided.

.PARAMETER Agent
    Worker CLI to launch. Auto picks Codex when the scheduler is launched from a
    Codex environment, otherwise Copilot.

.PARAMETER ReasoningEffort
    Copilot CLI reasoning effort level. Default: low.

.PARAMETER UseTierDispatch
    Parse the [H] / [S] / [L] / [X] tier tag from each task's text and dispatch
    each task to the matching model + reasoning effort instead of using a single
    pair for the whole batch. [X] tasks (subagent / no model) are skipped so they
    can be run separately as validation. -Model and -ReasoningEffort act as the
    fallback when a task carries no tier tag.

.PARAMETER TaskSection
    The heading that marks the task section in TODO.md. Default: auto-detect from
    common workflow headings.

.PARAMETER OnFailure
    What to do when a task fails (timeout, non-zero exit, no commit, cherry-pick
    conflict). 'stop' halts the loop (default, current behaviour). 'skip' logs
    the failure and moves to the next task.

.PARAMETER MaxContinues
    Safety cap on Copilot CLI continuation rounds per task (--max-autopilot-continues).
    Codex does not expose the same continuation flag, so this is Copilot-only.
    Default: 5. Raise for complex tasks that need more agent turns.

.PARAMETER Workflow
    Todo: read unchecked items from TODO.md (legacy scheduler).
    SpecKit: drive the active spec package(s) from docs/specs.md through implement,
    In versioned repositories, drive catalog packages with active lifecycle and
    owner-cleared entry/task gates. Legacy SpecKit display routing is retained.

.PARAMETER MaxSpecs
    SpecKit only. Cap how many in-progress spec packages to process (0 = no cap).

.PARAMETER MaxAddressRounds
    SpecKit only. How many address-review invocations to attempt per spec after the
    adversarial review (default: 3).

.NOTES
  Prerequisites:
    - Worker CLI installed: codex for Codex launches, or copilot for Copilot launches
    - GitHub auth: gh auth login --web -h github.com
    - PowerShell 7+ available as `pwsh` on macOS, Ubuntu, and Windows
    - Start from a clean git working tree for real runs; the script aborts if the repo is dirty
#>

param(
    [int]$MaxTasks = 10,
    [switch]$DryRun,
    [int]$TaskTimeoutSeconds = 900,
    [ValidateSet('Auto', 'Copilot', 'Codex')]
    [string]$Agent = 'Auto',
    [string]$Model = 'gpt-5.4',
    [ValidateSet('low', 'medium', 'high', 'xhigh')]
    [string]$ReasoningEffort = 'low',
    [switch]$UseTierDispatch,
    [string]$TaskSection = 'auto',
    [ValidateSet('stop', 'skip')]
    [string]$OnFailure = 'stop',
    [int]$MaxContinues = 5,
    [ValidateSet('Todo', 'SpecKit')]
    [string]$Workflow = 'Todo',
    [int]$MaxSpecs = 0,
    [int]$MaxAddressRounds = 3,
    [string]$RepoRoot = $PWD
)

# Tier -> (model, reasoning effort). Effort = $null means do not pass --effort
# (Claude models reject --effort; reasoning is implicit). [X] is intentionally
# skipped so subagent / validation tasks don't burn a worker CLI invocation.
#
# Preferred targets (when Copilot CLI exposes them) per the kit's model-preference
# rules owned here (other surfaces link to this table):
#   [H] -> claude-opus-4.7 (7.5x; not in CLI as of 2026-04-28) or gpt-5.5 (7.5x; not in CLI as of 2026-04-28)
#   [S] -> gpt-5.4 (1x)
#   [L] -> gpt-5.4-mini (0.33x) or claude-haiku-4.5 (0.33x)
# Until the heavy-tier premium models appear in the CLI, [H] uses gpt-5.4 + xhigh
# effort (closest available step up from [S]). Avoid claude-opus-4.5 / sonnet-4.5
# / sonnet-4.6: same 1x cost as gpt-5.4, measurably weaker output per the user.
$TierDispatchMap = @{
    'H' = @{ Model = 'gpt-5.4'; Effort = 'xhigh' }
    'S' = @{ Model = 'gpt-5.4'; Effort = 'high' }
    'L' = @{ Model = 'gpt-5.4-mini'; Effort = $null }
    'X' = @{ Model = $null; Effort = $null; Skip = $true }
}

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/workflow-model.ps1"
. "$PSScriptRoot/workflow-scheduler.ps1"
Set-Location $RepoRoot

function Resolve-WorkerAgent {
    param([string]$RequestedAgent)

    if ($RequestedAgent -eq 'Codex') {
        return 'Codex'
    }
    if ($RequestedAgent -eq 'Copilot') {
        return 'Copilot'
    }

    $codexLaunched = (
        $env:CODEX_THREAD_ID -or
        $env:CODEX_CI -or
        $env:CODEX_INTERNAL_ORIGINATOR_OVERRIDE
    )

    if ($codexLaunched) {
        return 'Codex'
    }

    return 'Copilot'
}

$WorkerAgent = Resolve-WorkerAgent -RequestedAgent $Agent

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

# -- Helpers -----------------------------------------------------------------

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
                    if ($step) { "$step - $($summaryParts.NextAction)" } else { $summaryParts.NextAction }
                } elseif ($step) {
                    "$step - $summary"
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

function Get-TaskTier {
    param($Task)

    $sourceTexts = Get-TaskSourceTexts -Task $Task
    foreach ($sourceText in $sourceTexts) {
        $match = [regex]::Match($sourceText, '`?\[([HSLX])\]`?')
        if ($match.Success) {
            return $match.Groups[1].Value.ToUpperInvariant()
        }
    }

    return $null
}

function Resolve-TaskDispatch {
    param(
        $Task,
        [string]$DefaultModel,
        [string]$DefaultEffort
    )

    if (-not $UseTierDispatch) {
        return [pscustomobject]@{
            Tier  = (Get-TaskTier -Task $Task)
            Model = $DefaultModel
            Effort = $DefaultEffort
            Skip  = $false
            Reason = 'tier-dispatch off; using -Model / -ReasoningEffort'
        }
    }

    $tier = Get-TaskTier -Task $Task
    if (-not $tier) {
        return [pscustomobject]@{
            Tier  = $null
            Model = $DefaultModel
            Effort = $DefaultEffort
            Skip  = $false
            Reason = 'no tier tag; falling back to -Model / -ReasoningEffort'
        }
    }

    $entry = $TierDispatchMap[$tier]
    if (-not $entry) {
        return [pscustomobject]@{
            Tier  = $tier
            Model = $DefaultModel
            Effort = $DefaultEffort
            Skip  = $false
            Reason = "tier [$tier] not in dispatch map; using fallback"
        }
    }

    if ($entry.ContainsKey('Skip') -and $entry.Skip) {
        return [pscustomobject]@{
            Tier  = $tier
            Model = $null
            Effort = $null
            Skip  = $true
            Reason = "tier [$tier] is subagent / no-model; skipping"
        }
    }

    return [pscustomobject]@{
        Tier  = $tier
        Model = $entry.Model
        Effort = $entry.Effort
        Skip  = $false
        Reason = if ($entry.Effort) { "tier [$tier] -> $($entry.Model) / $($entry.Effort)" } else { "tier [$tier] -> $($entry.Model) (no --effort)" }
    }
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
    param([int[]]$ExcludeLineIndices = @())

    $taskContext = Get-TaskContext -Lines (Get-Content TODO.md)
    foreach ($candidate in $taskContext.Tasks) {
        if ($candidate.LineIndex -notin $ExcludeLineIndices) {
            return $candidate
        }
    }

    return $null
}

function Get-SpecPackageFromBranch {
    param([string]$RepoPath)

    $branch = git -C $RepoPath rev-parse --abbrev-ref HEAD 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $branch) {
        return $null
    }

    if ($branch -match '^feat/(?<id>\d{3})-(?<slug>[A-Za-z0-9-]+)$') {
        $relativePath = "specs/$($Matches.id)-$($Matches.slug)"
        $absolutePath = Join-Path $RepoPath $relativePath
        if (Test-Path -LiteralPath $absolutePath) {
            return [pscustomobject]@{
                Id = $Matches.id
                Slug = $Matches.slug
                RelativePath = $relativePath
                AbsolutePath = $absolutePath
                Branch = $branch
                Source = 'current-branch'
            }
        }
    }

    return $null
}

function Get-InProgressSpecPackagesFromIndex {
    param([string]$RepoPath)

    $specsIndexPath = Join-Path $RepoPath 'docs/specs.md'
    if (-not (Test-Path -LiteralPath $specsIndexPath)) {
        return @()
    }

    $packages = [System.Collections.Generic.List[object]]::new()
    foreach ($line in Get-Content -LiteralPath $specsIndexPath) {
        if ($line -notmatch '^\|\s*(?<label>\d{3}\s+[^|]+)\|\s*`(?<path>specs/\d{3}-[^`/]+)/`\s*\|\s*(?<status>In Progress)\s*\|') {
            continue
        }

        $relativePath = $Matches.path.TrimEnd('/')
        $label = $Matches.label.Trim()
        $absolutePath = Join-Path $RepoPath $relativePath
        if (-not (Test-Path -LiteralPath $absolutePath)) {
            continue
        }

        $idSlug = Split-Path $relativePath -Leaf
        if ($idSlug -notmatch '^(?<id>\d{3})-(?<slug>.+)$') {
            continue
        }

        $packages.Add([pscustomobject]@{
            Id = $Matches.id
            Slug = $Matches.slug
            RelativePath = $relativePath
            AbsolutePath = $absolutePath
            Branch = "feat/$idSlug"
            Label = $label
            Source = 'docs/specs.md'
        }) | Out-Null
    }

    return @($packages | Sort-Object { [int]$_.Id })
}

function Test-SpecPackageIndexedInProgress {
    param(
        [string]$RepoPath,
        $SpecPackage
    )

    foreach ($spec in Get-InProgressSpecPackagesFromIndex -RepoPath $RepoPath) {
        if ($spec.RelativePath -ieq $SpecPackage.RelativePath) {
            return $true
        }
    }

    return $false
}

function Get-SpecKitWorkQueue {
    param([string]$RepoPath)

    $queue = [System.Collections.Generic.List[object]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    $branchSpec = Get-SpecPackageFromBranch -RepoPath $RepoPath
    if ($branchSpec) {
        $branchUnchecked = @(Get-UncheckedSpecTasks -SpecPackage $branchSpec)
        $branchIndexedInProgress = Test-SpecPackageIndexedInProgress -RepoPath $RepoPath -SpecPackage $branchSpec
        if ($branchUnchecked.Count -gt 0 -or $branchIndexedInProgress) {
            $queue.Add($branchSpec) | Out-Null
            $null = $seen.Add($branchSpec.RelativePath)
        }
    }

    foreach ($spec in Get-InProgressSpecPackagesFromIndex -RepoPath $RepoPath) {
        if ($seen.Add($spec.RelativePath)) {
            $queue.Add($spec) | Out-Null
        }
    }

    if ($MaxSpecs -gt 0) {
        return @($queue | Select-Object -First $MaxSpecs)
    }

    return @($queue)
}

function Get-SpecTasksFilePath {
    param($SpecPackage)

    return Join-Path $SpecPackage.AbsolutePath 'tasks.md'
}

function Get-UncheckedSpecTasks {
    param($SpecPackage)

    $tasksPath = Get-SpecTasksFilePath -SpecPackage $SpecPackage
    if (-not (Test-Path -LiteralPath $tasksPath)) {
        return @()
    }

    $lines = @(Get-Content -LiteralPath $tasksPath)
    $tasks = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*-\s\[ \]\s+(.+)$') {
            $tasks += [pscustomobject]@{
                Kind = 'spec-checkbox'
                Text = $Matches[1]
                LineIndex = $i
                SpecPackage = $SpecPackage
                TasksPath = $tasksPath
            }
        }
    }

    return $tasks
}

function Test-SpecTasksComplete {
    param($SpecPackage)

    return (Get-UncheckedSpecTasks -SpecPackage $SpecPackage).Count -eq 0
}

function Get-NextUncheckedSpecTask {
    param($SpecPackage)

    $tasks = @(Get-UncheckedSpecTasks -SpecPackage $SpecPackage)
    if ($tasks.Count -eq 0) {
        return $null
    }

    return $tasks[0]
}

function Get-SpecKitPhaseLabel {
    param([ValidateSet('implement', 'adversarial-review', 'address-review')]
    [string]$Phase)

    switch ($Phase) {
        'implement' { return 'implement (spec-kit tasks)' }
        'adversarial-review' { return 'adversarial review' }
        'address-review' { return 'address review findings' }
    }
}

function Get-AdversarialReviewPromptPath {
    param([string]$RepoPath)

    $candidates = @(
        (Join-Path $RepoPath 'specs/ADVERSARIAL_REVIEW_PROMPT.md'),
        (Join-Path $RepoPath 'AGENT-INBOX.md')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    return $null
}

function Test-PackageReviewHasActiveFindings {
    param([string]$RepoPath, $SpecPackage)

    $inboxPath = Join-Path $RepoPath "$($SpecPackage.RelativePath)/reviews/agent-review.md"
    if (-not (Test-Path -LiteralPath $inboxPath)) {
        return $true
    }

    $content = Get-Content -LiteralPath $inboxPath -Raw
    return $content -notmatch '(?im)^[-* ]*\*?\*?Verdict\*?\*?:\s*\*?\*?accept\b' -or $content -match '(?m)^\s*- \[ \]'
}

function Build-SpecKitPrompt {
    param(
        $SpecPackage,
        [ValidateSet('implement', 'adversarial-review', 'address-review')]
        [string]$Phase,
        $Task = $null,
        [string]$RepoPath
    )

    $specDir = $SpecPackage.RelativePath
    $branch = $SpecPackage.Branch
    $config = Get-WorkflowConfig $RepoPath
    if ($config) {
        $taskLine = if ($Task) { $Task.Text } else { 'owner-requested review phase' }
        return @"
Read AGENTS.md, $specDir/spec.md and the bounded current-work header in $specDir/tasks.md.
Package: $specDir; scope: $($SpecPackage.Scope); integration branch: $branch; target/base: $($config.targetBranch).
Phase: $Phase. Focus: $taskLine.
This marked detached scratch worktree is authorized only for this package's task
and necessary kit implementation paths. Integrate only into $branch. Verify the
spec lifecycle, linked entry checkpoint and accepted verdict before work and at
scope changes. Stop before every uncleared gate; never clear owner checkpoints.
Implement only the focused task. Update its checkbox/current-work header after
validation and commit with an area prefix. No unrelated tasks or automatic reviews.
Preserve .workflow-kit.json, the task entry checkpoint, task IDs/order, and every
gate/manual annotation. These are owner declarations; task descriptions may change.
Existing files under reviews/ are owner records: do not modify, delete or rename
them. New worker notes may be unlabelled observations, but must not carry gate
labels: Verdict, Accepted scope, Checkpoint, Scope, Reviewer or Reviewed revision.
Owner-requested review requests/findings/dispositions belong in $specDir/reviews/;
workers cannot author their acceptance metadata. Preserve findings; transfer only
a recipient/scope/artifact/action link through the inbox.
No AGENTS handover or lifecycle edits, no SPECKIT markers, no root state files,
no network/push/installer/cross-repo operations without explicit owner instruction.
On incomplete work record the blocker in the task header and preserve all work.
"@
    }
    $rulesPath = if (Test-Path -LiteralPath (Join-Path $RepoPath 'AGENTS.md')) { 'AGENTS.md' } else { '.github/copilot-instructions.md' }
    $adversarialPath = Get-AdversarialReviewPromptPath -RepoPath $RepoPath
    $agentInboxPath = "$specDir/reviews/agent-review.md"

    $phaseBody = switch ($Phase) {
        'implement' {
            $taskLine = if ($Task) { $Task.Text } else { '(next unchecked item in tasks.md)' }
            @"
Phase: implement — work through the active spec-kit package until its tasks are complete.

Spec package: $specDir
Feature branch: $branch
Current unchecked task focus: $taskLine

Execution rules:
1. Read $rulesPath, $specDir/spec.md and $specDir/tasks.md.
2. This is an unattended overnight run. Do not stop after a single small commit if more unchecked tasks remain.
3. Implement the current unchecked task(s) in tasks.md. Mark a task [x] only when it is truly complete.
4. Continue through additional unchecked tasks in the same session when safe (--max-autopilot-continues is raised for this run).
5. Make logically grouped commits as you go; multiple commits are expected for a large spec.
6. Run targeted validation for the areas you change. Use the repo's declared validation commands when appropriate.
7. Update $specDir/tasks.md and its current-work header; never add an AGENTS handover.
8. Do not start unrelated specs, TODO.md side quests, or repo-wide audits.
9. If blocked, document the blocker in the package task header and stop with a clear explanation.
"@
        }
        'adversarial-review' {
            $reviewSource = if ($adversarialPath) { $adversarialPath } else { 'a fresh adversarial review of the branch changes for this spec' }
            @"
Phase: adversarial review — after implementation tasks are complete for this spec package.

Spec package: $specDir
Feature branch: $branch

Execution rules:
1. Read $rulesPath, $specDir/spec.md, $specDir/tasks.md, and $reviewSource.
2. Perform a skeptical adversarial review of the work done for this spec on the current branch.
3. Save a separate request and findings in $specDir/reviews/, naming scope, reviewed revision, actual reviewer, verdict and actionable findings.
4. Write complete findings to $agentInboxPath; the root inbox may hold only a transient recipient/scope/artifact/action link.
5. Do not implement fixes in this phase unless a trivial doc correction is required to record the review.
6. Commit only the review write-up ($agentInboxPath and any spec/task note updates needed to record review state).
"@
        }
        'address-review' {
            @"
Phase: address review — fix or explicitly defer findings from the adversarial review.

Spec package: $specDir
Feature branch: $branch

Execution rules:
1. Read the package's $agentInboxPath and treat unresolved findings as the work queue.
2. Fix the highest-priority actionable items with code/tests/docs changes as appropriate.
3. Preserve all findings and record per-finding dispositions beside them; never clear owner checkpoints.
4. Update $specDir/tasks.md if the review reopened work; do not falsely close the spec.
5. Make one or more commits with real fixes. Continue within this session while active findings remain and you can make safe progress.
6. Run targeted validation for changed areas.
"@
        }
    }

    return @"
You are working in the repo at the current directory.

Read $rulesPath for workflow rules.

$phaseBody

After completing this phase's work:
1. Stage and commit your changes with messages that follow the repo's commit rules.
2. Do not switch to a different spec package or unrelated TODO work.
"@
}

function Invoke-SpecKitWorkerPhase {
    param(
        $SpecPackage,
        [ValidateSet('implement', 'adversarial-review', 'address-review')]
        [string]$Phase,
        $Task,
        [string]$RepoPath,
        [ref]$InvocationCount,
        [ref]$SkippedLineIndices,
        [string]$DefaultModel,
        [string]$DefaultEffort
    )

    $phaseLabel = Get-SpecKitPhaseLabel -Phase $Phase
    Write-Host "`n-- $($SpecPackage.RelativePath): $phaseLabel ----------------" -ForegroundColor Cyan
    if ($Task) {
        Write-Host "  $($Task.Text)" -ForegroundColor Yellow
    }

    $dispatch = if ($Task) {
        Resolve-TaskDispatch -Task $Task -DefaultModel $DefaultModel -DefaultEffort $DefaultEffort
    } else {
        [pscustomobject]@{
            Tier = $null
            Model = $DefaultModel
            Effort = $DefaultEffort
            Skip = $false
            Reason = 'spec-kit phase dispatch'
        }
    }

    Write-Host "  Dispatch: $($dispatch.Reason)" -ForegroundColor DarkCyan
    if ($dispatch.Skip) {
        Write-Host '  Skipping this invocation (tier dispatch marked skip).' -ForegroundColor Yellow
        return [pscustomobject]@{ Status = 'skipped'; KeepWorktree = $false; WorktreePath = $null }
    }

    $prompt = Build-SpecKitPrompt -SpecPackage $SpecPackage -Phase $Phase -Task $Task -RepoPath $RepoPath
    $commitBefore = Get-HeadCommit -RepoPath $RepoPath
    $worktreePath = $null
    $keepWorktree = $false

    try {
        $worktreePath = New-TemporaryWorktree -RepoPath $RepoPath
        $worktreeHeadBefore = Get-HeadCommit -RepoPath $worktreePath

        Write-Host "  Using temporary worktree: $worktreePath" -ForegroundColor DarkGray
        Write-Host "  Invoking $WorkerAgent CLI..." -ForegroundColor DarkGray

        if (Get-WorkflowConfig $RepoPath) {
            $null = Assert-WorkflowPreflight $worktreePath
            $scratchPackage = Select-WorkflowPackage $worktreePath $SpecPackage.RelativePath
            if ($scratchPackage.Scope -ne $SpecPackage.Scope -or $scratchPackage.Lifecycle -ne 'active') { throw 'worker-incomplete: scratch scope/lifecycle changed before dispatch.' }
            $problem = Get-WorkflowGateProblem $scratchPackage $Task.Gate
            if ($problem) { throw "worker-incomplete: $problem" }
        }

        $copilotResult = Invoke-AgentTask -Prompt $prompt -TimeoutSeconds $TaskTimeoutSeconds -WorkingDirectory $worktreePath -ModelName $dispatch.Model -ReasoningEffortLevel $dispatch.Effort

        foreach ($line in $copilotResult.StdOut) { Write-Host "  $line" }
        foreach ($line in $copilotResult.StdErr) { Write-Host "  $line" }

        $worktreeHeadAfter = Get-HeadCommit -RepoPath $worktreePath
        $worktreeCommitCount = if ($worktreeHeadBefore -eq $worktreeHeadAfter) {
            0
        } else {
            Get-CommitCountBetween -RepoPath $worktreePath -BaseCommit $worktreeHeadBefore -HeadCommit $worktreeHeadAfter
        }

        $keepWorktree = Test-WorkflowScratchHasWork $worktreePath $worktreeHeadBefore
        if ($copilotResult.TimedOut) {
            Write-Host "  [x] $WorkerAgent timed out after $($copilotResult.ElapsedSeconds)s." -ForegroundColor Red
            if ($worktreeCommitCount -gt 0) { $keepWorktree = $true }
            if ($OnFailure -eq 'skip') { return [pscustomobject]@{ Status = 'failed-continue'; KeepWorktree = $keepWorktree; WorktreePath = $worktreePath } }
            return [pscustomobject]@{ Status = 'failed-stop'; KeepWorktree = $keepWorktree; WorktreePath = $worktreePath }
        }

        if ($copilotResult.ExitCode -ne 0) {
            Write-Host "  [x] $WorkerAgent exited with code $($copilotResult.ExitCode)." -ForegroundColor Red
            if ($worktreeCommitCount -gt 0) { $keepWorktree = $true }
            if ($OnFailure -eq 'skip') { return [pscustomobject]@{ Status = 'failed-continue'; KeepWorktree = $keepWorktree; WorktreePath = $worktreePath } }
            return [pscustomobject]@{ Status = 'failed-stop'; KeepWorktree = $keepWorktree; WorktreePath = $worktreePath }
        }

        if ($worktreeCommitCount -eq 0) {
            Write-Host '  [x] No new commit detected for this phase invocation.' -ForegroundColor Red
            $statusWithoutCommit = Get-WorkingTreeStatus -RepoPath $worktreePath
            if ($statusWithoutCommit.Count -gt 0) { $keepWorktree = $true }
            if ($OnFailure -eq 'skip') { return [pscustomobject]@{ Status = 'failed-continue'; KeepWorktree = $keepWorktree; WorktreePath = $worktreePath } }
            return [pscustomobject]@{ Status = 'failed-stop'; KeepWorktree = $keepWorktree; WorktreePath = $worktreePath }
        }

        $primaryStatusBeforeApply = Get-WorkingTreeStatus -RepoPath $RepoPath
        if ($primaryStatusBeforeApply.Count -gt 0) {
            $keepWorktree = $true
            Write-Host '  ! Primary worktree is dirty; skipping automatic cherry-pick.' -ForegroundColor Yellow
            return [pscustomobject]@{ Status = 'dirty-primary'; KeepWorktree = $keepWorktree; WorktreePath = $worktreePath }
        }

        if (Get-WorkflowConfig $RepoPath) {
            try {
                Assert-WorkflowWorkerRange -RepoPath $worktreePath -BaseCommit $worktreeHeadBefore -HeadCommit $worktreeHeadAfter -PackagePath $SpecPackage.RelativePath -TaskId $Task.Id
            } catch {
                $keepWorktree = $true
                Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
                return [pscustomobject]@{ Status = 'worker-incomplete'; KeepWorktree = $true; WorktreePath = $worktreePath; Reason = $_.Exception.Message }
            }
        }

        Write-Host '  Cherry-picking worker commit(s) into primary worktree...' -ForegroundColor DarkGray
        git -C $RepoPath cherry-pick "$worktreeHeadBefore..$worktreeHeadAfter" | Out-Null
        if ($LASTEXITCODE -ne 0) {
            git -C $RepoPath cherry-pick --abort | Out-Null
            $keepWorktree = $true
            Write-Host '  [x] Cherry-pick failed. Preserving worker worktree for inspection.' -ForegroundColor Red
            if ($OnFailure -eq 'skip') { return [pscustomobject]@{ Status = 'failed-continue'; KeepWorktree = $keepWorktree; WorktreePath = $worktreePath } }
            return [pscustomobject]@{ Status = 'failed-stop'; KeepWorktree = $keepWorktree; WorktreePath = $worktreePath }
        }

        $commitAfter = Get-HeadCommit -RepoPath $RepoPath
        Write-Host "  [ok] New commit: $commitAfter" -ForegroundColor Green
        $keepWorktree = $false
        return [pscustomobject]@{ Status = 'ok'; KeepWorktree = $false; WorktreePath = $worktreePath }
    } finally {
        if ($worktreePath -and -not $keepWorktree) {
            try {
                Remove-TemporaryWorktree -RepoPath $RepoPath -WorktreePath $worktreePath
            } catch {
                Write-Host "  ! Failed to remove temporary worktree $worktreePath" -ForegroundColor Yellow
            }
        } elseif ($worktreePath -and $keepWorktree) {
            Write-Host "  Preserved worktree: $worktreePath" -ForegroundColor Yellow
        }
    }
}

function Start-SpecKitScheduler {
    param([string]$RepoPath)

    if ($DryRun) {
        $queue = Get-SpecKitWorkQueue -RepoPath $RepoPath
        if ($queue.Count -eq 0) {
            Write-Host "`n[ok] No in-progress spec packages found (current feat/* branch or docs/specs.md)." -ForegroundColor Green
            return
        }

        Write-Host "`n-- Dry run: SpecKit overnight queue ($($queue.Count) package(s)) --" -ForegroundColor Cyan
        foreach ($spec in $queue) {
            $unchecked = @(Get-UncheckedSpecTasks -SpecPackage $spec)
            Write-Host "  $($spec.RelativePath) [$($spec.Source)] branch=$($spec.Branch) unchecked=$($unchecked.Count)" -ForegroundColor Yellow
            foreach ($task in $unchecked | Select-Object -First 5) {
                Write-Host "    - [ ] $($task.Text)" -ForegroundColor DarkYellow
            }
            if ($unchecked.Count -gt 5) {
                Write-Host "    ... and $($unchecked.Count - 5) more" -ForegroundColor DarkGray
            }
            Write-Host '    phases: implement -> adversarial-review -> address-review' -ForegroundColor DarkCyan
        }

        $capLabel = if ($MaxTasks -gt 0) { "$MaxTasks $WorkerAgent invocation(s)" } else { "unlimited $WorkerAgent invocations" }
        Write-Host "  Invocation cap: $capLabel" -ForegroundColor DarkGray
        Write-Host "  Worker agent: $WorkerAgent" -ForegroundColor DarkGray
        return
    }

    Assert-WorkerCommandAvailable
    Write-Host "`n-- SpecKit scheduler ------------------------------------" -ForegroundColor Cyan
    Write-Host "  Worker agent: $WorkerAgent" -ForegroundColor DarkGray

    $primaryStatusAtStart = Get-WorkingTreeStatus -RepoPath $RepoPath
    if ($primaryStatusAtStart.Count -gt 0) {
        Write-Host '  ! Primary worktree is already dirty. Tasks will run in disposable worktrees, but completed commits will be preserved for manual inspection instead of being applied automatically.' -ForegroundColor Yellow
    }

    $queue = Get-SpecKitWorkQueue -RepoPath $RepoPath
    if ($queue.Count -eq 0) {
        Write-Host "`n[ok] No in-progress spec packages found." -ForegroundColor Green
        return
    }

    $invocationCount = 0
    $stopAll = $false

    foreach ($spec in $queue) {
        if ($stopAll) { break }

        Write-Host "`n== Spec package: $($spec.RelativePath) ($($spec.Branch)) ==" -ForegroundColor Magenta

        git -C $RepoPath rev-parse --verify $spec.Branch 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            git -C $RepoPath checkout $spec.Branch | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "checkout-incomplete: could not checkout $($spec.Branch); no worker dispatched."
            }
        } else { throw "checkout-incomplete: branch $($spec.Branch) is missing." }

        while (-not (Test-SpecTasksComplete -SpecPackage $spec)) {
            $invocationCount++
            if ($MaxTasks -gt 0 -and $invocationCount -gt $MaxTasks) {
                Write-Host '  Invocation cap reached; stopping SpecKit scheduler.' -ForegroundColor Yellow
                $stopAll = $true
                break
            }

            $task = Get-NextUncheckedSpecTask -SpecPackage $spec
            $result = Invoke-SpecKitWorkerPhase -SpecPackage $spec -Phase 'implement' -Task $task -RepoPath $RepoPath -InvocationCount ([ref]$invocationCount) -SkippedLineIndices ([ref]$null) -DefaultModel $Model -DefaultEffort $ReasoningEffort
            if ($result.Status -eq 'failed-stop' -or $result.Status -eq 'dirty-primary') { $stopAll = $true; break }
        }

        if ($stopAll) { break }
        if (-not (Test-SpecTasksComplete -SpecPackage $spec)) {
            Write-Host '  ! Spec tasks still unchecked; skipping review phases for this package.' -ForegroundColor Yellow
            continue
        }

        Write-Host '  [ok] Spec tasks complete; running adversarial review.' -ForegroundColor Green

        foreach ($phase in @('adversarial-review')) {
            $invocationCount++
            if ($MaxTasks -gt 0 -and $invocationCount -gt $MaxTasks) { $stopAll = $true; break }
            $result = Invoke-SpecKitWorkerPhase -SpecPackage $spec -Phase $phase -Task $null -RepoPath $RepoPath -InvocationCount ([ref]$invocationCount) -SkippedLineIndices ([ref]$null) -DefaultModel $Model -DefaultEffort $ReasoningEffort
            if ($result.Status -eq 'failed-stop' -or $result.Status -eq 'dirty-primary') { $stopAll = $true; break }
        }

        if ($stopAll) { break }

        $null = Invoke-BoundedRemediation -MaxRounds $MaxAddressRounds -HasFindings {
            Test-PackageReviewHasActiveFindings -RepoPath $RepoPath -SpecPackage $spec
        } -RunRound {
            param($round)
            $invocationCount++
            if ($MaxTasks -gt 0 -and $invocationCount -gt $MaxTasks) { throw 'scheduler-incomplete: invocation cap with review findings remaining.' }
            Write-Host "  Address round $round / $MaxAddressRounds" -ForegroundColor DarkCyan
            $result = Invoke-SpecKitWorkerPhase -SpecPackage $spec -Phase 'address-review' -Task $null -RepoPath $RepoPath -InvocationCount ([ref]$invocationCount) -SkippedLineIndices ([ref]$null) -DefaultModel $Model -DefaultEffort $ReasoningEffort
            return $result.Status
        }
        Write-Host "  [ok] Finished legacy spec package $($spec.RelativePath)" -ForegroundColor Green
    }

    Write-Host "`n-- SpecKit summary -------------------------------------" -ForegroundColor Cyan
    Write-Host "  $WorkerAgent invocations: $invocationCount"
    Write-Host "  HEAD is now: $(Get-HeadCommit -RepoPath $RepoPath)"
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
    return New-WorkflowScratch -RepoPath $RepoPath
}

function Remove-TemporaryWorktree {
    param([string]$RepoPath, [string]$WorktreePath)
    Remove-WorkflowScratch -RepoPath $RepoPath -WorktreePath $WorktreePath
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

function Join-CommandArguments {
    param([string[]]$Arguments)

    $quoted = foreach ($argument in $Arguments) {
        if ($null -eq $argument) {
            '""'
            continue
        }

        if ($argument -match '[\s"]') {
            '"' + ($argument -replace '"', '\"') + '"'
        } else {
            $argument
        }
    }

    return ($quoted -join ' ')
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
        try {
            $hostPath = Resolve-CommandPath 'pwsh'
        } catch {
            $hostPath = Resolve-CommandPath 'powershell'
        }

        return [pscustomobject]@{
            FileName = $hostPath
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

    $copilotArguments = @('-p', $Prompt, '--model', $ModelName)
    if ($ReasoningEffortLevel) {
        $copilotArguments += @('--effort', $ReasoningEffortLevel)
    }
    $copilotArguments += @('--autopilot', '--allow-all', '--no-ask-user', '--max-autopilot-continues', "$MaxContinues", '-s')
    $copilotLaunchSpec = Resolve-CopilotLaunchSpec -CopilotArguments $copilotArguments

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    $startInfo.FileName = $copilotLaunchSpec.FileName
    if ($null -ne $startInfo.ArgumentList) {
        foreach ($argument in $copilotLaunchSpec.ArgumentList) {
            $null = $startInfo.ArgumentList.Add($argument)
        }
    } else {
        $startInfo.Arguments = Join-CommandArguments -Arguments $copilotLaunchSpec.ArgumentList
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

function Test-CodexCompatibleModel {
    param([string]$ModelName)

    if (-not $ModelName) {
        return $false
    }

    # gpt-5.4 / gpt-5.4-mini are Copilot model aliases. Let Codex use its
    # configured default unless the caller explicitly passes a Codex model name.
    return ($ModelName -notmatch '^gpt-5\.4')
}

function Invoke-CodexTask {
    param(
        [string]$Prompt,
        [int]$TimeoutSeconds,
        [string]$WorkingDirectory,
        [string]$ModelName,
        [string]$ReasoningEffortLevel
    )

    $codexArguments = @(
        'exec',
        '--cd', $WorkingDirectory,
        '--dangerously-bypass-approvals-and-sandbox',
        '--color', 'never'
    )
    if (Test-CodexCompatibleModel -ModelName $ModelName) {
        $codexArguments += @('--model', $ModelName)
    }
    $codexArguments += @($Prompt)

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.FileName = Resolve-CommandPath 'codex'

    if ($null -ne $startInfo.ArgumentList) {
        foreach ($argument in $codexArguments) {
            $null = $startInfo.ArgumentList.Add($argument)
        }
    } else {
        $startInfo.Arguments = Join-CommandArguments -Arguments $codexArguments
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo

    try {
        if (-not $process.Start()) {
            throw 'Failed to start Codex CLI process.'
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

function Assert-WorkerCommandAvailable {
    if ($WorkerAgent -eq 'Codex') {
        Assert-CommandAvailable codex
        return
    }

    Assert-CommandAvailable copilot
}

function Invoke-AgentTask {
    param(
        [string]$Prompt,
        [int]$TimeoutSeconds,
        [string]$WorkingDirectory,
        [string]$ModelName,
        [string]$ReasoningEffortLevel
    )

    if ($WorkerAgent -eq 'Codex') {
        return Invoke-CodexTask -Prompt $Prompt -TimeoutSeconds $TimeoutSeconds -WorkingDirectory $WorkingDirectory -ModelName $ModelName -ReasoningEffortLevel $ReasoningEffortLevel
    }

    return Invoke-CopilotTask -Prompt $Prompt -TimeoutSeconds $TimeoutSeconds -WorkingDirectory $WorkingDirectory -ModelName $ModelName -ReasoningEffortLevel $ReasoningEffortLevel
}

# -- Main loop ---------------------------------------------------------------

Assert-CommandAvailable git
Set-Location $RepoRoot
$repoRoot = (Get-Location).Path

$workflowConfig = Get-WorkflowConfig $repoRoot
if ($workflowConfig) {
    if ($PSBoundParameters.ContainsKey('Workflow') -and $Workflow -eq 'Todo') {
        throw 'workflow-incomplete: migrated repositories cannot execute the legacy TODO scheduler.'
    }
    if (-not $PSBoundParameters.ContainsKey('MaxTasks')) { $MaxTasks = 0 }
    Start-WorkflowScheduler -RepoPath $repoRoot -Config $workflowConfig
    return
}

if ($Workflow -eq 'SpecKit') {
    if (-not $PSBoundParameters.ContainsKey('MaxTasks')) { $MaxTasks = 0 }
    if (-not $PSBoundParameters.ContainsKey('MaxContinues')) { $MaxContinues = 25 }
    if (-not $PSBoundParameters.ContainsKey('TaskTimeoutSeconds')) { $TaskTimeoutSeconds = 3600 }
    if (-not $PSBoundParameters.ContainsKey('OnFailure')) { $OnFailure = 'skip' }
    Start-SpecKitScheduler -RepoPath $repoRoot
    return
}

$taskCount = 0

# Dry-run: list all tasks at once and exit
if ($DryRun) {
    $taskContext = Get-TaskContext -Lines (Get-Content TODO.md)
    $allTasks = @($taskContext.Tasks)
    if ($allTasks.Count -eq 0) {
        Write-Host "`n[ok] No unchecked tasks found." -ForegroundColor Green
    } else {
        $cap = [Math]::Min($allTasks.Count, $MaxTasks)
        $sectionLabel = if ($taskContext.Section) { $taskContext.Section.Heading } else { 'auto-detect' }
        $dispatchLabel = if ($UseTierDispatch) { 'tier dispatch ON' } else { 'tier dispatch OFF (single -Model/-ReasoningEffort)' }
        Write-Host "`n-- Dry run: $($allTasks.Count) actionable task(s) found in $sectionLabel (cap: $MaxTasks; $dispatchLabel) --" -ForegroundColor Cyan
        for ($i = 0; $i -lt $cap; $i++) {
            $dispatch = Resolve-TaskDispatch -Task $allTasks[$i] -DefaultModel $Model -DefaultEffort $ReasoningEffort
            $tierLabel = if ($dispatch.Tier) { "[$($dispatch.Tier)]" } else { '[?]' }
            $effortDisplay = if ($dispatch.Effort) { " / $($dispatch.Effort)" } else { '' }
            $routeLabel = if ($dispatch.Skip) { 'SKIP (subagent / validation)' } else { "$($dispatch.Model)$effortDisplay" }
            Write-Host "  $($i + 1). $tierLabel -> $routeLabel" -ForegroundColor DarkCyan
            Write-Host "     $(Get-TaskSummary $allTasks[$i])" -ForegroundColor Yellow
        }
        if ($allTasks.Count -gt $MaxTasks) {
            Write-Host "  ... and $($allTasks.Count - $MaxTasks) more beyond the cap" -ForegroundColor DarkGray
        }
    }
    return
}

Assert-WorkerCommandAvailable
$primaryStatusAtStart = Get-WorkingTreeStatus -RepoPath $repoRoot
if ($primaryStatusAtStart.Count -gt 0) {
    Write-Host '  ! Primary worktree is already dirty. Tasks will run in disposable worktrees, but completed commits will be preserved for manual inspection instead of being applied automatically.' -ForegroundColor Yellow
    foreach ($line in $primaryStatusAtStart) {
        Write-Host "    $line" -ForegroundColor Yellow
    }
}

$skippedLineIndices = @()

while ($taskCount -lt $MaxTasks) {
    $task = Get-NextTask -ExcludeLineIndices $skippedLineIndices
    if (-not $task) {
        Write-Host "`n[ok] No more actionable tasks. Loop complete." -ForegroundColor Green
        break
    }

    $taskCount++
    Write-Host "`n-- Task $taskCount --------------------------------------" -ForegroundColor Cyan
    Write-Host "  $(Get-TaskSummary $task)" -ForegroundColor Yellow

    $dispatch = Resolve-TaskDispatch -Task $task -DefaultModel $Model -DefaultEffort $ReasoningEffort
    Write-Host "  Dispatch: $($dispatch.Reason)" -ForegroundColor DarkCyan
    if ($dispatch.Skip) {
        Write-Host "  Skipping this task (no $WorkerAgent CLI invocation). Run it manually with the relevant subagent or validation command." -ForegroundColor Yellow
        continue
    }
    $taskModel = $dispatch.Model
    $taskEffort = $dispatch.Effort

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
5. Do NOT move on to other tasks - stop after that one commit.
"@

    try {
        $worktreePath = New-TemporaryWorktree -RepoPath $repoRoot
        $worktreeHeadBefore = Get-HeadCommit -RepoPath $worktreePath

        Write-Host "  Using temporary worktree: $worktreePath" -ForegroundColor DarkGray
        Write-Host "  Invoking $WorkerAgent CLI..." -ForegroundColor DarkGray

        # Invoke the selected worker CLI in non-interactive mode.
        # --autopilot:              no human in the loop
        # --allow-all:              don't prompt for file/tool permissions
        # --no-ask-user:            don't block waiting for human input
        # --max-autopilot-continues:   safety cap on continuation rounds
        # -p:                       non-interactive prompt (exits when done)
        # -s:                       silent (agent response only, no UI chrome)
        $copilotResult = Invoke-AgentTask -Prompt $prompt -TimeoutSeconds $TaskTimeoutSeconds -WorkingDirectory $worktreePath -ModelName $taskModel -ReasoningEffortLevel $taskEffort

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

        $keepWorktree = Test-WorkflowScratchHasWork $worktreePath $worktreeHeadBefore
        if ($copilotResult.TimedOut) {
            Write-Host "  [x] $WorkerAgent timed out after $($copilotResult.ElapsedSeconds)s. Stopping." -ForegroundColor Red
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

            if ($OnFailure -eq 'skip') {
                Write-Host '  [skip] Skipping to next task.' -ForegroundColor Yellow
                $skippedLineIndices += $task.LineIndex
                continue
            }
            break
        }

        if ($exitCode -ne 0) {
            Write-Host "  [x] $WorkerAgent exited with code $exitCode. Stopping." -ForegroundColor Red
            if ($worktreeCommitCount -gt 0) {
                $keepWorktree = $true
                Write-Host "  Worktree contains unmerged commit(s):" -ForegroundColor Yellow
                foreach ($line in (Get-CommitSummariesBetween -RepoPath $worktreePath -BaseCommit $worktreeHeadBefore -HeadCommit $worktreeHeadAfter)) {
                    Write-Host "    $line" -ForegroundColor Yellow
                }
                Write-Host "  Preserved worktree: $worktreePath" -ForegroundColor Yellow
            }
            if ($OnFailure -eq 'skip') {
                Write-Host '  [skip] Skipping to next task.' -ForegroundColor Yellow
                $skippedLineIndices += $task.LineIndex
                continue
            }
            break
        }

        if ($worktreeCommitCount -eq 0) {
            Write-Host "  [x] No new commit detected. Task may have failed. Stopping." -ForegroundColor Red
            $statusWithoutCommit = Get-WorkingTreeStatus -RepoPath $worktreePath
            if ($statusWithoutCommit.Count -gt 0) {
                $keepWorktree = $true
                Write-Host "  Partial changes remain in preserved worktree:" -ForegroundColor Red
                foreach ($line in $statusWithoutCommit) {
                    Write-Host "    $line" -ForegroundColor Red
                }
                Write-Host "  Preserved worktree: $worktreePath" -ForegroundColor Yellow
            }
            if ($OnFailure -eq 'skip') {
                Write-Host '  [skip] Skipping to next task.' -ForegroundColor Yellow
                $skippedLineIndices += $task.LineIndex
                continue
            }
            break
        }

        if ($worktreeCommitCount -gt 1) {
            Write-Host "  Worker made $worktreeCommitCount commits. Cherry-picking range..." -ForegroundColor Yellow
            foreach ($line in (Get-CommitSummariesBetween -RepoPath $worktreePath -BaseCommit $worktreeHeadBefore -HeadCommit $worktreeHeadAfter)) {
                Write-Host "    $line" -ForegroundColor DarkCyan
            }
        }

        $primaryStatusBeforeApply = Get-WorkingTreeStatus -RepoPath $repoRoot
        if ($primaryStatusBeforeApply.Count -gt 0) {
            $keepWorktree = $true
            Write-Host '  ! Primary worktree is dirty; skipping automatic cherry-pick and TODO bookkeeping.' -ForegroundColor Yellow
            foreach ($line in $primaryStatusBeforeApply) {
                Write-Host "    $line" -ForegroundColor Yellow
            }
            Write-Host "  Worker commit(s) to inspect manually: $worktreeHeadAfter" -ForegroundColor Yellow
            Write-Host "  Preserved worktree: $worktreePath" -ForegroundColor Yellow
            break
        }

        $cherryPickLabel = if ($worktreeCommitCount -gt 1) { 'commit range' } else { 'worker commit' }
        Write-Host "  Cherry-picking $cherryPickLabel into primary worktree..." -ForegroundColor DarkGray
        git cherry-pick "$worktreeHeadBefore..$worktreeHeadAfter" | Out-Null
        if ($LASTEXITCODE -ne 0) {
            git cherry-pick --abort | Out-Null
            $keepWorktree = $true
            Write-Host '  [x] Cherry-pick failed. Preserving worker worktree for inspection.' -ForegroundColor Red
            Write-Host "  Preserved worktree: $worktreePath" -ForegroundColor Yellow
            if ($OnFailure -eq 'skip') {
                Write-Host '  [skip] Skipping to next task.' -ForegroundColor Yellow
                $skippedLineIndices += $task.LineIndex
                continue
            }
            break
        }

        $commitAfter = Get-HeadCommit -RepoPath $repoRoot
        $keepWorktree = $false

        $primaryStatusBeforeBookkeeping = Get-WorkingTreeStatus -RepoPath $repoRoot
        if ($primaryStatusBeforeBookkeeping.Count -gt 0) {
            Write-Host '  ! Primary worktree became dirty before scheduler bookkeeping. Leaving TODO state untouched.' -ForegroundColor Yellow
            foreach ($line in $primaryStatusBeforeBookkeeping) {
                Write-Host "    $line" -ForegroundColor Yellow
            }
            Write-Host "  [ok] New commit: $commitAfter" -ForegroundColor Green
            break
        }

        $todoAfter = Get-TodoText
        $workerUpdatedTodo = $todoAfter -ne $todoBefore

        if ($workerUpdatedTodo) {
            if (Test-TaskStillPending $task) {
                Write-Host "  ! TODO.md changed during the worker commit, but the same task still appears actionable." -ForegroundColor Yellow
                Write-Host "  ! Scheduler is leaving TODO state untouched to avoid clobbering worker-authored task decomposition." -ForegroundColor Yellow
            } else {
                Write-Host "  [ok] TODO state updated by worker; skipping scheduler bookkeeping." -ForegroundColor Green
            }
        } else {
            # Mark the task done in TODO.md (scheduler owns TODO bookkeeping by default)
            Mark-TaskDone $task
            $bookkeepingCommit = Commit-Bookkeeping (Get-TaskSummary $task)
            Write-Host "  [ok] Task marked done in TODO.md" -ForegroundColor Green
            Write-Host "  [ok] Bookkeeping commit: $bookkeepingCommit" -ForegroundColor Green
        }

        Write-Host "  [ok] New commit: $commitAfter" -ForegroundColor Green
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

Write-Host "`n-- Summary ----------------------------------------------" -ForegroundColor Cyan
Write-Host "  Tasks attempted: $taskCount"
if ($skippedLineIndices.Count -gt 0) {
    Write-Host "  Tasks skipped (failures): $($skippedLineIndices.Count)" -ForegroundColor Yellow
}
Write-Host "  HEAD is now: $(Get-HeadCommit -RepoPath $repoRoot)"
$logCount = $taskCount + 2
$recentLog = git log --oneline -$logCount
foreach ($line in $recentLog) {
    Write-Host "  $line"
}
