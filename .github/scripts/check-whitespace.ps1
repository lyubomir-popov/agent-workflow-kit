param(
    [string]$RepoRoot = $PWD,
    [Parameter(Mandatory)][ValidateSet('push','pull_request')][string]$EventName,
    [Parameter(Mandatory)][string]$EventPath
)
$ErrorActionPreference = 'Stop'

function Resolve-EventCommit {
    param([string]$Revision)
    if ($Revision -notmatch '^[0-9a-fA-F]{40,64}$') { throw 'Whitespace check requires a full event commit ID.' }
    $resolved = & git -C $RepoRoot rev-parse --verify "${Revision}^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Whitespace event revision is unavailable: $Revision." }
    return [string]$resolved
}

$event = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $EventPath).Path) | ConvertFrom-Json
$rootComparison = $false
if ($EventName -eq 'pull_request') {
    $base = Resolve-EventCommit ([string]$event.pull_request.base.sha)
    $head = Resolve-EventCommit ([string]$event.pull_request.head.sha)
    $base = [string](& git -C $RepoRoot merge-base $base $head)
    if ($LASTEXITCODE -ne 0 -or -not $base) { throw 'Whitespace PR commits have no available merge base.' }
} else {
    $head = Resolve-EventCommit ([string]$event.after)
    $before = [string]$event.before
    if ($before -match '^0{40,64}$') {
        . (Join-Path $PSScriptRoot '../../workflow-model.ps1')
        $config = Get-WorkflowConfig $RepoRoot
        if (-not $config) { throw 'First-push whitespace fallback requires the configured target.' }
        $target = & git -C $RepoRoot rev-parse --verify "refs/heads/$($config.targetBranch)^{commit}" 2>$null
        if ($LASTEXITCODE -ne 0) { throw 'First-push whitespace target is unavailable.' }
        $base = [string](& git -C $RepoRoot merge-base ([string]$target) $head)
        if ($LASTEXITCODE -ne 0 -or -not $base) { throw 'First-push whitespace target has no merge base.' }
        if ($base -eq $head) {
            $parent = & git -C $RepoRoot rev-parse --verify "${head}^" 2>$null
            if ($LASTEXITCODE -eq 0) { $base = [string]$parent }
            else { $rootComparison = $true }
        }
    } else {
        $base = Resolve-EventCommit $before
    }
}
if ($rootComparison) {
    Write-Host "Whitespace range: empty tree..$head"
    & git -C $RepoRoot diff-tree --root -r --check $head --
} else {
    Write-Host "Whitespace range: ${base}..$head"
    & git -C $RepoRoot diff --check "${base}..$head" --
}
if ($LASTEXITCODE -ne 0) { throw 'Committed-range whitespace check failed.' }
