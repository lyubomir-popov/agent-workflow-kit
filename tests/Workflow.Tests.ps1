. (Join-Path $PSScriptRoot 'Fixture.Helpers.ps1')
. (Join-Path $script:KitRoot 'workflow-model.ps1')

Describe 'Versioned workflow model with isolated Git owners' {
    BeforeEach { $script:fixture = New-WorkflowFixture }
    AfterEach { Remove-WorkflowFixture $script:fixture }

    It 'selects legacy mode when the config or model version is absent' {
        Remove-Item -LiteralPath (Join-Path $fixture.RepoRoot '.workflow-kit.json')
        (Get-WorkflowConfig $fixture.RepoRoot) | Should BeNullOrEmpty
        Write-FixtureFile $fixture '.workflow-kit.json' '{"canonicalMirrorMode":"external"}'
        (Get-WorkflowConfig $fixture.RepoRoot) | Should BeNullOrEmpty
    }

    It 'keeps external mirror selection independent of model activation' {
        $config = Get-FixtureConfig $fixture
        $config | Add-Member NoteProperty canonicalMirrorMode external
        Set-FixtureConfig $fixture $config
        (Get-WorkflowConfig $fixture.RepoRoot).workflowModelVersion | Should Be 1
    }

    It 'fails closed for malformed, nonobject and unsupported version configs' {
        foreach ($text in @('{broken', '[]', '{"workflowModelVersion":2}', '{"workflowModelVersion":"1"}', '{"workflowModelVersion":null}')) {
            Write-FixtureFile $fixture '.workflow-kit.json' $text
            (Test-FixtureThrows { Get-WorkflowConfig $fixture.RepoRoot }) | Should Be $true
        }
    }

    It 'requires complete configured inventories and bounded authorized exceptions' {
        $config = Get-FixtureConfig $fixture
        $config.PSObject.Properties.Remove('hostBudgets')
        Set-FixtureConfig $fixture $config
        (Test-FixtureThrows { Get-WorkflowConfig $fixture.RepoRoot }) | Should Be $true
        $config = Get-Content (Join-Path $script:KitRoot '.workflow-kit.json') -Raw | ConvertFrom-Json
        $config.budgetExceptions = @(@{ path='AGENTS.md'; lines=200; bytes=20000; authorization='owner'; reason='fixture'; expiry='2000-01-01' })
        Set-FixtureConfig $fixture $config
        (Test-FixtureThrows { Get-WorkflowConfig $fixture.RepoRoot }) | Should Be $true
    }

    It 'requires CLAUDE.md in the copilot-chat loading inventory' {
        $config=Get-FixtureConfig $fixture
        $adapter=@($config.autoLoadedFiles | Where-Object path -eq 'CLAUDE.md')[0]
        ($adapter.hosts -contains 'copilot-chat') | Should Be $true
        $adapter.hosts=@($adapter.hosts | Where-Object { $_ -ne 'copilot-chat' })
        Set-FixtureConfig $fixture $config
        @(Get-FixtureFindings (Invoke-FixtureLint $fixture) inventory-missing).Count | Should Be 1
    }

    It 'fails versioned lint for missing or overwritten Spec Kit integration sentinels' {
        foreach ($name in @('common.ps1','check-prerequisites.ps1','create-new-feature.ps1')) {
            $relative=".specify/scripts/powershell/$name"
            $original=[IO.File]::ReadAllText((Join-Path $fixture.RepoRoot $relative))
            foreach ($mode in @('overwritten','missing')) {
                if ($mode -eq 'missing') { Remove-Item -LiteralPath (Join-Path $fixture.RepoRoot $relative) }
                else { Write-FixtureFile $fixture $relative '# Restored vendor script without kit integration.' }
                $result=Invoke-FixtureLint $fixture -Strict
                $result.ExitCode | Should Be 1
                $finding=@(Get-FixtureFindings $result '^speckit-integration$')
                $finding.Count | Should Be 1
                $finding[0].path | Should Be $relative
                Write-FixtureFile $fixture $relative $original
            }
        }
        (Invoke-FixtureLint $fixture -Strict).ExitCode | Should Be 0
    }

    It 'reads every declared lifecycle without treating age as activation' {
        foreach ($state in @('draft','review','ready','active','parked','delivered','closed','superseded')) {
            Set-FixtureSpec $fixture -Lifecycle $state
            @(Get-WorkflowPackages $fixture.RepoRoot)[0].Lifecycle | Should Be $state
        }
    }

    It 'reads declared branch content before a conflicting master snapshot' {
        Set-FixtureSpec $fixture -Lifecycle parked
        Save-FixtureRevision $fixture
        $null = Invoke-FixtureGit $fixture @('switch','--quiet','master')
        Set-FixtureSpec $fixture -Lifecycle closed
        $package = @(Get-WorkflowPackages $fixture.RepoRoot)[0]
        $package.Lifecycle | Should Be parked
        $package.Local | Should Be $false
    }

    It 'uses uncommitted declared worktree content rather than a primary checkout copy' {
        $null = Invoke-FixtureGit $fixture @('switch','--quiet','master')
        $worktree = Join-Path $fixture.TempRoot 'feature-worktree'
        $null = Invoke-FixtureGit $fixture @('worktree','add','--quiet',$worktree,'feat/001-example')
        $worktreeFixture = [pscustomobject]@{ RepoRoot=$worktree }
        Set-FixtureSpec $worktreeFixture -Lifecycle parked
        Set-FixtureSpec $fixture -Lifecycle closed
        $package = @(Get-WorkflowPackages $fixture.RepoRoot)[0]
        $package.Lifecycle | Should Be parked
        [IO.Path]::GetFullPath($package.WorktreeRoot) | Should Be $worktree
    }

    It 'rejects explicit package edits from a different branch' {
        $null = Invoke-FixtureGit $fixture @('switch','--quiet','master')
        (Test-FixtureThrows { Select-WorkflowPackage $fixture.RepoRoot 'specs/001-example' }) | Should Be $true
    }

    It 'resolves an archived package from the current checkout after its branch is deleted' {
        Set-FixtureArchivedPackage $fixture
        Save-FixtureRevision $fixture
        $null=Invoke-FixtureGit $fixture @('switch','--quiet','master')
        $null=Invoke-FixtureGit $fixture @('merge','--quiet','--ff-only','feat/001-example')
        $null=Invoke-FixtureGit $fixture @('branch','-d','feat/001-example')
        $package=@(Get-WorkflowPackages $fixture.RepoRoot)[0]
        $package.Archived | Should Be $true
        $package.Local | Should Be $true
        $package.WorktreeRoot | Should Be $fixture.RepoRoot
        $package.Lifecycle | Should Be delivered
        (Invoke-FixtureLint $fixture -Strict).ExitCode | Should Be 0
    }

    It 'accepts a staged delivery squash and its final commit on the configured target' {
        Set-FixtureArchivedPackage $fixture
        Save-FixtureRevision $fixture
        $null=Invoke-FixtureGit $fixture @('switch','--quiet','master')
        $null=Invoke-FixtureGit $fixture @('merge','--squash','feat/001-example')
        $output=& pwsh -NoLogo -NoProfile -File (Join-Path $script:KitRoot 'workflow-hook.ps1') -RepoRoot $fixture.RepoRoot 2>&1
        $LASTEXITCODE | Should Be 0
        (Invoke-FixtureLint $fixture -Strict).ExitCode | Should Be 0
        $null=Invoke-FixtureGit $fixture @('commit','--quiet','-m','Fixture delivery squash')
        git -C $fixture.RepoRoot merge-base --is-ancestor 'feat/001-example' master
        $LASTEXITCODE | Should Be 1
        $package=@(Get-WorkflowPackages $fixture.RepoRoot)[0]
        $package.Archived | Should Be $true
        $package.Lifecycle | Should Be delivered
        (Invoke-FixtureLint $fixture -Strict).ExitCode | Should Be 0
    }

    It 'ignores a stale local cursor when selecting the current declared package' {
        Write-FixtureFile $fixture '.specify/feature.json' '{"feature_directory":"specs/999-stale"}'
        (Select-WorkflowPackage $fixture.RepoRoot).Id | Should Be '001'
    }

    It 'requires unique stable task identities' {
        Set-FixtureTasks $fixture "- [ ] T001 First.`n- [ ] T001 Duplicate."
        $package = @(Get-WorkflowPackages $fixture.RepoRoot)[0]
        (Test-FixtureThrows { Get-WorkflowTasks $package }) | Should Be $true
        Set-FixtureTasks $fixture '- [ ] Missing stable identity.'
        (Test-FixtureThrows { Get-WorkflowTasks $package }) | Should Be $true
    }

    It 'keeps future checkpoint overrides separate from the authorized entry gate' {
        Set-FixtureTasks $fixture "- [ ] T001 Authorized entry work.`n- [ ] T002 Future work (gate: CP2)."
        $package = @(Get-WorkflowPackages $fixture.RepoRoot)[0]
        $tasks = @(Get-WorkflowTasks $package)
        $tasks[0].Gate | Should Be CP1
        $tasks[1].Gate | Should Be CP2
        (Get-WorkflowGateProblem $package $tasks[0].Gate) | Should BeNullOrEmpty
        (Get-WorkflowGateProblem $package $tasks[1].Gate) | Should Not BeNullOrEmpty
    }

    It 'stops pending and unknown checkpoints even with an accepted saved verdict' {
        Set-FixtureSpec $fixture -State pending
        $package = @(Get-WorkflowPackages $fixture.RepoRoot)[0]
        (Get-WorkflowGateProblem $package CP1) | Should Not BeNullOrEmpty
        (Get-WorkflowGateProblem $package CP9) | Should Not BeNullOrEmpty
    }

    It 'stops an owner-cleared checkpoint without a saved verdict' {
        Set-FixtureSpec $fixture -VerdictLink none
        (Get-WorkflowGateProblem @(Get-WorkflowPackages $fixture.RepoRoot)[0] CP1) | Should Not BeNullOrEmpty
        Set-FixtureSpec $fixture -VerdictLink '[missing](reviews/missing.md)'
        (Get-WorkflowGateProblem @(Get-WorkflowPackages $fixture.RepoRoot)[0] CP1) | Should Not BeNullOrEmpty
    }

    It 'stops blocking rejected and superseded saved verdicts' {
        foreach ($verdict in @('blocking','reject','superseded')) {
            Set-FixtureReview $fixture -Verdict $verdict
            (Get-WorkflowGateProblem @(Get-WorkflowPackages $fixture.RepoRoot)[0] CP1) | Should Not BeNullOrEmpty
        }
    }

    It 'requires owner acceptance for the current scope when a review is obsolete' {
        Set-FixtureSpec $fixture -Scope '001/spec-r2' -SupersededScope '001/spec-r1'
        (Get-WorkflowGateProblem @(Get-WorkflowPackages $fixture.RepoRoot)[0] CP1) | Should Match 'obsolete|scope'
    }
}

Describe 'Read-only workflow lint detects mechanical drift' {
    BeforeEach { $script:fixture = New-WorkflowFixture }
    AfterEach { Remove-WorkflowFixture $script:fixture }

    It 'accepts a bounded fixture and reports mode and stable finding identities' {
        $result = Invoke-FixtureLint $fixture
        $result.ExitCode | Should Be 0
        $result.Report.mode | Should Match 'spec|version'
        foreach ($finding in $result.Report.findings) {
            $finding.rule | Should Not BeNullOrEmpty
            $finding.id | Should Not BeNullOrEmpty
        }
    }

    It 'reports malformed versioned configuration as a machine readable failure' {
        Write-FixtureFile $fixture '.workflow-kit.json' '{"workflowModelVersion":99}'
        $result = Invoke-FixtureLint $fixture
        $result.ExitCode | Should Be 1
        @(Get-FixtureFindings $result 'config').Count | Should BeGreaterThan 0
    }

    It 'detects duplicate catalog package identities' {
        $path = Join-Path $fixture.RepoRoot 'docs/specs.md'
        $text = [IO.File]::ReadAllText($path)
        Write-FixtureFile $fixture 'docs/specs.md' ($text.Replace('## Archive', '| 001 | [Duplicate](../specs/001-example/spec.md) | `feat/001-example` |' + "`n`n## Archive"))
        $result = Invoke-FixtureLint $fixture
        @(Get-FixtureFindings $result 'catalog-').Count | Should BeGreaterThan 0
        $result.ExitCode | Should Be 1
    }

    It 'detects missing owners and declared branch mismatches' {
        $path = Join-Path $fixture.RepoRoot 'specs/001-example/spec.md'
        Write-FixtureFile $fixture 'specs/001-example/spec.md' ([IO.File]::ReadAllText($path).Replace('feat/001-example','feat/001-wrong'))
        $result = Invoke-FixtureLint $fixture
        @(Get-FixtureFindings $result 'branch|package').Count | Should BeGreaterThan 0
        $result.ExitCode | Should Be 1
    }

    It 'counts long lines by UTF8 bytes as well as physical lines' {
        Write-FixtureFile $fixture 'AGENTS.md' ('# Invariants' + "`n" + ('é' * 7000) + "`n")
        $result = Invoke-FixtureLint $fixture
        @(Get-FixtureFindings $result 'budget-').Count | Should BeGreaterThan 0
        $result.ExitCode | Should Be 1
    }

    It 'counts blank physical lines against per file budgets' {
        Write-FixtureFile $fixture 'AGENTS.md' ("# Invariants`n" + ("`n" * 101))
        $result = Invoke-FixtureLint $fixture
        @(Get-FixtureFindings $result 'budget-').Count | Should BeGreaterThan 0
        $result.ExitCode | Should Be 1
    }

    It 'enforces aggregate budgets when instructions are split across files' {
        $config = Get-FixtureConfig $fixture
        $config.autoLoadedFiles += @(
            [pscustomobject]@{ path='extra-one.md'; hosts=@('codex'); lines=100; bytes=12288; loading='full' },
            [pscustomobject]@{ path='extra-two.md'; hosts=@('codex'); lines=100; bytes=12288; loading='full' })
        Set-FixtureConfig $fixture $config
        Write-FixtureFile $fixture 'extra-one.md' (('a' * 9000) + "`n")
        Write-FixtureFile $fixture 'extra-two.md' (('b' * 9000) + "`n")
        $result = Invoke-FixtureLint $fixture
        @(Get-FixtureFindings $result 'budget-.*(host|aggregate)|(host|aggregate).*budget').Count | Should BeGreaterThan 0
        $result.ExitCode | Should Be 1
    }

    It 'bounds the tasks current work header' {
        $path = Join-Path $fixture.RepoRoot 'specs/001-example/tasks.md'
        $text = [IO.File]::ReadAllText($path)
        Write-FixtureFile $fixture 'specs/001-example/tasks.md' ($text.Replace('## Work', ("header expansion`n" * 26) + '## Work'))
        $result = Invoke-FixtureLint $fixture
        @(Get-FixtureFindings $result 'budget-').Count | Should BeGreaterThan 0
        $result.ExitCode | Should Be 1
    }

    It 'bounds review requests while leaving findings on demand' {
        Write-FixtureFile $fixture 'specs/001-example/reviews/CP1-request.md' ("# Request`n" + ("Review this.`n" * 31))
        $result = Invoke-FixtureLint $fixture
        @(Get-FixtureFindings $result 'budget-').Count | Should BeGreaterThan 0
        $result.ExitCode | Should Be 1
    }

    It 'allows large saved findings on demand without treating them as requests' {
        Write-FixtureFile $fixture 'specs/001-example/reviews/extra-findings.md' ("# Findings`n" + ("Detailed on-demand evidence.`n" * 100))
        $result = Invoke-FixtureLint $fixture
        $result.ExitCode | Should Be 0
        @($result.Report.findings | Where-Object { $_.rule -match 'budget-' -and $_.path -match 'extra-findings' }).Count | Should Be 0
    }

    It 'reports unknown host loading as an honest gap' {
        $config = Get-FixtureConfig $fixture
        $config.autoLoadedFiles += [pscustomobject]@{ path='vendor-unknown.md'; hosts=@('codex'); lines=0; bytes=0; loading='unknown' }
        Set-FixtureConfig $fixture $config
        $result = Invoke-FixtureLint $fixture
        @(Get-FixtureFindings $result 'host-loading-gap').Count | Should BeGreaterThan 0
        $result.ExitCode | Should Be 0
    }

    It 'requires the actual host inventory and detects omitted always-loaded adapters' {
        $config = Get-FixtureConfig $fixture
        $config.autoLoadedFiles = @($config.autoLoadedFiles | Where-Object { $_.path -ne 'CLAUDE.md' })
        Set-FixtureConfig $fixture $config
        $result = Invoke-FixtureLint $fixture
        @(Get-FixtureFindings $result 'inventory-missing').Count | Should BeGreaterThan 0
        $result.ExitCode | Should Be 1
    }

    It 'honors an exact bounded authorized unexpired budget exception' {
        $config = Get-FixtureConfig $fixture
        $config.budgetExceptions = @([pscustomobject]@{
            path='AGENTS.md'; lines=120; bytes=12288; authorization='Fixture owner';
            reason='Temporary fixture illustration'; expiry=[datetime]::UtcNow.AddDays(30).ToString('yyyy-MM-dd') })
        Set-FixtureConfig $fixture $config
        Write-FixtureFile $fixture 'AGENTS.md' ("# Invariants`nRead [catalog](docs/specs.md).`n" + ("`n" * 103))
        $result = Invoke-FixtureLint $fixture
        $result.ExitCode | Should Be 0
    }

    It 'keeps stable finding IDs across repeated readonly checks' {
        Write-FixtureFile $fixture 'AGENTS.md' ("# Invariants`n" + ("`n" * 101))
        $first = Invoke-FixtureLint $fixture
        $second = Invoke-FixtureLint $fixture
        (@($first.Report.findings | ForEach-Object id) -join ',') | Should Be (@($second.Report.findings | ForEach-Object id) -join ',')
    }

    It 'detects injected Spec Kit marker blocks in root instructions and adapters' {
        foreach ($name in @('AGENTS.md','CLAUDE.md')) {
            $original = [IO.File]::ReadAllText((Join-Path $fixture.RepoRoot $name))
            Write-FixtureFile $fixture $name ($original + "`n<!-- SPECKIT:START -->`nGenerated instructions`n<!-- SPECKIT:END -->`n")
            $result = Invoke-FixtureLint $fixture
            @(Get-FixtureFindings $result 'marker').Count | Should BeGreaterThan 0
            $result.ExitCode | Should Be 1
            Write-FixtureFile $fixture $name $original
        }
    }

    It 'detects fourteen daily drift updates at the next check without rewriting them' {
        for ($day = 1; $day -le 14; $day++) {
            $path = Join-Path $fixture.RepoRoot 'AGENTS.md'
            $text = [IO.File]::ReadAllText($path) + ("Daily update $day historical narrative.`n" * 8)
            Write-FixtureFile $fixture 'AGENTS.md' $text
            $result = Invoke-FixtureLint $fixture
            [IO.File]::ReadAllText($path) | Should Be $text
        }
        @(Get-FixtureFindings $result 'budget-|router|state').Count | Should BeGreaterThan 0
        $result.ExitCode | Should Be 1
    }

    It 'retains an unread valid handoff byte for byte' {
        $text = "# Agent Inbox`n`n- Recipient: maintainer; Scope: ``001/spec-r1``; Artifact: [review](specs/001-example/reviews/CP1-review.md); Action: receive review.`n"
        Write-FixtureFile $fixture 'AGENT-INBOX.md' $text
        $path = Join-Path $fixture.RepoRoot 'AGENT-INBOX.md'
        $before = [Convert]::ToBase64String([IO.File]::ReadAllBytes($path))
        $result = Invoke-FixtureLint $fixture
        $result.ExitCode | Should Be 0
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) | Should Be $before
        @(Get-FixtureFindings $result 'inbox-not-drained|stale-handoff').Count | Should Be 0
    }

    It 'detects handoffs to a closed package' {
        Set-FixtureSpec $fixture -Lifecycle closed
        Write-FixtureFile $fixture 'AGENT-INBOX.md' "# Agent Inbox`n- Recipient: maintainer; Scope: ``001/spec-r1``; Artifact: [spec](specs/001-example/spec.md); Action: resume work.`n"
        $result = Invoke-FixtureLint $fixture
        @(Get-FixtureFindings $result 'stale-handoff').Count | Should BeGreaterThan 0
    }

    It 'detects explicitly superseded handoff scopes and tasks' {
        Set-FixtureSpec $fixture -Scope '001/spec-r2' -SupersededScope '001/spec-r1' -SupersededTasks T009
        Set-FixtureReview $fixture -Scope '001/spec-r2'
        Write-FixtureFile $fixture 'AGENT-INBOX.md' "# Agent Inbox`n- Recipient: maintainer; Scope: ``001/spec-r1``; Artifact: [spec](specs/001-example/spec.md); Action: resume T009.`n"
        $result = Invoke-FixtureLint $fixture
        @(Get-FixtureFindings $result 'stale-handoff').Count | Should BeGreaterThan 0
    }

    It 'detects a handoff naming an explicitly completed task' {
        Set-FixtureTasks $fixture "- [x] T001 Completed work.`n- [ ] T002 Current work."
        $path = Join-Path $fixture.RepoRoot 'specs/001-example/tasks.md'
        Write-FixtureFile $fixture 'specs/001-example/tasks.md' ([IO.File]::ReadAllText($path).Replace('**Next tasks**: T001.', '**Next tasks**: T002.'))
        Write-FixtureFile $fixture 'AGENT-INBOX.md' "# Agent Inbox`n- Recipient: maintainer; Scope: ``001/spec-r1``; Artifact: [tasks](specs/001-example/tasks.md); Action: resume T001.`n"
        $result = Invoke-FixtureLint $fixture
        @(Get-FixtureFindings $result 'stale-handoff').Count | Should BeGreaterThan 0
    }

    It 'does not declare parked handoffs stale from age alone' {
        Set-FixtureSpec $fixture -Lifecycle parked
        Write-FixtureFile $fixture 'AGENT-INBOX.md' "# Agent Inbox`n- Date: 2000-01-01; Recipient: maintainer; Scope: ``001/spec-r1``; Artifact: [spec](specs/001-example/spec.md); Action: retain until owner resumes.`n"
        $result = Invoke-FixtureLint $fixture
        @(Get-FixtureFindings $result 'stale-handoff').Count | Should Be 0
        @(Get-WorkflowPackages $fixture.RepoRoot)[0].Lifecycle | Should Be parked
    }

    It 'leaves Git status and all tracked content unchanged after lint' {
        Write-FixtureFile $fixture 'AGENT-INBOX.md' "# Agent Inbox`n- Recipient: maintainer; Scope: ``001/spec-r1``; Artifact: [spec](specs/001-example/spec.md); Action: read.`n"
        $before = @(Invoke-FixtureGit $fixture @('status','--porcelain=v1')) -join "`n"
        $diffBefore = @(Invoke-FixtureGit $fixture @('diff','--binary')) -join "`n"
        $null = Invoke-FixtureLint $fixture
        (@(Invoke-FixtureGit $fixture @('status','--porcelain=v1')) -join "`n") | Should Be $before
        (@(Invoke-FixtureGit $fixture @('diff','--binary')) -join "`n") | Should Be $diffBefore
    }
}
