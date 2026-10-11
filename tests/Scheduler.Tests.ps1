. (Join-Path $PSScriptRoot 'Fixture.Helpers.ps1')
. (Join-Path $script:KitRoot 'workflow-model.ps1')
. (Join-Path $script:KitRoot 'workflow-scheduler.ps1')

# The scheduler library has no worker executable. These local primitives use
# only fixture Git; a missing worker mock fails immediately and cannot launch.
function Get-WorkingTreeStatus {
    param([string]$RepoPath)
    return @(git -C $RepoPath status --porcelain)
}
function Get-HeadCommit {
    param([string]$RepoPath)
    return [string](git -C $RepoPath rev-parse HEAD)
}
function Invoke-SpecKitWorkerPhase {
    param($SpecPackage, $Phase, $Task, $RepoPath, $InvocationCount, $SkippedLineIndices, $DefaultModel, $DefaultEffort)
    throw 'Test worker was not mocked; no real worker can run from this fixture.'
}

Describe 'Scheduler authorization and bounded failure paths' {
    BeforeEach {
        $script:fixture = New-WorkflowFixture
        $script:config = Get-FixtureConfig $fixture
        $config.managedScratchRoot = Join-Path $fixture.TempRoot 'scratch'
        Set-FixtureConfig $fixture $config
        Save-FixtureRevision $fixture
        $script:DryRun = $false
        $script:MaxSpecs = 0
        $script:MaxTasks = 0
        $script:Model = 'fixture-mock'
        $script:ReasoningEffort = 'low'
        Mock Assert-WorkflowPreflight { }
        Mock Invoke-SpecKitWorkerPhase { [pscustomobject]@{ Status='ok'; WorktreePath='fixture-only' } }
    }
    AfterEach { Remove-WorkflowFixture $script:fixture }

    It 'dispatches no worker for every lifecycle outside active' {
        foreach ($state in @('draft','review','ready','parked','delivered','closed','superseded')) {
            Set-FixtureSpec $fixture -Lifecycle $state
            Save-FixtureRevision $fixture
            Start-WorkflowScheduler $fixture.RepoRoot $config
        }
        Assert-MockCalled Invoke-SpecKitWorkerPhase -Times 0 -Exactly -Scope It
    }

    It 'reports an active package with all checkboxes complete as incomplete rather than clearing exit gates' {
        Set-FixtureTasks $fixture '- [x] T001 Implement example.'
        Save-FixtureRevision $fixture
        (Test-FixtureThrows { Start-WorkflowScheduler $fixture.RepoRoot $config }) | Should Be $true
        Assert-MockCalled Invoke-SpecKitWorkerPhase -Times 0 -Exactly -Scope It
        @(Get-WorkflowPackages $fixture.RepoRoot)[0].Checkpoints[1].State | Should Be pending
    }

    It 'stops before dispatch when the entry checkpoint is pending' {
        Set-FixtureSpec $fixture -State pending
        Save-FixtureRevision $fixture
        (Test-FixtureThrows { Start-WorkflowScheduler $fixture.RepoRoot $config }) | Should Be $true
        Assert-MockCalled Invoke-SpecKitWorkerPhase -Times 0 -Exactly -Scope It
    }

    It 'stops before dispatch for missing blocking superseded and obsolete verdicts' {
        foreach ($verdict in @('blocking','superseded')) {
            Set-FixtureReview $fixture -Verdict $verdict
            Save-FixtureRevision $fixture
            (Test-FixtureThrows { Start-WorkflowScheduler $fixture.RepoRoot $config }) | Should Be $true
        }
        Set-FixtureSpec $fixture -VerdictLink '[missing](reviews/missing.md)'
        Save-FixtureRevision $fixture
        (Test-FixtureThrows { Start-WorkflowScheduler $fixture.RepoRoot $config }) | Should Be $true
        Set-FixtureSpec $fixture -Scope '001/spec-r2'
        Set-FixtureReview $fixture -Scope '001/spec-r1'
        Save-FixtureRevision $fixture
        (Test-FixtureThrows { Start-WorkflowScheduler $fixture.RepoRoot $config }) | Should Be $true
        Assert-MockCalled Invoke-SpecKitWorkerPhase -Times 0 -Exactly -Scope It
    }

    It 'rechecks the next task override gate after one authorized task completes' {
        Set-FixtureTasks $fixture "- [ ] T001 Authorized work.`n- [ ] T002 Future work (gate: CP2)."
        Save-FixtureRevision $fixture
        Mock Invoke-SpecKitWorkerPhase {
            Set-FixtureTasks $script:fixture "- [x] T001 Authorized work.`n- [ ] T002 Future work (gate: CP2)."
            Save-FixtureRevision $script:fixture
            [pscustomobject]@{ Status='ok'; WorktreePath='fixture-only' }
        }
        (Test-FixtureThrows { Start-WorkflowScheduler $fixture.RepoRoot $config }) | Should Be $true
        Assert-MockCalled Invoke-SpecKitWorkerPhase -Times 1 -Exactly -Scope It
        $tasks = @(Get-WorkflowTasks @(Get-WorkflowPackages $fixture.RepoRoot)[0])
        $tasks[0].Complete | Should Be $true
        $tasks[1].Complete | Should Be $false
    }

    It 'runs dry discovery without workers branch changes or file mutations' {
        $script:DryRun = $true
        $branch = Get-WorkflowBranch $fixture.RepoRoot
        $head = Get-HeadCommit $fixture.RepoRoot
        Start-WorkflowScheduler $fixture.RepoRoot $config
        Assert-MockCalled Invoke-SpecKitWorkerPhase -Times 0 -Exactly -Scope It
        (Get-WorkflowBranch $fixture.RepoRoot) | Should Be $branch
        (Get-HeadCommit $fixture.RepoRoot) | Should Be $head
        @(Get-WorkingTreeStatus $fixture.RepoRoot).Count | Should Be 0
    }

    It 'fails preflight before a worker or checkout mutation' {
        Mock Assert-WorkflowPreflight { throw 'fixture preflight failure' }
        (Test-FixtureThrows { Start-WorkflowScheduler $fixture.RepoRoot $config }) | Should Be $true
        Assert-MockCalled Invoke-SpecKitWorkerPhase -Times 0 -Exactly -Scope It
        (Get-WorkflowBranch $fixture.RepoRoot) | Should Be 'feat/001-example'
    }

    It 'fails a real unavailable branch checkout without falling back' {
        (Test-FixtureThrows { Switch-WorkflowBranch $fixture.RepoRoot 'feat/999-absent' }) | Should Be $true
        (Get-WorkflowBranch $fixture.RepoRoot) | Should Be 'feat/001-example'
        Assert-MockCalled Invoke-SpecKitWorkerPhase -Times 0 -Exactly -Scope It
    }

    It 'preserves a dirty primary checkout and dispatches no worker' {
        Write-FixtureFile $fixture 'user-work.txt' 'Keep this user work.'
        (Test-FixtureThrows { Start-WorkflowScheduler $fixture.RepoRoot $config }) | Should Be $true
        Assert-MockCalled Invoke-SpecKitWorkerPhase -Times 0 -Exactly -Scope It
        [IO.File]::ReadAllText((Join-Path $fixture.RepoRoot 'user-work.txt')) | Should Be 'Keep this user work.'
    }

    It 'refuses an unchanged success result after exactly one invocation' {
        (Test-FixtureThrows { Start-WorkflowScheduler $fixture.RepoRoot $config }) | Should Be $true
        Assert-MockCalled Invoke-SpecKitWorkerPhase -Times 1 -Exactly -Scope It
        @(Get-WorkflowTasks @(Get-WorkflowPackages $fixture.RepoRoot)[0])[0].Complete | Should Be $false
    }

    It 'fails worker and integration failure outcomes while retaining partial scratch' {
        Mock Invoke-SpecKitWorkerPhase {
            $script:partialScratch = New-WorkflowScratch $script:fixture.RepoRoot
            [IO.File]::WriteAllText((Join-Path $script:partialScratch 'partial-work.txt'), 'Recoverable partial work.')
            [pscustomobject]@{ Status='integration-failed'; WorktreePath=$script:partialScratch }
        }
        (Test-FixtureThrows { Start-WorkflowScheduler $fixture.RepoRoot $config }) | Should Be $true
        Assert-MockCalled Invoke-SpecKitWorkerPhase -Times 1 -Exactly -Scope It
        (Test-Path -LiteralPath (Join-Path $script:partialScratch 'partial-work.txt')) | Should Be $true
        (Test-FixtureThrows { Remove-WorkflowScratch $fixture.RepoRoot $script:partialScratch }) | Should Be $true
        (Test-Path -LiteralPath $script:partialScratch) | Should Be $true
    }

    It 'fails a mocked worker process failure without retrying' {
        Mock Invoke-SpecKitWorkerPhase { [pscustomobject]@{ Status='worker-failed'; WorktreePath='retained-fixture-path' } }
        (Test-FixtureThrows { Start-WorkflowScheduler $fixture.RepoRoot $config }) | Should Be $true
        Assert-MockCalled Invoke-SpecKitWorkerPhase -Times 1 -Exactly -Scope It
    }

    It 'fails a cap with required work remaining after preserving completed progress' {
        $script:MaxTasks = 1
        Set-FixtureTasks $fixture "- [ ] T001 First.`n- [ ] T002 Second."
        Save-FixtureRevision $fixture
        Mock Invoke-SpecKitWorkerPhase {
            Set-FixtureTasks $script:fixture "- [x] T001 First.`n- [ ] T002 Second."
            Save-FixtureRevision $script:fixture
            [pscustomobject]@{ Status='ok'; WorktreePath='fixture-only' }
        }
        (Test-FixtureThrows { Start-WorkflowScheduler $fixture.RepoRoot $config }) | Should Be $true
        Assert-MockCalled Invoke-SpecKitWorkerPhase -Times 1 -Exactly -Scope It
    }

    It 'fails exhausted remediation instead of reporting success' {
        $script:rounds = 0
        (Test-FixtureThrows {
            Invoke-BoundedRemediation -MaxRounds 2 -HasFindings { $true } -RunRound { $script:rounds++; 'ok' }
        }) | Should Be $true
        $script:rounds | Should Be 2
    }

    It 'stops remediation immediately when a round fails' {
        $script:rounds = 0
        (Test-FixtureThrows {
            Invoke-BoundedRemediation -MaxRounds 3 -HasFindings { $true } -RunRound { $script:rounds++; 'worker-failed' }
        }) | Should Be $true
        $script:rounds | Should Be 1
    }
}

Describe 'Contained scratch preservation' {
    BeforeEach {
        $script:fixture = New-WorkflowFixture
        $config = Get-FixtureConfig $fixture
        $config.managedScratchRoot = Join-Path $fixture.TempRoot 'scratch'
        Set-FixtureConfig $fixture $config
        Save-FixtureRevision $fixture
        $script:scratch = New-WorkflowScratch $fixture.RepoRoot
    }
    AfterEach { Remove-WorkflowFixture $script:fixture }

    It 'removes only marked contained integrated scratch through Git' {
        Remove-WorkflowScratch $fixture.RepoRoot $scratch
        (Test-Path -LiteralPath $scratch) | Should Be $false
        (Test-Path -LiteralPath $fixture.RepoRoot) | Should Be $true
        @(Get-WorkingTreeStatus $fixture.RepoRoot).Count | Should Be 0
    }

    It 'protects the primary checkout from scratch removal' {
        (Test-FixtureThrows { Remove-WorkflowScratch $fixture.RepoRoot $fixture.RepoRoot }) | Should Be $true
        (Test-Path -LiteralPath $fixture.RepoRoot) | Should Be $true
    }

    It 'preserves tracked scratch changes' {
        [IO.File]::AppendAllText((Join-Path $scratch 'README.md'), "`nRecoverable changes.`n")
        (Test-FixtureThrows { Remove-WorkflowScratch $fixture.RepoRoot $scratch }) | Should Be $true
        (Test-Path -LiteralPath $scratch) | Should Be $true
    }

    It 'preserves ignored evidence even within a disposable directory' {
        $scratchFixture = [pscustomobject]@{ RepoRoot=$scratch }
        Write-FixtureFile $scratchFixture 'node_modules/evidence/result.txt' 'Keep evidence.'
        # Directory is untracked here; preservation must also apply when ignored.
        $admin = [string](git -C $scratch rev-parse --git-common-dir)
        [IO.File]::AppendAllText((Join-Path $admin 'info/exclude'), "`nnode_modules/`n")
        (Test-FixtureThrows { Remove-WorkflowScratch $fixture.RepoRoot $scratch }) | Should Be $true
        [IO.File]::ReadAllText((Join-Path $scratch 'node_modules/evidence/result.txt')) | Should Be 'Keep evidence.'
    }

    It 'preserves unpublished committed scratch work' {
        $scratchFixture = [pscustomobject]@{ RepoRoot=$scratch }
        Write-FixtureFile $scratchFixture 'unpublished.txt' 'Keep committed work.'
        Save-FixtureRevision $scratchFixture
        (Test-FixtureThrows { Remove-WorkflowScratch $fixture.RepoRoot $scratch }) | Should Be $true
        (Test-Path -LiteralPath $scratch) | Should Be $true
    }

    It 'preserves a scratch worktree whose marker is missing' {
        $admin = [string](git -C $scratch rev-parse --absolute-git-dir)
        Remove-Item -LiteralPath (Join-Path $admin 'workflow-kit-scratch.json')
        (Test-FixtureThrows { Remove-WorkflowScratch $fixture.RepoRoot $scratch }) | Should Be $true
        (Test-Path -LiteralPath $scratch) | Should Be $true
    }

    It 'preserves locked scratch worktrees' {
        $null = Invoke-FixtureGit $fixture @('worktree','lock',$scratch)
        (Test-FixtureThrows { Remove-WorkflowScratch $fixture.RepoRoot $scratch }) | Should Be $true
        (Test-Path -LiteralPath $scratch) | Should Be $true
    }

    It 'refuses a scratch sibling with a shared path prefix' {
        $sibling = (Split-Path $scratch -Parent) + '-outside'
        $null = New-Item -ItemType Directory -Path $sibling
        [IO.File]::WriteAllText((Join-Path $sibling 'keep.txt'), 'Protected sibling.')
        (Test-FixtureThrows { Remove-WorkflowScratch $fixture.RepoRoot $sibling }) | Should Be $true
        [IO.File]::ReadAllText((Join-Path $sibling 'keep.txt')) | Should Be 'Protected sibling.'
    }

    It 'refuses a linked path inside the managed root' {
        $link = Join-Path (Split-Path $scratch -Parent) 'linked-scratch'
        $type = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
        $null = New-Item -ItemType $type -Path $link -Target $scratch
        (Test-FixtureThrows { Remove-WorkflowScratch $fixture.RepoRoot $link }) | Should Be $true
        (Test-Path -LiteralPath $scratch) | Should Be $true
    }

    It 'preserves a scratch worktree with mismatched marker ownership' {
        $admin = [string](git -C $scratch rev-parse --absolute-git-dir)
        $path = Join-Path $admin 'workflow-kit-scratch.json'
        $marker = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        $marker.repo = Join-Path $fixture.TempRoot 'wrong-repo'
        [IO.File]::WriteAllText($path, ($marker | ConvertTo-Json))
        (Test-FixtureThrows { Remove-WorkflowScratch $fixture.RepoRoot $scratch }) | Should Be $true
        (Test-Path -LiteralPath $scratch) | Should Be $true
    }

    It 'preserves on-demand reviews and unknown untracked files' {
        $scratchFixture = [pscustomobject]@{ RepoRoot=$scratch }
        Write-FixtureFile $scratchFixture 'specs/001-example/reviews/new-findings.md' 'Preserve the review.'
        Write-FixtureFile $scratchFixture 'unknown-untracked.txt' 'Preserve this file.'
        (Test-FixtureThrows { Remove-WorkflowScratch $fixture.RepoRoot $scratch }) | Should Be $true
        (Test-Path -LiteralPath (Join-Path $scratch 'specs/001-example/reviews/new-findings.md')) | Should Be $true
        (Test-Path -LiteralPath (Join-Path $scratch 'unknown-untracked.txt')) | Should Be $true
    }
}
