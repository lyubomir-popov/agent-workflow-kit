. (Join-Path $PSScriptRoot 'Fixture.Helpers.ps1')
. (Join-Path $script:KitRoot 'workflow-migration.ps1')

function New-MigrationFixture {
    $fixture = New-WorkflowFixture
    Write-FixtureFile $fixture '.specify/templates/overrides/tasks-template.md' (
        [IO.File]::ReadAllText((Join-Path $script:KitRoot '.specify/templates/overrides/tasks-template.md')))
    return $fixture
}

function Set-MigrationFixtureMigrated {
    param($Fixture)
    foreach ($relative in @('STATUS.md','TODO.md','HISTORY.md')) {
        Write-FixtureFile $Fixture $relative "# Retired workflow file`nRead [the catalog](docs/specs.md).`n"
    }
    foreach ($relative in @('.github/agents/agent.md')) {
        $path = Join-Path $Fixture.RepoRoot $relative
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }
    Write-FixtureFile $Fixture '.github/copilot-instructions.md' "Read [AGENTS.md](../AGENTS.md).`n"
    Write-FixtureFile $Fixture 'prompts/whats-next.prompt.md' @'
---
description: "Fixture dual-mode orientation command."
mode: agent
model: fixture-model
---

# What's next

Read `.workflow-kit.json` and inspect `workflowModelVersion`. An absent property
uses the legacy procedure, version `1` uses the version 1 route, and malformed or
unsupported configuration stops.

## Version 1 route

Read AGENTS.md, docs/specs.md, and the selected package owners.

## Legacy procedure

Read the legacy workflow owners.
'@
    Save-FixtureRevision $Fixture
}

function Set-MigrationFixtureLegacy {
    param($Fixture)
    $config = Get-FixtureConfig $Fixture
    $config.PSObject.Properties.Remove('workflowModelVersion')
    $config | Add-Member productSettings ([pscustomobject]@{
        deploymentRing = 'fixture-only'
        preserveThis = @('alpha','beta')
    })
    Set-FixtureConfig $Fixture $config
    Write-FixtureFile $Fixture 'STATUS.md' "# Status`n`nRelease notes remain useful during migration review.`n"
    Write-FixtureFile $Fixture 'TODO.md' "# TODO`n`nNo live legacy task queue; preserve these historical ideas for owner review.`n"
    Write-FixtureFile $Fixture 'HISTORY.md' "# History`n`nThe fixture shipped its first release.`n"
    Write-FixtureFile $Fixture 'ROADMAP.md' "# Roadmap`n`nDurable fixture product direction.`n"
    Write-FixtureFile $Fixture '.github/agents/agent.md' "---`ndescription: 'Fixture legacy resume agent.'`n---`n`n# Legacy resume agent`n`nRead the root workflow files.`n"
    Write-FixtureFile $Fixture '.github/copilot-instructions.md' @'
# What this repo is

The fixture models a product repository.

## Validation

Run the fixture's declared checks.

## Product-specific deployment invariant

The blue ring must remain available during releases.
'@
    Write-FixtureFile $Fixture 'prompts/legacy-only.prompt.md' "---`ndescription: 'Fixture legacy command.'`nmode: agent`nmodel: fixture-model`n---`n`n# Legacy command`n`nRead STATUS.md and TODO.md.`n"
    Write-FixtureFile $Fixture 'tmp/notes δ.txt' 'Tracked scratch evidence must be reported and preserved.'
    Save-FixtureRevision $Fixture
}

function Set-MigrationFixtureExternalConfig {
    param($Fixture, [switch]$Versioned)
    $config = [ordered]@{
        canonicalMirrorMode = 'external'
        productSettings = [ordered]@{
            deploymentRing = 'fixture-only'
            preserveThis = @('alpha','beta')
        }
    }
    if ($Versioned) {
        $config = Get-Content -LiteralPath (Join-Path $script:KitRoot '.workflow-kit.json') -Raw | ConvertFrom-Json
        $config.targetBranch = 'master'
        $config | Add-Member canonicalMirrorMode 'external'
        $config | Add-Member productSettings ([pscustomobject]@{
            deploymentRing = 'fixture-only'
            preserveThis = @('alpha','beta')
        })
    }
    Write-FixtureFile $Fixture '.workflow-kit.json' ($config | ConvertTo-Json -Depth 20)
}

function Get-MigrationFixtureSnapshot {
    param($Fixture, [string[]]$ContentPaths = @())
    $content = foreach ($relative in $ContentPaths) {
        $path = Join-Path $Fixture.RepoRoot $relative
        if (Test-Path -LiteralPath $path) {
            $bytes = [Convert]::ToBase64String([IO.File]::ReadAllBytes($path))
            "${relative}=${bytes}"
        } else { "${relative}=<absent>" }
    }
    return [pscustomobject]@{
        Branch = [string](Invoke-FixtureGit $Fixture @('branch','--show-current'))
        Head = [string](Invoke-FixtureGit $Fixture @('rev-parse','HEAD'))
        Status = (@(Invoke-FixtureGit $Fixture @('status','--porcelain=v1','--untracked-files=all')) -join "`n")
        Index = (@(Invoke-FixtureGit $Fixture @('ls-files','--stage')) -join "`n")
        WorktreeDiff = (@(Invoke-FixtureGit $Fixture @('diff','--binary')) -join "`n")
        IndexDiff = (@(Invoke-FixtureGit $Fixture @('diff','--cached','--binary')) -join "`n")
        Content = (@($content) -join "`n")
    }
}

function Assert-MigrationFixtureSnapshot {
    param($Fixture, $Before, [string[]]$ContentPaths = @())
    $after = Get-MigrationFixtureSnapshot $Fixture $ContentPaths
    $after.Branch | Should Be $Before.Branch
    $after.Head | Should Be $Before.Head
    $after.Status | Should Be $Before.Status
    $after.Index | Should Be $Before.Index
    $after.WorktreeDiff | Should Be $Before.WorktreeDiff
    $after.IndexDiff | Should Be $Before.IndexDiff
    $after.Content | Should Be $Before.Content
}

function Get-MigrationDisposition {
    param($Report, [string]$Source)
    return @($Report.dispositions | Where-Object source -eq $Source | Select-Object -First 1)
}

function Invoke-MigrationCli {
    param($Fixture, [string[]]$ExtraArguments = @())
    $arguments = @('-NoLogo','-NoProfile','-File',(Join-Path $script:KitRoot 'workflow-kit.ps1'),
        '-Command','migrate','-RepoRoot',$Fixture.RepoRoot,'-KitRoot',$script:KitRoot) + $ExtraArguments
    $output = & pwsh @arguments 2>&1
    $raw = @($output) -join "`n"
    $diagnostic = ConvertFrom-MigrationDiagnostic $raw
    return [pscustomobject]@{ ExitCode=$LASTEXITCODE; Raw=$raw; Diagnostic=$diagnostic }
}

function ConvertFrom-MigrationDiagnostic {
    param([string]$Text)
    # Unwrap ConciseView like the T051 hook checks, including coloured output.
    $text = $Text -replace '\x1b\[[0-9;]*m', ''
    return ($text -replace '(?m)^\s*\|\s?', '') -replace '\s+', ' '
}

Describe 'Read-only migration preview contract' {
    BeforeEach { $script:fixture = New-MigrationFixture }
    AfterEach { Remove-WorkflowFixture $script:fixture }

    It 'accepts bounded retirement pointers in a spec-first fixture without changing Git or content' {
        Set-MigrationFixtureMigrated $fixture
        $paths = @('.workflow-kit.json','AGENTS.md','README.md','docs/specs.md',
            'STATUS.md','TODO.md','HISTORY.md',
            '.specify/templates/overrides/spec-template.md','.specify/templates/overrides/tasks-template.md')
        $before = Get-MigrationFixtureSnapshot $fixture $paths
        $report = Get-WorkflowMigrationPreview -RepoRoot $fixture.RepoRoot -KitRoot $script:KitRoot

        $report.mode | Should Be 'spec-first'
        $report.status | Should Be 'ready'
        @($report.PSObject.Properties.Name).Count | Should Be 4
        @($report.PSObject.Properties.Name) -contains 'dispositions' | Should Be $true
        @($report.PSObject.Properties.Name) -contains 'findings' | Should Be $true
        @($report.findings | Where-Object severity -eq 'error').Count | Should Be 0
        @($report.findings | Where-Object rule -eq 'migration-retired-owner').Count | Should Be 0
        @($report.findings | Where-Object rule -eq 'migration-retired-placeholder').Count | Should Be 3
        @(Get-MigrationDisposition $report 'prompts/whats-next.prompt.md')[0].action | Should Be 'review-dual-mode'
        foreach ($relative in @('STATUS.md','TODO.md','HISTORY.md')) {
            $placeholder = @(Get-MigrationDisposition $report $relative)[0]
            $placeholder.state | Should Be 'tracked'
            $placeholder.action | Should Be 'preserve-placeholder'
        }
        foreach ($disposition in @($report.dispositions)) {
            @($disposition.PSObject.Properties.Name) -join ',' | Should Be 'source,state,action,destination,reason'
            $disposition.source | Should Not BeNullOrEmpty
            $disposition.state | Should Not BeNullOrEmpty
            $disposition.action | Should Not BeNullOrEmpty
            $disposition.destination | Should Not BeNullOrEmpty
            $disposition.reason | Should Not BeNullOrEmpty
        }
        Assert-MigrationFixtureSnapshot $fixture $before $paths
    }

    It 'inventories legacy files sections unknown prose and tracked scratch without mutation' {
        Set-MigrationFixtureLegacy $fixture
        $paths = @('.workflow-kit.json','STATUS.md','TODO.md','HISTORY.md','AGENTS.md','README.md',
            '.github/agents/agent.md','.github/copilot-instructions.md','prompts/legacy-only.prompt.md',
            'tmp/notes δ.txt')
        $before = Get-MigrationFixtureSnapshot $fixture $paths
        $encoding = [Console]::OutputEncoding
        try {
            [Console]::OutputEncoding = [Text.Encoding]::GetEncoding(437)
            $report = Get-WorkflowMigrationPreview -RepoRoot $fixture.RepoRoot -KitRoot $script:KitRoot
        } finally { [Console]::OutputEncoding = $encoding }

        $report.mode | Should Be 'legacy'
        $report.status | Should Be 'incomplete'
        $status = @(Get-MigrationDisposition $report 'STATUS.md')[0]
        $status.state | Should Be 'tracked'
        $status.action | Should Be 'retire-after-reconcile'
        $status.destination | Should Be 'docs/specs.md and package spec.md/tasks.md'
        @(Get-MigrationDisposition $report 'TODO.md')[0].destination | Should Be 'package tasks.md or ROADMAP.md'
        @(Get-MigrationDisposition $report 'HISTORY.md')[0].action | Should Be 'retire-preserve-git'
        @(Get-MigrationDisposition $report '.github/agents/agent.md')[0].action | Should Be 'retire'
        @(Get-MigrationDisposition $report 'CLAUDE.md')[0].action | Should Be 'reduce-to-adapter'
        @(Get-MigrationDisposition $report 'docs/specs.md')[0].action | Should Be 'convert-to-catalog'
        @(Get-MigrationDisposition $report '.workflow-kit.json')[0].action | Should Be 'add-workflow-model-version'
        @(Get-MigrationDisposition $report 'prompts/legacy-only.prompt.md')[0].action | Should Be 'add-mode-selection'
        @(Get-MigrationDisposition $report 'INBOX.md')[0].action | Should Be 'retain-reconcile'
        @(Get-MigrationDisposition $report '.github/copilot-instructions.md')[0].action | Should Be 'migrate-sections'
        @(Get-MigrationDisposition $report '.specify/feature.json')[0].action | Should Be 'none'
        @(Get-MigrationDisposition $report 'AGENTS.md')[0].action | Should Be 'review-in-place'
        @(Get-MigrationDisposition $report 'README.md')[0].destination | Should Be 'README.md'
        @($report.dispositions | Where-Object { $_.state -eq 'recognized-heading' }).Count | Should BeGreaterThan 0
        @($report.dispositions | Where-Object action -eq 'move-or-reconcile').Count | Should BeGreaterThan 0
        $unknown = @($report.dispositions | Where-Object { $_.state -eq 'unfamiliar-heading' -and $_.source -match 'Product-specific deployment invariant' })
        $unknown.Count | Should Be 1
        $unknown[0].action | Should Be 'preserve-for-review'
        $unknown[0].destination | Should Be 'owner review'
        $scratch = @($report.findings | Where-Object rule -eq 'migration-tracked-scratch')
        $scratch.Count | Should Be 1
        $scratch[0].path | Should Be 'tmp/notes δ.txt'
        @($report.dispositions | Where-Object source -eq 'tmp/notes δ.txt').Count | Should Be 1
        @($report.findings | Where-Object rule -eq 'migration-resume-agent').Count | Should Be 1
        @($report.findings | Where-Object rule -eq 'migration-retired-owner').Count | Should Be 3
        @($report.findings | Where-Object { $_.rule -eq 'migration-live-route' -and $_.path -eq 'prompts/legacy-only.prompt.md' }).Count | Should Be 1
        Assert-MigrationFixtureSnapshot $fixture $before $paths
    }

    It 'preserves external-only config and keeps shared-file ownership external after versioning' {
        Set-MigrationFixtureLegacy $fixture
        Set-MigrationFixtureExternalConfig $fixture
        $configPath = Join-Path $fixture.RepoRoot '.workflow-kit.json'
        $legacyBytes = [Convert]::ToBase64String([IO.File]::ReadAllBytes($configPath))
        $legacy = Get-WorkflowMigrationPreview -RepoRoot $fixture.RepoRoot -KitRoot $script:KitRoot
        $legacy.mode | Should Be 'legacy'
        $legacy.status | Should Be 'incomplete'
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($configPath)) | Should Be $legacyBytes
        (Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json).productSettings.deploymentRing | Should Be 'fixture-only'
        @($legacy.findings | Where-Object rule -eq 'canonical-file-missing').Count | Should Be 0

        Remove-Item -LiteralPath (Join-Path $fixture.RepoRoot 'prompts/legacy-only.prompt.md') -Force
        Set-FixtureTasks $fixture
        Set-MigrationFixtureMigrated $fixture
        Set-MigrationFixtureExternalConfig $fixture -Versioned
        Save-FixtureRevision $fixture
        $versionedBytes = [Convert]::ToBase64String([IO.File]::ReadAllBytes($configPath))
        $versioned = Get-WorkflowMigrationPreview -RepoRoot $fixture.RepoRoot -KitRoot $script:KitRoot
        $versioned.mode | Should Be 'spec-first'
        $versioned.status | Should Be 'ready'
        @($versioned.findings | Where-Object rule -eq 'canonical-file-missing').Count | Should Be 0
        @($versioned.findings | Where-Object { $_.rule -eq 'migration-destination' -and $_.path -match 'workflow-kit|prompts' }).Count | Should Be 0
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($configPath)) | Should Be $versionedBytes
        (Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json).productSettings.preserveThis -join ',' | Should Be 'alpha,beta'
    }
}

Describe 'Migration blockers and CLI guards' {
    BeforeEach { $script:fixture = New-MigrationFixture }
    AfterEach { Remove-WorkflowFixture $script:fixture }

    It 'reports competing live task owners incomplete' {
        Set-MigrationFixtureMigrated $fixture
        Write-FixtureFile $fixture 'TODO.md' "# Active queue`n`n- [ ] Run the legacy task owner.`n"
        Save-FixtureRevision $fixture
        $report = Get-WorkflowMigrationPreview -RepoRoot $fixture.RepoRoot -KitRoot $script:KitRoot
        $report.status | Should Be 'incomplete'
        @($report.findings | Where-Object { $_.rule -eq 'migration-task-owner' -and $_.severity -eq 'error' }).Count | Should BeGreaterThan 0
    }

    It 'reports a missing required override and invalid config incomplete' {
        Set-MigrationFixtureMigrated $fixture
        Remove-Item -LiteralPath (Join-Path $fixture.RepoRoot '.specify/templates/overrides/tasks-template.md') -Force
        $missing = Get-WorkflowMigrationPreview -RepoRoot $fixture.RepoRoot -KitRoot $script:KitRoot
        $missing.mode | Should Be 'spec-first'
        $missing.status | Should Be 'incomplete'
        @($missing.findings | Where-Object { $_.rule -eq 'migration-destination' -and $_.path -match 'tasks-template' }).Count | Should BeGreaterThan 0
        @(Get-MigrationDisposition $missing '.specify/templates/overrides/tasks-template.md')[0].action | Should Be 'create'

        Write-FixtureFile $fixture '.workflow-kit.json' '{"workflowModelVersion":99}'
        $invalid = Get-WorkflowMigrationPreview -RepoRoot $fixture.RepoRoot -KitRoot $script:KitRoot
        $invalid.mode | Should Be 'invalid'
        $invalid.status | Should Be 'incomplete'
        @($invalid.findings | Where-Object { $_.rule -eq 'workflow-config' -and $_.severity -eq 'error' }).Count | Should BeGreaterThan 0
        @(Get-MigrationDisposition $invalid '.workflow-kit.json')[0].action | Should Be 'repair'
    }

    It 'reports pre-activation blockers in legacy and versioned modes without changing their owners' {
        Set-MigrationFixtureLegacy $fixture
        Write-FixtureFile $fixture '.specify/feature.json' '{"branch":"feat/001-example"}'
        $null = Invoke-FixtureGit $fixture @('add','--force','.specify/feature.json')
        Write-FixtureFile $fixture 'workflow-kit.ps1' '# Legacy validator without mode routing.'
        Write-FixtureFile $fixture 'agent-loop.ps1' '# Legacy scheduler without mode routing.'
        Write-FixtureFile $fixture 'workflow-scheduler.ps1' '# Legacy scheduler without mode routing.'
        Remove-Item -LiteralPath (Join-Path $fixture.RepoRoot '.specify/templates/overrides/tasks-template.md') -Force
        Save-FixtureRevision $fixture
        foreach ($mode in @('legacy','spec-first')) {
            if ($mode -eq 'spec-first') {
                $config = Get-FixtureConfig $fixture
                $config | Add-Member workflowModelVersion 1
                Set-FixtureConfig $fixture $config
            }
            $before = Get-MigrationFixtureSnapshot $fixture @('.workflow-kit.json','.specify/feature.json')
            $report = Get-WorkflowMigrationPreview -RepoRoot $fixture.RepoRoot -KitRoot $script:KitRoot
            $report.mode | Should Be $mode
            $report.status | Should Be 'incomplete'
            foreach ($rule in @('migration-resume-agent','migration-feature-cursor','migration-destination')) {
                @($report.findings | Where-Object { $_.rule -eq $rule -and $_.severity -eq 'error' }).Count | Should BeGreaterThan 0
            }
            foreach ($path in @('prompts/legacy-only.prompt.md','workflow-kit.ps1','agent-loop.ps1','workflow-scheduler.ps1')) {
                @($report.findings | Where-Object { $_.rule -eq 'migration-live-route' -and $_.path -eq $path }).Count | Should Be 1
            }
            @(Get-MigrationDisposition $report '.specify/feature.json')[0].action | Should Be 'untrack-and-ignore'
            @(Get-MigrationDisposition $report 'agent-loop.ps1')[0].action | Should Be 'replace-incompatible-route'
            Assert-MigrationFixtureSnapshot $fixture $before @('.workflow-kit.json','.specify/feature.json')
        }
    }

    It 'does not require retired root files before activation and reports Git inventory failure incomplete' {
        Set-MigrationFixtureLegacy $fixture
        foreach ($path in @('STATUS.md','TODO.md','HISTORY.md','.github/agents/agent.md','prompts/legacy-only.prompt.md')) {
            Remove-Item -LiteralPath (Join-Path $fixture.RepoRoot $path) -Force
        }
        Save-FixtureRevision $fixture
        $report = Get-WorkflowMigrationPreview -RepoRoot $fixture.RepoRoot -KitRoot $script:KitRoot
        $report.mode | Should Be 'legacy'
        $report.status | Should Be 'ready'
        @($report.findings | Where-Object { $_.rule -eq 'required-file' -and $_.path -match 'STATUS|TODO|HISTORY' }).Count | Should Be 0

        $notRepository = Join-Path $fixture.TempRoot 'not-a-repository'
        $null = New-Item -ItemType Directory -Path $notRepository
        $gitFailure = Get-WorkflowMigrationPreview -RepoRoot $notRepository -KitRoot $script:KitRoot
        $gitFailure.status | Should Be 'incomplete'
        @($gitFailure.findings | Where-Object { $_.rule -eq 'migration-git' -and $_.severity -eq 'error' }).Count | Should Be 1
    }

    It 'requires preview rejects apply and emits the report as JSON' {
        Set-MigrationFixtureMigrated $fixture
        $missingPreview = Invoke-MigrationCli $fixture
        $missingPreview.ExitCode | Should Be 1
        $missingPreview.Diagnostic | Should Match 'migration-incomplete:'
        $missingPreview.Diagnostic | Should Match 'specify -Preview'

        $apply = Invoke-MigrationCli $fixture @('-Preview','-Apply')
        $apply.ExitCode | Should Be 1
        $apply.Diagnostic | Should Match 'migration-incomplete:'
        $apply.Diagnostic | Should Match '-Apply is not supported'

        $preview = Invoke-MigrationCli $fixture @('-Preview','-Json')
        $preview.ExitCode | Should Be 0
        $report = $preview.Raw | ConvertFrom-Json
        $report.mode | Should Be 'spec-first'
        $report.status | Should Be 'ready'
        @($report.PSObject.Properties.Name) -join ',' | Should Be 'mode,status,dispositions,findings'
    }

    It 'unwraps coloured narrow-console diagnostic continuation lines' {
        $escape = [char]27
        $wrapped = "${escape}[31mmigration-incomplete: specify -Preview;${escape}[0m`n${escape}[31m   | migration is read-only.${escape}[0m"
        (ConvertFrom-MigrationDiagnostic $wrapped).Trim() | Should Be 'migration-incomplete: specify -Preview; migration is read-only.'
    }
}

Describe 'Dual-mode prompt source contracts' {
    It 'selects mode explicitly in all prompt sources without operational retired-owner routes' {
        $promptFiles = @(Get-ChildItem -LiteralPath (Join-Path $script:KitRoot 'prompts') -Filter '*.prompt.md' -File)
        ($promptFiles.Name -contains 'review.prompt.md') | Should Be $true
        $routerFiles = @($promptFiles | Where-Object Name -ne 'review.prompt.md')
        $routerFiles.Count | Should Be 13
        foreach ($prompt in $routerFiles) {
            $text = [IO.File]::ReadAllText($prompt.FullName)
            $text | Should Match '(?m)^## Workflow mode\s*$'
            $text | Should Match 'workflowModelVersion'
            $text | Should Match '(?m)^## Version 1 route\s*$'
            $text | Should Match '(?m)^## Version 2 route\s*$'
            $text | Should Match '(?m)^## Legacy procedure\s*$'
            $legacyRoute = [regex]::Match($text,'(?ms)^## Legacy procedure\s*$(.*)').Groups[1].Value
            $legacyRoute | Should Not Match '(?m)^## '
            $text | Should Match '(?is)absent.*legacy'
            $text | Should Match '(?is)(malformed|invalid).*\b(stop|fail)\b|\b(stop|fail)\b.*(malformed|invalid)'
            $text | Should Match '(?is)unsupported.*\b(stop|fail)\b|\b(stop|fail)\b.*unsupported'
            $text | Should Match '(?i)JSON integer\s+`?1`?'

            $versionRoute = [regex]::Match($text,'(?ms)^## Version 1 route\s*$(.*?)(?=^## )').Groups[1].Value
            $versionRoute | Should Match 'AGENTS\.md|/whats-next|/overnight'
            $versionRoute | Should Match 'docs/specs\.md|catalog|package|/whats-next|/overnight'
            if ($prompt.Name -ne 'freshen-status.prompt.md') {
                $versionRoute | Should Not Match '(?i)\b(read|consult|update|write|recreate)\b[^\r\n]*(STATUS|TODO|HISTORY)\.md'
            }
            if ($prompt.Name -eq 'sync-all-repos.prompt.md') {
                $versionRoute | Should Not Match '(?i)git add -A|push every|push all'
                $text | Should Match '(?is)## Shared.*?(force.push|force push)'
            }
        }
    }

    It 'keeps the compatibility commands explicit and leaves installation separate' {
        $freshen = [IO.File]::ReadAllText((Join-Path $script:KitRoot 'prompts/freshen-status.prompt.md'))
        $freshen | Should Match '(?is)## Version 1 route.*deprecated.*?/whats-next'
        $freshen | Should Match '(?is)## Version 1 route.*?(do not|never).*?(create|update|write).*?STATUS\.md'
        $overnight = [IO.File]::ReadAllText((Join-Path $script:KitRoot 'prompts/overnight.prompt.md'))
        $overnight | Should Match '(?is)## Version 1 route.*?(SpecKit|spec.scheduler)'
        $legacyOvernight = [regex]::Match($overnight,'(?ms)^## Legacy procedure\s*$(.*)').Groups[1].Value
        $legacyOvernight | Should Match '-Workflow SpecKit'
        $legacyOvernight | Should Match '(?is)do not fall back.*?TODO.*?(user|explicit)'
        $legacyOvernight | Should Match 'docs/operations\.md'
        $legacyOvernight | Should Match '(?i)(pre.flight|before.*launch)'
        $legacyOvernight | Should Match '(?i)(login|authentication|auth)'
        $legacyOvernight | Should Match '(?im)^### Overrides'
        $alias = [IO.File]::ReadAllText((Join-Path $script:KitRoot 'prompts/proceed-autonomously.prompt.md'))
        $alias | Should Match '(?is)## Version 1 route.*?alias.*?/overnight'
        $alias | Should Match '(?is)## Legacy procedure.*?alias.*?/overnight'

        foreach ($prompt in Get-ChildItem -LiteralPath (Join-Path $script:KitRoot 'prompts') -Filter '*.prompt.md' -File) {
            [IO.File]::ReadAllText($prompt.FullName) | Should Not Match '(?i)(invoke|run|execute)\s+[^\r\n]*install-vscode-prompts'
        }
    }

    It 'keeps shared orchestration and competing-audit procedures available to both routes' {
        $orchestrate = [IO.File]::ReadAllText((Join-Path $script:KitRoot 'prompts/orchestrate.prompt.md'))
        $audit = [IO.File]::ReadAllText((Join-Path $script:KitRoot 'prompts/competing-audit.prompt.md'))
        foreach ($text in @($orchestrate,$audit)) {
            $shared = [regex]::Match($text,'(?ms)^## Shared procedure\s*$(.*?)(?=^## Workflow mode\s*$)').Groups[1].Value
            $shared | Should Not BeNullOrEmpty
            foreach ($heading in @('Version 1 route','Legacy procedure')) {
                $route = [regex]::Match($text,('(?ms)^## '+$heading+'\s*$(.*?)(?=^## |\z)')).Groups[1].Value
                $route | Should Match '(?i)shared procedure'
            }
        }
        $orchestrateShared = [regex]::Match($orchestrate,'(?ms)^## Shared procedure\s*$(.*?)(?=^## Workflow mode\s*$)').Groups[1].Value
        $orchestrateShared | Should Match '(?i)dispatch'
        $orchestrateShared | Should Match 'TierDispatchMap'
        $audit | Should Match '(?is)## Shared procedure.*?(independent|competing).*?(findings|report).*?## Workflow mode'
    }
}
