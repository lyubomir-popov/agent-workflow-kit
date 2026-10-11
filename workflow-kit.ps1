<#
.SYNOPSIS
  Workflow-kit validator and drift reporter.

.DESCRIPTION
  Provides two commands:
    lint - validate a repo that uses the agent-workflow-kit conventions.
    diff - report canonical workflow-file drift between this kit and a target repo.

  Output is human-readable by default. Use -Json for machine-readable findings.
#>

param(
    [ValidateSet('lint', 'diff')]
    [string]$Command = 'lint',
    [string]$RepoRoot = $PWD,
    [string]$KitRoot = $PSScriptRoot,
    [switch]$Json,
    [switch]$Strict
)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/workflow-model.ps1"
. "$PSScriptRoot/workflow-checks.ps1"

function Resolve-RepoPath {
    param([string]$Path)

    return (Resolve-Path -LiteralPath $Path).Path
}

function New-Finding {
    param(
        [ValidateSet('error', 'warning', 'info')]
        [string]$Severity,
        [string]$Rule,
        [string]$Path,
        [string]$Message
    )

    return [pscustomobject]@{
        id = ('{0}:{1}' -f $Rule, $Path)
        severity = $Severity
        rule = $Rule
        path = $Path
        message = $Message
    }
}

function Add-Finding {
    param(
        [System.Collections.Generic.List[object]]$Findings,
        [ValidateSet('error', 'warning', 'info')]
        [string]$Severity,
        [string]$Rule,
        [string]$Path,
        [string]$Message
    )

    $Findings.Add((New-Finding -Severity $Severity -Rule $Rule -Path $Path -Message $Message)) | Out-Null
}

function Get-PromptCommandName {
    param([string]$FileName)

    return '/' + ($FileName -replace '\.prompt\.md$', '')
}

function Test-FrontMatterField {
    param(
        [string[]]$Lines,
        [string]$FieldName
    )

    if ($Lines.Count -lt 3 -or $Lines[0].Trim() -ne '---') {
        return $false
    }

    $end = -1
    for ($i = 1; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i].Trim() -eq '---') {
            $end = $i
            break
        }
    }

    if ($end -lt 0) {
        return $false
    }

    $pattern = '^\s*' + [regex]::Escape($FieldName) + '\s*:'
    for ($i = 1; $i -lt $end; $i++) {
        if ($Lines[$i] -match $pattern) {
            return $true
        }
    }

    return $false
}

function Test-InboxDrained {
    param(
        [System.Collections.Generic.List[object]]$Findings,
        [string]$RepoRoot,
        [string]$RelativePath,
        [string[]]$ExpectedNonEmptyLines
    )

    $path = Join-Path $RepoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        return
    }

    $actual = @((Get-Content -LiteralPath $path) | Where-Object { $_.Trim().Length -gt 0 })
    $expected = @($ExpectedNonEmptyLines)

    if ($actual.Count -ne $expected.Count) {
        Add-Finding $Findings 'warning' 'inbox-drained' $RelativePath 'Inbox has content beyond its template header; triage it into canonical files.'
        return
    }

    for ($i = 0; $i -lt $expected.Count; $i++) {
        if ($actual[$i].Trim() -ne $expected[$i].Trim()) {
            Add-Finding $Findings 'warning' 'inbox-drained' $RelativePath 'Inbox differs from its template header; verify it has been drained.'
            return
        }
    }
}

function Test-LegacyWorkflowRepo {
    param([string]$RepoRoot)

    $findings = [System.Collections.Generic.List[object]]::new()
    $requiredFiles = @(
        '.github/copilot-instructions.md',
        '.github/agents/agent.md',
        'README.md',
        'ROADMAP.md',
        'TODO.md',
        'INBOX.md',
        'AGENT-INBOX.md',
        'STATUS.md',
        'HISTORY.md',
        'docs/specs.md'
    )

    foreach ($relativePath in $requiredFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot $relativePath))) {
            Add-Finding $findings 'error' 'required-file' $relativePath 'Required workflow file is missing.'
        }
    }

    $instructionsPath = Join-Path $RepoRoot '.github/copilot-instructions.md'
    if (Test-Path -LiteralPath $instructionsPath) {
        $instructions = Get-Content -LiteralPath $instructionsPath -Raw
        if ($instructions -notmatch '(?m)^## What this repo is\s*$') {
            Add-Finding $findings 'warning' 'instructions-orientation' '.github/copilot-instructions.md' 'Add a short "What this repo is" section near the top.'
        }
        if ($instructions -notmatch '(?m)^## Token discipline\s*$') {
            Add-Finding $findings 'warning' 'token-discipline' '.github/copilot-instructions.md' 'Add token-discipline guidance for large generated or data-heavy paths.'
        }
        if ($instructions -notmatch '(?m)^### Full validation\b') {
            Add-Finding $findings 'warning' 'tiered-validation' '.github/copilot-instructions.md' 'Validation should include a "Full validation" command.'
        }
        if ($instructions -notmatch '(?m)^### Targeted validation\b') {
            Add-Finding $findings 'warning' 'tiered-validation' '.github/copilot-instructions.md' 'Validation should include a "Targeted validation" command.'
        }
        if ($instructions -notmatch 'repo-type-aware|Repo-type-aware|repo type') {
            Add-Finding $findings 'warning' 'repo-type-precedence' '.github/copilot-instructions.md' 'Document how source precedence changes for docs, code, and data repos.'
        }
    }

    $agentPath = Join-Path $RepoRoot '.github/agents/agent.md'
    if (Test-Path -LiteralPath $agentPath) {
        $agentLines = @(Get-Content -LiteralPath $agentPath)
        if (-not (Test-FrontMatterField -Lines $agentLines -FieldName 'description')) {
            Add-Finding $findings 'error' 'agent-frontmatter' '.github/agents/agent.md' 'Resume agent file must have frontmatter with description.'
        }
        if ($agentLines.Count -gt 60) {
            Add-Finding $findings 'warning' 'agent-size' '.github/agents/agent.md' 'Resume agent file is long; keep it as a short first-read prompt, not a second STATUS.md.'
        }
    }

    $todoPath = Join-Path $RepoRoot 'TODO.md'
    if (Test-Path -LiteralPath $todoPath) {
        $todo = Get-Content -LiteralPath $todoPath -Raw
        if ($todo -notmatch '(?m)^## Maintaining this file\s*$') {
            Add-Finding $findings 'warning' 'todo-maintenance' 'TODO.md' 'Add a maintenance section saying TODO contains only open items.'
        }
        foreach ($heading in @('## Short-term', '## Medium-term', '## Long-term')) {
            if ($todo -notmatch ('(?m)^' + [regex]::Escape($heading) + '\s*$')) {
                Add-Finding $findings 'warning' 'todo-priority-sections' 'TODO.md' "Missing priority section: $heading."
            }
        }
    }

    $historyPath = Join-Path $RepoRoot 'HISTORY.md'
    if (Test-Path -LiteralPath $historyPath) {
        $historyLineCount = @((Get-Content -LiteralPath $historyPath)).Count
        if ($historyLineCount -gt 200) {
            Add-Finding $findings 'warning' 'history-rotation' 'HISTORY.md' "HISTORY.md has $historyLineCount lines; rotate older entries into docs/archive/YYYY.md."
        }
    }

    Test-InboxDrained -Findings $findings -RepoRoot $RepoRoot -RelativePath 'INBOX.md' -ExpectedNonEmptyLines @(
        '# Inbox',
        'Drop notes here. The agent will triage items into `TODO.md` (near-term) or `ROADMAP.md` (longer-term), then empty this file back to its template header.'
    )

    Test-InboxDrained -Findings $findings -RepoRoot $RepoRoot -RelativePath 'AGENT-INBOX.md' -ExpectedNonEmptyLines @(
        '# Agent Inbox',
        'Machine-generated handoffs, long diagnostics, and cross-repo follow-up notes go here.',
        'Do not use this file for user notes. User-authored async notes belong in `INBOX.md`.',
        'The agent should triage anything durable from this file into `TODO.md`, `ROADMAP.md`, `STATUS.md`, `HISTORY.md`, or `docs/specs.md`, then empty this file back to this header template.'
    )

    $specsPath = Join-Path $RepoRoot 'docs/specs.md'
    if (Test-Path -LiteralPath $specsPath) {
        $specs = Get-Content -LiteralPath $specsPath -Raw
        if ($specs -match '<upstream-spec>|<repo>|TODO') {
            Add-Finding $findings 'warning' 'spec-placeholders' 'docs/specs.md' 'docs/specs.md appears to contain placeholders; replace them with real source references or note that none exist.'
        }
    }

    $promptsDir = Join-Path $RepoRoot 'prompts'
    if (Test-Path -LiteralPath $promptsDir) {
        $promptFiles = @(Get-ChildItem -LiteralPath $promptsDir -Filter '*.prompt.md' -File)
        foreach ($promptFile in $promptFiles) {
            $relative = 'prompts/' + $promptFile.Name
            $lines = @(Get-Content -LiteralPath $promptFile.FullName)
            if (-not (Test-FrontMatterField -Lines $lines -FieldName 'description')) {
                Add-Finding $findings 'error' 'prompt-frontmatter' $relative 'Prompt file must have frontmatter with description.'
            }
            if (-not (Test-FrontMatterField -Lines $lines -FieldName 'mode')) {
                Add-Finding $findings 'warning' 'prompt-frontmatter' $relative 'Prompt file should specify mode.'
            }
            if (-not (Test-FrontMatterField -Lines $lines -FieldName 'model')) {
                Add-Finding $findings 'warning' 'prompt-frontmatter' $relative 'Prompt file should pin a model via the model: frontmatter field (e.g. claude-opus-4.7, gpt-5.4, gpt-5.4-mini). Pinning enforces tier discipline so the right model runs the slash command regardless of picker selection.'
            }
        }

        $readmePath = Join-Path $RepoRoot 'README.md'
        if (Test-Path -LiteralPath $readmePath) {
            $readme = Get-Content -LiteralPath $readmePath -Raw
            foreach ($promptFile in $promptFiles) {
                $commandName = Get-PromptCommandName $promptFile.Name
                if ($readme -notmatch [regex]::Escape($commandName)) {
                    Add-Finding $findings 'warning' 'prompt-readme-drift' 'README.md' "Prompt command $commandName exists but is not listed in README.md."
                }
            }
        }
    }

    return @($findings)
}

function Test-WorkflowRepo {
    param([string]$RepoRoot)
    try { $config = Get-WorkflowConfig $RepoRoot }
    catch { return @(New-Finding error workflow-config '.workflow-kit.json' $_.Exception.Message) }
    if ($config) { return @(Test-SpecWorkflowRepo $RepoRoot $config) }
    return @(Test-LegacyWorkflowRepo $RepoRoot)
}

function Get-CanonicalMirrorFiles {
    param([string]$KitRoot)

    $files = [System.Collections.Generic.List[string]]::new()
    foreach ($relative in @(
        'agent-loop.ps1',
        'workflow-model.ps1',
        'workflow-checks.ps1',
        'workflow-scheduler.ps1',
        'install-vscode-prompts.ps1',
        'bin/agent-loop',
        'bin/agent-loop.cmd',
        'bin/install-vscode-prompts',
        'bin/install-vscode-prompts.cmd'
    )) {
        $files.Add($relative) | Out-Null
    }

    $promptRoot = Join-Path $KitRoot 'prompts'
    if (Test-Path -LiteralPath $promptRoot) {
        foreach ($promptFile in Get-ChildItem -LiteralPath $promptRoot -Filter '*.prompt.md' -File) {
            $files.Add('prompts/' + $promptFile.Name) | Out-Null
        }
    }

    return @($files)
}

function Get-WorkflowKitRepoConfig {
    param(
        [string]$RepoRoot,
        [System.Collections.Generic.List[object]]$Findings
    )

    $configPath = Join-Path $RepoRoot '.workflow-kit.json'
    $config = [pscustomobject]@{
        canonicalMirrorMode = 'mirror'
    }

    if (-not (Test-Path -LiteralPath $configPath)) {
        return $config
    }

    try {
        $parsed = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    }
    catch {
        Add-Finding $Findings 'error' 'workflow-kit-config' '.workflow-kit.json' 'Config file is not valid JSON.'
        return $null
    }

    if ($null -ne $parsed.canonicalMirrorMode -and [string]::IsNullOrWhiteSpace([string]$parsed.canonicalMirrorMode) -eq $false) {
        $canonicalMirrorMode = [string]$parsed.canonicalMirrorMode
        if (@('mirror', 'external') -notcontains $canonicalMirrorMode) {
            Add-Finding $Findings 'error' 'workflow-kit-config' '.workflow-kit.json' 'canonicalMirrorMode must be either "mirror" or "external".'
            return $null
        }

        $config = [pscustomobject]@{
            canonicalMirrorMode = $canonicalMirrorMode
        }
    }

    return $config
}

function Test-WorkflowDrift {
    param(
        [string]$KitRoot,
        [string]$RepoRoot
    )

    $findings = [System.Collections.Generic.List[object]]::new()
    $config = Get-WorkflowKitRepoConfig -RepoRoot $RepoRoot -Findings $findings
    if ($null -eq $config) {
        return @($findings)
    }

    $suppressMissingCanonicalFiles = $config.canonicalMirrorMode -eq 'external'

    foreach ($relativePath in Get-CanonicalMirrorFiles -KitRoot $KitRoot) {
        $kitPath = Join-Path $KitRoot $relativePath
        $repoPath = Join-Path $RepoRoot $relativePath

        if (-not (Test-Path -LiteralPath $kitPath)) {
            continue
        }

        if (-not (Test-Path -LiteralPath $repoPath)) {
            if (-not $suppressMissingCanonicalFiles) {
                Add-Finding $findings 'warning' 'canonical-file-missing' $relativePath 'Canonical kit file is absent from target repo. This may be intentional if the repo uses PATH-based launchers only.'
            }
            continue
        }

        $kitHash = (Get-FileHash -LiteralPath $kitPath -Algorithm SHA256).Hash
        $repoHash = (Get-FileHash -LiteralPath $repoPath -Algorithm SHA256).Hash
        if ($kitHash -ne $repoHash) {
            Add-Finding $findings 'warning' 'canonical-file-drift' $relativePath 'Target repo copy differs from agent-workflow-kit canonical copy.'
        }
    }

    return @($findings)
}

function Write-WorkflowReport {
    param(
        [object[]]$Findings,
        [switch]$Json,
        [switch]$Strict
    )

    $normalizedFindings = @($Findings | Where-Object { $null -ne $_ })
    $summary = [pscustomobject]@{
        errors = @($normalizedFindings | Where-Object { $_.severity -eq 'error' }).Count
        warnings = @($normalizedFindings | Where-Object { $_.severity -eq 'warning' }).Count
        infos = @($normalizedFindings | Where-Object { $_.severity -eq 'info' }).Count
    }

    if ($Json) {
        [pscustomobject]@{
            findings = $normalizedFindings
            summary = $summary
            mode = $script:WorkflowMode
            triggers = Get-WorkflowTriggerReport $script:ReportRepoRoot
            limits = @('Mechanical evidence does not establish semantic prose freshness.', 'Host instruction compliance and skipped hooks are not enforceable by files.')
        } | ConvertTo-Json -Depth 5
    } else {
        if ($normalizedFindings.Count -eq 0) {
            Write-Host 'workflow-kit: no findings'
        } else {
            foreach ($finding in $normalizedFindings) {
                Write-Host ("[{0}] {1} {2} - {3}" -f $finding.severity.ToUpperInvariant(), $finding.rule, $finding.path, $finding.message)
            }
        }
        Write-Host ("Summary: {0} error(s), {1} warning(s), {2} info item(s)" -f $summary.errors, $summary.warnings, $summary.infos)
    }

    if ($summary.errors -gt 0 -or ($Strict -and $summary.warnings -gt 0)) {
        exit 1
    }
}

$resolvedRepoRoot = Resolve-RepoPath $RepoRoot
$resolvedKitRoot = Resolve-RepoPath $KitRoot
$script:ReportRepoRoot = $resolvedRepoRoot
$script:WorkflowMode = 'legacy'
try { if (Get-WorkflowConfig $resolvedRepoRoot) { $script:WorkflowMode = 'spec-first' } } catch { $script:WorkflowMode = 'invalid' }

switch ($Command) {
    'lint' {
        Write-WorkflowReport -Findings (Test-WorkflowRepo -RepoRoot $resolvedRepoRoot) -Json:$Json -Strict:$Strict
    }
    'diff' {
        $findings = @()
        $findings += Test-WorkflowRepo -RepoRoot $resolvedRepoRoot
        $findings += Test-WorkflowDrift -KitRoot $resolvedKitRoot -RepoRoot $resolvedRepoRoot
        Write-WorkflowReport -Findings $findings -Json:$Json -Strict:$Strict
    }
}
