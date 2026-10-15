# Read-only migration inspection. Rendering and exit behavior belong to workflow-kit.ps1.
if (-not (Get-Command Add-Finding -CommandType Function -ErrorAction SilentlyContinue) -or
    -not (Get-Command Test-WorkflowRepo -CommandType Function -ErrorAction SilentlyContinue) -or
    -not (Get-Command Test-WorkflowDrift -CommandType Function -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot 'workflow-kit.ps1')
}
if (-not (Get-Command Get-WorkflowPreservationGitRecords -CommandType Function -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot 'workflow-preservation.ps1')
}

function New-WorkflowMigrationDisposition {
    param([string]$Source, [string]$State, [string]$Action, [string]$Destination, [string]$Reason)
    [pscustomobject]@{ source=$Source; state=$State; action=$Action; destination=$Destination; reason=$Reason }
}

function Get-WorkflowMigrationPreview {
    param([string]$RepoRoot, [string]$KitRoot)

    $findings=[Collections.Generic.List[object]]::new()
    $dispositions=[Collections.Generic.List[object]]::new()
    $tracked=@{}
    try { $trackedPaths=@(Get-WorkflowPreservationGitRecords $RepoRoot @('ls-files','-z')) }
    catch {
        $trackedPaths=@()
        Add-Finding $findings error migration-git '.' 'Cannot inventory tracked repository paths.'
    }
    foreach ($path in $trackedPaths) { $tracked[$path.Replace('\','/')]= $true }

    $config=$null; $mode='legacy'
    try {
        $config=Get-WorkflowConfig $RepoRoot
        if ($config) { $mode='spec-first' }
    } catch {
        $mode='invalid'
        Add-Finding $findings error workflow-config '.workflow-kit.json' $_.Exception.Message
    }

    $filePlans=@(
        @('STATUS.md','retire-after-reconcile','docs/specs.md and package spec.md/tasks.md','Move current state and active work to their declared owners; preserve useful prose.'),
        @('TODO.md','retire-after-reconcile','package tasks.md or ROADMAP.md','Move executable work to tasks and durable ideas to the roadmap.'),
        @('HISTORY.md','retire-preserve-git','Git history','Retire the status file while retaining recoverable history in Git.'),
        @('.github/agents/agent.md','retire','AGENTS.md and prompts/','Remove the competing resume agent after its useful procedure is reconciled.'),
        @('AGENTS.md','review-in-place','AGENTS.md','Preserve product invariants and keep only static workflow routing.'),
        @('CLAUDE.md','reduce-to-adapter','AGENTS.md','Keep the host adapter as a pointer to the shared instruction owner.'),
        @('.github/copilot-instructions.md','migrate-sections','AGENTS.md, README.md, prompts/, and docs/operations.md','Move recognized instruction sections to their named owners and preserve product prose.'),
        @('README.md','review-in-place','README.md','Preserve the product overview and add the human migration procedure.'),
        @('INBOX.md','retain-reconcile','INBOX.md','Retain unresolved user handoffs in the bounded inbox format.'),
        @('AGENT-INBOX.md','retain-reconcile','AGENT-INBOX.md','Retain unresolved agent handoffs in the bounded inbox format.'),
        @('ROADMAP.md','review-in-place','ROADMAP.md','Preserve durable product direction without making it an execution queue.'),
        @('docs/specs.md','convert-to-catalog','docs/specs.md','Use the catalog as the package router without duplicating package state.'),
        @('.specify/feature.json','untrack-and-ignore','.gitignore','Keep the Spec Kit cursor local and non-authoritative.')
    )
    foreach ($plan in $filePlans) {
        $source=$plan[0]; $exists=Test-Path -LiteralPath (Join-Path $RepoRoot $source)
        $state=if ($tracked.ContainsKey($source)) {'tracked'} elseif ($exists) {'untracked'} else {'absent'}
        $action=if ($exists) {$plan[1]} else {'none'}
        $reason=$plan[3]; $placeholder=$false
        if ($exists -and $source -in @('STATUS.md','TODO.md','HISTORY.md')) {
            $text=[IO.File]::ReadAllText((Join-Path $RepoRoot $source)); $measure=Measure-WorkflowText $text
            $placeholder=$measure.Lines -ge 2 -and $measure.Lines -le 3 -and $text -match 'docs/specs\.md' -and $text -notmatch '(?m)^- \['
            if ($placeholder) { $action='preserve-placeholder'; $reason='Keep the catalog pointer until separately authorized prompt activation retires it.' }
        }
        $dispositions.Add((New-WorkflowMigrationDisposition $source $state $action $plan[2] $reason)) | Out-Null
        if ($mode -eq 'spec-first' -and $placeholder) {
            Add-Finding $findings info migration-retired-placeholder $source 'Valid catalog placeholder is retained until separately authorized prompt activation.'
        } elseif ($mode -eq 'spec-first' -and $source -in @('STATUS.md','TODO.md','HISTORY.md') -and $exists) {
            Add-Finding $findings error migration-retired-owner $source 'Retired root execution owner remains in a versioned repository; reconcile and retire it.'
        }
        if ($mode -eq 'spec-first' -and $source -eq '.github/agents/agent.md' -and $exists) {
            Add-Finding $findings error migration-resume-agent $source 'Competing resume agent remains live; reconcile it into AGENTS.md and prompts, then retire it.'
        }
        if ($mode -eq 'spec-first' -and $source -eq '.specify/feature.json' -and $tracked.ContainsKey($source)) {
            Add-Finding $findings error migration-feature-cursor $source 'Tracked Spec Kit cursor can compete with catalog/package selection; untrack and ignore it.'
        }
    }

    $requiredDestinations=@('AGENTS.md','README.md','docs/specs.md','.specify/templates/overrides/spec-template.md','.specify/templates/overrides/tasks-template.md')
    foreach ($source in $requiredDestinations) {
        $exists=Test-Path -LiteralPath (Join-Path $RepoRoot $source) -PathType Leaf
        if ($source -like '.specify/templates/*') {
            $state=if ($tracked.ContainsKey($source)) {'tracked'} elseif ($exists) {'untracked'} else {'absent'}
            $dispositions.Add((New-WorkflowMigrationDisposition $source $state $(if ($exists) {'review-in-place'} else {'create'}) $source 'Repo-owned package override required by the spec-first creation path.')) | Out-Null
        }
        if ($mode -eq 'spec-first' -and -not $exists) {
            Add-Finding $findings error migration-destination $source 'Required spec-first destination or template is missing.'
        }
    }

    $configState=if ($tracked.ContainsKey('.workflow-kit.json')) {'tracked'} elseif (Test-Path -LiteralPath (Join-Path $RepoRoot '.workflow-kit.json')) {'untracked'} else {'absent'}
    $configAction=if ($mode -eq 'legacy') {'add-workflow-model-version'} elseif ($mode -eq 'spec-first') {'review-in-place'} else {'repair'}
    $dispositions.Add((New-WorkflowMigrationDisposition '.workflow-kit.json' $configState $configAction '.workflow-kit.json' 'Preserve unknown product fields and external-mirror ownership while selecting the workflow model explicitly.')) | Out-Null

    $instructionPath=Join-Path $RepoRoot '.github/copilot-instructions.md'
    if (Test-Path -LiteralPath $instructionPath -PathType Leaf) {
        $sectionPlans=@(
            @('what this repo|key surfaces','README.md and AGENTS.md'),
            @('documentation structure|instruction file scope|what goes where|agent file roles','AGENTS.md'),
            @('source.of.truth|token discipline|repo boundary','AGENTS.md'),
            @('planning threshold|agent workflow|session start|during.*session|session end|inbox pattern','AGENTS.md and relevant prompts/'),
            @('history rules|^history$','Git history'),
            @('validation','AGENTS.md, README.md, and prompts/run-validation.prompt.md'),
            @('agent environment|authentication','docs/operations.md or prompts/overnight.prompt.md'),
            @('commit message|commit discipline','AGENTS.md'),
            @('autonomous continuation|maximizing run','prompts/orchestrate.prompt.md and prompts/overnight.prompt.md'),
            @('tier routing|orchestrator.*subagent|subagent execution','prompts/orchestrate.prompt.md'),
            @('model preferences','agent-loop.ps1'),
            @('cross.repo coordination','AGENTS.md'),
            @('how to use.*boilerplate|boilerplate','README.md')
        )
        foreach ($line in [IO.File]::ReadAllLines($instructionPath)) {
            if ($line -notmatch '^#{1,6}\s+(.+?)\s*$') { continue }
            $heading=$Matches[1]; $destination='owner review'; $state='unfamiliar-heading'; $action='preserve-for-review'
            foreach ($sectionPlan in $sectionPlans) {
                if ($heading -match ('(?i)'+$sectionPlan[0])) { $destination=$sectionPlan[1]; $state='recognized-heading'; $action='move-or-reconcile'; break }
            }
            $dispositions.Add((New-WorkflowMigrationDisposition ".github/copilot-instructions.md#$heading" $state $action $destination 'Preserve useful product content; headings outside the known workflow map require owner placement review.')) | Out-Null
        }
    }

    $promptRoot=Join-Path $RepoRoot 'prompts'
    if (Test-Path -LiteralPath $promptRoot -PathType Container) {
        foreach ($prompt in Get-ChildItem -LiteralPath $promptRoot -Filter '*.prompt.md' -File | Sort-Object Name) {
            $source='prompts/'+$prompt.Name; $text=[IO.File]::ReadAllText($prompt.FullName)
            $state=if ($tracked.ContainsKey($source)) {'tracked'} else {'untracked'}
            $dualMode=$text -match 'workflowModelVersion'
            $action=if ($dualMode) {'review-dual-mode'} else {'add-mode-selection'}
            $dispositions.Add((New-WorkflowMigrationDisposition $source $state $action $source 'Preserve the legacy procedure while selecting spec-first behavior from workflowModelVersion.')) | Out-Null
            if ($mode -eq 'spec-first' -and $text -match '(STATUS|TODO|HISTORY)\.md' -and -not $dualMode) {
                Add-Finding $findings error migration-live-route $source 'Prompt routes to retired owners without an explicit workflowModelVersion mode selection.'
            }
        }
    }

    $external=$config -and $config.PSObject.Properties.Name -contains 'canonicalMirrorMode' -and $config.canonicalMirrorMode -eq 'external'
    $liveRoutes=@(
        @('workflow-kit.ps1','Get-WorkflowConfig','Test-SpecWorkflowRepo','select lint mode from workflowModelVersion'),
        @('agent-loop.ps1','Get-WorkflowConfig','workflow-scheduler\.ps1','route spec-first work through the gated scheduler'),
        @('workflow-scheduler.ps1','Get-WorkflowConfig','Invoke-SpecKitWorkerPhase','run the versioned package scheduler')
    )
    foreach ($route in $liveRoutes) {
        $path=Join-Path $RepoRoot $route[0]
        if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or $external) { continue }
        $text=[IO.File]::ReadAllText($path); $compatible=$text -match $route[1] -and $text -match $route[2]
        $state=if ($tracked.ContainsKey($route[0])) {'tracked'} else {'untracked'}
        $dispositions.Add((New-WorkflowMigrationDisposition $route[0] $state $(if ($compatible) {'review-in-place'} else {'replace-incompatible-route'}) $route[0] $route[3])) | Out-Null
        if ($mode -eq 'spec-first' -and -not $compatible) {
            Add-Finding $findings error migration-live-route $route[0] 'Local validator or scheduler lacks the known spec-first routing sentinels.'
        }
    }

    $todoPath=Join-Path $RepoRoot 'TODO.md'
    $legacyLive=(Test-Path -LiteralPath $todoPath -PathType Leaf) -and ([IO.File]::ReadAllText($todoPath) -match '(?m)^\s*[-*]\s+\[ \]')
    $packageLive=$false
    foreach ($path in $tracked.Keys | Where-Object { $_ -match '^specs/[^/]+/tasks\.md$' }) {
        $taskPath=Join-Path $RepoRoot $path
        if ((Test-Path -LiteralPath $taskPath -PathType Leaf) -and [IO.File]::ReadAllText($taskPath) -match '(?m)^\s*[-*]\s+\[ \]') { $packageLive=$true; break }
    }
    if ($legacyLive -and $packageLive) {
        Add-Finding $findings error migration-task-owner 'TODO.md' 'TODO.md and package tasks.md files are both tracked execution owners; reconcile the live route before migration.'
    }
    foreach ($path in $tracked.Keys | Sort-Object) {
        if ($path -match '(^|/)(tmp|temp|\.tmp|scratch)(/|$)') {
            $dispositions.Add((New-WorkflowMigrationDisposition $path 'tracked' 'preserve-for-review' 'migration branch or declared durable owner' 'Tracked scratch is never deleted or ignored silently.')) | Out-Null
            Add-Finding $findings info migration-tracked-scratch $path 'Tracked scratch requires an explicit preserve, move, or retire decision during human migration.'
        }
    }

    if ($mode -ne 'invalid') {
        try { foreach ($finding in @(Test-WorkflowRepo $RepoRoot)) { $findings.Add($finding) | Out-Null } }
        catch { Add-Finding $findings error migration-lint '.' $_.Exception.Message }
        try { foreach ($finding in @(Test-WorkflowDrift -KitRoot $KitRoot -RepoRoot $RepoRoot)) { $findings.Add($finding) | Out-Null } }
        catch { Add-Finding $findings error migration-drift '.' $_.Exception.Message }
    }
    $status=if (@($findings | Where-Object severity -eq 'error').Count) {'incomplete'} else {'ready'}
    [pscustomobject]@{ mode=$mode; status=$status; dispositions=@($dispositions); findings=@($findings) }
}
