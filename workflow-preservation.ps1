# Read-only preservation inventory shared by delivery and marked scratch cleanup.
# Integration proof and accepted-revision package holds belong to the caller.
function Get-WorkflowPreservationGitRecords {
    param([string]$WorktreePath, [string[]]$Arguments)
    # Git's NUL-delimited path output is UTF-8, independent of the host console.
    $start=[Diagnostics.ProcessStartInfo]::new('git')
    $start.UseShellExecute=$false; $start.CreateNoWindow=$true
    $start.RedirectStandardOutput=$true; $start.RedirectStandardError=$true
    $start.StandardOutputEncoding=[Text.UTF8Encoding]::new($false,$true)
    foreach ($argument in (@('-C',$WorktreePath)+$Arguments)) { $start.ArgumentList.Add($argument) }
    $process=[Diagnostics.Process]::new(); $process.StartInfo=$start
    try {
        if (-not $process.Start()) { throw 'Git inventory could not start.' }
        $errorOutput=$process.StandardError.ReadToEndAsync()
        $output=$process.StandardOutput.ReadToEnd()
        $process.WaitForExit(); $null=$errorOutput.GetAwaiter().GetResult()
        if ($process.ExitCode) { throw "preservation-unknown: Git inventory failed: $($Arguments -join ' ')." }
        return @($output -split "`0" | Where-Object { $_ -ne '' })
    } finally { $process.Dispose() }
}

function Get-WorkflowPreservationHolds {
    param([string]$RepoRoot, [string]$Revision, [string]$PackageRelativePath)
    $scope=if ($PackageRelativePath) { $PackageRelativePath.TrimEnd('/')+'/spec.md' } else { 'specs' }
    $paths=@(Get-WorkflowPreservationGitRecords $RepoRoot @('ls-tree','-r','--name-only','-z',$Revision,'--',$scope))
    foreach ($path in $paths) {
        if ($path -notmatch '^specs/[^/]+/spec\.md$') { continue }
        $text=Read-WorkflowGitFile $RepoRoot $Revision $path
        if ($null -eq $text) { throw "preservation-unknown: package hold inventory failed at $path." }
        foreach ($match in [regex]::Matches($text,'(?im)^\*\*(?:Cleanup holds|Worktree holds|Holds|Hold)\*\*:[ \t]*([^\r\n]+)')) {
            if ($match.Groups[1].Value.Trim().TrimEnd('.') -notin @('none','no')) { "${path}: $($match.Groups[1].Value.Trim())" }
        }
        foreach ($match in [regex]::Matches($text,'(?ims)^##[ \t]+(?:Cleanup holds|Worktree holds|Holds|Hold)[ \t]*\r?$\n(?<body>.*?)(?=^##[ \t]+|\z)')) {
            $body=$match.Groups['body'].Value.Trim()
            if ($body -and $body.TrimEnd('.') -notin @('none','no')) { "${path}: $body" }
        }
    }
}

function Get-WorkflowDisposableRoot {
    param([string]$Relative, $Config)
    $relativePath=$Relative -replace '\\','/'
    $patterns=if ($Config) { @($Config.disposablePatterns) } else { @('node_modules/','.venv/','.pytest_cache/','__pycache__/','coverage/') }
    $root=$null
    foreach ($pattern in $patterns) {
        $match=[regex]::Match($relativePath,('(^|/)'+[regex]::Escape($pattern.TrimEnd('/'))+'(/|$)'),[Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($match.Success) {
            $candidate=$relativePath.Substring(0,$match.Index+$match.Length).TrimEnd('/')
            if (-not $root -or $candidate.Length -lt $root.Length) { $root=$candidate }
        }
    }
    return $root
}

function Get-WorkflowPreservationSubtree {
    param([string]$WorktreePath, [string]$Relative, [int]$MaxEntries=250000)
    $links=[Collections.Generic.List[string]]::new()
    $evidence=[Collections.Generic.List[string]]::new()
    $problems=[Collections.Generic.List[string]]::new()
    $pending=[Collections.Generic.Stack[string]]::new()
    $pending.Push((Join-Path $WorktreePath $Relative))
    $count=0
    try {
        while ($pending.Count) {
            $directory=$pending.Pop()
            $rootItem=Get-Item -LiteralPath $directory -Force -ErrorAction Stop
            if ($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                $links.Add(([IO.Path]::GetRelativePath($WorktreePath,$directory) -replace '\\','/')); continue
            }
            # Enumerate one directory at a time; never recurse through a link.
            foreach ($item in ([IO.DirectoryInfo]::new($directory)).EnumerateFileSystemInfos()) {
                $count++
                if ($count -gt $MaxEntries) { throw "scan bound exceeded ($MaxEntries entries)" }
                $path=[IO.Path]::GetRelativePath($WorktreePath,$item.FullName) -replace '\\','/'
                if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { $links.Add($path); continue }
                if ($item.Name -in @('specs','reviews','evidence')) {
                    $evidence.Add($path)
                    # This subtree is already protected; do not expand its bytes.
                    continue
                }
                if ($item.Attributes -band [IO.FileAttributes]::Directory) { $pending.Push($item.FullName) }
            }
        }
    } catch { $problems.Add("disposable scan unknown at ${Relative}: $($_.Exception.Message)") }
    return [pscustomobject]@{ LinkPaths=@($links.ToArray()); EvidencePaths=@($evidence.ToArray()); Reasons=@($problems.ToArray()); EntryCount=$count }
}

function Get-WorkflowPreservationInventory {
    param([string]$RepoRoot, [string]$WorktreePath, $Config, [string]$PackageRelativePath)
    $reasons=[Collections.Generic.List[string]]::new()
    $protected=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $links=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $roots=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $tracked=@(); $changes=@(); $untracked=@(); $ignored=@(); $protectedTracked=@(); $holds=@()
    $head=$null; $locked=$false; $dirty=$false; $scanCount=0; $entryCount=0; $directoryCheckCount=0
    try {
        $actual=[IO.Path]::GetFullPath($WorktreePath)
        Assert-WorkflowNoLinks $actual
        $gitRoot=[string](git -C $actual rev-parse --show-toplevel 2>$null)
        if ($LASTEXITCODE -or [IO.Path]::GetFullPath($gitRoot) -ne $actual) { throw 'target is not a Git worktree root' }
        $common=[string](git -C $actual rev-parse --path-format=absolute --git-common-dir 2>$null)
        if ($LASTEXITCODE) { throw 'worktree repository identity is unknown' }
        $ownerCommon=[string](git -C $RepoRoot rev-parse --path-format=absolute --git-common-dir 2>$null)
        if ($LASTEXITCODE -or $common -ne $ownerCommon) { throw 'worktree belongs to another repository' }
        $head=[string](git -C $actual rev-parse --verify HEAD 2>$null)
        if ($LASTEXITCODE) { throw 'worktree HEAD is unknown' }
        $holds=@(Get-WorkflowPreservationHolds $actual $head $PackageRelativePath)
        foreach ($hold in $holds) { $reasons.Add("package-owned hold: $hold") }
        $admin=[string](git -C $actual rev-parse --absolute-git-dir 2>$null)
        if ($LASTEXITCODE) { throw 'worktree lock inventory is unknown' }
        $locked=Test-Path -LiteralPath (Join-Path $admin 'locked')
        if ($locked) { $reasons.Add('worktree is locked') }
        $stages=@(Get-WorkflowPreservationGitRecords $actual @('ls-files','--stage','-z'))
        $tracked=@(foreach ($record in $stages) {
            if ($record -notmatch '(?s)^(?<mode>\d+) [0-9a-f]+ \d+\t(?<path>.+)$') { throw 'tracked path inventory is unknown' }
            $path=$Matches.path; $mode=$Matches.mode
            if ($mode -in @('120000','160000')) {
                $null=$links.Add($path); $null=$protected.Add($path)
                $reasons.Add("tracked link/submodule is protected: $path")
            }
            $path
        })
        $protectedTracked=@($tracked | Where-Object { Get-WorkflowDisposableRoot $_ $Config })
        foreach ($path in $protectedTracked) { $null=$protected.Add($path) }
        # Tracked modes detect symlinks; Windows directory junctions require an
        # attribute check. Cache unique parents so shared dependency ancestors
        # are checked once rather than walking to the filesystem root per file.
        $parents=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($relative in $tracked) {
            $parent=($relative -replace '/[^/]+$','')
            while ($parent -ne $relative -and $parent) {
                if (-not $parents.Add($parent)) { break }
                $relative=$parent
                $parent=$relative -replace '/[^/]+$',''
            }
        }
        $linkedParents=[Collections.Generic.List[string]]::new()
        foreach ($parent in @($parents | Sort-Object Length)) {
            if (@($linkedParents | Where-Object { $parent.StartsWith($_+'/',[StringComparison]::Ordinal) }).Count) { continue }
            $directoryCheckCount++
            $item=Get-Item -LiteralPath (Join-Path $actual $parent) -Force -ErrorAction SilentlyContinue
            if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                $linkedParents.Add($parent)
                $null=$links.Add($parent); $null=$protected.Add($parent); $reasons.Add("tracked directory link is protected: $parent")
            }
        }
        if ($links.Count) { throw 'linked tracked content prevents safe filesystem inventory' }
        $changes=@(Get-WorkflowPreservationGitRecords $actual @('status','--porcelain=v1','--untracked-files=no','-z'))
        $dirty=$changes.Count -gt 0
        if ($dirty) { $reasons.Add('tracked/index changes remain') }
        # Git collapses complete untracked/ignored directories before PowerShell
        # sees them, avoiding dependency-file expansion and per-file parent scans.
        $untracked=@(Get-WorkflowPreservationGitRecords $actual @('ls-files','--others','--exclude-standard','--directory','--no-empty-directory','-z'))
        $ignored=@(Get-WorkflowPreservationGitRecords $actual @('ls-files','--others','--ignored','--exclude-standard','--directory','--no-empty-directory','-z'))
        foreach ($relative in @($untracked)+@($ignored)) {
            if ($relative -match '(^|/)(specs|reviews|evidence)(/|$)') {
                $null=$protected.Add($relative); $reasons.Add("protected untracked/ignored evidence: $relative"); continue
            }
            $root=Get-WorkflowDisposableRoot $relative $Config
            if (-not $root) {
                $null=$protected.Add($relative); $reasons.Add("protected untracked/ignored content: $relative"); continue
            }
            $null=$roots.Add($root)
        }
        # Collapse overlapping summaries once, then scan each disposable subtree
        # once. Ancestor validation runs per root, never per dependency file.
        $selected=[Collections.Generic.List[string]]::new()
        foreach ($root in @($roots | Sort-Object Length)) {
            if (@($selected | Where-Object { $root.StartsWith($_+'/',[StringComparison]::Ordinal) }).Count) { continue }
            $selected.Add($root)
        }
        $roots.Clear()
        foreach ($root in $selected) {
            try { $path=Resolve-WorkflowRelativePath $actual $root }
            catch { $reasons.Add("linked/unknown disposable root ${root}: $($_.Exception.Message)"); $null=$links.Add($root); continue }
            $item=Get-Item -LiteralPath $path -Force -ErrorAction Stop
            if (-not $item.PSIsContainer) {
                $null=$protected.Add($root); $reasons.Add("disposable pattern names a file: $root"); continue
            }
            $scanCount++
            $scan=Get-WorkflowPreservationSubtree $actual $root
            $entryCount+=$scan.EntryCount
            foreach ($reason in $scan.Reasons) { $reasons.Add($reason) }
            foreach ($link in $scan.LinkPaths) { $null=$links.Add($link); $null=$protected.Add($link); $reasons.Add("linked content is protected: $link") }
            foreach ($evidence in $scan.EvidencePaths) { $null=$protected.Add($evidence); $reasons.Add("nested evidence is protected: $evidence") }
            $hasTracked=@($protectedTracked | Where-Object { $_ -eq $root -or $_.StartsWith($root+'/',[StringComparison]::Ordinal) }).Count -gt 0
            if (-not $hasTracked -and -not $scan.Reasons.Count -and -not $scan.LinkPaths.Count -and -not $scan.EvidencePaths.Count) { $null=$roots.Add($root) }
        }
    } catch { $reasons.Add("preservation inventory unknown: $($_.Exception.Message)") }
    return [pscustomobject]@{
        Reasons=@($reasons.ToArray()); Dirty=$dirty; ProtectedPaths=@($protected | Sort-Object)
        DisposableDirectories=@($roots | Sort-Object); ScanCount=$scanCount; ScanEntryCount=$entryCount; DirectoryCheckCount=$directoryCheckCount
        TrackedPaths=@($tracked); ProtectedTrackedPaths=@($protectedTracked); TrackedChanges=@($changes)
        UntrackedPaths=@($untracked); IgnoredPaths=@($ignored); LinkPaths=@($links | Sort-Object)
        Locked=$locked; Head=$head; Holds=@($holds)
    }
}
