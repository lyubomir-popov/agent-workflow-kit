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
# Execute the production TODO loop with fixture-only variables and mocked workers.
$script:legacyTodoLoop=@($ast.EndBlock.Statements | Where-Object {
    $_ -is [Management.Automation.Language.WhileStatementAst] -and $_.Condition.Extent.Text -match '\$taskCount -lt \$MaxTasks'
})[0].Extent.Text
function Invoke-FixtureLegacyTodoLoop {
    $repoRoot=$script:fixture.RepoRoot
    if (Get-WorkflowConfig $repoRoot) { throw 'Fixture must be in legacy mode.' }
    $taskCount=0; $MaxTasks=1; $TaskSection='## Tasks'; $skippedLineIndices=@()
    $Model='fixture'; $ReasoningEffort='low'
    Invoke-Expression $script:legacyTodoLoop
}

function Assert-FixtureWorkerRejected {
    param([string]$Reason)
    $package=@(Get-WorkflowPackages $script:fixture.RepoRoot)[0]
    $task=@(Get-WorkflowTasks $package | Where-Object Id -eq T001)[0]
    $before=Get-HeadCommit $script:fixture.RepoRoot
    $result=Invoke-SpecKitWorkerPhase -SpecPackage $package -Phase implement -Task $task -RepoPath $script:fixture.RepoRoot -InvocationCount ([ref]$script:invocations) -SkippedLineIndices ([ref]$null) -DefaultModel fixture -DefaultEffort low
    $result.Status | Should Be worker-incomplete
    $result.Reason | Should Match $Reason
    $result.KeepWorktree | Should Be $true
    (Get-HeadCommit $script:fixture.RepoRoot) | Should Be $before
    (Test-Path -LiteralPath $result.WorktreePath) | Should Be $true
    @(Get-WorkflowTasks @(Get-WorkflowPackages $script:fixture.RepoRoot)[0] | Where-Object Id -eq T001)[0].Complete | Should Be $false
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
        Set-FixtureTasks $fixture "- [ ] T001 Implement example.`n- [ ] T002 Future work (gate: CP2)."
        Save-FixtureRevision $fixture
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
            Set-FixtureTasks $worker "- [x] T001 Completed focused implementation.`n- [ ] T002 Updated description for future work (gate: CP2)."
            $path=Join-Path $WorkingDirectory 'specs/001-example/tasks.md'
            [IO.File]::WriteAllText($path,[IO.File]::ReadAllText($path).Replace('**Next tasks**: T001.','**Next tasks**: T002.').Replace('**Blockers**: none.','**Blockers**: Owner action before future work.'))
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
            $result.Reason | Should Match 'review (record|gate metadata)'
            (Get-HeadCommit $fixture.RepoRoot) | Should Be $before
            (Test-Path -LiteralPath $result.WorktreePath) | Should Be $true
        }
    }

    It 'rejects a single-emphasis verdict before integration and retains scratch' {
        Mock Invoke-AgentTask {
            $worker=[pscustomobject]@{RepoRoot=$WorkingDirectory}
            Write-FixtureFile $worker 'specs/001-example/reviews/fabricated.md' "*Verdict*: accept`n"
            Save-FixtureRevision $worker
            [pscustomobject]@{ExitCode=0; TimedOut=$false; ElapsedSeconds=0; StdOut=@(); StdErr=@()}
        }
        Assert-FixtureWorkerRejected 'new review gate metadata'
    }

    It 'rejects removing a superseded verdict from an existing review' {
        Write-FixtureFile $fixture 'specs/001-example/reviews/older.md' "# Earlier review`n**Verdict**: superseded`n"
        Save-FixtureRevision $fixture
        Mock Invoke-AgentTask {
            $worker=[pscustomobject]@{RepoRoot=$WorkingDirectory}
            Write-FixtureFile $worker 'specs/001-example/reviews/older.md' "# Earlier review`n"
            Save-FixtureRevision $worker
            [pscustomobject]@{ExitCode=0; TimedOut=$false; ElapsedSeconds=0; StdOut=@(); StdErr=@()}
        }
        Assert-FixtureWorkerRejected 'existing review record changed or deleted'
    }

    It 'rejects deleting an existing review even if it has no verdict' {
        Write-FixtureFile $fixture 'specs/001-example/reviews/dispositions.md' "# Author dispositions`nAwaiting owner acceptance.`n"
        Save-FixtureRevision $fixture
        Mock Invoke-AgentTask {
            $worker=[pscustomobject]@{RepoRoot=$WorkingDirectory}
            Remove-Item -LiteralPath (Join-Path $WorkingDirectory 'specs/001-example/reviews/dispositions.md')
            Save-FixtureRevision $worker
            [pscustomobject]@{ExitCode=0; TimedOut=$false; ElapsedSeconds=0; StdOut=@(); StdErr=@()}
        }
        Assert-FixtureWorkerRejected 'existing review record changed or deleted'
    }

    It 'rejects injecting accepted scope into an existing verdict-less dispositions file' {
        Write-FixtureFile $fixture 'specs/001-example/reviews/dispositions.md' "# Author dispositions`nAwaiting owner acceptance.`n"
        Save-FixtureRevision $fixture
        Mock Invoke-AgentTask {
            $worker=[pscustomobject]@{RepoRoot=$WorkingDirectory}
            Write-FixtureFile $worker 'specs/001-example/reviews/dispositions.md' "# Author dispositions`n- **Accepted scope**: ``001/spec-r1```n"
            Save-FixtureRevision $worker
            [pscustomobject]@{ExitCode=0; TimedOut=$false; ElapsedSeconds=0; StdOut=@(); StdErr=@()}
        }
        Assert-FixtureWorkerRejected 'existing review record changed or deleted'
    }

    It 'rejects each gate label in newly added review files' {
        Mock Invoke-AgentTask {
            $worker=[pscustomobject]@{RepoRoot=$WorkingDirectory}
            Write-FixtureFile $worker 'specs/001-example/reviews/new-record.md' $script:newReviewLabel
            Save-FixtureRevision $worker
            [pscustomobject]@{ExitCode=0; TimedOut=$false; ElapsedSeconds=0; StdOut=@(); StdErr=@()}
        }
        foreach ($label in @('Verdict','Accepted scope','Checkpoint','Scope','Reviewer','Reviewed revision')) {
            $script:newReviewLabel="- **${label}**: fixture-value`n"
            Assert-FixtureWorkerRejected 'new review gate metadata'
        }
        Assert-MockCalled Invoke-AgentTask -Times 6 -Exactly -Scope It
    }

    It 'rejects gate metadata in BOM-encoded new reviews just as the filesystem reader does' {
        Mock Invoke-AgentTask {
            $worker=[pscustomobject]@{RepoRoot=$WorkingDirectory}
            [IO.File]::WriteAllText((Join-Path $WorkingDirectory 'specs/001-example/reviews/encoded.md'),"- **Accepted scope**: ``001/spec-r1```n",$script:reviewEncoding)
            Save-FixtureRevision $worker
            [pscustomobject]@{ExitCode=0; TimedOut=$false; ElapsedSeconds=0; StdOut=@(); StdErr=@()}
        }
        foreach ($encoding in @([Text.Encoding]::Unicode,[Text.Encoding]::BigEndianUnicode,[Text.Encoding]::UTF32)) {
            $script:reviewEncoding=$encoding
            Assert-FixtureWorkerRejected 'new review gate metadata'
        }
        Assert-MockCalled Invoke-AgentTask -Times 3 -Exactly -Scope It
    }

    It 'rejects an existing review edit even when a later worker commit restores it' {
        Write-FixtureFile $fixture 'specs/001-example/reviews/notes.md' "# Saved owner notes`nOriginal evidence.`n"
        Save-FixtureRevision $fixture
        Mock Invoke-AgentTask {
            $worker=[pscustomobject]@{RepoRoot=$WorkingDirectory}
            Write-FixtureFile $worker 'specs/001-example/reviews/notes.md' "# Saved owner notes`nRewritten evidence.`n"
            Save-FixtureRevision $worker
            Write-FixtureFile $worker 'specs/001-example/reviews/notes.md' "# Saved owner notes`nOriginal evidence.`n"
            Save-FixtureRevision $worker
            [pscustomobject]@{ExitCode=0; TimedOut=$false; ElapsedSeconds=0; StdOut=@(); StdErr=@()}
        }
        Assert-FixtureWorkerRejected 'existing review record changed or deleted'
    }

    It 'permits new unlabelled worker notes alongside focused task completion' {
        $package=@(Get-WorkflowPackages $fixture.RepoRoot)[0]
        $task=@(Get-WorkflowTasks $package)[0]
        Mock Invoke-AgentTask {
            $worker=[pscustomobject]@{RepoRoot=$WorkingDirectory}
            Write-FixtureFile $worker 'specs/001-example/reviews/worker-notes.md' "# Implementation observations`nFixture evidence only.`n"
            Set-FixtureTasks $worker '- [x] T001 Implement example.'
            $path=Join-Path $WorkingDirectory 'specs/001-example/tasks.md'
            Write-FixtureFile $worker 'specs/001-example/tasks.md' ([IO.File]::ReadAllText($path).Replace('**Next tasks**: T001.','**Next tasks**: none.'))
            Save-FixtureRevision $worker
            [pscustomobject]@{ExitCode=0; TimedOut=$false; ElapsedSeconds=0; StdOut=@(); StdErr=@()}
        }
        $result=Invoke-SpecKitWorkerPhase -SpecPackage $package -Phase implement -Task $task -RepoPath $fixture.RepoRoot -InvocationCount ([ref]$script:invocations) -SkippedLineIndices ([ref]$null) -DefaultModel fixture -DefaultEffort low
        $result.Status | Should Be ok
        (Test-Path -LiteralPath (Join-Path $fixture.RepoRoot 'specs/001-example/reviews/worker-notes.md')) | Should Be $true
        (Invoke-FixtureLint $fixture -Strict).ExitCode | Should Be 0
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

    It 'rejects changes or removal of the task entry checkpoint before integration' {
        Mock Invoke-AgentTask {
            $worker=[pscustomobject]@{RepoRoot=$WorkingDirectory}
            $text=[IO.File]::ReadAllText((Join-Path $WorkingDirectory 'specs/001-example/tasks.md'))
            Write-FixtureFile $worker 'specs/001-example/tasks.md' ($text.Replace('**Entry checkpoint**: CP1',$script:entryReplacement))
            Save-FixtureRevision $worker
            [pscustomobject]@{ExitCode=0; TimedOut=$false; ElapsedSeconds=0; StdOut=@(); StdErr=@()}
        }
        foreach ($replacement in @('**Entry checkpoint**: CP2','')) {
            $script:entryReplacement=$replacement
            Assert-FixtureWorkerRejected 'task entry checkpoint changed'
        }
        Assert-MockCalled Invoke-AgentTask -Times 2 -Exactly -Scope It
    }

    It 'rejects removing changing or adding an existing task gate annotation' {
        Set-FixtureTasks $fixture "- [ ] T001 Implement example.`n- [ ] T002 Later work (gate: CP2) (manual)."
        Save-FixtureRevision $fixture
        Mock Invoke-AgentTask {
            $worker=[pscustomobject]@{RepoRoot=$WorkingDirectory}
            Set-FixtureTasks $worker $script:mutatedTaskBody
            Save-FixtureRevision $worker
            [pscustomobject]@{ExitCode=0; TimedOut=$false; ElapsedSeconds=0; StdOut=@(); StdErr=@()}
        }
        foreach ($body in @(
            "- [ ] T001 Implement example.`n- [ ] T002 Later work (manual).",
            "- [ ] T001 Implement example.`n- [ ] T002 Later work (gate: CP1) (manual).",
            "- [ ] T001 Implement example (gate: CP1).`n- [ ] T002 Later work (gate: CP2) (manual)."
        )) {
            $script:mutatedTaskBody=$body
            Assert-FixtureWorkerRejected 'task gate/manual annotation changed'
        }
        Assert-MockCalled Invoke-AgentTask -Times 3 -Exactly -Scope It
    }

    It 'rejects removing or adding an existing task manual annotation' {
        Set-FixtureTasks $fixture "- [ ] T001 Implement example.`n- [ ] T002 Later work (gate: CP2) (manual)."
        Save-FixtureRevision $fixture
        Mock Invoke-AgentTask {
            $worker=[pscustomobject]@{RepoRoot=$WorkingDirectory}
            Set-FixtureTasks $worker $script:mutatedTaskBody
            Save-FixtureRevision $worker
            [pscustomobject]@{ExitCode=0; TimedOut=$false; ElapsedSeconds=0; StdOut=@(); StdErr=@()}
        }
        foreach ($body in @(
            "- [ ] T001 Implement example.`n- [ ] T002 Later work (gate: CP2).",
            "- [ ] T001 Implement example (manual).`n- [ ] T002 Later work (gate: CP2) (manual)."
        )) {
            $script:mutatedTaskBody=$body
            Assert-FixtureWorkerRejected 'task gate/manual annotation changed'
        }
        Assert-MockCalled Invoke-AgentTask -Times 2 -Exactly -Scope It
    }

    It 'rejects adding an unchecked task ID even behind a pending gate' {
        Mock Invoke-AgentTask {
            $worker=[pscustomobject]@{RepoRoot=$WorkingDirectory}
            Set-FixtureTasks $worker "- [ ] T001 Implement example.`n- [ ] T002 Added work (gate: CP2)."
            Save-FixtureRevision $worker
            [pscustomobject]@{ExitCode=0; TimedOut=$false; ElapsedSeconds=0; StdOut=@(); StdErr=@()}
        }
        Assert-FixtureWorkerRejected 'task IDs added, removed or reordered'
        Assert-MockCalled Invoke-AgentTask -Times 1 -Exactly -Scope It
    }

    It 'rejects removing a task ID before integration' {
        Set-FixtureTasks $fixture "- [ ] T001 Implement example.`n- [ ] T002 Later work (gate: CP2) (manual)."
        Save-FixtureRevision $fixture
        Mock Invoke-AgentTask {
            $worker=[pscustomobject]@{RepoRoot=$WorkingDirectory}
            Set-FixtureTasks $worker '- [ ] T001 Implement example.'
            Save-FixtureRevision $worker
            [pscustomobject]@{ExitCode=0; TimedOut=$false; ElapsedSeconds=0; StdOut=@(); StdErr=@()}
        }
        Assert-FixtureWorkerRejected 'task IDs added, removed or reordered'
        Assert-MockCalled Invoke-AgentTask -Times 1 -Exactly -Scope It
    }

    It 'rejects moving a later task ahead of an owner manual boundary' {
        Set-FixtureTasks $fixture "- [ ] T001 Implement example.`n- [ ] T002 Owner boundary (manual).`n- [ ] T003 Later work."
        Save-FixtureRevision $fixture
        Mock Invoke-AgentTask {
            $worker=[pscustomobject]@{RepoRoot=$WorkingDirectory}
            Set-FixtureTasks $worker "- [ ] T001 Implement example.`n- [ ] T003 Later work.`n- [ ] T002 Owner boundary (manual)."
            Save-FixtureRevision $worker
            [pscustomobject]@{ExitCode=0; TimedOut=$false; ElapsedSeconds=0; StdOut=@(); StdErr=@()}
        }
        Assert-FixtureWorkerRejected 'task IDs added, removed or reordered'
        Assert-MockCalled Invoke-AgentTask -Times 1 -Exactly -Scope It
    }

    It 'rejects a task gate edit even when a later worker commit restores it' {
        Set-FixtureTasks $fixture "- [ ] T001 Implement example.`n- [ ] T002 Later work (gate: CP2) (manual)."
        Save-FixtureRevision $fixture
        Mock Invoke-AgentTask {
            $worker=[pscustomobject]@{RepoRoot=$WorkingDirectory}
            Set-FixtureTasks $worker "- [ ] T001 Implement example.`n- [ ] T002 Later work (manual)."
            Save-FixtureRevision $worker
            Set-FixtureTasks $worker "- [ ] T001 Implement example.`n- [ ] T002 Later work (gate: CP2) (manual)."
            Save-FixtureRevision $worker
            [pscustomobject]@{ExitCode=0; TimedOut=$false; ElapsedSeconds=0; StdOut=@(); StdErr=@()}
        }
        Assert-FixtureWorkerRejected 'task gate/manual annotation changed'
        Assert-MockCalled Invoke-AgentTask -Times 1 -Exactly -Scope It
    }

    It 'rejects worker budget exception target host budget and config deletion changes' {
        Mock Invoke-AgentTask {
            $worker=[pscustomobject]@{RepoRoot=$WorkingDirectory}
            if ($script:policyMutation -eq 'delete') {
                Remove-Item -LiteralPath (Join-Path $WorkingDirectory '.workflow-kit.json')
            } else {
                $policy=Get-FixtureConfig $worker
                switch ($script:policyMutation) {
                    'exception' { $policy.budgetExceptions=@(@{path='AGENTS.md'; lines=120; bytes=16384; authorization='worker'; reason='Fixture exception'; expiry='2099-01-01'}) }
                    'target' { $policy.targetBranch='feat/001-example' }
                    'budget' { $policy.hostBudgets[0].bytes+=1 }
                }
                Set-FixtureConfig $worker $policy
            }
            Save-FixtureRevision $worker
            [pscustomobject]@{ExitCode=0; TimedOut=$false; ElapsedSeconds=0; StdOut=@(); StdErr=@()}
        }
        foreach ($mutation in @('exception','target','budget','delete')) {
            $script:policyMutation=$mutation
            Assert-FixtureWorkerRejected 'owner workflow policy changed'
        }
        Assert-MockCalled Invoke-AgentTask -Times 4 -Exactly -Scope It
    }

    It 'rejects an owner policy edit even when a later worker commit restores it' {
        Mock Invoke-AgentTask {
            $worker=[pscustomobject]@{RepoRoot=$WorkingDirectory}
            $path=Join-Path $WorkingDirectory '.workflow-kit.json'
            $original=[IO.File]::ReadAllText($path)
            $policy=Get-FixtureConfig $worker
            $policy.targetBranch='feat/001-example'
            Set-FixtureConfig $worker $policy
            Save-FixtureRevision $worker
            Write-FixtureFile $worker '.workflow-kit.json' $original
            Save-FixtureRevision $worker
            [pscustomobject]@{ExitCode=0; TimedOut=$false; ElapsedSeconds=0; StdOut=@(); StdErr=@()}
        }
        Assert-FixtureWorkerRejected 'owner workflow policy changed'
        Assert-MockCalled Invoke-AgentTask -Times 1 -Exactly -Scope It
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

    It 'removes clean zero-commit scratch after timeout process failure or missing progress' {
        $package=@(Get-WorkflowPackages $fixture.RepoRoot)[0]
        $task=@(Get-WorkflowTasks $package)[0]
        $before=Get-HeadCommit $fixture.RepoRoot
        Mock Invoke-AgentTask {
            [pscustomobject]@{ExitCode=$script:failureCode; TimedOut=$script:failureTimeout; ElapsedSeconds=0; StdOut=@(); StdErr=@()}
        }
        foreach ($mode in @('timeout','exit','no-commit')) {
            $script:failureTimeout=$mode -eq 'timeout'
            $script:failureCode=if ($mode -eq 'exit') { 1 } else { 0 }
            $result=Invoke-SpecKitWorkerPhase -SpecPackage $package -Phase implement -Task $task -RepoPath $fixture.RepoRoot -InvocationCount ([ref]$script:invocations) -SkippedLineIndices ([ref]$null) -DefaultModel fixture -DefaultEffort low
            $result.Status | Should Be failed-stop
            $result.KeepWorktree | Should Be $false
            (Test-Path -LiteralPath $result.WorktreePath) | Should Be $false
            (Get-HeadCommit $fixture.RepoRoot) | Should Be $before
        }
    }

    It 'removes legacy TODO scratch after cherry-pick and a separate bookkeeping commit' {
        Remove-Item -LiteralPath (Join-Path $fixture.RepoRoot '.workflow-kit.json')
        Write-FixtureFile $fixture 'TODO.md' "# TODO`n`n## Tasks`n`n- [ ] Write fixture output.`n"
        Save-FixtureRevision $fixture
        $before=Get-HeadCommit $fixture.RepoRoot
        Mock Get-WorkflowScratchRoot { Join-Path $script:fixture.TempRoot 'scratch' }
        Mock Invoke-AgentTask {
            $script:legacyScratch=$WorkingDirectory
            Write-FixtureFile ([pscustomobject]@{RepoRoot=$WorkingDirectory}) 'output.txt' 'Completed fixture task.'
            git -C $WorkingDirectory add -- output.txt
            git -C $WorkingDirectory -c 'user.name=Fixture scratch worker' commit --quiet -m 'Fixture worker change'
            if ($LASTEXITCODE) { throw 'Fixture worker commit failed.' }
            $script:legacyWorkerHead=Get-HeadCommit $WorkingDirectory
            [pscustomobject]@{ExitCode=0; TimedOut=$false; ElapsedSeconds=0; StdOut=@(); StdErr=@()}
        }
        Invoke-FixtureLegacyTodoLoop
        (git -C $fixture.RepoRoot rev-list --count "$before..HEAD") | Should Be 2
        (git -C $fixture.RepoRoot log -1 --format=%s) | Should Be 'chore: mark TODO task done'
        (git -C $fixture.RepoRoot rev-parse 'HEAD~1') | Should Not Be $script:legacyWorkerHead
        (Get-TodoText) | Should Match '\[x\] Write fixture output'
        (Test-Path -LiteralPath $script:legacyScratch) | Should Be $false
        @(git -C $fixture.RepoRoot worktree list --porcelain | Where-Object { $_ -match '^worktree ' }).Count | Should Be 1
        Assert-MockCalled Invoke-AgentTask -Times 1 -Exactly -Scope It
    }

    It 'removes clean failed legacy TODO scratch without a bookkeeping commit' {
        Remove-Item -LiteralPath (Join-Path $fixture.RepoRoot '.workflow-kit.json')
        Write-FixtureFile $fixture 'TODO.md' "# TODO`n`n## Tasks`n`n- [ ] Write fixture output.`n"
        Save-FixtureRevision $fixture
        $before=Get-HeadCommit $fixture.RepoRoot
        Mock Get-WorkflowScratchRoot { Join-Path $script:fixture.TempRoot 'scratch' }
        Mock Invoke-AgentTask {
            $script:legacyScratch=$WorkingDirectory
            [pscustomobject]@{ExitCode=1; TimedOut=$false; ElapsedSeconds=0; StdOut=@(); StdErr=@()}
        }
        Invoke-FixtureLegacyTodoLoop
        (Get-HeadCommit $fixture.RepoRoot) | Should Be $before
        (Get-TodoText) | Should Match '\[ \] Write fixture output'
        (Test-Path -LiteralPath $script:legacyScratch) | Should Be $false
        Assert-MockCalled Invoke-AgentTask -Times 1 -Exactly -Scope It
    }
}
