param([string[]]$Path = @($PSScriptRoot))
$ErrorActionPreference = 'Stop'
$compatible = Get-Module -ListAvailable Pester | Where-Object { $_.Version -ge [version]'3.4' -and $_.Version.Major -lt 5 } | Sort-Object Version -Descending | Select-Object -First 1
if (-not $compatible) { throw 'Tests require Pester 3.4 or 4.x; install Pester 4.10.1 explicitly. The runner never installs dependencies.' }
Import-Module $compatible.Path -ErrorAction Stop
$result = Invoke-Pester -Script $Path -PassThru
if ($result.FailedCount -gt 0) { exit 1 }
exit 0
