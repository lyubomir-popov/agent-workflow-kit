. "$PSScriptRoot/Fixture.Helpers.ps1"

Describe 'Spec Kit ownership and reserved identities' {
    BeforeEach {
        $fixture = New-WorkflowFixture
        $previousLocation = (Get-Location).Path
        $previousFeature = $env:SPECIFY_FEATURE
        $previousDirectory = $env:SPECIFY_FEATURE_DIRECTORY
        $env:SPECIFY_FEATURE = $null
        $env:SPECIFY_FEATURE_DIRECTORY = $null
        foreach ($relative in @('workflow-model.ps1', '.specify/scripts/powershell/common.ps1', '.specify/scripts/powershell/create-new-feature.ps1', '.specify/scripts/powershell/check-prerequisites.ps1')) {
            Write-FixtureFile $fixture $relative ([IO.File]::ReadAllText((Join-Path $script:KitRoot $relative)))
        }
        Save-FixtureRevision $fixture
        Set-Location $fixture.RepoRoot
        . (Join-Path $fixture.RepoRoot '.specify/scripts/powershell/common.ps1')
        $create = Join-Path $fixture.RepoRoot '.specify/scripts/powershell/create-new-feature.ps1'
    }

    AfterEach {
        Set-Location $previousLocation
        $env:SPECIFY_FEATURE = $previousFeature
        $env:SPECIFY_FEATURE_DIRECTORY = $previousDirectory
        Remove-WorkflowFixture $fixture
    }

    It 'allows implementation prerequisites only for the authorized entry task' {
        $output=& pwsh -NoLogo -NoProfile -File .specify/scripts/powershell/check-prerequisites.ps1 -Json -RequireTasks -IncludeTasks 2>&1
        $LASTEXITCODE | Should Be 0
        ($output -join "`n" | ConvertFrom-Json).FEATURE_DIR | Should Be (Join-Path $fixture.RepoRoot 'specs/001-example')
    }

    It 'prevents a completed checklist or paths-only switch bypassing an uncleared implementation gate' {
        Set-FixtureSpec $fixture -State pending
        Write-FixtureFile $fixture 'specs/001-example/checklists/requirements.md' '- [x] Every author check complete.'
        foreach ($extra in @(@(),@('-PathsOnly'))) {
            $output=& pwsh -NoLogo -NoProfile -File .specify/scripts/powershell/check-prerequisites.ps1 -Json -RequireTasks @extra 2>&1
            $LASTEXITCODE | Should Be 1
            ($output -join "`n") | Should Match 'not owner-cleared'
        }
    }

    It 'stops vendor implementation prerequisites at a later slice task gate' {
        Set-FixtureTasks $fixture "- [x] T001 Completed A.`n- [ ] T002 Deferred B (gate: CP2)."
        $output=& pwsh -NoLogo -NoProfile -File .specify/scripts/powershell/check-prerequisites.ps1 -Json -RequireTasks 2>&1
        $LASTEXITCODE | Should Be 1
        ($output -join "`n") | Should Match 'CP2 is not owner-cleared'
    }

    It 'stops vendor implementation prerequisites at an owner manual task' {
        Set-FixtureTasks $fixture '- [ ] T001 Author next slice tasks (manual).'
        $output=& pwsh -NoLogo -NoProfile -File .specify/scripts/powershell/check-prerequisites.ps1 -Json -RequireTasks -PathsOnly 2>&1
        $LASTEXITCODE | Should Be 1
        ($output -join "`n") | Should Match 'T001 is manual'
    }

    It 'reads actual Git branch despite a spoofed feature environment variable' {
        $env:SPECIFY_FEATURE = 'fake/branch'
        (Get-FeaturePathsEnv).CURRENT_BRANCH | Should Be 'feat/001-example'
        (Test-FeatureBranch -Branch 'fake/branch') | Should Be $false
    }

    It 'accepts a catalog-declared branch without vendor numeric naming' {
        $null = Invoke-FixtureGit $fixture @('branch', '-m', 'custom/owner')
        foreach ($relative in @('docs/specs.md','specs/001-example/spec.md')) {
            $text = Get-Content -LiteralPath (Join-Path $fixture.RepoRoot $relative) -Raw
            Write-FixtureFile $fixture $relative ($text.Replace('feat/001-example','custom/owner'))
        }
        $env:SPECIFY_FEATURE_DIRECTORY = 'specs/001-example'
        (Get-FeaturePathsEnv).CURRENT_BRANCH | Should Be 'custom/owner'
        (Test-FeatureBranch -Branch 'custom/owner') | Should Be $true
    }

    It 'ignores the local cursor and prevents it bypassing branch validation' {
        Write-FixtureFile $fixture '.specify/feature.json' '{"feature_directory":"specs/999-stale"}'
        $paths = Get-FeaturePathsEnv
        $paths.FEATURE_DIR | Should Be (Join-Path $fixture.RepoRoot 'specs/001-example')
        (Test-FeatureJsonMatchesFeatureDir $fixture.RepoRoot $paths.FEATURE_DIR) | Should Be $false
        $null = Invoke-FixtureGit $fixture @('switch', '--quiet', 'master')
        (Test-FixtureThrows { Get-FeaturePathsEnv }) | Should Be $true
    }

    It 'rejects explicit package paths outside the catalog or declared branch' {
        $env:SPECIFY_FEATURE_DIRECTORY = 'specs/999-stale'
        (Test-FixtureThrows { Get-FeaturePathsEnv }) | Should Be $true
        $env:SPECIFY_FEATURE_DIRECTORY = 'specs/001-example'
        $null = Invoke-FixtureGit $fixture @('switch', '--quiet', 'master')
        (Test-FixtureThrows { Get-FeaturePathsEnv }) | Should Be $true
    }

    It 'reserves all retained directories, archived catalog IDs and local refs without network' {
        Write-FixtureFile $fixture 'specs/011-closed/spec.md' '**Lifecycle**: closed'
        Write-FixtureFile $fixture 'specs/20261011-123456-legacy/spec.md' 'Legacy timestamp'
        $catalog = Get-Content -LiteralPath (Join-Path $fixture.RepoRoot 'docs/specs.md') -Raw
        $catalog = $catalog.Replace('## Candidates', '| 008 | [Delivered](../specs/008-delivered/spec.md) | `feat/008-delivered` |' + "`n`n## Candidates")
        Write-FixtureFile $fixture 'docs/specs.md' $catalog
        $null = Invoke-FixtureGit $fixture @('branch','feat/015-reserved')
        $null = Invoke-FixtureGit $fixture @('update-ref','refs/remotes/origin/feat/018-reserved','HEAD')
        $null = Invoke-FixtureGit $fixture @('tag','archive/022-preserved')
        $gitExecutable = (Get-Command git).Source
        function git {
            if ($args -contains 'fetch' -or $args -contains 'ls-remote') { throw 'Unexpected network call.' }
            & $gitExecutable @args
        }
        $allocation = (& $create -DryRun -Json -ShortName verify 'Fixture allocation') | ConvertFrom-Json
        $allocation.FEATURE_NUM | Should Be '023'
        (Test-Path -LiteralPath (Join-Path $fixture.RepoRoot 'specs/023-verify')) | Should Be $false
        foreach ($number in @(8,11,15,18,22)) {
            (Test-FixtureThrows { & $create -DryRun -Number $number -ShortName reused 'Fixture reuse' }) | Should Be $true
        }
    }

    It 'rejects identity-reuse and non-catalog numbering switches in versioned mode' {
        (Test-FixtureThrows { & $create -DryRun -AllowExistingBranch 'Fixture reuse' }) | Should Be $true
        (Test-FixtureThrows { & $create -DryRun -Timestamp 'Fixture timestamp' }) | Should Be $true
        (Test-FixtureThrows { & $create -DryRun -Number -1 'Fixture negative' }) | Should Be $true
    }

    It 'requires the configured target branch to exist locally even during dry run' {
        $config = Get-FixtureConfig $fixture
        $config.targetBranch = 'missing-target'
        Set-FixtureConfig $fixture $config
        (Test-FixtureThrows { & $create -DryRun 'Fixture missing target' }) | Should Be $true
    }

    It 'stops after checkout failure before creating any package' {
        Write-FixtureFile $fixture 'README.md' 'Feature branch change'
        Save-FixtureRevision $fixture
        Write-FixtureFile $fixture 'README.md' 'Uncommitted conflicting change'
        (Test-FixtureThrows { & $create -Number 2 -ShortName failed 'Fixture checkout' }) | Should Be $true
        (Test-Path -LiteralPath (Join-Path $fixture.RepoRoot 'specs/002-failed')) | Should Be $false
        (Get-CurrentBranch) | Should Be 'feat/001-example'
    }

    It 'creates its new feature from configured target rather than current feature HEAD' {
        $baseRevision = [string](Invoke-FixtureGit $fixture @('rev-parse','master'))
        $allocation = (& $create -Number 2 -Json -ShortName target 'Fixture target') | ConvertFrom-Json
        $registeredRevision=[string](Invoke-FixtureGit $fixture @('rev-parse','master'))
        $registeredRevision | Should Not Be $baseRevision
        ([string](Invoke-FixtureGit $fixture @('rev-parse','master^'))) | Should Be $baseRevision
        ([string](Invoke-FixtureGit $fixture @('rev-parse','HEAD'))) | Should Be $registeredRevision
        ([string](Invoke-FixtureGit $fixture @('diff-tree','--no-commit-id','--name-only','-r','master'))) | Should Be 'docs/specs.md'
        (Invoke-FixtureGit $fixture @('show','master:docs/specs.md') | Out-String) | Should Match '002-target'
        (Test-Path -LiteralPath $allocation.SPEC_FILE) | Should Be $true
        $env:SPECIFY_FEATURE | Should BeNullOrEmpty
    }

    It 'creates a catalog-owned draft from the override and then sets up its plan' {
        $allocation=(& $create -Number 2 -Json -ShortName created 'Fixture create then plan') | ConvertFrom-Json
        . (Join-Path $fixture.RepoRoot 'workflow-model.ps1')
        $package=Select-WorkflowPackage $fixture.RepoRoot
        $package.Id | Should Be '002'
        $package.Branch | Should Be $allocation.BRANCH_NAME
        $package.Lifecycle | Should Be draft
        $package.Scope | Should Be '002/spec-r1'
        $package.Checkpoints[0].State | Should Be pending
        $package.SpecText | Should Match 'Fixture create then plan'
        $package.Header | Should Not Match '\[DECLARED CATALOG BRANCH\]|\[PACKAGE ID\]'
        $output=& pwsh -NoLogo -NoProfile -File .specify/scripts/powershell/setup-plan.ps1 -Json 2>&1
        $LASTEXITCODE | Should Be 0
        $plan=$output -join "`n" | ConvertFrom-Json
        $plan.SPECS_DIR | Should Be $package.AbsolutePath
        (Test-Path -LiteralPath $plan.IMPL_PLAN) | Should Be $true
        [IO.File]::ReadAllText($plan.IMPL_PLAN) | Should Match 'Implementation Plan'
        (Invoke-FixtureLint $fixture -Strict).ExitCode | Should Be 0
        Save-FixtureRevision $fixture
        $null=Invoke-FixtureGit $fixture @('switch','--quiet','master')
        (Invoke-FixtureLint $fixture -Strict).ExitCode | Should Be 0
        $catalog=@(Get-WorkflowCatalog $fixture.RepoRoot | Where-Object Id -eq '002')
        $catalog.Count | Should Be 1
        $catalog[0].Branch | Should Be $allocation.BRANCH_NAME
        # The newly created spec exists only on its declared branch.
        (Test-Path -LiteralPath $allocation.SPEC_FILE) | Should Be $false
        @(Get-WorkflowPackages $fixture.RepoRoot | Where-Object Id -eq '002')[0].Lifecycle | Should Be draft
    }

    It 'reports fetch info in a fresh clone even when only a remote package ref exists' {
        $allocation=(& $create -Number 2 -Json -ShortName cloned 'Fixture clone') | ConvertFrom-Json
        Save-FixtureRevision $fixture
        $null=Invoke-FixtureGit $fixture @('switch','--quiet','master')
        $cloneRoot=Join-Path $fixture.TempRoot 'clone'
        $null=Invoke-FixtureGit $fixture @('clone','--quiet','--no-local','--branch','master',$fixture.RepoRoot,$cloneRoot)
        $clone=[pscustomobject]@{RepoRoot=$cloneRoot}
        git -C $cloneRoot show-ref --verify --quiet "refs/heads/$($allocation.BRANCH_NAME)"
        $LASTEXITCODE | Should Be 1
        $null=Invoke-FixtureGit $clone @('show-ref','--verify',"refs/remotes/origin/$($allocation.BRANCH_NAME)")
        $result=Invoke-FixtureLint $clone -Strict
        $result.ExitCode | Should Be 0
        $finding=@(Get-FixtureFindings $result 'package-fetch' | Where-Object path -eq 'specs/002-cloned')
        $finding.Count | Should Be 1
        $finding[0].severity | Should Be info
        $finding[0].message | Should Match 'fetch the declared branch'
    }

    It 'commits target registration through the real hook before the feature ref exists' {
        $hooksRoot=Join-Path $fixture.TempRoot 'registration-hooks'
        $null=New-Item -ItemType Directory -Path $hooksRoot
        $hookScript=(Join-Path $script:KitRoot 'workflow-hook.ps1') -replace '\\','/'
        $hookText="#!/bin/sh`ngit show-ref --verify --quiet refs/heads/002-hooked && exit 93`nexec pwsh -NoLogo -NoProfile -File '$hookScript' -RepoRoot .`n"
        [IO.File]::WriteAllText((Join-Path $hooksRoot 'pre-commit'),$hookText,[Text.UTF8Encoding]::new($false))
        $null=Invoke-FixtureGit $fixture @('config','core.hooksPath',$hooksRoot)
        $allocation=(& $create -Number 2 -Json -ShortName hooked 'Fixture hooked creation') | ConvertFrom-Json
        $allocation.BRANCH_NAME | Should Be '002-hooked'
        ([string](Invoke-FixtureGit $fixture @('rev-parse','HEAD'))) | Should Be ([string](Invoke-FixtureGit $fixture @('rev-parse','master')))
        (Invoke-FixtureGit $fixture @('show','master:docs/specs.md') | Out-String) | Should Match '002-hooked'
    }

    It 'stops incomplete on a dirty target without changing its catalog or head' {
        $null=Invoke-FixtureGit $fixture @('switch','--quiet','master')
        $before=[string](Invoke-FixtureGit $fixture @('rev-parse','HEAD'))
        $catalogBefore=[IO.File]::ReadAllText((Join-Path $fixture.RepoRoot 'docs/specs.md'))
        Write-FixtureFile $fixture 'README.md' 'Owner dirty target work'
        $message=$null
        try { & $create -Number 2 -ShortName dirty 'Fixture dirty target' } catch { $message=$_.Exception.Message }
        $message | Should Match 'specify-incomplete:.*clean checkout'
        ([string](Invoke-FixtureGit $fixture @('rev-parse','HEAD'))) | Should Be $before
        [IO.File]::ReadAllText((Join-Path $fixture.RepoRoot 'docs/specs.md')) | Should Be $catalogBefore
        [IO.File]::ReadAllText((Join-Path $fixture.RepoRoot 'README.md')) | Should Be 'Owner dirty target work'
        (Test-Path -LiteralPath (Join-Path $fixture.RepoRoot 'specs/002-dirty')) | Should Be $false
    }

    It 'stops incomplete when the configured target is checked out elsewhere' {
        $targetWorktree=Join-Path $fixture.TempRoot 'target'
        $null=Invoke-FixtureGit $fixture @('worktree','add','--quiet',$targetWorktree,'master')
        $before=[string](Invoke-FixtureGit $fixture @('rev-parse','master'))
        $message=$null
        try { & $create -Number 2 -ShortName blocked 'Fixture unavailable checkout' } catch { $message=$_.Exception.Message }
        $message | Should Match 'specify-incomplete: cannot switch'
        (Get-CurrentBranch) | Should Be 'feat/001-example'
        ([string](Invoke-FixtureGit $fixture @('rev-parse','master'))) | Should Be $before
        (Test-Path -LiteralPath (Join-Path $fixture.RepoRoot 'specs/002-blocked')) | Should Be $false
    }

    It 'keeps missing-branch diagnostics as errors away from the configured target' {
        $allocation=(& $create -Number 2 -Json -ShortName missing 'Fixture missing sibling') | ConvertFrom-Json
        Save-FixtureRevision $fixture
        $null=Invoke-FixtureGit $fixture @('switch','--quiet','feat/001-example')
        $null=Invoke-FixtureGit $fixture @('branch','-D',$allocation.BRANCH_NAME)
        # Bring the target's registered catalog into this other package branch.
        Write-FixtureFile $fixture 'docs/specs.md' ((Invoke-FixtureGit $fixture @('show','master:docs/specs.md')) -join "`n")
        $result=Invoke-FixtureLint $fixture -Strict
        $result.ExitCode | Should Be 1
        @(Get-FixtureFindings $result 'package-owner').Count | Should Be 1
        @(Get-FixtureFindings $result 'package-fetch').Count | Should Be 0
    }

    It 'still rejects target-side edits to a package whose branch is unavailable' {
        $allocation=(& $create -Number 2 -Json -ShortName guarded 'Fixture unavailable edit') | ConvertFrom-Json
        Save-FixtureRevision $fixture
        $null=Invoke-FixtureGit $fixture @('switch','--quiet','master')
        $null=Invoke-FixtureGit $fixture @('branch','-D',$allocation.BRANCH_NAME)
        Write-FixtureFile $fixture 'specs/002-guarded/spec.md' 'Unauthorized target edit'
        $result=Invoke-FixtureLint $fixture -Strict
        $result.ExitCode | Should Be 1
        @(Get-FixtureFindings $result 'package-branch').Count | Should Be 1
        @(Get-FixtureFindings $result 'package-fetch' | Where-Object path -eq 'specs/002-guarded').Count | Should Be 1
    }

    It 'retains legacy cursor and environment behavior when version is absent' {
        $config = Get-FixtureConfig $fixture
        $config.PSObject.Properties.Remove('workflowModelVersion')
        Set-FixtureConfig $fixture $config
        $env:SPECIFY_FEATURE = '001-example'
        Write-FixtureFile $fixture '.specify/feature.json' '{"feature_directory":"specs/001-example"}'
        $paths = Get-FeaturePathsEnv
        $paths.CURRENT_BRANCH | Should Be '001-example'
        (Test-FeatureJsonMatchesFeatureDir $fixture.RepoRoot $paths.FEATURE_DIR) | Should Be $true
    }

    It 'fails closed for an unsupported workflow version' {
        $config = Get-FixtureConfig $fixture
        $config.workflowModelVersion = 99
        Set-FixtureConfig $fixture $config
        (Test-FixtureThrows { Get-FeaturePathsEnv }) | Should Be $true
    }

    It 'validates detached marked scratch against its declared integration branch' {
        $config = Get-FixtureConfig $fixture
        $config.managedScratchRoot = Join-Path $fixture.TempRoot 'scratch'
        Set-FixtureConfig $fixture $config
        Save-FixtureRevision $fixture
        $scratch = Join-Path $config.managedScratchRoot 'worker'
        $null = Invoke-FixtureGit $fixture @('worktree','add','--quiet','--detach',$scratch,'HEAD')
        $admin = [string](git -C $scratch rev-parse --absolute-git-dir)
        $marker = [ordered]@{
            kind='workflow-kit-scratch-v1'; repo=$fixture.RepoRoot; worktree=$scratch
            commonGitDir=[string](git -C $scratch rev-parse --path-format=absolute --git-common-dir)
            integrationBranch='feat/001-example'; base=[string](git -C $scratch rev-parse HEAD)
        }
        $markerPath = Join-Path $admin 'workflow-kit-scratch.json'
        $marker | ConvertTo-Json | Set-Content -LiteralPath $markerPath
        Set-Location $scratch
        $env:SPECIFY_FEATURE_DIRECTORY = 'specs/001-example'
        $paths = Get-FeaturePathsEnv
        $paths.CURRENT_BRANCH | Should Be 'HEAD'
        $paths.FEATURE_DIR | Should Be (Join-Path $scratch 'specs/001-example')
        (Test-FeatureBranch -Branch 'HEAD') | Should Be $true
        $marker.integrationBranch = 'master'
        $marker | ConvertTo-Json | Set-Content -LiteralPath $markerPath
        (Test-FixtureThrows { Get-FeaturePathsEnv }) | Should Be $true
    }
}
