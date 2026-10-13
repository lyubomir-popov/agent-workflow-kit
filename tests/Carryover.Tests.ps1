. (Join-Path $PSScriptRoot 'Fixture.Helpers.ps1')

Describe 'Slice B archive and mirror carryovers' {
    BeforeEach { $script:fixture = New-WorkflowFixture }
    AfterEach { Remove-WorkflowFixture $script:fixture }

    It 'allows the final delivery transition on its declared branch but freezes later archive edits there' {
        Set-FixtureArchivedPackage $fixture
        (Invoke-FixtureLint $fixture -Strict).ExitCode | Should Be 0
        Save-FixtureRevision $fixture
        Write-FixtureFile $fixture 'specs/001-example/plan.md' '# Later archive edit'
        $result = Invoke-FixtureLint $fixture -Strict
        $result.ExitCode | Should Be 1
        @(Get-FixtureFindings $result '^package-archive-branch$').Count | Should Be 1
    }

    It 'allows archived edits only on the configured target after source deletion' {
        Set-FixtureArchivedPackage $fixture
        Save-FixtureRevision $fixture
        $null = Invoke-FixtureGit $fixture @('switch','--quiet','master')
        $null = Invoke-FixtureGit $fixture @('merge','--quiet','--ff-only','feat/001-example')
        $null = Invoke-FixtureGit $fixture @('branch','-d','feat/001-example')
        Write-FixtureFile $fixture 'specs/001-example/plan.md' '# Target archive correction'
        (Invoke-FixtureLint $fixture -Strict).ExitCode | Should Be 0
        Save-FixtureRevision $fixture
        $null = Invoke-FixtureGit $fixture @('switch','--quiet','-c','other')
        Write-FixtureFile $fixture 'specs/001-example/plan.md' '# Other branch archive correction'
        @(Get-FixtureFindings (Invoke-FixtureLint $fixture -Strict) '^package-archive-branch$').Count | Should Be 1
    }

    It 'does not equate an archived edit branch with a differently cased target name' {
        Set-FixtureArchivedPackage $fixture
        Save-FixtureRevision $fixture
        $null = Invoke-FixtureGit $fixture @('switch','--quiet','master')
        $null = Invoke-FixtureGit $fixture @('merge','--quiet','--ff-only','feat/001-example')
        $config = Get-FixtureConfig $fixture
        $config.targetBranch = 'MASTER'
        Set-FixtureConfig $fixture $config
        Write-FixtureFile $fixture 'specs/001-example/plan.md' '# Case-distinct target edit'
        @(Get-FixtureFindings (Invoke-FixtureLint $fixture -Strict) '^package-archive-branch$').Count | Should Be 1
    }

    It 'rejects archived edits with quoted Unicode filenames on another branch' {
        Write-FixtureFile $fixture 'specs/001-example/évidence.md' "Committed evidence.`n"
        Set-FixtureArchivedPackage $fixture
        Save-FixtureRevision $fixture
        $null = Invoke-FixtureGit $fixture @('config','core.quotePath','true')
        Write-FixtureFile $fixture 'specs/001-example/évidence.md' "Changed archived evidence.`n"
        $result = Invoke-FixtureLint $fixture -Strict
        $result.ExitCode | Should Be 1
        @(Get-FixtureFindings $result '^package-archive-branch$').Count | Should Be 1
    }

    It 'reports missing and drifted hook mirror assets without installing them' {
        $result = Invoke-FixtureLint $fixture -Command diff
        foreach ($path in @('workflow-hook.ps1','.githooks/pre-commit')) {
            @($result.Report.findings | Where-Object { $_.rule -eq 'canonical-file-missing' -and $_.path -eq $path }).Count | Should Be 1
            Write-FixtureFile $fixture $path '# Deliberate mirror drift'
        }
        $result = Invoke-FixtureLint $fixture -Command diff
        foreach ($path in @('workflow-hook.ps1','.githooks/pre-commit')) {
            @($result.Report.findings | Where-Object { $_.rule -eq 'canonical-file-drift' -and $_.path -eq $path }).Count | Should Be 1
        }
        git -C $fixture.RepoRoot config --get core.hooksPath | Should Match 'no-hooks'
    }

    It 'preserves external mirror suppression while still reporting an existing drifted hook' {
        $config = Get-FixtureConfig $fixture
        $config | Add-Member NoteProperty canonicalMirrorMode external
        Set-FixtureConfig $fixture $config
        $result = Invoke-FixtureLint $fixture -Command diff
        @(Get-FixtureFindings $result '^canonical-file-missing$').Count | Should Be 0
        Write-FixtureFile $fixture 'workflow-hook.ps1' '# Existing drifted hook'
        $result = Invoke-FixtureLint $fixture -Command diff
        @($result.Report.findings | Where-Object { $_.rule -eq 'canonical-file-drift' -and $_.path -eq 'workflow-hook.ps1' }).Count | Should Be 1
    }

    It 'exposes read-only JSON closeout through the CLI and refuses unauthorized apply' {
        $base = [string](git -C $fixture.RepoRoot rev-parse master)
        Set-FixtureArchivedPackage $fixture
        Save-FixtureRevision $fixture
        $accepted = [string](git -C $fixture.RepoRoot rev-parse HEAD)
        $null = Invoke-FixtureGit $fixture @('switch','--quiet','master')
        $null = Invoke-FixtureGit $fixture @('merge','--quiet','--ff-only','feat/001-example')
        $arguments = @('-NoLogo','-NoProfile','-File',(Join-Path $script:KitRoot 'workflow-kit.ps1'),'-Command','closeout','-RepoRoot',$fixture.RepoRoot,'-PackageId','001','-AcceptedRevision',$accepted,'-BaseRevision',$base,'-LandedRevision',$accepted,'-Json')
        $output = & pwsh @arguments 2>&1
        $LASTEXITCODE | Should Be 0
        $report = ($output -join "`n") | ConvertFrom-Json
        $report.proofMethod | Should Be 'ancestry'
        $report.networkActionsEnabled | Should Be $false
        @(& git -C $fixture.RepoRoot status --porcelain).Count | Should Be 0
        $humanArguments = @($arguments | Where-Object { $_ -ne '-Json' })
        $human = (& pwsh @humanArguments 2>&1) -join "`n"
        $LASTEXITCODE | Should Be 0
        $human | Should Match ([regex]::Escape("Base: $base"))
        $human | Should Match ([regex]::Escape("Accepted source: $accepted"))
        $human | Should Match ([regex]::Escape("Landed target: $accepted"))
        $human | Should Match 'Archive tag archive/001-example: absent'
        $human | Should Match 'Local outcome: eligible'
        $human | Should Match 'Remote outcome: disabled'
        $output = & pwsh @arguments -Apply -DeleteLocalBranch 2>&1
        $LASTEXITCODE | Should Be 1
        $report = ($output -join "`n") | ConvertFrom-Json
        $report.status | Should Be 'incomplete'
        git -C $fixture.RepoRoot show-ref --verify --quiet refs/heads/feat/001-example
        $LASTEXITCODE | Should Be 0
        git -C $fixture.RepoRoot show-ref --verify --quiet refs/tags/archive/001-example
        $LASTEXITCODE | Should Be 1
    }
}
