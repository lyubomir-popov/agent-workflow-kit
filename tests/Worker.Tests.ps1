. (Join-Path $PSScriptRoot 'Fixture.Helpers.ps1')
. (Join-Path $script:KitRoot 'workflow-model.ps1')
. (Join-Path $script:KitRoot 'workflow-scheduler.ps1')
# Import production functions without executing the agent-loop entry point.
$tokens=$null; $errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $script:KitRoot 'agent-loop.ps1'),[ref]$tokens,[ref]$errors)
if ($errors) { throw $errors }
foreach ($definition in $ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst]},$true)) {
    Invoke-Expression $definition.Extent.Text
}

Describe 'Production worker integration and failure preservation in disposable repositories' {
    BeforeEach {
        $script:fixture=New-WorkflowFixture
        $config=Get-FixtureConfig $fixture
        $config.managedScratchRoot=Join-Path $fixture.TempRoot 'scratch'
        Set-FixtureConfig $fixture $config
        Save-FixtureRevision $fixture
        $script:WorkerAgent='Copilot'; $script:UseTierDispatch=$false; $script:OnFailure='stop'
        $script:TaskTimeoutSeconds=5; $script:MaxContinues=1
        $script:invocations=0
        # A regression must only affect fixtures, never the real kit checkout.
        Push-Location $fixture.RepoRoot
    }
    AfterEach { Pop-Location; Remove-WorkflowFixture $script:fixture }

    It 'integrates into the declared worktree and leaves an unrelated primary branch untouched' {
        $null=Invoke-FixtureGit $fixture @('switch','--quiet','master')
        $delivery=Join-Path $fixture.TempRoot 'delivery'
        $null=Invoke-FixtureGit $fixture @('worktree','add','--quiet',$delivery,'feat/001-example')
        $primaryBefore=Get-HeadCommit $fixture.RepoRoot
        $package=@(Get-WorkflowPackages $fixture.RepoRoot)[0]
        $task=@(Get-WorkflowTasks $package)[0]
        Mock Invoke-AgentTask {
            $worker=[pscustomobject]@{RepoRoot=$WorkingDirectory}
            $specPath=Join-Path $WorkingDirectory 'specs/001-example/spec.md'
            [IO.File]::AppendAllText($specPath,"`nImplementation detail below the owner block.`n")
            Set-FixtureTasks $worker "- [x] T001 Implement example.`n- [ ] T002 Future work (gate: CP2)."
            $path=Join-Path $WorkingDirectory 'specs/001-example/tasks.md'
            [IO.File]::WriteAllText($path,[IO.File]::ReadAllText($path).Replace('**Next tasks**: T001.','**Next tasks**: T002.'))
            Save-FixtureRevision $worker
            [pscustomobject]@{ExitCode=0; TimedOut=$false; ElapsedSeconds=0; StdOut=@(); StdErr=@()}
        }
        $result=Invoke-SpecKitWorkerPhase -SpecPackage $package -Phase implement -Task $task -RepoPath $delivery -InvocationCount ([ref]$script:invocations) -SkippedLineIndices ([ref]$null) -DefaultModel fixture -DefaultEffort low
        $result.Status | Should Be ok
        (Get-HeadCommit $fixture.RepoRoot) | Should Be $primaryBefore
        (Get-HeadCommit $delivery) | Should Not Be $primaryBefore
        @(Get-WorkflowTasks @(Get-WorkflowPackages $delivery)[0])[0].Complete | Should Be $true
        (Test-Path -LiteralPath $result.WorktreePath) | Should Be $false
        Assert-MockCalled Invoke-AgentTask -Times 1 -Exactly -Scope It
    }

    It 'rejects worker spec owner-block edits before integration and retains scratch' {
        $package=@(Get-WorkflowPackages $fixture.RepoRoot)[0]
        $task=@(Get-WorkflowTasks $package)[0]
        $before=Get-HeadCommit $fixture.RepoRoot
        Mock Invoke-AgentTask {
            $worker=[pscustomobject]@{RepoRoot=$WorkingDirectory}
            Set-FixtureSpec $worker -Lifecycle delivered
            Save-FixtureRevision $worker
            [pscustomobject]@{ExitCode=0; TimedOut=$false; ElapsedSeconds=0; StdOut=@(); StdErr=@()}
        }
        $result=Invoke-SpecKitWorkerPhase -SpecPackage $package -Phase implement -Task $task -RepoPath $fixture.RepoRoot -InvocationCount ([ref]$script:invocations) -SkippedLineIndices ([ref]$null) -DefaultModel fixture -DefaultEffort low
        $result.Status | Should Be worker-incomplete
        $result.Reason | Should Match 'owner spec block'
        (Get-HeadCommit $fixture.RepoRoot) | Should Be $before
        (Test-Path -LiteralPath $result.WorktreePath) | Should Be $true
    }

    It 'rejects added and modified review verdicts before integration and retains scratch' {
        $package=@(Get-WorkflowPackages $fixture.RepoRoot)[0]
        $task=@(Get-WorkflowTasks $package)[0]
        $before=Get-HeadCommit $fixture.RepoRoot
        Mock Invoke-AgentTask {
            $worker=[pscustomobject]@{RepoRoot=$WorkingDirectory}
            Write-FixtureFile $worker $script:reviewPath "# Worker review`n- **Verdict**: accept`n"
            Save-FixtureRevision $worker
            [pscustomobject]@{ExitCode=0; TimedOut=$false; ElapsedSeconds=0; StdOut=@(); StdErr=@()}
        }
        foreach ($path in @('specs/001-example/reviews/fabricated.md','specs/001-example/reviews/CP1-review.md')) {
            $script:reviewPath=$path
            $result=Invoke-SpecKitWorkerPhase -SpecPackage $package -Phase implement -Task $task -RepoPath $fixture.RepoRoot -InvocationCount ([ref]$script:invocations) -SkippedLineIndices ([ref]$null) -DefaultModel fixture -DefaultEffort low
            $result.Status | Should Be worker-incomplete
            $result.Reason | Should Match 'review verdict'
            (Get-HeadCommit $fixture.RepoRoot) | Should Be $before
            (Test-Path -LiteralPath $result.WorktreePath) | Should Be $true
        }
    }

    It 'rejects newly completing an unrelated task before integration and retains scratch' {
        Set-FixtureTasks $fixture "- [ ] T001 Implement example.`n- [ ] T002 Beyond the pending gate (gate: CP2)."
        Save-FixtureRevision $fixture
        $package=@(Get-WorkflowPackages $fixture.RepoRoot)[0]
        $task=@(Get-WorkflowTasks $package)[0]
        $before=Get-HeadCommit $fixture.RepoRoot
        Mock Invoke-AgentTask {
            $worker=[pscustomobject]@{RepoRoot=$WorkingDirectory}
            Set-FixtureTasks $worker "- [x] T001 Implement example.`n- [x] T002 Beyond the pending gate (gate: CP2)."
            Save-FixtureRevision $worker
            [pscustomobject]@{ExitCode=0; TimedOut=$false; ElapsedSeconds=0; StdOut=@(); StdErr=@()}
        }
        $result=Invoke-SpecKitWorkerPhase -SpecPackage $package -Phase implement -Task $task -RepoPath $fixture.RepoRoot -InvocationCount ([ref]$script:invocations) -SkippedLineIndices ([ref]$null) -DefaultModel fixture -DefaultEffort low
        $result.Status | Should Be worker-incomplete
        $result.Reason | Should Match 'unrelated task T002'
        (Get-HeadCommit $fixture.RepoRoot) | Should Be $before
        (Test-Path -LiteralPath $result.WorktreePath) | Should Be $true
    }

    It 'rejects an owner-block edit even when a later worker commit reverts it' {
        $package=@(Get-WorkflowPackages $fixture.RepoRoot)[0]
        $task=@(Get-WorkflowTasks $package)[0]
        $before=Get-HeadCommit $fixture.RepoRoot
        Mock Invoke-AgentTask {
            $worker=[pscustomobject]@{RepoRoot=$WorkingDirectory}
            Set-FixtureSpec $worker -Lifecycle delivered
            Save-FixtureRevision $worker
            Set-FixtureSpec $worker
            Save-FixtureRevision $worker
            [pscustomobject]@{ExitCode=0; TimedOut=$false; ElapsedSeconds=0; StdOut=@(); StdErr=@()}
        }
        $result=Invoke-SpecKitWorkerPhase -SpecPackage $package -Phase implement -Task $task -RepoPath $fixture.RepoRoot -InvocationCount ([ref]$script:invocations) -SkippedLineIndices ([ref]$null) -DefaultModel fixture -DefaultEffort low
        $result.Status | Should Be worker-incomplete
        (Get-HeadCommit $fixture.RepoRoot) | Should Be $before
        (Test-Path -LiteralPath $result.WorktreePath) | Should Be $true
    }

    It 'preserves a timed-out worker with ignored user evidence even without a commit' {
        $package=@(Get-WorkflowPackages $fixture.RepoRoot)[0]
        $task=@(Get-WorkflowTasks $package)[0]
        Mock Invoke-AgentTask {
            $script:timedOutScratch=$WorkingDirectory
            $admin=[string](git -C $WorkingDirectory rev-parse --git-common-dir)
            [IO.File]::AppendAllText((Join-Path $admin 'info/exclude'), "`nprivate-evidence.txt`n")
            [IO.File]::WriteAllText((Join-Path $WorkingDirectory 'private-evidence.txt'),'Recover this evidence.')
            [pscustomobject]@{ExitCode=124; TimedOut=$true; ElapsedSeconds=5; StdOut=@(); StdErr=@()}
        }
        $result=Invoke-SpecKitWorkerPhase -SpecPackage $package -Phase implement -Task $task -RepoPath $fixture.RepoRoot -InvocationCount ([ref]$script:invocations) -SkippedLineIndices ([ref]$null) -DefaultModel fixture -DefaultEffort low
        $result.Status | Should Be failed-stop
        $result.KeepWorktree | Should Be $true
        [IO.File]::ReadAllText((Join-Path $script:timedOutScratch 'private-evidence.txt')) | Should Be 'Recover this evidence.'
        Assert-MockCalled Invoke-AgentTask -Times 1 -Exactly -Scope It
    }
}
