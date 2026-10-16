. (Join-Path $PSScriptRoot 'Fixture.Helpers.ps1')
. (Join-Path $script:KitRoot 'workflow-model.ps1')
. (Join-Path $script:KitRoot 'workflow-scheduler.ps1')

function Get-HeadCommit {
    param([string]$RepoPath)
    return [string](git -C $RepoPath rev-parse HEAD)
}

Describe 'Shared preservation inventory' {
    BeforeEach {
        $script:fixture=New-WorkflowFixture
        $script:config=Get-FixtureConfig $fixture
    }
    AfterEach { Remove-WorkflowFixture $script:fixture }

    It 'summarizes a large ignored dependency directory and scans it only once' {
        $null=Invoke-FixtureGit $fixture @('config','core.quotePath','true')
        [IO.File]::AppendAllText((Join-Path $fixture.RepoRoot '.git/info/exclude'), "`nnode_modules/`n")
        for ($i=0; $i -lt 1200; $i++) {
            Write-FixtureFile $fixture "node_modules/pkg-$($i % 20)/file-$i.js" 'Generated dependency.'
        }
        $before=[string](git -C $fixture.RepoRoot rev-parse HEAD)
        $inventory=Get-WorkflowPreservationInventory $fixture.RepoRoot $fixture.RepoRoot $config
        $inventory.Reasons.Count | Should Be 0
        $inventory.IgnoredPaths.Count | Should Be 1
        $inventory.DisposableDirectories.Count | Should Be 1
        $inventory.DisposableDirectories[0] | Should Be node_modules
        $inventory.ScanCount | Should Be 1
        $inventory.ScanEntryCount | Should Be 1220
        ([string](git -C $fixture.RepoRoot rev-parse HEAD)) | Should Be $before
        [IO.File]::ReadAllText((Join-Path $fixture.RepoRoot 'node_modules/pkg-0/file-0.js')) | Should Be 'Generated dependency.'
    }

    It 'collapses ignored and untracked summaries to one disposable subtree scan' {
        Write-FixtureFile $fixture 'node_modules/pkg/generated.js' 'Generated.'
        Write-FixtureFile $fixture 'node_modules/pkg/cache.tmp' 'Ignored generated.'
        [IO.File]::AppendAllText((Join-Path $fixture.RepoRoot '.git/info/exclude'), "`n*.tmp`n")
        $inventory=Get-WorkflowPreservationInventory $fixture.RepoRoot $fixture.RepoRoot $config
        $inventory.Reasons.Count | Should Be 0
        $inventory.ScanCount | Should Be 1
        $inventory.DisposableDirectories[0] | Should Be node_modules
    }

    It 'preserves nested evidence hidden by an ignored directory summary' {
        foreach ($name in @('specs','reviews','evidence')) {
            Write-FixtureFile $fixture "node_modules/pkg/$name/result.txt" 'Keep this evidence.'
        }
        [IO.File]::AppendAllText((Join-Path $fixture.RepoRoot '.git/info/exclude'), "`nnode_modules/`n")
        $inventory=Get-WorkflowPreservationInventory $fixture.RepoRoot $fixture.RepoRoot $config
        $inventory.ScanCount | Should Be 1
        $inventory.DisposableDirectories.Count | Should Be 0
        $inventory.ProtectedPaths.Count | Should Be 3
        ($inventory.Reasons -join ';') | Should Match 'nested evidence'
    }

    It 'preserves ignored secrets unknown untracked bytes and staged changes' {
        Write-FixtureFile $fixture '.private-secret' 'Keep secret.'
        Write-FixtureFile $fixture 'user-note.txt' 'Keep note.'
        [IO.File]::AppendAllText((Join-Path $fixture.RepoRoot '.git/info/exclude'), "`n.private-secret`n")
        Write-FixtureFile $fixture 'README.md' 'Changed tracked work.'
        $null=Invoke-FixtureGit $fixture @('add','README.md')
        $inventory=Get-WorkflowPreservationInventory $fixture.RepoRoot $fixture.RepoRoot $config
        $inventory.Dirty | Should Be $true
        ($inventory.ProtectedPaths -contains '.private-secret') | Should Be $true
        ($inventory.ProtectedPaths -contains 'user-note.txt') | Should Be $true
        ($inventory.Reasons -join ';') | Should Match 'tracked/index changes'
    }

    It 'keeps tracked dependency content protected and dirty dependency bytes block removal' {
        Write-FixtureFile $fixture 'node_modules/owned.txt' 'Tracked owned bytes.'
        Save-FixtureRevision $fixture
        Write-FixtureFile $fixture 'node_modules/generated.js' 'Generated.'
        $inventory=Get-WorkflowPreservationInventory $fixture.RepoRoot $fixture.RepoRoot $config
        ($inventory.ProtectedTrackedPaths -contains 'node_modules/owned.txt') | Should Be $true
        ($inventory.ProtectedPaths -contains 'node_modules/owned.txt') | Should Be $true
        $inventory.Reasons.Count | Should Be 0
        $inventory.DisposableDirectories.Count | Should Be 0
        Write-FixtureFile $fixture 'node_modules/owned.txt' 'Changed owned bytes.'
        $inventory=Get-WorkflowPreservationInventory $fixture.RepoRoot $fixture.RepoRoot $config
        $inventory.Dirty | Should Be $true
        ($inventory.Reasons -join ';') | Should Match 'tracked/index changes'
    }

    It 'preserves exact Unicode Git paths under a non-UTF8 console without changing its encoding' {
        $trackedPath='node_modules/notes δ.txt'
        $untrackedPath='notes λ.txt'
        Write-FixtureFile $fixture $trackedPath 'Tracked owned bytes.'
        Save-FixtureRevision $fixture
        Write-FixtureFile $fixture $untrackedPath 'Untracked owner note.'
        $originalConsoleEncoding=[Console]::OutputEncoding
        $originalOutputEncoding=$OutputEncoding
        try {
            [Console]::OutputEncoding=[Text.Encoding]::GetEncoding(437)
            $OutputEncoding=[Text.Encoding]::GetEncoding(437)
            $tracked=@(Get-WorkflowPreservationGitRecords $fixture.RepoRoot @('ls-files','-z'))
            $untracked=@(Get-WorkflowPreservationGitRecords $fixture.RepoRoot @('ls-files','--others','--exclude-standard','-z'))
            ($tracked -contains $trackedPath) | Should Be $true
            ($untracked -contains $untrackedPath) | Should Be $true
            $inventory=Get-WorkflowPreservationInventory $fixture.RepoRoot $fixture.RepoRoot $config
            ($inventory.TrackedPaths -contains $trackedPath) | Should Be $true
            ($inventory.ProtectedTrackedPaths -contains $trackedPath) | Should Be $true
            ($inventory.ProtectedPaths -contains $trackedPath) | Should Be $true
            ($inventory.UntrackedPaths -contains $untrackedPath) | Should Be $true
            ($inventory.ProtectedPaths -contains $untrackedPath) | Should Be $true
            $inventory.DisposableDirectories.Count | Should Be 0
            [Console]::OutputEncoding.CodePage | Should Be 437
            $OutputEncoding.CodePage | Should Be 437
        } finally {
            [Console]::OutputEncoding=$originalConsoleEncoding
            $OutputEncoding=$originalOutputEncoding
        }
        [Console]::OutputEncoding.CodePage | Should Be $originalConsoleEncoding.CodePage
        $OutputEncoding.CodePage | Should Be $originalOutputEncoding.CodePage
    }

    It 'detects a nested link without traversing its target' {
        $external=Join-Path $fixture.TempRoot 'outside'
        $null=New-Item -ItemType Directory -Path (Join-Path $external 'evidence') -Force
        [IO.File]::WriteAllText((Join-Path $external 'evidence/keep.txt'),'External bytes.')
        $null=New-Item -ItemType Directory -Path (Join-Path $fixture.RepoRoot 'node_modules')
        $type=if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
        $null=New-Item -ItemType $type -Path (Join-Path $fixture.RepoRoot 'node_modules/linked') -Target $external
        [IO.File]::AppendAllText((Join-Path $fixture.RepoRoot '.git/info/exclude'), "`nnode_modules/`n")
        $inventory=Get-WorkflowPreservationInventory $fixture.RepoRoot $fixture.RepoRoot $config
        $inventory.ScanCount | Should Be 1
        ($inventory.LinkPaths -contains 'node_modules/linked') | Should Be $true
        ($inventory.ProtectedPaths -contains 'node_modules/linked/evidence') | Should Be $false
        $inventory.ScanEntryCount | Should Be 1
        ($inventory.Reasons -join ';') | Should Match 'linked content'
        [IO.File]::ReadAllText((Join-Path $external 'evidence/keep.txt')) | Should Be 'External bytes.'
    }

    It 'retains unresolved bounded scans and does not treat a file pattern as a directory' {
        Write-FixtureFile $fixture 'node_modules/a.txt' 'Generated.'
        Write-FixtureFile $fixture 'node_modules/b.txt' 'Generated.'
        $scan=Get-WorkflowPreservationSubtree $fixture.RepoRoot node_modules -MaxEntries 1
        ($scan.Reasons -join ';') | Should Match 'scan bound exceeded'
        $config.disposablePatterns=@('generated/')
        Write-FixtureFile $fixture 'generated' 'Untracked file.'
        $inventory=Get-WorkflowPreservationInventory $fixture.RepoRoot $fixture.RepoRoot $config
        ($inventory.Reasons -join ';') | Should Match 'pattern names a file'
    }

    It 'uses unique tracked parent checks rather than scanning every parent for every file' {
        for ($i=0; $i -lt 40; $i++) { Write-FixtureFile $fixture "owned/shared/file-$i.txt" 'Tracked.' }
        Save-FixtureRevision $fixture
        $inventory=Get-WorkflowPreservationInventory $fixture.RepoRoot $fixture.RepoRoot $config
        $inventory.Reasons.Count | Should Be 0
        ($inventory.DirectoryCheckCount -lt 40) | Should Be $true
    }

    It 'keeps zero-commit scratch failure cleanup available for disposable bytes only' {
        $config.managedScratchRoot=Join-Path $fixture.TempRoot 'scratch'
        Set-FixtureConfig $fixture $config
        Save-FixtureRevision $fixture
        $scratch=New-WorkflowScratch $fixture.RepoRoot
        $base=Get-HeadCommit $scratch
        $scratchFixture=[pscustomobject]@{RepoRoot=$scratch}
        Write-FixtureFile $scratchFixture 'node_modules/generated.js' 'Generated.'
        (Test-WorkflowScratchHasWork $scratch $base) | Should Be $false
        Remove-WorkflowScratch $fixture.RepoRoot $scratch
        (Test-Path -LiteralPath $scratch) | Should Be $false
        $scratch=New-WorkflowScratch $fixture.RepoRoot
        Write-FixtureFile ([pscustomobject]@{RepoRoot=$scratch}) 'coverage/evidence/failure.txt' 'Keep failure evidence.'
        (Test-WorkflowScratchHasWork $scratch (Get-HeadCommit $scratch)) | Should Be $true
        $failure=$null
        try { Remove-WorkflowScratch $fixture.RepoRoot $scratch } catch { $failure=$_.Exception.Message }
        $failure | Should Match 'evidence'
        (Test-Path -LiteralPath $scratch) | Should Be $true
    }

    It 'preserves locks and committed package holds even after local hold deletion' {
        $config.managedScratchRoot=Join-Path $fixture.TempRoot 'scratch'
        Set-FixtureConfig $fixture $config
        $spec=Join-Path $fixture.RepoRoot 'specs/001-example/spec.md'
        [IO.File]::AppendAllText($spec,"`n**Cleanup holds**: Preserve owner evidence.`n")
        Save-FixtureRevision $fixture
        $scratch=New-WorkflowScratch $fixture.RepoRoot
        $null=Invoke-FixtureGit $fixture @('worktree','lock',$scratch)
        $inventory=Get-WorkflowPreservationInventory $fixture.RepoRoot $scratch $config
        $inventory.Locked | Should Be $true
        ($inventory.Reasons -join ';') | Should Match 'package-owned hold'
        $null=Invoke-FixtureGit $fixture @('worktree','unlock',$scratch)
        $scratchSpec=Join-Path $scratch 'specs/001-example/spec.md'
        [IO.File]::WriteAllText($scratchSpec,[IO.File]::ReadAllText($scratchSpec).Replace('**Cleanup holds**: Preserve owner evidence.',''))
        $failure=$null
        try { Remove-WorkflowScratch $fixture.RepoRoot $scratch } catch { $failure=$_.Exception.Message }
        $failure | Should Match 'base holds'
        (Test-Path -LiteralPath $scratch) | Should Be $true
    }

    It 'scopes delivery holds so an unrelated held package does not block independent cleanup' {
        Write-FixtureFile $fixture 'specs/002-held/spec.md' "# Held package`n**Cleanup holds**: Preserve a different worktree.`n"
        Save-FixtureRevision $fixture
        $unscoped=Get-WorkflowPreservationInventory $fixture.RepoRoot $fixture.RepoRoot $config
        $unscoped.Holds.Count | Should Be 1
        $scoped=Get-WorkflowPreservationInventory $fixture.RepoRoot $fixture.RepoRoot $config -PackageRelativePath specs/001-example
        $scoped.Reasons.Count | Should Be 0
        $scoped.Holds.Count | Should Be 0
        $held=Get-WorkflowPreservationInventory $fixture.RepoRoot $fixture.RepoRoot $config -PackageRelativePath specs/002-held
        ($held.Reasons -join ';') | Should Match 'package-owned hold'
    }

    It 'reads committed holds through the shared BOM-aware blob decoder' {
        $spec=Join-Path $fixture.RepoRoot 'specs/001-example/spec.md'
        $text=[IO.File]::ReadAllText($spec)+"`n**Cleanup holds**: Preserve encoded evidence.`n"
        foreach ($encoding in @([Text.Encoding]::Unicode,[Text.Encoding]::BigEndianUnicode,[Text.Encoding]::UTF32)) {
            [IO.File]::WriteAllText($spec,$text,$encoding)
            Save-FixtureRevision $fixture
            $inventory=Get-WorkflowPreservationInventory $fixture.RepoRoot $fixture.RepoRoot $config -PackageRelativePath specs/001-example
            $inventory.Holds.Count | Should Be 1
            ($inventory.Reasons -join ';') | Should Match 'encoded evidence'
        }
    }

    It 'checks tracked directory parents shallowest first and skips linked descendants' {
        Write-FixtureFile $fixture 'owned/deep/shared/file.txt' 'Tracked bytes.'
        Save-FixtureRevision $fixture
        $outside=Join-Path $fixture.TempRoot 'outside-tracked'
        Move-Item -LiteralPath (Join-Path $fixture.RepoRoot 'owned') -Destination $outside
        $type=if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
        $null=New-Item -ItemType $type -Path (Join-Path $fixture.RepoRoot 'owned') -Target $outside
        $inventory=Get-WorkflowPreservationInventory $fixture.RepoRoot $fixture.RepoRoot $config
        ($inventory.LinkPaths -contains 'owned') | Should Be $true
        ($inventory.LinkPaths -contains 'owned/deep/shared') | Should Be $false
        ($inventory.Reasons -join ';') | Should Match 'tracked directory link'
        [IO.File]::ReadAllText((Join-Path $outside 'deep/shared/file.txt')) | Should Be 'Tracked bytes.'
    }
}
