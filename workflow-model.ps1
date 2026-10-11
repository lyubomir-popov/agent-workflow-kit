# Shared, read-only model. No worker invocation, network, or persistent state here.
function Get-WorkflowConfig {
    param([string]$RepoRoot)
    $path = Join-Path $RepoRoot '.workflow-kit.json'
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    try {
        $raw = [IO.File]::ReadAllText($path)
        if (-not $raw.TrimStart().StartsWith('{')) { throw 'Config must be a JSON object.' }
        $config = $raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch { throw "workflow-config: invalid JSON in $path" }
    if ($config -isnot [pscustomobject]) { throw 'workflow-config: config must be an object.' }
    if (-not ($config.PSObject.Properties.Name -contains 'workflowModelVersion')) { return $null }
    if ($config.workflowModelVersion -isnot [long] -and $config.workflowModelVersion -isnot [int]) { throw 'workflow-config: version must be integer 1.' }
    if ($config.workflowModelVersion -ne 1) { throw 'workflow-config: unsupported workflowModelVersion; expected 1.' }
    $gitRoot = [string](git -C $RepoRoot rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -or [IO.Path]::GetFullPath($gitRoot) -ne [IO.Path]::GetFullPath($RepoRoot)) { throw 'workflow-config: RepoRoot must be the actual Git worktree root.' }
    foreach ($field in @('targetBranch','managedScratchRoot','disposablePatterns','autoLoadedFiles','hostBudgets','budgetExceptions')) {
        if (-not ($config.PSObject.Properties.Name -contains $field)) { throw "workflow-config: missing $field." }
    }
    if ([string]::IsNullOrWhiteSpace($config.targetBranch) -or $config.targetBranch.StartsWith('-')) { throw 'workflow-config: declare a valid targetBranch.' }
    git -C $RepoRoot check-ref-format --branch $config.targetBranch 2>$null | Out-Null
    if ($LASTEXITCODE) { throw 'workflow-config: invalid targetBranch.' }
    if ([string]::IsNullOrWhiteSpace($config.managedScratchRoot)) { throw 'workflow-config: declare managedScratchRoot.' }
    foreach ($field in @('disposablePatterns','autoLoadedFiles','hostBudgets','budgetExceptions')) {
        if ($config.$field -isnot [array]) { throw "workflow-config: $field must be an array." }
    }
    foreach ($pattern in $config.disposablePatterns) {
        if ($pattern -isnot [string] -or $pattern -notmatch '^[\w./-]+/$' -or $pattern -match '(^|/)\.\.(/|$)' -or $pattern.StartsWith('/')) {
            throw 'workflow-config: disposablePatterns must be explicit relative directory patterns.'
        }
    }
    $hostsSeen = @{}
    foreach ($budget in $config.hostBudgets) {
        if (-not $budget.host -or $hostsSeen.ContainsKey([string]$budget.host) -or $budget.lines -le 0 -or $budget.bytes -le 0) { throw 'workflow-config: invalid/duplicate host budget.' }
        $hostsSeen[[string]$budget.host] = $true
    }
    foreach ($file in $config.autoLoadedFiles) {
        if (-not $file.path -or @($file.hosts).Count -eq 0 -or $file.loading -notin @('full','on-demand','unknown')) { throw 'workflow-config: invalid autoLoadedFiles declaration.' }
        if ($file.loading -eq 'full' -and ($file.lines -le 0 -or $file.bytes -le 0)) { throw 'workflow-config: fully loaded files need line and byte budgets.' }
        foreach ($hostName in $file.hosts) { if (-not $hostsSeen.ContainsKey([string]$hostName)) { throw "workflow-config: no budget for host $hostName." } }
    }
    foreach ($exception in $config.budgetExceptions) {
        $expiry = [datetime]::MinValue
        if ((-not $exception.path -and -not $exception.host) -or -not $exception.authorization -or -not $exception.reason -or
            -not [datetime]::TryParse([string]$exception.expiry, [ref]$expiry) -or $expiry.Date -lt [datetime]::UtcNow.Date -or
            $exception.lines -le 0 -or $exception.bytes -le 0 -or $exception.path -match '[*?]' -or $exception.host -match '[*?]') {
            throw 'workflow-config: budget exception requires exact path/host, positive limits, owner authorization, reason and unexpired expiry.'
        }
    }
    return $config
}

function Get-WorkflowBranch {
    param([string]$RepoRoot)
    $branch = git -C $RepoRoot symbolic-ref --quiet --short HEAD 2>$null
    if ($LASTEXITCODE -ne 0) { return 'HEAD' }
    return [string]$branch
}

function Assert-WorkflowNoLinks {
    param([string]$Path)
    $current = [IO.Path]::GetFullPath($Path)
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "workflow-path: link/junction is forbidden: $current" }
        }
        $parent = Split-Path $current -Parent
        if ($parent -eq $current) { break }
        $current = $parent
    }
}

function Resolve-WorkflowRelativePath {
    param([string]$Root, [string]$Relative)
    if ([IO.Path]::IsPathRooted($Relative)) { throw "workflow-path: absolute path forbidden: $Relative" }
    $rootPath = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $path = [IO.Path]::GetFullPath((Join-Path $rootPath $Relative))
    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    if (-not $path.StartsWith($rootPath + [IO.Path]::DirectorySeparatorChar, $comparison)) { throw "workflow-path: path escapes owner: $Relative" }
    Assert-WorkflowNoLinks $path
    return $path
}

function Get-WorkflowScratchRoot {
    param([string]$RepoRoot, $Config)
    $raw = if ($Config) { [string]$Config.managedScratchRoot } else { '{temp}/agent-loop-worktrees' }
    $raw = $raw.Replace('{temp}', [IO.Path]::GetTempPath().TrimEnd([IO.Path]::DirectorySeparatorChar))
    $path = if ([IO.Path]::IsPathRooted($raw)) { [IO.Path]::GetFullPath($raw) } else { Resolve-WorkflowRelativePath $RepoRoot $raw }
    Assert-WorkflowNoLinks $path
    return $path
}

function Get-WorkflowScratchMarker {
    param([string]$RepoRoot)
    $admin = git -C $RepoRoot rev-parse --absolute-git-dir 2>$null
    if ($LASTEXITCODE) { return $null }
    $path = Join-Path ([string]$admin) 'workflow-kit-scratch.json'
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    try { $marker = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json } catch { throw 'workflow-scratch: invalid marker.' }
    $actual = [IO.Path]::GetFullPath($RepoRoot)
    $common = [string](git -C $RepoRoot rev-parse --path-format=absolute --git-common-dir)
    if ($LASTEXITCODE -or $marker.kind -ne 'workflow-kit-scratch-v1' -or $marker.worktree -ne $actual -or
        $marker.commonGitDir -ne $common -or $marker.base -notmatch '^[0-9a-f]{40,64}$' -or -not $marker.repo -or -not $marker.integrationBranch) { throw 'workflow-scratch: invalid marker/repo proof.' }
    $sourceCommon = [string](git -C $marker.repo rev-parse --path-format=absolute --git-common-dir 2>$null)
    if ($LASTEXITCODE -or $sourceCommon -ne $common) { throw 'workflow-scratch: integration repository mismatch.' }
    $config = Get-WorkflowConfig $marker.repo
    $root = Get-WorkflowScratchRoot $marker.repo $config
    $null = Resolve-WorkflowRelativePath $root ([IO.Path]::GetRelativePath($root, $actual))
    git -C $RepoRoot merge-base --is-ancestor $marker.base $marker.integrationBranch 2>$null
    if ($LASTEXITCODE) { throw 'workflow-scratch: invalid base/integration target.' }
    Assert-WorkflowNoLinks $actual
    return $marker
}

function Get-WorkflowCatalog {
    param([string]$RepoRoot)
    $path = Join-Path $RepoRoot 'docs/specs.md'
    if (-not (Test-Path -LiteralPath $path)) { throw 'catalog-owner: missing docs/specs.md.' }
    $section = ''; $columns = @(); $entries = @()
    foreach ($line in Get-Content -LiteralPath $path) {
        if ($line -match '^##\s+(.+)$') { $section = $Matches[1].Trim(); $columns = @(); continue }
        if ($section -notin @('Current packages','Archive') -or $line -notmatch '^\|') { continue }
        $cells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        if ($cells[0] -eq 'Spec') { $columns = $cells; continue }
        if ($cells[0] -match '^[-:]+$') { continue }
        if ($cells[0] -notmatch '^(\d{3,})\b') { throw "catalog-row: malformed identity: $line" }
        $id = $Matches[1]
        if ($columns -notcontains 'Package' -or $columns -notcontains 'Branch' -or $cells.Count -ne $columns.Count) { throw "catalog-columns: expected Spec, Package, Branch: $line" }
        $packageCell = $cells[[array]::IndexOf($columns, 'Package')]
        if ($packageCell -notmatch '\]\(\.\./(?<path>specs/[^()]+/spec\.md)\)') { throw "catalog-path: expected relative package spec link: $line" }
        $relativePath = $Matches.path -replace '/spec\.md$', ''
        if ((Split-Path $relativePath -Leaf) -notmatch ('^' + [regex]::Escape($id) + '-')) { throw "catalog-identity: package does not match $id." }
        $null = Resolve-WorkflowRelativePath $RepoRoot $relativePath
        $branch = $cells[[array]::IndexOf($columns, 'Branch')].Trim('`')
        git -C $RepoRoot check-ref-format --branch $branch 2>$null | Out-Null
        if ($LASTEXITCODE) { throw "catalog-branch: invalid branch $branch." }
        $derived = if ($columns -contains 'Lifecycle') { $cells[[array]::IndexOf($columns,'Lifecycle')].Trim('`') } else { $null }
        $entries += [pscustomobject]@{ Id=$id; RelativePath=$relativePath; Branch=$branch; Archived=($section -eq 'Archive'); DerivedLifecycle=$derived }
    }
    return $entries
}

function Read-WorkflowPackageFile {
    param($Package, [string]$Name)
    if ($Package.Local) {
        $path = Resolve-WorkflowRelativePath $Package.AbsolutePath $Name
        if (Test-Path -LiteralPath $path -PathType Leaf) { return [IO.File]::ReadAllText($path) }
        return $null
    }
    $text = git -C $Package.RepoRoot show "$($Package.Branch):$($Package.RelativePath)/$Name" 2>$null
    if ($LASTEXITCODE) { return $null }
    return ($text -join "`n") + "`n"
}

function Get-WorkflowPackages {
    param([string]$RepoRoot)
    $worktrees = @(); $worktree = $null
    foreach ($line in (git -C $RepoRoot worktree list --porcelain)) {
        if ($line -match '^worktree (.+)$') { $worktree = $Matches[1] }
        if ($line -match '^branch refs/heads/(.+)$') { $worktrees += [pscustomobject]@{Path=$worktree; Branch=$Matches[1]} }
    }
    if ($LASTEXITCODE) { throw 'workflow-git: cannot list worktrees.' }
    $current = Get-WorkflowBranch $RepoRoot
    $marker = if ($current -eq 'HEAD') { Get-WorkflowScratchMarker $RepoRoot } else { $null }
    $packages = @()
    foreach ($entry in @(Get-WorkflowCatalog $RepoRoot)) {
        $local = @($worktrees | Where-Object Branch -eq $entry.Branch | Select-Object -First 1)
        $localRoot = if ($entry.Archived -or $current -eq $entry.Branch -or ($marker -and $marker.integrationBranch -eq $entry.Branch)) { $RepoRoot }
            elseif ($local.Count) { $local[0].Path } else { $null }
        $package = [pscustomobject]@{
            Id=$entry.Id; RelativePath=$entry.RelativePath; Branch=$entry.Branch; Archived=$entry.Archived
            DerivedLifecycle=$entry.DerivedLifecycle; RepoRoot=$RepoRoot; Local=[bool]$localRoot
            WorktreeRoot=$localRoot; AbsolutePath=if ($localRoot) { Resolve-WorkflowRelativePath $localRoot $entry.RelativePath } else { $null }
            Lifecycle=$null; Scope=$null; SupersededScopes=@(); SupersededTasks=@(); Checkpoints=@(); SpecText=$null; Header=$null
        }
        $spec = Read-WorkflowPackageFile $package 'spec.md'
        if (-not $spec) {
            $source=if ($entry.Archived) { 'current checkout (archived package)' } else { "declared branch $($entry.Branch)" }
            throw "package-owner: $($entry.RelativePath)/spec.md missing on $source."
        }
        $header = ($spec -split '(?m)^##\s', 2)[0]
        $lifecycle = [regex]::Matches($spec, '(?m)^\*\*Lifecycle\*\*:\s*([a-z-]+)\s*$')
        if ($lifecycle.Count -ne 1 -or $lifecycle[0].Groups[1].Value -notin @('draft','review','ready','active','parked','delivered','closed','superseded')) { throw "lifecycle-block: invalid/duplicate lifecycle in $($entry.RelativePath)." }
        $package.Lifecycle = $lifecycle[0].Groups[1].Value
        if ($header -notmatch '(?m)^\*\*Feature branch\*\*:\s*`([^`]+)`') { throw "package-branch: missing Feature branch in $($entry.RelativePath)." }
        if ($Matches[1] -ne $entry.Branch) { throw "package-branch: spec/catalog branch mismatch in $($entry.RelativePath)." }
        if ($header -notmatch '(?m)^\*\*Scope\*\*:\s*`([^`]+)`') { throw "scope-block: missing Scope in $($entry.RelativePath)." }
        $package.Scope = $Matches[1]
        $scopeLine = [regex]::Match($header, '(?m)^\*\*Scope\*\*:(.+)$').Groups[1].Value
        $package.SupersededScopes = @([regex]::Matches($scopeLine, '`([^`]+)`') | Select-Object -Skip 1 | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ -match '/' })
        if ($header -notmatch '(?m)^\*\*Superseded tasks\*\*:(.+)$') { throw "scope-block: missing Superseded tasks in $($entry.RelativePath)." }
        $package.SupersededTasks = @([regex]::Matches($Matches[1], '\bT\d{3,}\b') | ForEach-Object Value)
        if ($header -notmatch '(?m)^\*\*Checkpoints\*\*:\s*$' -or $header -notmatch '\| ID \| Gate \| Verdict link \| State \|') { throw "checkpoint-block: missing checkpoint table in $($entry.RelativePath)." }
        $seen = @{}
        foreach ($line in ($header -split "`r?`n")) {
            if ($line -notmatch '^\|\s*(CP\d+)\s*\|') { continue }
            $cells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
            if ($cells.Count -ne 4 -or $cells[3] -notin @('pending','findings-received','owner-cleared','superseded') -or $seen.ContainsKey($cells[0])) { throw "checkpoint-block: invalid/duplicate checkpoint in $($entry.RelativePath)." }
            $seen[$cells[0]]=$true
            $package.Checkpoints += [pscustomobject]@{Id=$cells[0]; Gate=$cells[1]; Links=$cells[2]; State=$cells[3]}
        }
        if (-not $package.Checkpoints.Count) { throw "checkpoint-block: empty checkpoint table in $($entry.RelativePath)." }
        $package.SpecText=$spec; $package.Header=$header
        $packages += $package
    }
    return $packages
}

function Get-WorkflowTasks {
    param($Package)
    $text = Read-WorkflowPackageFile $Package 'tasks.md'
    if (-not $text) { return @() }
    $header = ($text -split '(?m)^##\s',2)[0]
    if ($header -notmatch '(?m)^\*\*Entry checkpoint\*\*:\s*(CP\d+)\s*$') { throw "task-gate: missing Entry checkpoint in $($Package.RelativePath)/tasks.md." }
    $defaultGate = $Matches[1]; $seen=@{}; $tasks=@(); $index=0
    foreach ($line in ($text -split "`r?`n")) {
        if ($line -match '^\s*- \[([ xX])\] (T\d{3,})\s+(.+)$') {
            $id=$Matches[2]; $done=$Matches[1] -ne ' '; $description=$Matches[3]
            if ($seen.ContainsKey($id)) { throw "task-identity: duplicate $id in $($Package.RelativePath)." }
            $seen[$id]=$true
            $gate=if ($description -match '\(gate: (CP\d+)\)') { $Matches[1] } else { $defaultGate }
            if ($gate -notin @($Package.Checkpoints.Id)) { throw "task-gate: unknown $gate for $id." }
            $tasks += [pscustomobject]@{Id=$id; Text="$id $description"; Complete=$done; Gate=$gate; Manual=($description -match '\(manual\)'); LineIndex=$index; SpecPackage=$Package; Kind='spec-checkbox'}
        } elseif ($line -match '^\s*- \[[ xX]\]') { throw "task-identity: checklist needs a stable Tnnn ID in $($Package.RelativePath)." }
        $index++
    }
    return $tasks
}

function Get-WorkflowGateProblem {
    param($Package, [string]$Gate)
    $checkpoint = @($Package.Checkpoints | Where-Object Id -eq $Gate)
    if ($checkpoint.Count -ne 1 -or $checkpoint[0].State -ne 'owner-cleared') { return "$Gate is not owner-cleared; stop for owner acceptance." }
    $links = [regex]::Matches($checkpoint[0].Links, '\]\(([^)#]+)(?:#[^)]*)?\)')
    if (-not $links.Count) { return "$Gate lacks a saved verdict link." }
    $accepted = $false; $scopeMismatch = $false; $acceptedScope = $false
    foreach ($link in $links) {
        $name=$link.Groups[1].Value
        if (-not $name.StartsWith('reviews/') -or $name -match '\.\.') { return "$Gate review link must stay in package reviews/." }
        $review=Read-WorkflowPackageFile $Package $name
        if (-not $review) { return "$Gate saved review is missing: $name." }
        if ($review -match '(?m)^\*\*Checkpoint\*\*:\s*(CP\d+)\s*$' -and $Matches[1] -ne $Gate) { return "$Gate verdict names a different checkpoint: $name." }
        if ($review -match '(?im)^[-* ]*\*?\*?Verdict\*?\*?:\s*\*?\*?(reject|blocking|superseded)\b') { return "$Gate verdict is blocking or superseded: $name." }
        if ($review -match '(?im)^[-* ]*\*?\*?Verdict\*?\*?:\s*\*?\*?accept\b') {
            if ($review -notmatch '(?im)^[-* ]*\*?\*?Reviewer\*?\*?:\s*\S' -or $review -notmatch '(?im)^[-* ]*\*?\*?Reviewed revision\*?\*?:\s*\S') { return "$Gate verdict lacks actual reviewer or reviewed revision: $name." }
            $accepted=$true
        }
        if ($review -match '(?m)^\*\*Scope\*\*:\s*`?([^`\r\n]+)') { if ($Matches[1].Trim() -ne $Package.Scope) { $scopeMismatch=$true } }
        if ($review -match '(?m)^\*\*Accepted scope\*\*:\s*`?([^`\r\n]+)') { if ($Matches[1].Trim() -eq $Package.Scope) { $acceptedScope=$true } }
    }
    if (-not $accepted) { return "$Gate lacks an accepted saved verdict." }
    if ($scopeMismatch -and -not $acceptedScope) { return "$Gate verdict scope is obsolete; owner acceptance for $($Package.Scope) is required." }
    return $null
}

function Select-WorkflowPackage {
    param([string]$RepoRoot, [string]$Selection)
    $packages=@(Get-WorkflowPackages $RepoRoot); $branch=Get-WorkflowBranch $RepoRoot
    $marker=if ($branch -eq 'HEAD') { Get-WorkflowScratchMarker $RepoRoot } else { $null }
    $effective=if ($marker) { $marker.integrationBranch } else { $branch }
    if ($Selection) {
        $selectedPath=if ([IO.Path]::IsPathRooted($Selection)) { [IO.Path]::GetFullPath($Selection) } else { Resolve-WorkflowRelativePath $RepoRoot $Selection }
        $matches=@($packages | Where-Object { (Resolve-WorkflowRelativePath $RepoRoot $_.RelativePath) -eq $selectedPath })
    } else { $matches=@($packages | Where-Object { -not $_.Archived -and $_.Branch -eq $effective }) }
    if ($matches.Count -ne 1) { throw 'package-selection: select exactly one catalog-declared package; the local cursor is not an owner.' }
    if ($matches[0].Branch -ne $effective) { throw "package-selection: checkout $($matches[0].Branch); package edits on $branch are forbidden." }
    return $matches[0]
}
