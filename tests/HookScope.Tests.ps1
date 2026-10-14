. (Join-Path $PSScriptRoot 'Fixture.Helpers.ps1')

function Invoke-ScopedHookCheck {
    param($Fixture)
    $output = & pwsh -NoLogo -NoProfile -File (Join-Path $script:KitRoot 'workflow-hook.ps1') -RepoRoot $Fixture.RepoRoot 2>&1
    $text = ($output -join "`n") -replace '(?m)^\s*\|\s?', ''
    $text = $text -replace '\s+', ' '
    return [pscustomobject]@{ ExitCode=$LASTEXITCODE; Output=$text }
}

function Add-SecondHookPackage {
    param($Fixture)
    $catalogPath = Join-Path $Fixture.RepoRoot 'docs/specs.md'
    $catalog = [IO.File]::ReadAllText($catalogPath)
    Write-FixtureFile $Fixture 'docs/specs.md' ($catalog.Replace(
        '| 001 | [Example](../specs/001-example/spec.md) | `feat/001-example` |',
        "| 001 | [Example](../specs/001-example/spec.md) | ``feat/001-example`` |`n| 002 | [Other](../specs/002-other/spec.md) | ``feat/001-example`` |"))
    Write-FixtureFile $Fixture 'specs/002-other/spec.md' @'
# Other

**Feature branch**: `feat/001-example`
**Lifecycle**: active
**Scope**: `002/spec-r1`
**Superseded tasks**: none
**Checkpoints**:

| ID | Gate | Verdict link | State |
|---|---|---|---|
| CP1 | implementation | [saved verdict](reviews/CP1-review.md) | owner-cleared |
| CP2 | closeout | none | pending |

## Intent

Exercise package-scoped hook behavior.
'@
    Write-FixtureFile $Fixture 'specs/002-other/tasks.md' @'
# Current work

**Next tasks**: T002.
**Blockers**: none.
**Checkpoint links**: [CP1](spec.md#checkpoints).
**Entry checkpoint**: CP1
**Validation**: local fixture checks.

## Work

- [ ] T002 Implement the other example.
'@
    Write-FixtureFile $Fixture 'specs/002-other/reviews/CP1-review.md' @'
# Saved review

**Checkpoint**: CP1
**Scope**: `002/spec-r1`
**Reviewed revision**: `fixture-base`
**Reviewer**: Fixture reviewer
**Verdict**: accept

## Findings

No blocking findings.
'@
    Write-FixtureFile $Fixture 'specs/002-other/README.md' '# Other package'
    Write-FixtureFile $Fixture 'specs/002-other/plan.md' "# Plan`nLocal fixture behavior.`n"
    Save-FixtureRevision $Fixture
}

Describe 'Staged hook contract scope' {
    BeforeEach {
        $script:fixture=New-WorkflowFixture
        Add-SecondHookPackage $script:fixture
    }
    AfterEach { Remove-WorkflowFixture $script:fixture }

    It 'ignores unrelated unstaged package owner bytes and leaves source state unchanged' {
        Write-FixtureFile $fixture 'specs/001-example/plan.md' "# Plan`nStaged package-one change.`n"
        $null=Invoke-FixtureGit $fixture @('add','specs/001-example/plan.md')
        Write-FixtureFile $fixture 'specs/002-other/spec.md' '# invalid unstaged package snapshot'
        $statusBefore = @(Invoke-FixtureGit $fixture @('status','--short')) -join "`n"
        $indexPath = Invoke-FixtureGit $fixture @('rev-parse','--path-format=absolute','--git-path','index')
        $indexBefore = (Get-FileHash -LiteralPath $indexPath -Algorithm SHA256).Hash
        $branchBefore = Invoke-FixtureGit $fixture @('branch','--show-current')

        $result=Invoke-ScopedHookCheck $fixture

        $result.ExitCode | Should Be 0
        (@(Invoke-FixtureGit $fixture @('status','--short')) -join "`n") | Should Be $statusBefore
        (Get-FileHash -LiteralPath $indexPath -Algorithm SHA256).Hash | Should Be $indexBefore
        (Invoke-FixtureGit $fixture @('branch','--show-current')) | Should Be $branchBefore
    }

    It 'does not require an unrelated package new review to join the commit' {
        Write-FixtureFile $fixture 'specs/001-example/plan.md' "# Plan`nStaged package-one change.`n"
        $null=Invoke-FixtureGit $fixture @('add','specs/001-example/plan.md')
        Write-FixtureFile $fixture 'specs/002-other/reviews/local-notes.md' "# Local notes`nUnrelated work in progress.`n"
        $result=Invoke-ScopedHookCheck $fixture
        $result.ExitCode | Should Be 0
    }

    It 'still refuses partial staging of an affected contract owner' {
        $path=Join-Path $fixture.RepoRoot 'specs/001-example/spec.md'
        Write-FixtureFile $fixture 'specs/001-example/spec.md' ([IO.File]::ReadAllText($path)+"`nStaged note.`n")
        $null=Invoke-FixtureGit $fixture @('add','specs/001-example/spec.md')
        Write-FixtureFile $fixture 'specs/001-example/spec.md' ([IO.File]::ReadAllText($path)+"`nUnstaged note.`n")
        $result=Invoke-ScopedHookCheck $fixture
        $result.ExitCode | Should Be 1
        $result.Output | Should Match 'differs between index and worktree'
    }

    It 'requires a new review in the affected package to be staged' {
        Write-FixtureFile $fixture 'specs/001-example/plan.md' "# Plan`nStaged package-one change.`n"
        $null=Invoke-FixtureGit $fixture @('add','specs/001-example/plan.md')
        Write-FixtureFile $fixture 'specs/001-example/reviews/new-findings.md' "# Findings`nDurable evidence.`n"
        $result=Invoke-ScopedHookCheck $fixture
        $result.ExitCode | Should Be 1
        $result.Output | Should Match 'affected package owner/review artifacts are not staged'
    }

    It 'broadens catalog changes to every governed package' {
        $catalogPath=Join-Path $fixture.RepoRoot 'docs/specs.md'
        Write-FixtureFile $fixture 'docs/specs.md' ([IO.File]::ReadAllText($catalogPath)+"`n")
        $null=Invoke-FixtureGit $fixture @('add','docs/specs.md')
        Write-FixtureFile $fixture 'specs/002-other/reviews/new-findings.md' "# Findings`nDurable evidence.`n"
        $result=Invoke-ScopedHookCheck $fixture
        $result.ExitCode | Should Be 1
        $result.Output | Should Match 'affected package owner/review artifacts are not staged'
    }

    It 'broadens config changes to every governed package' {
        $config=Get-FixtureConfig $fixture
        $config.managedScratchRoot='{temp}/hook-scope-fixture'
        Set-FixtureConfig $fixture $config
        $null=Invoke-FixtureGit $fixture @('add','.workflow-kit.json')
        Write-FixtureFile $fixture 'specs/002-other/reviews/new-findings.md' "# Findings`nDurable evidence.`n"
        $result=Invoke-ScopedHookCheck $fixture
        $result.ExitCode | Should Be 1
        $result.Output | Should Match 'affected package owner/review artifacts are not staged'
    }

    It 'rejects staged review deletion and rename' {
        $null=Invoke-FixtureGit $fixture @('mv','specs/002-other/reviews/CP1-review.md','specs/002-other/reviews/CP1-verdict.md')
        $result=Invoke-ScopedHookCheck $fixture
        $result.ExitCode | Should Be 1
        $result.Output | Should Match 'staged deletion of contract owner/review'
    }

    It 'rejects staged deletion of a Unicode-named durable review' {
        Write-FixtureFile $fixture 'specs/002-other/reviews/révision-δ.md' "# Révision`nDurable evidence.`n"
        Save-FixtureRevision $fixture
        $null=Invoke-FixtureGit $fixture @('rm','specs/002-other/reviews/révision-δ.md')
        $result=Invoke-ScopedHookCheck $fixture
        $result.ExitCode | Should Be 1
        $result.Output | Should Match 'révision-δ\.md'
        $result.Output | Should Match 'staged deletion of contract owner/review'
    }

    It 'rejects staged rename of a Unicode-named durable review' {
        Write-FixtureFile $fixture 'specs/002-other/reviews/révision-δ.md' "# Révision`nDurable evidence.`n"
        Save-FixtureRevision $fixture
        $null=Invoke-FixtureGit $fixture @('mv','specs/002-other/reviews/révision-δ.md','specs/002-other/reviews/révision-終.md')
        $result=Invoke-ScopedHookCheck $fixture
        $result.ExitCode | Should Be 1
        $result.Output | Should Match 'révision-δ\.md'
        $result.Output | Should Match 'staged deletion of contract owner/review'
    }

    It 'validates staged bytes for injected root content' {
        $path=Join-Path $fixture.RepoRoot 'AGENTS.md'
        $original=[IO.File]::ReadAllText($path)
        Write-FixtureFile $fixture 'AGENTS.md' ($original+"<!-- SPECKIT START -->`nInjected plan`n<!-- SPECKIT END -->`n")
        $null=Invoke-FixtureGit $fixture @('add','AGENTS.md')
        $result=Invoke-ScopedHookCheck $fixture
        $result.ExitCode | Should Be 1
        $result.Output | Should Match 'marker-injection'
    }

    It 'preserves a remote-only declared branch as fetchable in the snapshot' {
        $featureRevision=Invoke-FixtureGit $fixture @('rev-parse','feat/001-example')
        $null=Invoke-FixtureGit $fixture @('switch','--quiet','master')
        $null=Invoke-FixtureGit $fixture @('config','remote.origin.url','https://example.invalid/workflow.git')
        $null=Invoke-FixtureGit $fixture @('update-ref','refs/remotes/origin/feat/001-example',$featureRevision)
        $null=Invoke-FixtureGit $fixture @('branch','-D','feat/001-example')
        Write-FixtureFile $fixture 'README.md' "# Fixture`nRead [the catalog](docs/specs.md).`nRemote inventory check.`n"
        $null=Invoke-FixtureGit $fixture @('add','README.md')
        $result=Invoke-ScopedHookCheck $fixture
        $result.ExitCode | Should Be 0
        $result.Output | Should Match 'package-fetch'
    }

    It 'preserves an uncached configured remote as unknown in the snapshot' {
        $null=Invoke-FixtureGit $fixture @('switch','--quiet','master')
        $null=Invoke-FixtureGit $fixture @('config','remote.origin.url','https://example.invalid/workflow.git')
        $null=Invoke-FixtureGit $fixture @('branch','-D','feat/001-example')
        Write-FixtureFile $fixture 'README.md' "# Fixture`nRead [the catalog](docs/specs.md).`nUnknown inventory check.`n"
        $null=Invoke-FixtureGit $fixture @('add','README.md')
        $result=Invoke-ScopedHookCheck $fixture
        $result.ExitCode | Should Be 0
        $result.Output | Should Match 'package-fetch'
        $result.Output | Should Match 'remote inventory is unknown'
    }

    It 'preserves a known missing declared branch as an error in the snapshot' {
        $null=Invoke-FixtureGit $fixture @('switch','--quiet','master')
        $null=Invoke-FixtureGit $fixture @('branch','-D','feat/001-example')
        Write-FixtureFile $fixture 'README.md' "# Fixture`nRead [the catalog](docs/specs.md).`nMissing inventory check.`n"
        $null=Invoke-FixtureGit $fixture @('add','README.md')
        $result=Invoke-ScopedHookCheck $fixture
        $result.ExitCode | Should Be 1
        $result.Output | Should Match 'package-orphan'
    }
}
