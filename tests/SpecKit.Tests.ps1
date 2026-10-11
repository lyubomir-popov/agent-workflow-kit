. "$PSScriptRoot/Fixture.Helpers.ps1"

Describe 'Spec Kit ownership and reserved identities' {
    BeforeEach {
        $fixture = New-WorkflowFixture
        $previousLocation = (Get-Location).Path
        $previousFeature = $env:SPECIFY_FEATURE
        $previousDirectory = $env:SPECIFY_FEATURE_DIRECTORY
        $env:SPECIFY_FEATURE = $null
        $env:SPECIFY_FEATURE_DIRECTORY = $null
        foreach ($relative in @('workflow-model.ps1', '.specify/scripts/powershell/common.ps1', '.specify/scripts/powershell/create-new-feature.ps1')) {
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
        $catalog = $catalog.Replace('## Candidates', '| 008 | [Delivered](../specs/008-delivered/spec.md) | `archive/eight` |' + "`n`n## Candidates")
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
        ([string](Invoke-FixtureGit $fixture @('rev-parse','HEAD'))) | Should Be $baseRevision
        (Test-Path -LiteralPath $allocation.SPEC_FILE) | Should Be $true
        $env:SPECIFY_FEATURE | Should BeNullOrEmpty
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
