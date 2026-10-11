. (Join-Path $PSScriptRoot 'Fixture.Helpers.ps1')

function Invoke-FixtureCommitCheck {
    param($Fixture)
    $output = & pwsh -NoLogo -NoProfile -File (Join-Path $script:KitRoot 'workflow-hook.ps1') -RepoRoot $Fixture.RepoRoot 2>&1
    return [pscustomobject]@{ExitCode=$LASTEXITCODE; Output=($output -join "`n")}
}

Describe 'Local commit checks validate the staged governing contract' {
    BeforeEach { $script:fixture=New-WorkflowFixture }
    AfterEach { Remove-WorkflowFixture $script:fixture }

    It 'accepts matching bounded staged owners' {
        (Invoke-FixtureCommitCheck $fixture).ExitCode | Should Be 0
    }

    It 'rejects staged marker injection hidden by clean worktree bytes' {
        $path=Join-Path $fixture.RepoRoot 'AGENTS.md'
        $original=[IO.File]::ReadAllText($path)
        Write-FixtureFile $fixture 'AGENTS.md' ($original+"<!-- SPECKIT START -->`nInjected plan`n<!-- SPECKIT END -->`n")
        $null=Invoke-FixtureGit $fixture @('add','AGENTS.md')
        Write-FixtureFile $fixture 'AGENTS.md' $original
        $result=Invoke-FixtureCommitCheck $fixture
        $result.ExitCode | Should Be 1
        $result.Output | Should Match 'differs between index and worktree'
        [IO.File]::ReadAllText($path) | Should Be $original
    }

    It 'rejects matching staged long-line overflow through lint' {
        Write-FixtureFile $fixture 'AGENTS.md' ("Read docs/specs.md`n"+('é'*7000)+"`n")
        $null=Invoke-FixtureGit $fixture @('add','AGENTS.md')
        $result=Invoke-FixtureCommitCheck $fixture
        $result.ExitCode | Should Be 1
        $result.Output | Should Match 'budget-file'
    }

    It 'requires durable review artifacts to be staged and preserves them on failure' {
        Write-FixtureFile $fixture 'specs/001-example/reviews/new-findings.md' "# New findings`nKeep these findings.`n"
        $result=Invoke-FixtureCommitCheck $fixture
        $result.ExitCode | Should Be 1
        $result.Output | Should Match 'not staged'
        (Test-Path -LiteralPath (Join-Path $fixture.RepoRoot 'specs/001-example/reviews/new-findings.md')) | Should Be $true
    }
}

Describe 'Unmigrated legacy lint and external-mirror compatibility' {
    BeforeEach {
        $script:fixture=New-WorkflowFixture
        Write-FixtureFile $fixture '.workflow-kit.json' '{"canonicalMirrorMode":"external"}'
        Write-FixtureFile $fixture '.github/copilot-instructions.md' "## What this repo is`nLegacy fixture, repo-type-aware precedence.`n## Token discipline`nUse targeted reads.`n### Full validation`nRun checks.`n### Targeted validation`nRun checks.`n"
        Write-FixtureFile $fixture '.github/agents/agent.md' "---`ndescription: Legacy resume fixture`n---`nRead legacy owners.`n"
        Write-FixtureFile $fixture 'TODO.md' "## Maintaining this file`nOpen items only.`n## Short-term`n- [ ] A legacy task.`n## Medium-term`n## Long-term`n"
        Write-FixtureFile $fixture 'STATUS.md' '# Legacy status'
        Write-FixtureFile $fixture 'HISTORY.md' '# Legacy history'
        Write-FixtureFile $fixture 'INBOX.md' "# Inbox`n`nDrop notes here. The agent will triage items into ``TODO.md`` (near-term) or ``ROADMAP.md`` (longer-term), then empty this file back to its template header.`n"
        Write-FixtureFile $fixture 'AGENT-INBOX.md' "# Agent Inbox`n`nMachine-generated handoffs, long diagnostics, and cross-repo follow-up notes go here.`n`nDo not use this file for user notes. User-authored async notes belong in ``INBOX.md``.`n`nThe agent should triage anything durable from this file into ``TODO.md``, ``ROADMAP.md``, ``STATUS.md``, ``HISTORY.md``, or ``docs/specs.md``, then empty this file back to this header template.`n"
        Write-FixtureFile $fixture 'ROADMAP.md' '# Legacy product direction'
    }
    AfterEach { Remove-WorkflowFixture $script:fixture }

    It 'passes legacy lint without imposing versioned owners or budgets' {
        $result=Invoke-FixtureLint $fixture -Strict
        $result.Report.mode | Should Be legacy
        $result.ExitCode | Should Be 0
    }

    It 'suppresses missing external kit mirrors while preserving legacy validation' {
        $result=Invoke-FixtureLint $fixture -Strict -Command diff
        $result.ExitCode | Should Be 0
        @(Get-FixtureFindings $result 'canonical-file-missing').Count | Should Be 0
    }
}
