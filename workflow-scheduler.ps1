# Spec-first scheduler functions; worker process primitives are in agent-loop.ps1.
function Read-WorkflowRevisionFile {
    param([string]$RepoPath, [string]$Revision, [string]$Path)
    $content=@(git -C $RepoPath show "${Revision}:$Path" 2>$null)
    if ($LASTEXITCODE) { return $null }
    return ($content -join "`n") + "`n"
}

function Assert-WorkflowWorkerRange {
    param([string]$RepoPath, [string]$BaseCommit, [string]$HeadCommit,
        [string]$PackagePath, [string]$TaskId)
    git -C $RepoPath merge-base --is-ancestor $BaseCommit $HeadCommit
    if ($LASTEXITCODE) { throw 'worker-incomplete: worker range no longer descends from its base.' }
    $revisions=@(git -C $RepoPath rev-list --reverse "$BaseCommit..$HeadCommit")
    if ($LASTEXITCODE) { throw 'worker-incomplete: cannot inspect worker range.' }
    # Inspect each revision against the base, including changes reverted later.
    foreach ($revision in $revisions) {
        $names=@(git -C $RepoPath diff --name-only --no-renames -z $BaseCommit $revision)
        if ($LASTEXITCODE) { throw 'worker-incomplete: cannot inspect changed paths.' }
        foreach ($path in (($names -join "`n") -split "`0" | Where-Object { $_ })) {
            if ($path -notmatch '(^|/)(spec\.md|tasks\.md)$' -and $path -notmatch '(^|/)reviews/') { continue }
            $before=Read-WorkflowRevisionFile $RepoPath $BaseCommit $path
            $after=Read-WorkflowRevisionFile $RepoPath $revision $path
            if ($path -match '(^|/)spec\.md$') {
                $beforeHeader=if ($null -ne $before) { ($before -split '(?m)^##\s',2)[0] } else { $null }
                $afterHeader=if ($null -ne $after) { ($after -split '(?m)^##\s',2)[0] } else { $null }
                if ($beforeHeader -cne $afterHeader) { throw "worker-incomplete: owner spec block changed at $revision ($path)." }
            }
            if ($path -match '(^|/)reviews/' -and $after -match '(?im)^.*\bVerdict(?:\*\*)?:') {
                throw "worker-incomplete: review verdict added or modified at $revision ($path)."
            }
            if ($path -match '(^|/)tasks\.md$') {
                $completedBefore=@([regex]::Matches([string]$before,'(?m)^\s*- \[[xX]\] (T\d{3,})\b') | ForEach-Object { $_.Groups[1].Value })
                $completedAfter=@([regex]::Matches([string]$after,'(?m)^\s*- \[[xX]\] (T\d{3,})\b') | ForEach-Object { $_.Groups[1].Value })
                foreach ($id in $completedAfter) {
                    if ($id -notin $completedBefore -and ($id -ne $TaskId -or $path -cne "$PackagePath/tasks.md")) {
                        throw "worker-incomplete: unrelated task $id newly completed at $revision ($path)."
                    }
                }
            }
        }
    }
}

function Assert-WorkflowPreflight {
    param([string]$RepoPath)
    $output = & pwsh -NoLogo -NoProfile -File "$PSScriptRoot/workflow-kit.ps1" -Command lint -RepoRoot $RepoPath -Strict -Json
    if ($LASTEXITCODE) { throw "preflight-incomplete: quick health check failed. $($output -join ' ')" }
    return ($output -join "`n" | ConvertFrom-Json)
}

function Switch-WorkflowBranch {
    param([string]$RepoPath, [string]$Branch)
    git -C $RepoPath rev-parse --verify "$Branch^{commit}" 2>$null | Out-Null
    if ($LASTEXITCODE) { throw "checkout-incomplete: declared branch $Branch is unavailable." }
    git -C $RepoPath checkout $Branch 2>$null | Out-Null
    if ($LASTEXITCODE -or (Get-WorkflowBranch $RepoPath) -ne $Branch) { throw "checkout-incomplete: failed to checkout $Branch; no worker dispatched." }
}

function Assert-WorkflowWorkerScope {
    param([string]$RepoPath, $Package, $Config)
    if ((Get-WorkflowBranch $RepoPath) -ne $Package.Branch) { throw 'worker-scope: wrong integration branch.' }
    git -C $RepoPath merge-base --is-ancestor $Config.targetBranch HEAD
    if ($LASTEXITCODE) { throw "worker-scope: package head does not include configured base $($Config.targetBranch); owner reconciliation required." }
    if (@(Get-WorkingTreeStatus -RepoPath $RepoPath).Count) { throw 'integration-incomplete: primary worktree is dirty; preserve changes before launch.' }
    $next=@(Get-WorkflowTasks $Package | Where-Object { -not $_.Complete } | Select-Object -First 1)
    if ($Package.Lifecycle -ne 'active') { throw 'worker-scope: package is not active.' }
    if ($next.Count) {
        $problem=Get-WorkflowGateProblem $Package $next[0].Gate
        if ($problem) { throw "checkpoint-incomplete: $problem" }
    }
}

function Start-WorkflowScheduler {
    param([string]$RepoPath, $Config)
    $null=Assert-WorkflowPreflight $RepoPath
    $packages=@(Get-WorkflowPackages $RepoPath | Where-Object { -not $_.Archived })
    $invocations=0; $active=0
    foreach ($package in $packages) {
        if ($package.Lifecycle -ne 'active') {
            if ($DryRun) { Write-Host "Not actionable: $($package.RelativePath) lifecycle=$($package.Lifecycle)" }
            continue
        }
        $active++
        if ($MaxSpecs -gt 0 -and $active -gt $MaxSpecs) { break }
        $tasks=@(Get-WorkflowTasks $package | Where-Object { -not $_.Complete })
        if (-not $tasks.Count) {
            Write-Host "Incomplete: $($package.RelativePath) has no unchecked tasks; declared exit reviews still require owner acceptance. No review started."
            if (-not $DryRun) { throw 'scheduler-incomplete: active package has no authorized task; reconcile exit checkpoints and lifecycle with the owner.' }
            continue
        }
        $problem=Get-WorkflowGateProblem $package $tasks[0].Gate
        if ($DryRun) {
            Write-Host "Dry run: $($package.RelativePath) branch=$($package.Branch) target=$($Config.targetBranch) worktree=$($package.WorktreeRoot)"
            if ($problem) { Write-Host "Stopped: $problem"; continue }
            foreach ($task in $tasks) {
                $gateProblem=Get-WorkflowGateProblem $package $task.Gate
                if ($gateProblem) { Write-Host "Stopped before $($task.Id): $gateProblem"; break }
                Write-Host "  $($task.Text)"
            }
            continue
        }
        if ($problem) { throw "checkpoint-incomplete: $problem" }
        $executionRoot=if ($package.Local) { $package.WorktreeRoot } else { $RepoPath }
        Switch-WorkflowBranch $executionRoot $package.Branch
        while ($true) {
            $null=Assert-WorkflowPreflight $executionRoot
            $fresh=@(Get-WorkflowPackages $executionRoot | Where-Object Id -eq $package.Id)
            if ($fresh.Count -ne 1) { throw 'package-incomplete: package ownership changed.' }
            $package=$fresh[0]
            Assert-WorkflowWorkerScope $executionRoot $package $Config
            $remaining=@(Get-WorkflowTasks $package | Where-Object { -not $_.Complete })
            if (-not $remaining.Count) { Write-Host "Implementation tasks complete for $($package.Id); stop for declared owner checkpoints. No review started."; break }
            if ($MaxTasks -gt 0 -and $invocations -ge $MaxTasks) { throw 'scheduler-incomplete: invocation cap reached with required tasks remaining.' }
            $task=$remaining[0]
            $before=Read-WorkflowPackageFile $package 'tasks.md'
            $invocations++
            $result=Invoke-SpecKitWorkerPhase -SpecPackage $package -Phase implement -Task $task -RepoPath $executionRoot -InvocationCount ([ref]$invocations) -SkippedLineIndices ([ref]$null) -DefaultModel $Model -DefaultEffort $ReasoningEffort
            if ($result.Status -ne 'ok') { throw "worker-incomplete: $($result.Status); recoverable work retained at $($result.WorktreePath)." }
            $afterPackage=@(Get-WorkflowPackages $executionRoot | Where-Object Id -eq $package.Id)[0]
            $afterTasks=@(Get-WorkflowTasks $afterPackage)
            if (@($afterTasks | Where-Object { $_.Id -eq $task.Id -and -not $_.Complete }).Count -or (Read-WorkflowPackageFile $afterPackage 'tasks.md') -eq $before) {
                throw "scheduler-incomplete: $($task.Id) made no task progress; refusing unchanged retry."
            }
        }
    }
    if (-not $active) { Write-Host 'No active catalog packages; nothing is authorized for unattended implementation.' }
    Write-Host "Worker invocations: $invocations"
}

function Invoke-BoundedRemediation {
    param([int]$MaxRounds, [scriptblock]$HasFindings, [scriptblock]$RunRound)
    for ($round=1; $round -le $MaxRounds; $round++) {
        if (-not (& $HasFindings)) { return $true }
        $result=& $RunRound $round
        if ($result -ne 'ok') { throw "remediation-incomplete: round $round failed ($result)." }
    }
    if (& $HasFindings) { throw "remediation-incomplete: exhausted $MaxRounds rounds with findings remaining." }
    return $true
}

function Test-WorkflowDisposablePath {
    param([string]$Relative, $Config)
    $patterns=if ($Config) { $Config.disposablePatterns } else { @('node_modules/','.venv/','.pytest_cache/','__pycache__/','coverage/') }
    foreach ($pattern in $patterns) {
        if (($Relative -replace '\\','/') -match ('(^|/)'+[regex]::Escape($pattern.TrimEnd('/'))+'(/|$)')) { return $true }
    }
    return $false
}

function New-WorkflowScratch {
    param([string]$RepoPath)
    $config=Get-WorkflowConfig $RepoPath
    $branch=Get-WorkflowBranch $RepoPath
    if ($branch -eq 'HEAD') { throw 'scratch-incomplete: explicit integration branch required.' }
    $root=Get-WorkflowScratchRoot $RepoPath $config
    $null=New-Item -ItemType Directory -Path $root -Force
    $path=Resolve-WorkflowRelativePath $root ((Split-Path $RepoPath -Leaf)+'-'+[guid]::NewGuid().ToString('N'))
    $base=Get-HeadCommit $RepoPath
    git -C $RepoPath worktree add --detach $path HEAD 2>$null | Out-Null
    if ($LASTEXITCODE) { throw "scratch-incomplete: cannot create $path." }
    $admin=git -C $path rev-parse --absolute-git-dir
    $common=git -C $RepoPath rev-parse --path-format=absolute --git-common-dir
    $marker=[ordered]@{kind='workflow-kit-scratch-v1'; repo=[IO.Path]::GetFullPath($RepoPath); commonGitDir=[string]$common; integrationBranch=$branch; base=$base; worktree=$path}
    $marker | ConvertTo-Json | Set-Content -LiteralPath (Join-Path ([string]$admin) 'workflow-kit-scratch.json') -Encoding utf8
    return $path
}

function Remove-WorkflowScratch {
    param([string]$RepoPath, [string]$WorktreePath)
    $config=Get-WorkflowConfig $RepoPath; $root=Get-WorkflowScratchRoot $RepoPath $config
    $normalized=[IO.Path]::GetFullPath($WorktreePath)
    $comparison=if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    if ($normalized -eq [IO.Path]::GetFullPath($RepoPath) -or -not $normalized.StartsWith($root.TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar,$comparison)) { throw 'scratch-preserved: target is not contained scratch; primary checkout is protected.' }
    Assert-WorkflowNoLinks $normalized
    if (-not (Test-Path -LiteralPath $normalized)) { Write-Host "Scratch residue: $normalized; inspect Git inventory before later pruning."; return }
    foreach ($item in Get-ChildItem -LiteralPath $normalized -Recurse -Force) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "scratch-preserved: linked content at $($item.FullName)." }
    }
    $marker=Get-WorkflowScratchMarker $normalized
    $common=git -C $RepoPath rev-parse --path-format=absolute --git-common-dir
    if (-not $marker -or $marker.kind -ne 'workflow-kit-scratch-v1' -or $marker.worktree -ne $normalized -or $marker.commonGitDir -ne $common -or $marker.repo -ne [IO.Path]::GetFullPath($RepoPath)) { throw 'scratch-preserved: marker/repo/root proof is missing.' }
    $inventory=git -C $RepoPath worktree list --porcelain
    if ($inventory -notcontains ('worktree '+($normalized -replace '\\','/'))) { throw 'scratch-preserved: not a registered worktree.' }
    if (Test-Path -LiteralPath (Join-Path ((git -C $normalized rev-parse --absolute-git-dir)) 'locked')) { throw 'scratch-preserved: worktree is locked.' }
    if (@(git -C $normalized status --porcelain --untracked-files=no).Count) { throw 'scratch-preserved: tracked changes remain.' }
    $tracked=@(git -C $normalized ls-files)
    $extras=@(git -C $normalized ls-files --others --exclude-standard; git -C $normalized ls-files --others --ignored --exclude-standard)
    foreach ($relative in $extras) {
        if ($relative -in $tracked -or $relative -match '(^|/)(specs|reviews|evidence)(/|$)' -or -not (Test-WorkflowDisposablePath $relative $config)) { throw "scratch-preserved: protected untracked/ignored content $relative." }
        Assert-WorkflowNoLinks (Join-Path $normalized $relative)
    }
    $head=Get-HeadCommit $normalized
    # Cherry-picked commits have different IDs; prove every produced patch exists on
    # the explicit integration branch, plus exact tree equality at successful head.
    git -C $RepoPath merge-base --is-ancestor $head $marker.integrationBranch
    $ancestry=$LASTEXITCODE -eq 0
    if (-not $ancestry) {
        $cherries=@(git -C $RepoPath cherry $marker.integrationBranch $head $marker.base)
        if ($LASTEXITCODE -or @($cherries | Where-Object { $_ -match '^\+' }).Count) { throw 'scratch-preserved: unpublished commits remain.' }
        $scratchTree=git -C $normalized rev-parse 'HEAD^{tree}'
        $integratedTree=git -C $RepoPath rev-parse "$($marker.integrationBranch)^{tree}"
        if ($scratchTree -ne $integratedTree) { throw 'scratch-preserved: integration tree equality is unknown.' }
    }
    # Revalidate containment/links and marker immediately before Git's mutation.
    $null=Resolve-WorkflowRelativePath $root ([IO.Path]::GetRelativePath($root,$normalized))
    if ((Get-WorkflowScratchMarker $normalized | ConvertTo-Json -Compress) -ne ($marker | ConvertTo-Json -Compress)) { throw 'scratch-preserved: marker changed.' }
    git -C $RepoPath worktree remove --force $normalized 2>$null | Out-Null
    if ($LASTEXITCODE) { throw "scratch-preserved: Git removal failed at $normalized; no recursive filesystem fallback." }
}
