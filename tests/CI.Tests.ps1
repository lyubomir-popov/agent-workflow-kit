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

function Invoke-FixtureWhitespace {
    param($Fixture, [string]$EventName, $Event)
    $eventPath = Join-Path $Fixture.TempRoot 'whitespace-event.json'
    [IO.File]::WriteAllText($eventPath, ($Event | ConvertTo-Json -Depth 8))
    $output = & pwsh -NoLogo -NoProfile -File (Join-Path $script:KitRoot '.github/scripts/check-whitespace.ps1') -RepoRoot $Fixture.RepoRoot -EventName $EventName -EventPath $eventPath 2>&1
    return [pscustomobject]@{ ExitCode=$LASTEXITCODE; Raw=($output -join "`n") }
}

Describe 'CI checks committed event whitespace with a clean checkout' {
    BeforeEach { $script:fixture = New-WorkflowFixture }
    AfterEach { Remove-WorkflowFixture $script:fixture }

    It 'checks push before and after commits rather than an empty worktree diff' {
        $base = [string](git -C $fixture.RepoRoot rev-parse HEAD)
        Write-FixtureFile $fixture 'whitespace.txt' "Trailing whitespace   `n"
        Save-FixtureRevision $fixture
        $head = [string](git -C $fixture.RepoRoot rev-parse HEAD)
        @(& git -C $fixture.RepoRoot status --porcelain).Count | Should Be 0
        $result = Invoke-FixtureWhitespace $fixture push @{before=$base;after=$head}
        $result.ExitCode | Should Be 1
        $result.Raw | Should Match 'whitespace.txt:1: trailing whitespace'
    }

    It 'checks a PR merge-base-to-head range instead of unrelated target changes' {
        $base = [string](git -C $fixture.RepoRoot rev-parse master)
        Write-FixtureFile $fixture 'whitespace.txt' "PR whitespace   `n"
        Save-FixtureRevision $fixture
        $head = [string](git -C $fixture.RepoRoot rev-parse HEAD)
        $result = Invoke-FixtureWhitespace $fixture pull_request @{pull_request=@{base=@{sha=$base};head=@{sha=$head}}}
        $result.ExitCode | Should Be 1
        $result.Raw | Should Match 'whitespace.txt:1: trailing whitespace'
    }

    It 'excludes unrelated whitespace on a diverged PR target' {
        Write-FixtureFile $fixture 'source-clean.txt' "Clean feature change.`n"
        Save-FixtureRevision $fixture
        $head = [string](git -C $fixture.RepoRoot rev-parse HEAD)
        $null = Invoke-FixtureGit $fixture @('switch','--quiet','master')
        Write-FixtureFile $fixture 'target-only.txt' "Unrelated target whitespace   `n"
        Save-FixtureRevision $fixture
        $base = [string](git -C $fixture.RepoRoot rev-parse HEAD)
        $result = Invoke-FixtureWhitespace $fixture pull_request @{pull_request=@{base=@{sha=$base};head=@{sha=$head}}}
        $result.ExitCode | Should Be 0
        $result.Raw | Should Not Match 'target-only.txt'
    }

    It 'fails PR revisions that are unavailable or have unrelated histories' {
        $head = [string](git -C $fixture.RepoRoot rev-parse HEAD)
        $missing = Invoke-FixtureWhitespace $fixture pull_request @{pull_request=@{base=@{sha=('1'*40)};head=@{sha=$head}}}
        $missing.ExitCode | Should Be 1
        $missing.Raw | Should Match 'event revision is unavailable'
        $tree = [string](git -C $fixture.RepoRoot rev-parse 'HEAD^{tree}')
        $unrelated = [string](Invoke-FixtureGit $fixture @('commit-tree',$tree,'-m','Unrelated PR history'))
        $result = Invoke-FixtureWhitespace $fixture pull_request @{pull_request=@{base=@{sha=$unrelated};head=@{sha=$head}}}
        $result.ExitCode | Should Be 1
        $result.Raw | Should Match 'no available merge base'
    }

    It 'passes a nonempty clean push range and leaves status unchanged' {
        $base = [string](git -C $fixture.RepoRoot rev-parse HEAD)
        Write-FixtureFile $fixture 'clean.txt' "Clean committed text.`n"
        Save-FixtureRevision $fixture
        $head = [string](git -C $fixture.RepoRoot rev-parse HEAD)
        $result = Invoke-FixtureWhitespace $fixture push @{before=$base;after=$head}
        $result.ExitCode | Should Be 0
        $result.Raw | Should Match ([regex]::Escape("${base}..$head"))
        @(& git -C $fixture.RepoRoot status --porcelain).Count | Should Be 0
    }

    It 'uses the configured-target merge base for a first feature push' {
        Write-FixtureFile $fixture 'whitespace.txt' "First push   `n"
        Save-FixtureRevision $fixture
        $head = [string](git -C $fixture.RepoRoot rev-parse HEAD)
        $result = Invoke-FixtureWhitespace $fixture push @{before=('0'*40);after=$head}
        $result.ExitCode | Should Be 1
        $result.Raw | Should Match 'whitespace.txt:1: trailing whitespace'
    }

    It 'falls back to the parent when the first-push target is the event head' {
        $null = Invoke-FixtureGit $fixture @('switch','--quiet','master')
        Write-FixtureFile $fixture 'whitespace.txt' "First target push   `n"
        Save-FixtureRevision $fixture
        $head = [string](git -C $fixture.RepoRoot rev-parse HEAD)
        $result = Invoke-FixtureWhitespace $fixture push @{before=('0'*40);after=$head}
        $result.ExitCode | Should Be 1
        $result.Raw | Should Match 'whitespace.txt:1: trailing whitespace'
    }

    It 'checks a root commit against the empty tree rather than against itself' {
        Write-FixtureFile $fixture 'nested/root-whitespace.txt' "Root whitespace   `n"
        Save-FixtureRevision $fixture
        $tree = [string](git -C $fixture.RepoRoot rev-parse 'HEAD^{tree}')
        $head = [string](Invoke-FixtureGit $fixture @('commit-tree',$tree,'-m','Root whitespace fixture'))
        $null = Invoke-FixtureGit $fixture @('update-ref','refs/heads/master',$head)
        $result = Invoke-FixtureWhitespace $fixture push @{before=('0'*40);after=$head}
        $result.Raw | Should Match "empty tree\.\.$head"
        $result.ExitCode | Should Be 1
        $result.Raw | Should Match 'nested/root-whitespace.txt:1: trailing whitespace'
    }

    It 'fails unavailable or malformed nonzero event revisions instead of falling back' {
        $head = [string](git -C $fixture.RepoRoot rev-parse HEAD)
        foreach ($before in @(('1'*40),'HEAD; git status')) {
            $result = Invoke-FixtureWhitespace $fixture push @{before=$before;after=$head}
            $result.ExitCode | Should Be 1
            $result.Raw | Should Match 'Whitespace (event revision is unavailable|check requires a full event commit ID)'
        }
    }

    It 'wires the CI step to event-local evidence and full history' {
        $workflow | Should Match 'fetch-depth: 0'
        $workflow | Should Match 'check-whitespace.ps1 -RepoRoot \. -EventName \$env:GITHUB_EVENT_NAME -EventPath \$env:GITHUB_EVENT_PATH'
        $workflow | Should Not Match 'run: git diff --check\s*$'
    }
}
