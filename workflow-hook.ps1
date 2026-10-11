param([string]$RepoRoot = $PWD)
$ErrorActionPreference = 'Stop'

# Worktree lint is safe only if staged governing surfaces have the same bytes.
# Fail partial contract staging instead of silently validating a different tree.
$stagedConfig = git -C $RepoRoot show ':.workflow-kit.json' 2>$null
if ($LASTEXITCODE -eq 0) {
    try { $config = $stagedConfig -join "`n" | ConvertFrom-Json } catch { throw 'commit-incomplete: staged config is invalid.' }
    if ($config.PSObject.Properties.Name -contains 'workflowModelVersion') {
        if ($config.workflowModelVersion -ne 1) { throw 'commit-incomplete: invalid staged workflow model version.' }
        $paths = @('AGENTS.md','CLAUDE.md','.github/copilot-instructions.md','docs/specs.md','AGENT-INBOX.md','INBOX.md','.specify/memory/constitution.md','.workflow-kit.json')
        $paths += @($config.autoLoadedFiles | Where-Object loading -eq full | ForEach-Object path)
        $paths += @(git -C $RepoRoot ls-files -- specs/ | Where-Object { $_ -match '/(spec|tasks)\.md$|/reviews/' })
        foreach ($relative in ($paths | Select-Object -Unique)) {
            $workingPath = Join-Path $RepoRoot $relative
            $staged = git -C $RepoRoot rev-parse ":$relative" 2>$null
            if ($LASTEXITCODE -or -not (Test-Path -LiteralPath $workingPath -PathType Leaf)) { throw "commit-incomplete: stage required contract owner $relative." }
            $working = git -C $RepoRoot hash-object --path=$relative $workingPath
            if ($LASTEXITCODE -or $staged -ne $working) { throw "commit-incomplete: $relative differs between index and worktree; stage the validated owner or restore its validated bytes." }
        }
        $unstaged = @(git -C $RepoRoot ls-files --others --exclude-standard -- specs/ | Where-Object { $_ -match '/(spec|tasks)\.md$|/reviews/' })
        if ($unstaged.Count) { throw "commit-incomplete: package owner/review artifacts are not staged: $($unstaged -join ', ')." }
    }
}
& pwsh -NoLogo -NoProfile -File "$PSScriptRoot/workflow-kit.ps1" -Command lint -RepoRoot $RepoRoot -Strict
exit $LASTEXITCODE
