param(
    [string]$SourceDir = (Join-Path $PSScriptRoot 'prompts'),
    [string[]]$TargetPath,
    [switch]$IncludeInsiders
)

$ErrorActionPreference = 'Stop'

function Get-DefaultPromptTargets {
    $targets = [System.Collections.Generic.List[string]]::new()

    if ($IsWindows -or $env:OS -eq 'Windows_NT') {
        $targets.Add((Join-Path $env:APPDATA 'Code\User\prompts'))

        $insidersParent = Join-Path $env:APPDATA 'Code - Insiders\User'
        if ($IncludeInsiders -or (Test-Path $insidersParent)) {
            $targets.Add((Join-Path $insidersParent 'prompts'))
        }
    } elseif ($IsMacOS) {
        $targets.Add((Join-Path $HOME 'Library/Application Support/Code/User/prompts'))

        $insidersParent = Join-Path $HOME 'Library/Application Support/Code - Insiders/User'
        if ($IncludeInsiders -or (Test-Path $insidersParent)) {
            $targets.Add((Join-Path $insidersParent 'prompts'))
        }
    } else {
        $targets.Add((Join-Path $HOME '.config/Code/User/prompts'))

        $insidersParent = Join-Path $HOME '.config/Code - Insiders/User'
        if ($IncludeInsiders -or (Test-Path $insidersParent)) {
            $targets.Add((Join-Path $insidersParent 'prompts'))
        }
    }

    return @($targets | Select-Object -Unique)
}

if (-not (Test-Path $SourceDir)) {
    throw "Prompt source directory not found: $SourceDir"
}

$promptFiles = @(Get-ChildItem -Path $SourceDir -Filter '*.prompt.md' -File | Sort-Object Name)
if ($promptFiles.Count -eq 0) {
    throw "No .prompt.md files found in $SourceDir"
}

$targetPaths = if ($TargetPath -and $TargetPath.Count -gt 0) {
    @($TargetPath | Select-Object -Unique)
} else {
    Get-DefaultPromptTargets
}

if ($targetPaths.Count -eq 0) {
    throw 'No VS Code prompt target paths resolved.'
}

foreach ($target in $targetPaths) {
    $null = New-Item -ItemType Directory -Force -Path $target

    foreach ($promptFile in $promptFiles) {
        Copy-Item -LiteralPath $promptFile.FullName -Destination (Join-Path $target $promptFile.Name) -Force
    }

    Write-Host "Installed $($promptFiles.Count) prompt files to $target" -ForegroundColor Green
}

Write-Host 'Prompt install complete.' -ForegroundColor Green