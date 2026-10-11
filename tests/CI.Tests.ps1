. (Join-Path $PSScriptRoot 'Fixture.Helpers.ps1')

# Exercise the actual pwsh step offline, with synthetic remote refs in local Git.
$workflow=[IO.File]::ReadAllText((Join-Path $script:KitRoot '.github/workflows/workflow.yml'))
$restore=[regex]::Match($workflow,'(?ms)      - name: Restore local branch inventory\r?\n.*?        run: \|\r?\n(.*?)(?=      - name:)')
if (-not $restore.Success) { throw 'Cannot find the CI branch inventory step.' }
$script:restoreBranchStep=[regex]::Replace($restore.Groups[1].Value,'(?m)^          ','')

Describe 'CI restores branch inventory without resetting the current checkout' {
    BeforeEach { $script:fixture=New-WorkflowFixture; Push-Location $fixture.RepoRoot }
    AfterEach { Pop-Location; Remove-WorkflowFixture $script:fixture }

    It 'skips the current branch even when its remote ref sorts last' {
        $null=Invoke-FixtureGit $fixture @('switch','--quiet','-c','zz-current')
        Write-FixtureFile $fixture 'current-output.txt' 'Keep the current head.'
        Save-FixtureRevision $fixture
        $before=[string](git rev-parse HEAD)
        $null=Invoke-FixtureGit $fixture @('update-ref','refs/remotes/origin/zz-current','master')
        $null=Invoke-FixtureGit $fixture @('update-ref','refs/remotes/origin/restored','master')
        Invoke-Expression $script:restoreBranchStep
        $LASTEXITCODE | Should Be 0
        ([string](git branch --show-current)) | Should Be 'zz-current'
        ([string](git rev-parse HEAD)) | Should Be $before
        ([string](git rev-parse restored)) | Should Be ([string](git rev-parse master))
    }

    It 'stops at a failed ref instead of masking its exit code with a later ref' {
        $other=Join-Path $fixture.TempRoot 'other-checkout'
        $null=Invoke-FixtureGit $fixture @('worktree','add','--quiet','-b','blocked',$other,'master')
        $null=Invoke-FixtureGit $fixture @('update-ref','refs/remotes/origin/blocked','master')
        $null=Invoke-FixtureGit $fixture @('update-ref','refs/remotes/origin/zz-later','master')
        $message=$null
        try { Invoke-Expression $script:restoreBranchStep } catch { $message=$_.Exception.Message }
        $message | Should Match 'Cannot restore local branch blocked'
        git show-ref --verify --quiet refs/heads/zz-later
        $LASTEXITCODE | Should Be 1
    }
}
