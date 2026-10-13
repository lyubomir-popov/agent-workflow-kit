param([string]$RepoRoot = $PWD)
$ErrorActionPreference = 'Stop'

function Test-WorkflowHookPackageContractPath {
    param([string]$Path)
    return $Path -match '^specs/[^/]+/(?:spec|tasks)\.md$' -or $Path -match '^specs/[^/]+/reviews/.+'
}

function Test-WorkflowHookGovernedPath {
    param([string]$Path, [string[]]$RootPaths)
    return $Path -in $RootPaths -or (Test-WorkflowHookPackageContractPath $Path)
}

function Get-WorkflowHookGitNullList {
    param([string]$RepoRoot, [string[]]$Arguments, [string]$Failure)
    $process = [Diagnostics.Process]::new()
    try {
        $process.StartInfo.FileName = (Get-Command git -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
        $process.StartInfo.UseShellExecute = $false
        $process.StartInfo.CreateNoWindow = $true
        $process.StartInfo.RedirectStandardOutput = $true
        $process.StartInfo.RedirectStandardError = $true
        $process.StartInfo.StandardOutputEncoding = [Text.UTF8Encoding]::new($false, $true)
        foreach ($argument in @('-C', $RepoRoot) + $Arguments) { $process.StartInfo.ArgumentList.Add($argument) }
        if (-not $process.Start()) { throw $Failure }
        $errorRead = $process.StandardError.ReadToEndAsync()
        $output = $process.StandardOutput.ReadToEnd()
        $process.WaitForExit()
        $errorText = $errorRead.GetAwaiter().GetResult()
        if ($process.ExitCode) { throw "$Failure $errorText" }
        return @($output.Split([char]0, [StringSplitOptions]::RemoveEmptyEntries))
    } finally {
        $process.Dispose()
    }
}

function Remove-WorkflowHookSnapshot {
    param([string]$Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return }
    $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)
    $target = [IO.Path]::GetFullPath($Path).TrimEnd([IO.Path]::DirectorySeparatorChar)
    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    if (-not $target.StartsWith($temp + [IO.Path]::DirectorySeparatorChar, $comparison) -or
        (Split-Path $target -Leaf) -notmatch '^workflow-hook-index-[0-9a-f]{32}$') {
        throw "Refusing hook snapshot cleanup outside its unique OS temp root: $target"
    }
    $resolved = (Resolve-Path -LiteralPath $target).Path
    if ($resolved -ne $target) { throw "Unexpected resolved hook snapshot root: $resolved" }
    if ((Get-Item -LiteralPath $target -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw 'Refusing linked hook snapshot root cleanup.'
    }
    Remove-Item -LiteralPath $target -Recurse -Force
}

$sourceRoot = [string](git -C $RepoRoot rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -or -not $sourceRoot) { throw 'commit-incomplete: repository root is unavailable.' }
$sourceRoot = [IO.Path]::GetFullPath($sourceRoot)

# Read the hook's effective index before clearing repository-local Git variables.
# This preserves alternate/custom indexes used by Git commit and test harnesses.
$sourceIndex = [string](git -C $sourceRoot rev-parse --path-format=absolute --git-path index 2>$null)
if ($LASTEXITCODE -or -not (Test-Path -LiteralPath $sourceIndex -PathType Leaf)) {
    throw 'commit-incomplete: effective Git index is unavailable.'
}
$sourceHead = [string](git -C $sourceRoot rev-parse --verify HEAD 2>$null)
if ($LASTEXITCODE -or $sourceHead -notmatch '^[0-9a-f]{40,64}$') { throw 'commit-incomplete: HEAD is unavailable.' }
$sourceBranch = [string](git -C $sourceRoot symbolic-ref --quiet --short HEAD 2>$null)
if ($LASTEXITCODE) { $sourceBranch = $null }
$sourceRefs = @(git -C $sourceRoot for-each-ref --format='%(refname) %(objectname)' refs/heads/)
if ($LASTEXITCODE) { throw 'commit-incomplete: local branch inventory is unavailable.' }
$sourceRemoteNames = @(git -C $sourceRoot remote)
if ($LASTEXITCODE) { throw 'commit-incomplete: remote inventory is unavailable.' }
$sourceRemoteRefs = @(git -C $sourceRoot for-each-ref --format='%(refname) %(objectname)' refs/remotes/)
if ($LASTEXITCODE) { throw 'commit-incomplete: cached remote-ref inventory is unavailable.' }
$registrationHint = $null
$registrationSetting = [string](git -C $sourceRoot config --get --show-scope workflow-kit.registeringBranch 2>$null)
if ($LASTEXITCODE -eq 0 -and $registrationSetting -match "^command`t(.+)$") {
    $candidateHint = $Matches[1]
    git -C $sourceRoot check-ref-format --branch $candidateHint 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { $registrationHint = $candidateHint }
} elseif ($LASTEXITCODE -notin @(0,1)) {
    throw 'commit-incomplete: registration hint is unavailable.'
}
$checkoutConfig = @()
$checkoutConfigNames = @('core.autocrlf','core.eol','core.safecrlf','core.attributesFile','core.checkRoundtripEncoding')
$filterConfigNames = @(git -C $sourceRoot config --name-only --get-regexp '^filter\.' 2>$null | Select-Object -Unique)
if ($LASTEXITCODE -notin @(0,1)) { throw 'commit-incomplete: checkout filter configuration is unavailable.' }
foreach ($name in @($checkoutConfigNames + $filterConfigNames | Select-Object -Unique)) {
    $values = @(git -C $sourceRoot config --get-all $name 2>$null)
    if ($LASTEXITCODE -eq 0) {
        foreach ($value in $values) { $checkoutConfig += [pscustomobject]@{Name=$name; Value=$value} }
    } elseif ($LASTEXITCODE -ne 1) {
        throw "commit-incomplete: checkout configuration $name is unavailable."
    }
}

$stagedPaths = @(Get-WorkflowHookGitNullList -RepoRoot $sourceRoot -Arguments @('diff','--cached','--name-only','--no-renames','-z','--') -Failure 'commit-incomplete: staged path inventory is unavailable.')
$deletedPaths = @(Get-WorkflowHookGitNullList -RepoRoot $sourceRoot -Arguments @('diff','--cached','--diff-filter=D','--name-only','--no-renames','-z','--') -Failure 'commit-incomplete: staged deletion inventory is unavailable.')

$stagedConfig = git -C $sourceRoot show ':.workflow-kit.json' 2>$null
if ($LASTEXITCODE -eq 0) {
    try { $config = $stagedConfig -join "`n" | ConvertFrom-Json } catch { throw 'commit-incomplete: staged config is invalid.' }
    $headConfigText = git -C $sourceRoot show 'HEAD:.workflow-kit.json' 2>$null
    $headConfig = $null
    if ($LASTEXITCODE -eq 0) {
        try { $headConfig = $headConfigText -join "`n" | ConvertFrom-Json } catch { $headConfig = $null }
    }
    if ($headConfig -and $headConfig.PSObject.Properties.Name -contains 'workflowModelVersion' -and
        $config.PSObject.Properties.Name -notcontains 'workflowModelVersion') {
        throw 'commit-incomplete: staged config cannot remove the workflow model contract.'
    }
    if ($config.PSObject.Properties.Name -contains 'workflowModelVersion') {
        if ($config.workflowModelVersion -ne 1) { throw 'commit-incomplete: invalid staged workflow model version.' }
        $rootPaths = @('AGENTS.md','CLAUDE.md','.github/copilot-instructions.md','README.md','docs/specs.md',
            'AGENT-INBOX.md','INBOX.md','.specify/memory/constitution.md','.workflow-kit.json')
        $rootPaths += @($config.autoLoadedFiles | Where-Object loading -eq full | ForEach-Object path)
        $rootPaths = @($rootPaths | Select-Object -Unique)

        foreach ($relative in @($deletedPaths | Where-Object { Test-WorkflowHookGovernedPath $_ $rootPaths })) {
            throw "commit-incomplete: staged deletion of contract owner/review $relative is not allowed. Preserve the durable artifact and update its owner links."
        }
        foreach ($relative in @($stagedPaths | Where-Object { Test-WorkflowHookGovernedPath $_ $rootPaths })) {
            $workingPath = Join-Path $sourceRoot $relative
            $staged = git -C $sourceRoot rev-parse ":$relative" 2>$null
            if ($LASTEXITCODE -or -not (Test-Path -LiteralPath $workingPath -PathType Leaf)) {
                throw "commit-incomplete: stage required contract owner $relative."
            }
            $working = git -C $sourceRoot hash-object --path=$relative $workingPath
            if ($LASTEXITCODE -or $staged -ne $working) {
                throw "commit-incomplete: $relative differs between index and worktree; stage the validated owner or restore its validated bytes."
            }
        }

        $broadChange = @($stagedPaths | Where-Object { $_ -in $rootPaths }).Count -gt 0
        $affectedPackages = @($stagedPaths | ForEach-Object {
            if ($_ -match '^(specs/[^/]+)/') { $Matches[1] }
        } | Select-Object -Unique)
        if ($broadChange -or -not $stagedPaths.Count) {
            $catalogText = git -C $sourceRoot show ':docs/specs.md' 2>$null
            if ($LASTEXITCODE -eq 0) {
                $affectedPackages = @([regex]::Matches(($catalogText -join "`n"), '\]\(\.\./(?<path>specs/[^()]+?)/spec\.md\)') |
                    ForEach-Object { $_.Groups['path'].Value } | Select-Object -Unique)
            }
        }
        $untrackedPackagePaths = @(Get-WorkflowHookGitNullList -RepoRoot $sourceRoot -Arguments @('ls-files','--others','--exclude-standard','-z','--','specs/') -Failure 'commit-incomplete: untracked package inventory is unavailable.')
        $unstagedPackageRecords = @()
        foreach ($untrackedPath in $untrackedPackagePaths) {
            if (-not (Test-WorkflowHookPackageContractPath $untrackedPath)) { continue }
            foreach ($packagePath in $affectedPackages) {
                if ($untrackedPath.StartsWith($packagePath + '/', [StringComparison]::Ordinal)) {
                    $unstagedPackageRecords += $untrackedPath
                    break
                }
            }
        }
        if ($unstagedPackageRecords.Count) {
            throw "commit-incomplete: affected package owner/review artifacts are not staged for $($affectedPackages -join ', '): $($unstagedPackageRecords -join ', ')."
        }

        $snapshotRoot = Join-Path ([IO.Path]::GetTempPath()) ('workflow-hook-index-' + [guid]::NewGuid().ToString('N'))
        $snapshotRepo = Join-Path $snapshotRoot 'repo'
        $savedGitEnvironment = @{}
        try {
            $null = New-Item -ItemType Directory -Path $snapshotRoot
            $gitEnvironmentNames = @(git -C $sourceRoot rev-parse --local-env-vars)
            $gitEnvironmentNames += @([Environment]::GetEnvironmentVariables('Process').Keys |
                Where-Object { [string]$_ -match '^GIT_CONFIG_(?:COUNT|KEY_\d+|VALUE_\d+|PARAMETERS)$' })
            $gitEnvironmentNames += @('GIT_CONFIG_COUNT','GIT_CONFIG_KEY_0','GIT_CONFIG_VALUE_0','GIT_CONFIG_PARAMETERS')
            foreach ($name in @($gitEnvironmentNames | Select-Object -Unique)) {
                if (-not $name) { continue }
                $savedGitEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
                Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
            }
            if ($registrationHint) {
                [Environment]::SetEnvironmentVariable('GIT_CONFIG_COUNT', '1', 'Process')
                [Environment]::SetEnvironmentVariable('GIT_CONFIG_KEY_0', 'workflow-kit.registeringBranch', 'Process')
                [Environment]::SetEnvironmentVariable('GIT_CONFIG_VALUE_0', $registrationHint, 'Process')
            }

            # The shared clone is isolated for refs/index/worktree while retaining
            # read-only access to newly staged blob objects in the source object DB.
            $cloneOutput = @(git clone --quiet --shared --no-checkout -- $sourceRoot $snapshotRepo 2>&1)
            if ($LASTEXITCODE) {
                throw "commit-incomplete: cannot create isolated staged-contract snapshot at $snapshotRepo from $sourceRoot`: $($cloneOutput -join ' ')"
            }
            $snapshotNoHooks = Join-Path $snapshotRoot 'no-hooks'
            $null = New-Item -ItemType Directory -Path $snapshotNoHooks
            git -C $snapshotRepo config --local core.hooksPath $snapshotNoHooks
            if ($LASTEXITCODE) { throw 'commit-incomplete: cannot disable hooks inside staged-contract snapshot.' }
            git -C $snapshotRepo remote remove origin 2>$null
            if ($LASTEXITCODE -notin @(0,2)) { throw 'commit-incomplete: cannot remove synthetic snapshot remote.' }
            foreach ($remoteName in $sourceRemoteNames) {
                git -C $snapshotRepo config --local --add "remote.$remoteName.url" 'no-fetch://workflow-hook-snapshot'
                if ($LASTEXITCODE) { throw "commit-incomplete: cannot preserve remote inventory entry $remoteName." }
            }
            foreach ($setting in $checkoutConfig) {
                git -C $snapshotRepo config --local --add $setting.Name $setting.Value
                if ($LASTEXITCODE) { throw "commit-incomplete: cannot preserve checkout configuration $($setting.Name)." }
            }
            foreach ($refLine in $sourceRefs) {
                if ($refLine -notmatch '^(refs/heads/\S+) ([0-9a-f]{40,64})$') { throw 'commit-incomplete: invalid local branch inventory.' }
                git -C $snapshotRepo update-ref $Matches[1] $Matches[2]
                if ($LASTEXITCODE) { throw "commit-incomplete: cannot copy local branch $($Matches[1]) into staged-contract snapshot." }
            }
            foreach ($refLine in $sourceRemoteRefs) {
                if ($refLine -notmatch '^(refs/remotes/\S+) ([0-9a-f]{40,64})$') { throw 'commit-incomplete: invalid cached remote-ref inventory.' }
                git -C $snapshotRepo update-ref $Matches[1] $Matches[2]
                if ($LASTEXITCODE) { throw "commit-incomplete: cannot copy cached remote ref $($Matches[1]) into staged-contract snapshot." }
            }
            if ($sourceBranch) {
                git -C $snapshotRepo symbolic-ref HEAD "refs/heads/$sourceBranch"
            } else {
                git -C $snapshotRepo update-ref --no-deref HEAD $sourceHead
            }
            if ($LASTEXITCODE) { throw 'commit-incomplete: cannot preserve source branch in staged-contract snapshot.' }

            $snapshotIndex = [string](git -C $snapshotRepo rev-parse --path-format=absolute --git-path index)
            if ($LASTEXITCODE -or -not $snapshotIndex) { throw 'commit-incomplete: snapshot index path is unavailable.' }
            Copy-Item -LiteralPath $sourceIndex -Destination $snapshotIndex -Force
            git -C $snapshotRepo checkout-index --all --force
            if ($LASTEXITCODE) { throw 'commit-incomplete: cannot materialize staged-contract snapshot.' }

            & pwsh -NoLogo -NoProfile -File (Join-Path $PSScriptRoot 'workflow-kit.ps1') -Command lint -RepoRoot $snapshotRepo -Strict
            exit $LASTEXITCODE
        } finally {
            foreach ($name in $savedGitEnvironment.Keys) {
                if ($null -eq $savedGitEnvironment[$name]) {
                    Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
                } else {
                    [Environment]::SetEnvironmentVariable($name, $savedGitEnvironment[$name], 'Process')
                }
            }
            Remove-WorkflowHookSnapshot $snapshotRoot
        }
    }
} elseif (@($deletedPaths | Where-Object { $_ -eq '.workflow-kit.json' }).Count) {
    throw 'commit-incomplete: staged deletion of contract owner .workflow-kit.json is not allowed.'
}

# Legacy repositories keep their existing worktree-based lint behavior.
& pwsh -NoLogo -NoProfile -File "$PSScriptRoot/workflow-kit.ps1" -Command lint -RepoRoot $sourceRoot -Strict
exit $LASTEXITCODE
