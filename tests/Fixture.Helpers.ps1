# Disposable local Git fixtures. All writes and recursive cleanup stay in a
# unique OS temp directory; no installer, remote, model or sibling repo is used.
$script:KitRoot = Split-Path $PSScriptRoot -Parent

function Write-FixtureFile {
    param($Fixture, [string]$RelativePath, [string]$Text)
    $path = Join-Path $Fixture.RepoRoot $RelativePath
    $null = New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force
    [IO.File]::WriteAllText($path, $Text, [Text.UTF8Encoding]::new($false))
}

function Invoke-FixtureGit {
    param($Fixture, [string[]]$Arguments)
    $output = & git -C $Fixture.RepoRoot @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Fixture Git failed: $($Arguments -join ' '): $output" }
    return $output
}

function Save-FixtureRevision {
    param($Fixture)
    $null = Invoke-FixtureGit $Fixture @('add', '--all')
    $null = Invoke-FixtureGit $Fixture @('commit', '--quiet', '--allow-empty', '-m', 'Fixture state')
}

function Set-FixtureConfig {
    param($Fixture, $Config)
    Write-FixtureFile $Fixture '.workflow-kit.json' ($Config | ConvertTo-Json -Depth 20)
}

function Get-FixtureConfig {
    param($Fixture)
    return Get-Content -LiteralPath (Join-Path $Fixture.RepoRoot '.workflow-kit.json') -Raw | ConvertFrom-Json
}

function Set-FixtureSpec {
    param($Fixture, [string]$Lifecycle = 'active', [string]$Scope = '001/spec-r1',
        [string]$State = 'owner-cleared', [string]$VerdictLink = '[saved verdict](reviews/CP1-review.md)',
        [string]$SupersededTasks = 'none', [string]$SupersededScope = '')
    $scopeSuffix = if ($SupersededScope) { '; supersedes `' + $SupersededScope + '`' } else { '' }
    Write-FixtureFile $Fixture 'specs/001-example/spec.md' @"
# Example

**Feature branch**: ``feat/001-example``
**Lifecycle**: $Lifecycle
**Scope**: ``$Scope``$scopeSuffix
**Superseded tasks**: $SupersededTasks
**Checkpoints**:

| ID | Gate | Verdict link | State |
|---|---|---|---|
| CP1 | implementation | $VerdictLink | $State |
| CP2 | closeout | none | pending |

## Intent

Exercise fixture behavior.
"@
}

function Set-FixtureReview {
    param($Fixture, [string]$Verdict = 'accept', [string]$Scope = '001/spec-r1')
    Write-FixtureFile $Fixture 'specs/001-example/reviews/CP1-review.md' @"
# Saved review

**Checkpoint**: CP1
**Scope**: ``$Scope``
**Reviewed revision**: ``fixture-base``
**Reviewer**: Fixture reviewer
**Verdict**: $Verdict

## Findings

No blocking findings.
"@
}

function Set-FixtureTasks {
    param($Fixture, [string]$Body = '- [ ] T001 Implement example.')
    Write-FixtureFile $Fixture 'specs/001-example/tasks.md' @"
# Current work

**Next tasks**: T001.
**Blockers**: none.
**Checkpoint links**: [CP1](spec.md#checkpoints).
**Entry checkpoint**: CP1
**Validation**: local fixture checks.

## Work

$Body
"@
}

function New-WorkflowFixture {
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('workflow-kit-tests-' + [guid]::NewGuid().ToString('N'))
    $fixture = [pscustomobject]@{ TempRoot = $tempRoot; RepoRoot = Join-Path $tempRoot 'repo' }
    $null = New-Item -ItemType Directory -Path $fixture.RepoRoot -Force
    $null = Invoke-FixtureGit $fixture @('init', '--quiet', '--initial-branch=master')
    $null = Invoke-FixtureGit $fixture @('config', 'user.name', 'Workflow fixture')
    $null = Invoke-FixtureGit $fixture @('config', 'user.email', 'fixture@example.invalid')
    $null = Invoke-FixtureGit $fixture @('config', 'core.autocrlf', 'false')
    $null = Invoke-FixtureGit $fixture @('config', 'commit.gpgsign', 'false')
    $null = Invoke-FixtureGit $fixture @('config', 'core.hooksPath', (Join-Path $tempRoot 'no-hooks'))
    # Use the committed config schema, including every declared host/adapter.
    $config = Get-Content -LiteralPath (Join-Path $script:KitRoot '.workflow-kit.json') -Raw | ConvertFrom-Json
    Set-FixtureConfig $fixture $config
    Write-FixtureFile $fixture 'AGENTS.md' "# Agent invariants`n`nRead [the catalog](docs/specs.md) at session start/end and scope changes.`nCheck workflow-kit lint before work.`n"
    Write-FixtureFile $fixture 'CLAUDE.md' "@AGENTS.md`n"
    Write-FixtureFile $fixture '.github/copilot-instructions.md' "Read [AGENTS.md](../AGENTS.md).`n"
    Write-FixtureFile $fixture '.specify/memory/constitution.md' "# Principles`nPreserve work and require owner authorization.`n"
    Write-FixtureFile $fixture '.gitignore' ".specify/feature.json`n"
    Write-FixtureFile $fixture '.agents/skills/.keep' ''
    Write-FixtureFile $fixture '.claude/skills/.keep' ''
    Write-FixtureFile $fixture 'INBOX.md' "# Inbox`n`nTransient user handoffs: recipient, scope, artifact, action.`n"
    Write-FixtureFile $fixture 'AGENT-INBOX.md' "# Agent Inbox`n`nTransient agent handoffs: recipient, scope, artifact, action.`n"
    Write-FixtureFile $fixture 'docs/specs.md' @'
# Spec catalog

## Current packages

| Spec | Package | Branch |
|---|---|---|
| 001 | [Example](../specs/001-example/spec.md) | `feat/001-example` |

## Archive

| Spec | Package | Branch |
|---|---|---|

## Candidates

None.
'@
    foreach ($name in @('STATUS.md', 'TODO.md', 'HISTORY.md')) {
        Write-FixtureFile $fixture $name "# Retired workflow file`nRead [the catalog](docs/specs.md).`n"
    }
    Write-FixtureFile $fixture 'README.md' "# Fixture`nRead [the catalog](docs/specs.md).`n"
    Write-FixtureFile $fixture 'specs/001-example/README.md' "# Example package`nRead [spec](spec.md), [plan](plan.md), [tasks](tasks.md) and reviews on demand.`n"
    Write-FixtureFile $fixture 'specs/001-example/plan.md' "# Plan`nLocal fixture behavior.`n"
    Write-FixtureFile $fixture 'specs/001-example/reviews/CP1-request.md' "# Review request`n**Checkpoint**: CP1`n**Scope**: ``001/spec-r1```n**Reviewed revision**: ``fixture-base```n**Reviewer**: Fixture reviewer`nReview the fixture scope.`n"
    Set-FixtureSpec $fixture
    Set-FixtureTasks $fixture
    Set-FixtureReview $fixture
    Save-FixtureRevision $fixture
    $null = Invoke-FixtureGit $fixture @('switch', '--quiet', '-c', 'feat/001-example')
    return $fixture
}

function Set-FixtureArchivedPackage {
    param($Fixture)
    Set-FixtureSpec $Fixture -Lifecycle delivered
    Set-FixtureTasks $Fixture '- [x] T001 Implement example.'
    $tasksPath=Join-Path $Fixture.RepoRoot 'specs/001-example/tasks.md'
    [IO.File]::WriteAllText($tasksPath,[IO.File]::ReadAllText($tasksPath).Replace('**Next tasks**: T001.','**Next tasks**: none.'))
    Write-FixtureFile $Fixture 'docs/specs.md' @'
# Spec catalog

## Current packages

| Spec | Package | Branch |
|---|---|---|

## Archive

| Spec | Package | Branch |
|---|---|---|
| 001 | [Example](../specs/001-example/spec.md) | `feat/001-example` |

## Candidates

None.
'@
}

function Remove-WorkflowFixture {
    param($Fixture)
    if (-not $Fixture) { return }
    $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)
    $target = [IO.Path]::GetFullPath($Fixture.TempRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)
    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    if (-not $target.StartsWith($temp + [IO.Path]::DirectorySeparatorChar, $comparison) -or
        (Split-Path $target -Leaf) -notmatch '^workflow-kit-tests-[0-9a-f]{32}$') {
        throw "Refusing fixture cleanup outside its unique OS temp root: $target"
    }
    # Resolve existing paths again immediately before recursive deletion.
    if (Test-Path -LiteralPath $target) {
        $resolved = (Resolve-Path -LiteralPath $target).Path
        if ($resolved -ne $target) { throw "Unexpected resolved fixture root: $resolved" }
        if ((Get-Item -LiteralPath $target -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw 'Refusing linked fixture root cleanup.'
        }
        Remove-Item -LiteralPath $target -Recurse -Force
    }
}

function Invoke-FixtureLint {
    param($Fixture, [switch]$Strict, [ValidateSet('lint','diff')][string]$Command = 'lint')
    $arguments = @('-NoLogo','-NoProfile','-File',(Join-Path $script:KitRoot 'workflow-kit.ps1'),'-Command',$Command,'-RepoRoot',$Fixture.RepoRoot,'-Json')
    if ($Strict) { $arguments += '-Strict' }
    $output = & pwsh @arguments 2>&1
    $code = $LASTEXITCODE
    $raw = $output -join "`n"
    try { $report = $raw | ConvertFrom-Json -ErrorAction Stop }
    catch { throw "Lint returned non-JSON (exit $code): $raw" }
    [pscustomobject]@{ ExitCode = $code; Report = $report; Raw = $raw }
}

function Get-FixtureFindings {
    param($Result, [string]$Rule)
    return @($Result.Report.findings | Where-Object { $_.rule -match $Rule })
}

# Pester 3's Throw assertion runs in an assertion scope that does not reliably
# retain local It-block variables in PowerShell 7. Evaluate in the caller chain.
function Test-FixtureThrows {
    param([scriptblock]$Action)
    try { $null = & $Action; return $false } catch { return $true }
}
