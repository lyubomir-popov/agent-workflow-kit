# Versioned mechanical checks. Loaded by workflow-kit.ps1 after report helpers.
function Measure-WorkflowText {
    param([AllowEmptyString()][string]$Text)
    $lines = if ($Text.Length -eq 0) { 0 } else { [regex]::Matches($Text, "`n").Count + [int](-not $Text.EndsWith("`n")) }
    return [pscustomobject]@{Lines=$lines; Bytes=[Text.Encoding]::UTF8.GetByteCount($Text)}
}

function Test-WorkflowBudget {
    param($Findings, $Config, [string]$Path, [string]$Text, [int]$Lines, [int]$Bytes, [string]$HostName='')
    foreach ($exception in $Config.budgetExceptions) {
        if (($HostName -and $exception.host -eq $HostName) -or (-not $HostName -and $exception.path -eq $Path)) {
            $Lines=[int]$exception.lines; $Bytes=[int]$exception.bytes
        }
    }
    $measure=Measure-WorkflowText $Text
    if ($measure.Lines -gt $Lines -or $measure.Bytes -gt $Bytes) {
        $rule=if ($HostName) { 'budget-aggregate' } else { 'budget-file' }
        Add-Finding $Findings error $rule $Path "Measured $($measure.Lines) lines/$($measure.Bytes) UTF-8 bytes; maximum $Lines/$Bytes. Move detail to package owners or on-demand docs; exceptions need owner authorization, reason and expiry."
    }
}

function Test-WorkflowLinks {
    param($Findings, [string]$RepoRoot, [string]$Relative, [string]$Text)
    foreach ($link in [regex]::Matches($Text, '\]\(([^)]+)\)')) {
        $target=$link.Groups[1].Value.Trim('<','>') -split '#',2 | Select-Object -First 1
        if (-not $target -or $target -match '^https?://') { continue }
        try {
            $base=Split-Path (Join-Path $RepoRoot $Relative) -Parent
            $absolute=[IO.Path]::GetFullPath((Join-Path $base $target))
            $relativeTarget=[IO.Path]::GetRelativePath($RepoRoot,$absolute)
            $absolute=Resolve-WorkflowRelativePath $RepoRoot $relativeTarget
            if (-not (Test-Path -LiteralPath $absolute)) { Add-Finding $Findings error owner-link $Relative "Missing local owner/link $target; repair the pointer or preserve its artifact." }
        } catch { Add-Finding $Findings error owner-link $Relative "Unsafe link $target; keep routing within the repository." }
    }
}

function Get-WorkflowTriggerReport {
    param([string]$RepoRoot)
    $hookPath=git -C $RepoRoot rev-parse --git-path hooks/pre-commit 2>$null
    $hook=if ($hookPath) { if ([IO.Path]::IsPathRooted($hookPath)) { $hookPath } else { Join-Path $RepoRoot $hookPath } } else { '' }
    $hasKitHook=$hook -and (Test-Path -LiteralPath $hook -PathType Leaf) -and ([IO.File]::ReadAllText($hook) -match 'workflow-hook\.ps1|\.githooks/pre-commit')
    return [pscustomobject]@{
        workerPreflight='workflow-kit lint -Strict before dispatch'
        localCommitHook=if ($hasKitHook) { $hook } else { 'gap: no installed kit pre-commit check (existing hooks must be composed)' }
        ci=if (Test-Path -LiteralPath (Join-Path $RepoRoot '.github/workflows/workflow.yml')) { 'workflow.yml configured; remote execution not verified' } else { 'gap: no kit CI workflow' }
        instructions='manual session start/end and scope-change checks; host compliance cannot be enforced'
    }
}

function Test-SpecWorkflowRepo {
    param([string]$RepoRoot, $Config)
    $findings=[Collections.Generic.List[object]]::new()
    $contents=@{}
    foreach ($relative in @('AGENTS.md','CLAUDE.md','.github/copilot-instructions.md','README.md','docs/specs.md','AGENT-INBOX.md','INBOX.md','.specify/memory/constitution.md')) {
        $path=Resolve-WorkflowRelativePath $RepoRoot $relative
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Add-Finding $findings error owner-missing $relative 'Required owner or host adapter missing; restore its static pointer.'; continue }
        $contents[$relative]=[IO.File]::ReadAllText($path)
    }
    foreach ($relative in @('AGENTS.md','CLAUDE.md')) {
        if ($contents[$relative] -match '(?i)<!--\s*SPECKIT\b') { Add-Finding $findings error marker-injection $relative 'Remove vendor SPECKIT marker blocks; plan references belong in the package.' }
    }
    if ($contents['CLAUDE.md'] -and $contents['CLAUDE.md'].Trim() -cne '@AGENTS.md') { Add-Finding $findings error adapter-pointer 'CLAUDE.md' 'CLAUDE.md must contain only @AGENTS.md.' }
    if ($contents['.github/copilot-instructions.md'] -and $contents['.github/copilot-instructions.md'] -notmatch 'AGENTS\.md') { Add-Finding $findings error adapter-pointer '.github/copilot-instructions.md' 'Point to AGENTS.md.' }
    if ($contents['AGENTS.md'] -notmatch 'docs/specs\.md') { Add-Finding $findings error static-routing 'AGENTS.md' 'Route statically to docs/specs.md.' }
    if ($contents['AGENTS.md'] -match '(?i)specs/\d{3,}-|\bCP\d+\b|\*\*(Lifecycle|Next tasks)\*\*:') { Add-Finding $findings error static-routing 'AGENTS.md' 'Feature-specific state belongs in catalog/spec/tasks, never AGENTS.md.' }
    $liveCatalog=if ($contents['docs/specs.md']) { [regex]::Replace($contents['docs/specs.md'], '(?ms)^## Archive\s*\r?\n.*?(?=^## |\z)', '') } else { '' }
    $surfaces=@{
        'AGENTS.md'=@(100,12288); 'CLAUDE.md'=@(15,2048); '.github/copilot-instructions.md'=@(15,2048)
        'AGENT-INBOX.md'=@(60,8192); 'docs/specs.md'=@(100,12288)
    }
    foreach ($relative in $surfaces.Keys) {
        if ($contents.ContainsKey($relative)) {
            $text=if ($relative -eq 'docs/specs.md') { $liveCatalog } else { $contents[$relative] }
            Test-WorkflowBudget $findings $Config $relative $text $surfaces[$relative][0] $surfaces[$relative][1]
        }
    }
    foreach ($relative in @('AGENTS.md','CLAUDE.md','.github/copilot-instructions.md','docs/specs.md','INBOX.md','AGENT-INBOX.md')) {
        $text=if ($relative -eq 'docs/specs.md') { $liveCatalog } else { $contents[$relative] }
        Test-WorkflowLinks $findings $RepoRoot $relative $text
        if ($text -match '(?i)\b(STATUS|TODO|HISTORY)\.md') { Add-Finding $findings error retired-router $relative 'Remove retired execution routing; use catalog/spec/tasks. Historical procedure docs load on demand.' }
    }
    if (Test-Path -LiteralPath (Join-Path $RepoRoot '.github/agents/agent.md')) { Add-Finding $findings error retired-router '.github/agents/agent.md' 'Retire the competing resume agent.' }
    foreach ($relative in @('STATUS.md','TODO.md','HISTORY.md')) {
        $path=Join-Path $RepoRoot $relative
        if (Test-Path -LiteralPath $path) {
            $text=[IO.File]::ReadAllText($path); $measure=Measure-WorkflowText $text
            if ($measure.Lines -lt 2 -or $measure.Lines -gt 3 -or $text -notmatch 'docs/specs\.md' -or $text -match '(?m)^- \[') { Add-Finding $findings error retired-owner $relative 'During A keep only a 2–3 line catalog placeholder; preserve useful content in its owner or Git.' }
        }
    }
    if ($contents['.specify/memory/constitution.md'] -match '(?i)\bSpec \d{3}\b|\bCP\d+\b|\*\*Lifecycle\*\*:|current operating instructions') { Add-Finding $findings error constitution-state '.specify/memory/constitution.md' 'Keep durable principles only; remove live operational state.' }
    $cursor=git -C $RepoRoot ls-files -- .specify/feature.json
    if ($cursor) { Add-Finding $findings error feature-cursor '.specify/feature.json' 'git rm --cached the local convenience cursor and ignore it.' }
    git -C $RepoRoot check-ignore --no-index --quiet .specify/feature.json
    if ($LASTEXITCODE) { Add-Finding $findings error feature-cursor '.gitignore' 'Ignore .specify/feature.json; it cannot own package selection.' }
    git -C $RepoRoot rev-parse --verify "$($Config.targetBranch)^{commit}" 2>$null | Out-Null
    if ($LASTEXITCODE) { Add-Finding $findings error target-branch '.workflow-kit.json' "Configured target $($Config.targetBranch) is unavailable locally; do not assume main." }
    $loaded=@{}; $declared=@{}
    foreach ($file in $Config.autoLoadedFiles) {
        foreach ($hostName in $file.hosts) {
            $key="$hostName/$($file.path)"
            if ($declared.ContainsKey($key)) { Add-Finding $findings error inventory-duplicate '.workflow-kit.json' "Duplicate inventory entry $key." }
            $declared[$key]=$true
        }
        if ($file.loading -eq 'unknown') { Add-Finding $findings info host-loading-gap $file.path "Unknown host loading for $($file.hosts -join ', '); count cannot be verified as zero."; continue }
        try { $path=Resolve-WorkflowRelativePath $RepoRoot $file.path } catch { Add-Finding $findings error inventory-path $file.path $_.Exception.Message; continue }
        if (-not (Test-Path -LiteralPath $path)) { Add-Finding $findings error inventory-missing $file.path 'Declared host asset is missing; repair inventory.'; continue }
        if ($file.loading -eq 'on-demand') { continue }
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Add-Finding $findings error inventory-path $file.path 'Full host loading must name a file, not a directory.'; continue }
        $text=[IO.File]::ReadAllText($path)
        Test-WorkflowBudget $findings $Config $file.path $text $file.lines $file.bytes
        foreach ($hostName in $file.hosts) {
            if (-not $loaded.ContainsKey($hostName)) { $loaded[$hostName]='' }
            $loaded[$hostName]+=$text + $(if (-not $text.EndsWith("`n")) { "`n" } else { '' })
        }
    }
    # Every supported host must inventory its actual root instruction/adapter surface.
    $requiredInventory=@{
        'codex'=@('AGENTS.md'); 'claude-code'=@('AGENTS.md','CLAUDE.md')
        'copilot-chat'=@('AGENTS.md','CLAUDE.md','.github/copilot-instructions.md'); 'copilot-cli'=@('AGENTS.md','.github/copilot-instructions.md')
    }
    foreach ($hostName in $requiredInventory.Keys) {
        foreach ($relative in $requiredInventory[$hostName]) {
            if (-not $declared.ContainsKey("$hostName/$relative")) { Add-Finding $findings error inventory-missing '.workflow-kit.json' "Declare $relative for $hostName; omitted content cannot evade aggregate checks." }
        }
    }
    foreach ($budget in $Config.hostBudgets) {
        $text=if ($loaded.ContainsKey($budget.host)) { $loaded[$budget.host] } else { '' }
        Test-WorkflowBudget $findings $Config "host/$($budget.host)" $text ([Math]::Min(150,$budget.lines)) ([Math]::Min(16384,$budget.bytes)) $budget.host
    }
    try { $packages=@(Get-WorkflowPackages $RepoRoot) }
    catch { Add-Finding $findings error ($_.Exception.Message -split ':',2)[0] 'docs/specs.md' $_.Exception.Message; return @($findings) }
    $identities=@{}
    foreach ($directory in Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'specs') -Directory -ErrorAction SilentlyContinue) {
        if ($directory.Name -match '^(\d{3,})-') {
            $id=$Matches[1]
            if (@($packages | Where-Object Id -eq $id).Count -ne 1) { Add-Finding $findings error catalog-identity 'docs/specs.md' "Retained package $($directory.Name) must have exactly one catalog owner; identities stay reserved." }
        }
    }
    $currentBranch=Get-WorkflowBranch $RepoRoot
    $marker=if ($currentBranch -eq 'HEAD') { Get-WorkflowScratchMarker $RepoRoot } else { $null }
    $effective=if ($marker) { $marker.integrationBranch } else { $currentBranch }
    $changed=@(git -C $RepoRoot diff --name-only HEAD -- specs/; git -C $RepoRoot ls-files --others --exclude-standard -- specs/)
    $candidateBlock=[regex]::Match($liveCatalog, '(?ms)^## Candidates\s*\n(.*?)(?=^## |\z)').Groups[1].Value
    $candidates=@($candidateBlock -split "`r?`n" | Where-Object { ($_ -match '^\|' -and $_ -notmatch '^\|\s*(Idea|Spec|[-:]+)\s*\|') -or $_ -match '^- ' })
    if ($candidates.Count -gt 10) { Add-Finding $findings error catalog-candidates 'docs/specs.md' 'Keep at most ten candidates; move overflow to ROADMAP.md.' }
    foreach ($package in $packages) {
        if ($identities.ContainsKey($package.Id)) { Add-Finding $findings error catalog-identity 'docs/specs.md' "Duplicate package ID $($package.Id); preserve original paths/numbers." }
        $identities[$package.Id]=$true
        if ($package.DerivedLifecycle -and $package.DerivedLifecycle -ne $package.Lifecycle) { Add-Finding $findings error catalog-lifecycle 'docs/specs.md' "Lifecycle view disagrees with $($package.RelativePath)/spec.md on $($package.Branch)." }
        if ($package.Lifecycle -eq 'delivered' -and -not $package.Archived) { Add-Finding $findings error catalog-archive 'docs/specs.md' "Move delivered $($package.Id) to Archive without moving its package." }
        if (-not $package.Archived -and @($changed | Where-Object { $_.StartsWith($package.RelativePath+'/') }).Count -and $effective -ne $package.Branch) { Add-Finding $findings error package-branch $package.RelativePath "Package edits on $effective are forbidden; checkout declared $($package.Branch)." }
        $tasksText=Read-WorkflowPackageFile $package 'tasks.md'
        if ($package.Lifecycle -eq 'active' -and -not $tasksText) { Add-Finding $findings error task-owner $package.RelativePath 'Active package needs tasks.md.' }
        $tasks=@()
        if ($tasksText) {
            $header=($tasksText -split '(?m)^##\s',2)[0]
            Test-WorkflowBudget $findings $Config "$($package.RelativePath)/tasks.md#current-work" $header 25 4096
            if ($header -notmatch '^# Current work' -or $header -notmatch '\*\*Next tasks\*\*:' -or $header -notmatch '\*\*Blockers\*\*:' -or $header -notmatch '\*\*Checkpoint links\*\*:') { Add-Finding $findings error task-header $package.RelativePath 'Current work header must name next task IDs, blockers and checkpoint links.' }
            if ($header -match '\*\*(Lifecycle|Checkpoints)\*\*:|\b(owner-cleared|findings-received)\b') { Add-Finding $findings error task-header $package.RelativePath 'Link lifecycle/gates; do not duplicate their state in tasks.md.' }
            try { $tasks=@(Get-WorkflowTasks $package) } catch { Add-Finding $findings error task-identity $package.RelativePath $_.Exception.Message }
            if ($header -match '(?m)^\*\*Next tasks\*\*:(.+)$') {
                foreach ($id in @([regex]::Matches($Matches[1], '\bT\d{3,}\b') | ForEach-Object Value)) {
                    if ($id -notin $tasks.Id -or @($tasks | Where-Object { $_.Id -eq $id -and $_.Complete }).Count) { Add-Finding $findings error task-next $package.RelativePath "Next task $id is missing/completed; reconcile current-work header." }
                }
            }
            Test-WorkflowLinks $findings $(if ($package.Local) { $package.WorktreeRoot } else { $RepoRoot }) "$($package.RelativePath)/tasks.md" $header
        }
        foreach ($checkpoint in $package.Checkpoints | Where-Object State -eq 'owner-cleared') {
            $problem=Get-WorkflowGateProblem $package $checkpoint.Id
            if ($problem) { Add-Finding $findings error checkpoint-verdict $package.RelativePath $problem }
        }
        if (-not $package.Archived -and $package.Local) {
            $reviews=Join-Path $package.AbsolutePath 'reviews'
            if (Test-Path -LiteralPath $reviews) {
                foreach ($request in Get-ChildItem -LiteralPath $reviews -Filter '*request*.md' -File) {
                    Test-WorkflowBudget $findings $Config "$($package.RelativePath)/reviews/$($request.Name)" ([IO.File]::ReadAllText($request.FullName)) 30 6144
                }
            }
        }
        foreach ($relative in @('AGENT-INBOX.md','INBOX.md')) {
            foreach ($line in ($contents[$relative] -split "`r?`n")) {
                if ($line -notmatch $package.RelativePath -and $line -notmatch ('\b'+[regex]::Escape($package.Scope)+'\b') -and $line -notmatch ('\b'+[regex]::Escape($package.Id)+'/')) { continue }
                $stale=$package.Lifecycle -in @('closed','superseded','delivered')
                foreach ($id in @($package.SupersededScopes)+@($package.SupersededTasks)+@($tasks | Where-Object Complete | ForEach-Object Id)) {
                    if ($line -match ('(?<![\w/-])'+[regex]::Escape($id)+'(?![\w/-])')) { $stale=$true }
                }
                if ($stale) { Add-Finding $findings error stale-handoff $relative "Handoff points at ended scope/task in $($package.RelativePath); transfer/resolve it durably before removal." }
            }
        }
    }
    foreach ($relative in @('INBOX.md','AGENT-INBOX.md')) {
        foreach ($line in ($contents[$relative] -split "`r?`n" | Where-Object { $_ -match '^[-*] ' })) {
            if ($line -notmatch '(?i)recipient:' -or $line -notmatch '(?i)scope:' -or $line -notmatch '(?i)action:' -or $line -notmatch '\]\([^)]+\)') { Add-Finding $findings error handoff-shape $relative 'Handoff needs recipient, scope, artifact link and requested action; unread valid entries may remain.' }
        }
    }
    $triggers=Get-WorkflowTriggerReport $RepoRoot
    if ($triggers.localCommitHook -like 'gap:*') { Add-Finding $findings info enforcement-gap '.githooks/pre-commit' $triggers.localCommitHook }
    if ($triggers.ci -like 'gap:*') { Add-Finding $findings info enforcement-gap '.github/workflows/workflow.yml' $triggers.ci }
    Add-Finding $findings info semantic-limit 'docs/specs.md' 'Mechanical checks do not establish prose freshness; compare live routing to current package scope at scope reset/closeout.'
    return @($findings)
}
