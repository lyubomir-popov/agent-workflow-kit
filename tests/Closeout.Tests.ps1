. (Join-Path $PSScriptRoot 'Fixture.Helpers.ps1')
. (Join-Path $script:KitRoot 'workflow-closeout.ps1')
$script:closeoutGitImplementation=${function:Invoke-WorkflowCloseoutGit}
$script:closeoutWorktreeImplementation=${function:Get-WorkflowCloseoutWorktrees}
$script:closeoutProofLockImplementation=${function:Start-WorkflowCloseoutProofLock}

function New-CloseoutFixture {
    param([switch]$Squash,[switch]$NoWorktree,[switch]$Held)
    $fixture=New-WorkflowFixture
    Write-FixtureFile $fixture 'deleted.txt' 'old'
    Write-FixtureFile $fixture 'old-name.txt' 'rename bytes'
    Write-FixtureFile $fixture 'mode.txt' 'mode bytes'
    Save-FixtureRevision $fixture
    $base=[string](Invoke-FixtureGit $fixture @('rev-parse','HEAD'))
    $null=Invoke-FixtureGit $fixture @('branch','-f','master',$base)
    Set-FixtureArchivedPackage $fixture
    if ($Held) {
        $spec=Join-Path $fixture.RepoRoot 'specs/001-example/spec.md'
        [IO.File]::WriteAllText($spec,[IO.File]::ReadAllText($spec).Replace('**Lifecycle**: delivered',"**Lifecycle**: delivered`n**Cleanup holds**: preserve experiment"))
    }
    Write-FixtureFile $fixture 'added.txt' 'delivered'
    Write-FixtureFile $fixture 'résumé [notes] λ.txt' 'Unicode literal path bytes'
    $null=Invoke-FixtureGit $fixture @('rm','--quiet','deleted.txt')
    $null=Invoke-FixtureGit $fixture @('mv','old-name.txt','new-name.txt')
    $null=Invoke-FixtureGit $fixture @('add','--all')
    $null=Invoke-FixtureGit $fixture @('update-index','--chmod=+x','mode.txt')
    $null=Invoke-FixtureGit $fixture @('commit','--quiet','-m','Final delivery')
    $accepted=[string](Invoke-FixtureGit $fixture @('rev-parse','HEAD'))
    $null=Invoke-FixtureGit $fixture @('switch','--quiet','master')
    if ($Squash) {
        $null=Invoke-FixtureGit $fixture @('merge','--squash','feat/001-example')
        $null=Invoke-FixtureGit $fixture @('commit','--quiet','-m','Squash delivery')
    } else { $null=Invoke-FixtureGit $fixture @('merge','--quiet','--ff-only','feat/001-example') }
    $landed=[string](Invoke-FixtureGit $fixture @('rev-parse','HEAD'))
    $path=Join-Path $fixture.TempRoot 'delivery'
    if (-not $NoWorktree) { $null=Invoke-FixtureGit $fixture @('worktree','add','--quiet',$path,'feat/001-example') }
    $fixture | Add-Member Base $base
    $fixture | Add-Member Accepted $accepted
    $fixture | Add-Member Landed $landed
    $fixture | Add-Member DeliveryPath $path
    $fixture | Add-Member PreviewParameters @{RepoRoot=$fixture.RepoRoot; PackageId='001-example'; BaseRevision=$base; AcceptedRevision=$accepted; LandedRevision=$landed}
    return $fixture
}

function Invoke-CloseoutFixtureApply {
    param($Fixture,[switch]$OwnerConfirmed,[switch]$WorktreesOnly)
    $parameters=$Fixture.PreviewParameters.Clone()
    $parameters.Apply=$true; $parameters.AuthorizeLocalCleanup=$true; $parameters.RemoveWorktrees=$true
    if (-not $WorktreesOnly) { $parameters.DeleteLocalBranch=$true }
    if ($OwnerConfirmed) { $parameters.OwnerConfirmed=$true }
    return Invoke-WorkflowCloseout @parameters
}

function Move-CloseoutFixtureLiteralRef {
    param($Fixture,[string]$From,[string]$To)
    # Deliberately bypass Git's cooperating lock protocol in this private
    # failure fixture: literal casing must still be checked under held locks.
    $common=& $script:closeoutGitImplementation $Fixture.RepoRoot @('rev-parse','--path-format=absolute','--git-common-dir')
    if ($common.ExitCode) { throw 'fixture common directory is unavailable' }
    $root=[IO.Path]::GetFullPath($Fixture.TempRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar
    $comparison=if ($IsWindows) {[StringComparison]::OrdinalIgnoreCase} else {[StringComparison]::Ordinal}
    $source=[IO.Path]::GetFullPath((Join-Path $common.Output.Trim() $From))
    $destination=[IO.Path]::GetFullPath((Join-Path $common.Output.Trim() $To))
    if (-not $source.StartsWith($root,$comparison) -or -not $destination.StartsWith($root,$comparison) -or
        $From -notmatch '^refs/(heads|tags)/' -or $To -notmatch '^refs/(heads|tags)/') { throw 'fixture ref rename escaped its private temp repository' }
    $temporary=$source+'.case-'+[guid]::NewGuid().ToString('N')
    $null=[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
    [IO.File]::Move($source,$temporary)
    [IO.File]::Move($temporary,$destination)
}

function Test-CloseoutFixturePath {
    param([string]$Left,[string]$Right)
    $comparison=if ($IsWindows) {[StringComparison]::OrdinalIgnoreCase} else {[StringComparison]::Ordinal}
    return [string]::Equals([IO.Path]::GetFullPath($Left),[IO.Path]::GetFullPath($Right),$comparison)
}

function Enable-CloseoutRemoteMock {
    param($Fixture)
    $null=Invoke-FixtureGit $Fixture @('remote','add','origin','https://example.invalid/never-contact-this-fixture.git')
    $null=Invoke-FixtureGit $Fixture @('update-ref','refs/remotes/origin/feat/001-example',$Fixture.Accepted)
    $script:remoteFixture=$Fixture
    $script:remoteState=@{Target=$Fixture.Landed; Source=$Fixture.Accepted; Tag='absent'; TagObject=$null; FailPush=$false; FailDelete=$false; FailQuery=$false; QueryCount=0; ChangeAfterTag=''; ChangeAtDelete=''; OmitUnchangedLeaseChecks=$false; MoveLocalTagAtCapture=$false; ArchiveDateOverride=$null}
    $script:networkCalls=@()
    Mock Invoke-WorkflowCloseoutGit {
        if ($script:remoteState.ArchiveDateOverride -and $Arguments -contains 'tag' -and $Arguments -contains '-a') {
            $messageIndex=[array]::IndexOf($Arguments,'-m')+1
            $message=$Arguments[$messageIndex] | ConvertFrom-Json
            $message.date=$script:remoteState.ArchiveDateOverride
            $Arguments[$messageIndex]=$message | ConvertTo-Json -Compress
        }
        if ($script:remoteState.MoveLocalTagAtCapture -and $Arguments[0] -eq 'rev-parse' -and $Arguments[-1] -eq 'refs/tags/archive/001-example' -and
            @(Get-PSCallStack | Where-Object Command -eq 'Get-WorkflowCloseoutRemoteEvidence').Count) {
            $script:remoteState.MoveLocalTagAtCapture=$false
            $null=Invoke-FixtureGit $script:remoteFixture @('tag','-f','-a','archive/001-example',$script:remoteFixture.Accepted,'-m','Changed annotation at capture boundary')
        }
        if ($Arguments -contains 'ls-remote') {
            $script:networkCalls+=,($Arguments -join ' ')
            $script:remoteState.QueryCount++
            if ($script:remoteState.FailQuery) { return [pscustomobject]@{ExitCode=1; Output=''; Error='fixture remote query unavailable'} }
            if ($script:remoteState.Tag -eq 'matching' -and $script:remoteState.QueryCount -gt 1) {
                switch ($script:remoteState.ChangeAfterTag) {
                    'target' {$script:remoteState.Target=$script:remoteFixture.Base}
                    'source' {$script:remoteState.Source=$script:remoteFixture.Base}
                    'tag' {$script:remoteState.Tag='conflicting'}
                }
            }
            $lines=@()
            if ($script:remoteState.Target) { $lines+="$($script:remoteState.Target)`trefs/heads/master" }
            if ($script:remoteState.Source) { $lines+="$($script:remoteState.Source)`trefs/heads/feat/001-example" }
            if ($script:remoteState.Tag -eq 'matching') {
                if (-not $script:remoteState.TagObject) {
                    $tag=& $script:closeoutGitImplementation $RepoRoot @('rev-parse','refs/tags/archive/001-example')
                    $script:remoteState.TagObject=$tag.Output.Trim()
                }
                $lines+="$($script:remoteState.TagObject)`trefs/tags/archive/001-example"
                $lines+="$($script:remoteFixture.Accepted)`trefs/tags/archive/001-example^{}"
            } elseif ($script:remoteState.Tag -eq 'conflicting') { $lines+="$($script:remoteFixture.Accepted)`trefs/tags/archive/001-example" }
            return [pscustomobject]@{ExitCode=0; Output=($lines -join "`n"); Error=''}
        }
        if ($Arguments -contains 'push') {
            $script:networkCalls+=,($Arguments -join ' ')
            if ($Arguments[-1].StartsWith(':refs/heads/')) {
                if ($script:remoteState.ChangeAtDelete -eq 'target') { $script:remoteState.Target=$script:remoteFixture.Base }
                elseif ($script:remoteState.ChangeAtDelete -eq 'tag') { $script:remoteState.Tag='conflicting' }
                if ($script:remoteState.FailDelete) { return [pscustomobject]@{ExitCode=1; Output=''; Error='fixture remote source lease rejected'} }
                if (-not $script:remoteState.OmitUnchangedLeaseChecks -and ($script:remoteState.Target -cne $script:remoteFixture.Landed -or $script:remoteState.Tag -ne 'matching')) {
                    return [pscustomobject]@{ExitCode=1; Output=''; Error='fixture atomic target/tag lease rejected'}
                }
                $script:remoteState.Source=$null
            } else {
                if ($script:remoteState.FailPush) { return [pscustomobject]@{ExitCode=1; Output=''; Error='fixture archive tag creation lease rejected'} }
                $script:remoteState.Tag='matching'
                $script:remoteState.TagObject=($Arguments[-1] -split ':',2)[0]
            }
            return [pscustomobject]@{ExitCode=0; Output='fixture mocked remote mutation'; Error=''}
        }
        & $script:closeoutGitImplementation $RepoRoot $Arguments $EnvironmentOverrides
    }
}

function Invoke-CloseoutRemoteFixtureApply {
    param($Fixture,[switch]$SkipTagPush)
    $parameters=$Fixture.PreviewParameters.Clone()
    $parameters.Apply=$true; $parameters.AuthorizeLocalCleanup=$true; $parameters.RemoveWorktrees=$true; $parameters.DeleteLocalBranch=$true
    $parameters.AuthorizeRemoteChanges=$true; $parameters.Remote='origin'; $parameters.DeleteRemoteBranch=$true
    if (-not $SkipTagPush) { $parameters.PushArchiveTag=$true }
    return Invoke-WorkflowCloseout @parameters
}

Describe 'Offline closeout proof and guarded local cleanup' {
    BeforeEach {
        $script:fixture=$null
        # Pester 3 mocks survive examples; restore production behavior each time.
        Mock Invoke-WorkflowCloseoutGit {
            if ($Arguments -contains 'ls-remote' -or $Arguments -contains 'push') { throw 'Fixture network command was not explicitly mocked; no actual query/push is permitted.' }
            & $script:closeoutGitImplementation $RepoRoot $Arguments $EnvironmentOverrides
        }
        Mock Get-WorkflowCloseoutWorktrees { & $script:closeoutWorktreeImplementation $RepoRoot }
        Mock Start-WorkflowCloseoutProofLock { & $script:closeoutProofLockImplementation $RepoRoot $Preview }
    }
    AfterEach { Remove-WorkflowFixture $script:fixture }

    It 'previews exact squash proof without changing refs, files or target head' {
        $script:fixture=New-CloseoutFixture -Squash
        $refs=[string](Invoke-FixtureGit $fixture @('show-ref'))
        $status=[string](Invoke-FixtureGit $fixture @('status','--porcelain','--ignored'))
        $deliveryAdmin=& $script:closeoutGitImplementation $fixture.DeliveryPath @('rev-parse','--absolute-git-dir')
        $indexPath=Join-Path $deliveryAdmin.Output.Trim() 'index'
        $indexBytes=[Convert]::ToBase64String([IO.File]::ReadAllBytes($indexPath))
        $parameters=$fixture.PreviewParameters
        $preview=Get-WorkflowCloseoutPreview @parameters
        $preview.proofMethod | Should Be 'changed-path equality'
        $preview.version | Should Be 1
        $preview.targetBranch | Should Be master
        $preview.worktrees[0].eligible | Should Be $true
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($indexPath)) | Should Be $indexBytes
        [string](Invoke-FixtureGit $fixture @('show-ref')) | Should Be $refs
        [string](Invoke-FixtureGit $fixture @('status','--porcelain','--ignored')) | Should Be $status
        [string](Invoke-FixtureGit $fixture @('rev-parse','master')) | Should Be $fixture.Landed
        $preview.networkActionsEnabled | Should Be $false
    }

    It 'archives ancestry proof before cleanup, deletes locally and safely retries after branch removal' {
        $script:fixture=New-CloseoutFixture
        $head=$fixture.Landed
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be complete
        Test-Path -LiteralPath $fixture.DeliveryPath | Should Be $false
        $report.branch.exists | Should Be $false
        [string](Invoke-FixtureGit $fixture @('cat-file','-t','refs/tags/archive/001-example')) | Should Be tag
        [string](Invoke-FixtureGit $fixture @('rev-parse','archive/001-example^{commit}')) | Should Be $fixture.Accepted
        [string](Invoke-FixtureGit $fixture @('rev-parse','master')) | Should Be $head
        (Invoke-CloseoutFixtureApply $fixture).status | Should Be complete
    }

    It 'archives squash equality including delete, rename and executable mode before branch deletion' {
        $script:fixture=New-CloseoutFixture -Squash
        $null=Invoke-FixtureGit $fixture @('config','branch.feat/001-example.remote','origin')
        $null=Invoke-FixtureGit $fixture @('config','branch.feat/001-example.merge','refs/heads/feat/001-example')
        $systemConfig=[Environment]::GetEnvironmentVariable('GIT_CONFIG_SYSTEM','Process')
        $script:temporaryBranchConfig=$null
        Mock Invoke-WorkflowCloseoutGit {
            if ($Arguments -contains 'branch' -and $Arguments -contains '-d') { $script:temporaryBranchConfig=$EnvironmentOverrides.GIT_CONFIG_SYSTEM }
            & $script:closeoutGitImplementation $RepoRoot $Arguments $EnvironmentOverrides
        }
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be complete
        Test-Path -LiteralPath $script:temporaryBranchConfig | Should Be $false
        [Environment]::GetEnvironmentVariable('GIT_CONFIG_SYSTEM','Process') | Should Be $systemConfig
        $body=[string](Invoke-FixtureGit $fixture @('for-each-ref','--format=%(contents)','refs/tags/archive/001-example'))
        ($body | ConvertFrom-Json).proofMethod | Should Be 'changed-path equality'
    }

    It 'compares Unicode wildcard-like filenames as exact literal NUL-separated paths' {
        $script:fixture=New-CloseoutFixture -Squash
        $parameters=$fixture.PreviewParameters
        (Get-WorkflowCloseoutPreview @parameters).proofMethod | Should Be 'changed-path equality'
        Write-FixtureFile $fixture 'résumé [notes] λ.txt' 'changed Unicode bytes'
        Save-FixtureRevision $fixture
        $fixture.PreviewParameters.LandedRevision=[string](Invoke-FixtureGit $fixture @('rev-parse','HEAD'))
        (Invoke-CloseoutFixtureApply $fixture).status | Should Be incomplete
        Test-Path -LiteralPath $fixture.DeliveryPath | Should Be $true
    }

    It 'returns incomplete when exact Git filename evidence cannot be decoded as strict UTF8' {
        # Windows cannot create byte-invalid UTF-8 names. Simulate the strict
        # decoder failure at Git's changed-path boundary; never infer equality.
        $script:fixture=New-CloseoutFixture -Squash
        Mock Invoke-WorkflowCloseoutGit {
            if ($Arguments -contains 'diff' -and $Arguments -contains '--name-only') { throw 'closeout-git: strict UTF-8 decoding failed; filename/ref evidence is unknown and cleanup is retained.' }
            & $script:closeoutGitImplementation $RepoRoot $Arguments $EnvironmentOverrides
        }
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        $report.reasons -join ';' | Should Match 'UTF-8 decoding failed'
        $report.archiveTag.state | Should Be absent
        Test-Path -LiteralPath $fixture.DeliveryPath | Should Be $true
    }

    It 'retains divergent additions, deletion sides, rename sides and mode-only changes without owner confirmation' {
        foreach ($kind in @('addition','deletion','rename-old','rename-new','mode')) {
            $script:fixture=New-CloseoutFixture -Squash
            if ($kind -eq 'addition') { Write-FixtureFile $fixture 'added.txt' 'divergence' }
            elseif ($kind -eq 'deletion') { Write-FixtureFile $fixture 'deleted.txt' 'resurrected' }
            elseif ($kind -eq 'rename-old') { Write-FixtureFile $fixture 'old-name.txt' 'resurrected' }
            elseif ($kind -eq 'rename-new') { Write-FixtureFile $fixture 'new-name.txt' 'different' }
            $null=Invoke-FixtureGit $fixture @('add','--all')
            if ($kind -eq 'mode') { $null=Invoke-FixtureGit $fixture @('update-index','--chmod=-x','mode.txt') }
            $null=Invoke-FixtureGit $fixture @('commit','--quiet','-m','Divergent landing')
            $fixture.PreviewParameters.LandedRevision=[string](Invoke-FixtureGit $fixture @('rev-parse','HEAD'))
            $report=Invoke-CloseoutFixtureApply $fixture
            $report.status | Should Be incomplete
            $report.proofMethod | Should Be unknown
            Test-Path -LiteralPath $fixture.DeliveryPath | Should Be $true
            $report.archiveTag.state | Should Be absent
            Remove-WorkflowFixture $fixture; $script:fixture=$null
        }
    }

    It 'records exact owner confirmation durably and reuses it on retry without another confirmation switch' {
        $script:fixture=New-CloseoutFixture -Squash
        Write-FixtureFile $fixture 'added.txt' 'owner accepted divergence'
        Save-FixtureRevision $fixture
        $fixture.PreviewParameters.LandedRevision=[string](Invoke-FixtureGit $fixture @('rev-parse','HEAD'))
        $report=Invoke-CloseoutFixtureApply $fixture -OwnerConfirmed -WorktreesOnly
        $report.status | Should Be incomplete
        $report.localStatus | Should Be complete
        $report.archiveTag.proofMethod | Should Be 'owner confirmation'
        $retry=Invoke-CloseoutFixtureApply $fixture
        $retry.status | Should Be complete
        $retry.proofMethod | Should Be 'owner confirmation'
    }

    It 'requires apply, owner authorization and selected cleanup actions independently' {
        $script:fixture=New-CloseoutFixture
        $parameters=$fixture.PreviewParameters.Clone()
        $parameters.RemoveWorktrees=$true; $parameters.DeleteLocalBranch=$true
        (Invoke-WorkflowCloseout @parameters).archiveTag.state | Should Be absent
        $parameters.Apply=$true
        (Invoke-WorkflowCloseout @parameters).status | Should Be incomplete
        $parameters.Remove('RemoveWorktrees'); $parameters.Remove('DeleteLocalBranch'); $parameters.AuthorizeLocalCleanup=$true
        (Invoke-WorkflowCloseout @parameters).status | Should Be incomplete
        Test-Path -LiteralPath $fixture.DeliveryPath | Should Be $true
    }

    It 'retains missing commits, missing source without archive proof and stale target evidence' {
        $script:fixture=New-CloseoutFixture -NoWorktree
        $parameters=$fixture.PreviewParameters.Clone(); $parameters.AcceptedRevision='missing-commit'
        (Get-WorkflowCloseoutPreview @parameters).status | Should Be incomplete
        Write-FixtureFile $fixture 'target-bookkeeping.txt' 'later'
        Save-FixtureRevision $fixture
        $parameters=$fixture.PreviewParameters
        (Get-WorkflowCloseoutPreview @parameters).reasons -join ';' | Should Match 'current configured target'
        $fixture.PreviewParameters.LandedRevision=[string](Invoke-FixtureGit $fixture @('rev-parse','HEAD'))
        $null=Invoke-FixtureGit $fixture @('branch','-D','feat/001-example')
        (Get-WorkflowCloseoutPreview @parameters).reasons -join ';' | Should Match 'source branch missing'
    }

    It 'rejects a wrong squash base instead of proving a narrower changed path subset' {
        $script:fixture=New-CloseoutFixture -Squash
        $parameters=$fixture.PreviewParameters.Clone(); $parameters.BaseRevision=$fixture.Accepted
        $report=Get-WorkflowCloseoutPreview @parameters
        $report.status | Should Be incomplete
        $report.reasons -join ';' | Should Match 'base'
    }

    It 'requires the final delivered and archived record on both accepted source and landing' {
        $script:fixture=New-CloseoutFixture -Squash
        $text=Join-Path $fixture.RepoRoot 'specs/001-example/spec.md'
        [IO.File]::WriteAllText($text,[IO.File]::ReadAllText($text).Replace('**Lifecycle**: delivered','**Lifecycle**: active'))
        Save-FixtureRevision $fixture
        $fixture.PreviewParameters.LandedRevision=[string](Invoke-FixtureGit $fixture @('rev-parse','HEAD'))
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        $report.reasons -join ';' | Should Match 'delivered'
        Test-Path -LiteralPath $fixture.DeliveryPath | Should Be $true
    }

    It 'protects tracked dirt, untracked reviews and ignored user evidence without staging or discarding it' {
        $script:fixture=New-CloseoutFixture
        $path=Join-Path $fixture.DeliveryPath 'added.txt'
        [IO.File]::WriteAllText($path,'local edits')
        [IO.File]::WriteAllText((Join-Path $fixture.DeliveryPath 'specs/001-example/reviews/untracked.md'),'unsaved review')
        [IO.File]::WriteAllText((Join-Path $fixture.DeliveryPath '.gitignore'),"private.txt`n")
        [IO.File]::WriteAllText((Join-Path $fixture.DeliveryPath 'private.txt'),'private evidence')
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        $report.worktrees[0].eligible | Should Be $false
        [IO.File]::ReadAllText($path) | Should Be 'local edits'
        Test-Path -LiteralPath (Join-Path $fixture.DeliveryPath 'private.txt') | Should Be $true
    }

    It 'retains primary, locked, held and unpublished worktrees' {
        foreach ($kind in @('primary','locked','held','unpublished')) {
            $script:fixture=New-CloseoutFixture -Held:($kind -eq 'held') -NoWorktree:($kind -eq 'primary')
            if ($kind -eq 'primary') { $null=Invoke-FixtureGit $fixture @('switch','--quiet','feat/001-example') }
            elseif ($kind -eq 'locked') { $null=Invoke-FixtureGit $fixture @('worktree','lock',$fixture.DeliveryPath) }
            elseif ($kind -eq 'unpublished') {
                $result=& $script:closeoutGitImplementation $fixture.DeliveryPath @('commit','--quiet','--allow-empty','-m','Unpublished work')
                $result.ExitCode | Should Be 0
            }
            $report=Invoke-CloseoutFixtureApply $fixture
            $report.status | Should Be incomplete
            $report.worktrees[0].eligible | Should Be $false
            $report.branch.exists | Should Be $true
            Remove-WorkflowFixture $fixture; $script:fixture=$null
        }
    }

    It 'blocks conflicting and lightweight archive tags without rewriting them' {
        foreach ($kind in @('lightweight','wrong-head','wrong-message')) {
            $script:fixture=New-CloseoutFixture
            if ($kind -eq 'lightweight') { $null=Invoke-FixtureGit $fixture @('tag','archive/001-example',$fixture.Accepted) }
            else {
                $head=if ($kind -eq 'wrong-head') {$fixture.Base} else {$fixture.Accepted}
                $null=Invoke-FixtureGit $fixture @('tag','-a','archive/001-example',$head,'-m','unrelated tag')
            }
            $before=[string](Invoke-FixtureGit $fixture @('rev-parse','refs/tags/archive/001-example'))
            $report=Invoke-CloseoutFixtureApply $fixture
            $report.status | Should Be incomplete
            $report.archiveTag.state | Should Be conflicting
            [string](Invoke-FixtureGit $fixture @('rev-parse','refs/tags/archive/001-example')) | Should Be $before
            Test-Path -LiteralPath $fixture.DeliveryPath | Should Be $true
            Remove-WorkflowFixture $fixture; $script:fixture=$null
        }
    }

    It 'revalidates newly dirty content immediately before removal and retries preserved archive proof' {
        $script:fixture=New-CloseoutFixture
        Mock Invoke-WorkflowCloseoutGit {
            $result=& $script:closeoutGitImplementation $RepoRoot $Arguments $EnvironmentOverrides
            if ($Arguments -contains 'tag' -and $Arguments -contains '-a') { [IO.File]::WriteAllText((Join-Path $script:fixture.DeliveryPath 'late-evidence.txt'),'arrived after preview') }
            return $result
        }
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        $report.archiveTag.state | Should Be matching
        Test-Path -LiteralPath (Join-Path $fixture.DeliveryPath 'late-evidence.txt') | Should Be $true
        $report.branch.exists | Should Be $true
    }

    It 'reports ordinary removal refusal with no force, recursive fallback or network call' {
        $script:fixture=New-CloseoutFixture
        $script:mutationArguments=@()
        Mock Invoke-WorkflowCloseoutGit {
            $script:mutationArguments+=,($Arguments -join ' ')
            if ($Arguments.Count -ge 2 -and $Arguments[0] -eq 'worktree' -and $Arguments[1] -eq 'remove') { return [pscustomobject]@{ExitCode=1; Output=''; Error='fixture ordinary removal denied'} }
            & $script:closeoutGitImplementation $RepoRoot $Arguments $EnvironmentOverrides
        }
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        $report.results[1].reason | Should Match 'ordinary removal denied'
        Test-Path -LiteralPath $fixture.DeliveryPath | Should Be $true
        $script:mutationArguments -join ';' | Should Not Match '(--force|fetch|push|remote delete)'
    }

    It 'revalidates the configured target ref after archiving and retains source when landing changes' {
        $script:fixture=New-CloseoutFixture
        Mock Invoke-WorkflowCloseoutGit {
            $result=& $script:closeoutGitImplementation $RepoRoot $Arguments $EnvironmentOverrides
            if ($Arguments -contains 'tag' -and $Arguments -contains '-a') {
                Write-FixtureFile $script:fixture 'late-target.txt' 'target advanced after preview'
                Save-FixtureRevision $script:fixture
            }
            return $result
        }
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        $report.reasons -join ';' | Should Match 'current configured target'
        Test-Path -LiteralPath $fixture.DeliveryPath | Should Be $true
        [string](Invoke-FixtureGit $fixture @('rev-parse','feat/001-example')) | Should Be $fixture.Accepted
    }

    It 'resumes after removal succeeded and branch deletion was interrupted' {
        $script:fixture=New-CloseoutFixture -Squash
        Mock Invoke-WorkflowCloseoutGit {
            if ($Arguments -contains 'branch' -and $Arguments -contains '-d') { return [pscustomobject]@{ExitCode=1; Output=''; Error='fixture interrupted branch deletion'} }
            & $script:closeoutGitImplementation $RepoRoot $Arguments $EnvironmentOverrides
        }
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        Test-Path -LiteralPath $fixture.DeliveryPath | Should Be $false
        $report.branch.exists | Should Be $true
        Mock Invoke-WorkflowCloseoutGit { & $script:closeoutGitImplementation $RepoRoot $Arguments $EnvironmentOverrides }
        (Invoke-CloseoutFixtureApply $fixture).status | Should Be complete
    }

    It 'lets Git reject a newly checked-out branch at the deletion boundary' {
        $script:fixture=New-CloseoutFixture -Squash
        $script:racePath=Join-Path $fixture.TempRoot 'late-checkout'
        Mock Invoke-WorkflowCloseoutGit {
            if ($Arguments -contains 'branch' -and $Arguments -contains '-d') {
                $null=Invoke-FixtureGit $script:fixture @('worktree','add','--quiet',$script:racePath,'feat/001-example')
            }
            & $script:closeoutGitImplementation $RepoRoot $Arguments $EnvironmentOverrides
        }
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        $report.branch.exists | Should Be $true
        Test-Path -LiteralPath $script:racePath | Should Be $true
        $report.results[-1].reason | Should Match 'checked out|used by worktree'
    }

    It 'lets Git reject a newly unpublished commit without persistent upstream config changes' {
        $script:fixture=New-CloseoutFixture -Squash
        $null=Invoke-FixtureGit $fixture @('config','branch.feat/001-example.remote','origin')
        $null=Invoke-FixtureGit $fixture @('config','branch.feat/001-example.merge','refs/heads/feat/001-example')
        $script:raceCommit=$null
        Mock Invoke-WorkflowCloseoutGit {
            if ($Arguments -contains 'branch' -and $Arguments -contains '-d') {
                $newCommit=& $script:closeoutGitImplementation $RepoRoot @('commit-tree',"$($script:fixture.Accepted)^{tree}",'-p',$script:fixture.Accepted,'-m','Racing unpublished commit')
                $script:raceCommit=$newCommit.Output.Trim()
                $null=Invoke-FixtureGit $script:fixture @('update-ref','refs/heads/feat/001-example',$script:raceCommit)
            }
            & $script:closeoutGitImplementation $RepoRoot $Arguments $EnvironmentOverrides
        }
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        $report.branch.exists | Should Be $true
        [string](Invoke-FixtureGit $fixture @('rev-parse','feat/001-example')) | Should Be $script:raceCommit
        $config=& $script:closeoutGitImplementation $fixture.RepoRoot @('config','--get','branch.feat/001-example.merge')
        $config.ExitCode | Should Be 0
        $config.Output.Trim() | Should Be 'refs/heads/feat/001-example'
    }

    It 'rejects an ancestor source tip changed under the native ref transaction lock' {
        $script:fixture=New-CloseoutFixture -Squash
        Mock Invoke-WorkflowCloseoutGit {
            if ($Arguments -contains 'branch' -and $Arguments -contains '-d') { $null=Invoke-FixtureGit $script:fixture @('update-ref','refs/heads/feat/001-example',$script:fixture.Base) }
            & $script:closeoutGitImplementation $RepoRoot $Arguments $EnvironmentOverrides
        }
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        [string](Invoke-FixtureGit $fixture @('rev-parse','feat/001-example')) | Should Be $fixture.Base
        $report.results[-1].reason | Should Match 'exact accepted source tip changed under the ref lock'
        [string](Invoke-FixtureGit $fixture @('rev-parse','archive/001-example^{commit}')) | Should Be $fixture.Accepted
    }

    It 'retains source branches when reference transaction hook support is old or unknown' {
        foreach ($version in @('git version 2.28.0','unknown Git version')) {
            $script:fixture=New-CloseoutFixture -Squash
            $script:unsupportedVersion=$version
            Mock Invoke-WorkflowCloseoutGit {
                if ($Arguments[0] -eq 'version') { return [pscustomobject]@{ExitCode=0; Output=$script:unsupportedVersion; Error=''} }
                & $script:closeoutGitImplementation $RepoRoot $Arguments $EnvironmentOverrides
            }
            $report=Invoke-CloseoutFixtureApply $fixture
            $report.status | Should Be incomplete
            $report.branch.exists | Should Be $true
            $report.results[-1].reason | Should Match 'version 2.29 or newer'
            Remove-WorkflowFixture $fixture; $script:fixture=$null
        }
    }

    It 'holds annotated archive and landed target proof stable while native source deletion runs' {
        foreach ($kind in @('tag','target')) {
            $script:fixture=New-CloseoutFixture -Squash
            $script:proofRaceKind=$kind; $script:proofRaceResult=$null
            Mock Invoke-WorkflowCloseoutGit {
                if ($Arguments -contains 'branch' -and $Arguments -contains '-d') {
                    $ref=if ($script:proofRaceKind -eq 'tag') {'refs/tags/archive/001-example'} else {'refs/heads/master'}
                    $script:proofRaceResult=& $script:closeoutGitImplementation $RepoRoot @('update-ref',$ref,$script:fixture.Base)
                }
                & $script:closeoutGitImplementation $RepoRoot $Arguments $EnvironmentOverrides
            }
            $report=Invoke-CloseoutFixtureApply $fixture
            $report.status | Should Be complete
            $script:proofRaceResult.ExitCode | Should Not Be 0
            $script:proofRaceResult.Error | Should Match 'cannot lock ref|unable to create'
            [string](Invoke-FixtureGit $fixture @('rev-parse','master')) | Should Be $fixture.Landed
            $report.archiveTag.state | Should Be matching
            [string](Invoke-FixtureGit $fixture @('rev-parse','archive/001-example^{commit}')) | Should Be $fixture.Accepted
            Remove-WorkflowFixture $fixture; $script:fixture=$null
        }
    }

    It 'retains the source branch when verify-only prepared proof locking is unsupported' {
        $script:fixture=New-CloseoutFixture -Squash
        Mock Start-WorkflowCloseoutProofLock { throw 'fixture verify-only transaction cannot prepare' }
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        $report.branch.exists | Should Be $true
        $report.results[-1].reason | Should Match 'cannot prepare'
        $report.archiveTag.state | Should Be matching
    }

    It 'composes the owner reference hook and honors its prepared rejection without installing persistent hooks' {
        foreach ($reject in @($false,$true)) {
            $script:fixture=New-CloseoutFixture -Squash
            $hooks=Join-Path $fixture.TempRoot 'no-hooks'
            $null=New-Item -ItemType Directory -Path $hooks -Force
            $hookPath=Join-Path $hooks 'reference-transaction'
            $marker=Join-Path $fixture.TempRoot 'owner-reference-hook.log'
            $hook=@'
#!/bin/sh
records=$(cat)
printf '%s\n%s\n' "$1" "$records" >> __MARKER__
if [ "$1" = prepared ] && [ __REJECT__ = yes ]; then
    case "$records" in *refs/heads/feat/001-example*) exit 1 ;; esac
fi
exit 0
'@
            $shellMarker="'"+$marker.Replace('\','/').Replace("'","'\''")+"'"
            $hook=$hook.Replace('__MARKER__',$shellMarker).Replace('__REJECT__',$(if ($reject) {'yes'} else {'no'}))
            [IO.File]::WriteAllText($hookPath,($hook -replace "`r`n","`n")+"`n",[Text.UTF8Encoding]::new($false))
            if (-not $IsWindows) { [IO.File]::SetUnixFileMode($hookPath,([IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite -bor [IO.UnixFileMode]::UserExecute)) }
            $before=[IO.File]::ReadAllText($hookPath)
            $report=Invoke-CloseoutFixtureApply $fixture
            $report.status | Should Be $(if ($reject) {'incomplete'} else {'complete'})
            $report.branch.exists | Should Be $reject
            [IO.File]::ReadAllText($marker) | Should Match 'refs/heads/feat/001-example'
            [IO.File]::ReadAllText($hookPath) | Should Be $before
            [string](Invoke-FixtureGit $fixture @('config','--get','core.hooksPath')) | Should Be $hooks
            Remove-WorkflowFixture $fixture; $script:fixture=$null
        }
    }

    It 'cleans an eligible worktree while retaining an independent locked candidate' {
        $script:fixture=New-CloseoutFixture
        $heldPath=Join-Path $fixture.TempRoot 'delivery-held'
        $null=Invoke-FixtureGit $fixture @('worktree','add','--quiet','--force',$heldPath,'feat/001-example')
        $null=Invoke-FixtureGit $fixture @('worktree','lock',$heldPath)
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        Test-Path -LiteralPath $fixture.DeliveryPath | Should Be $false
        Test-Path -LiteralPath $heldPath | Should Be $true
        $report.branch.exists | Should Be $true
    }

    It 'rejects a prefix-lookalike directory that Git no longer owns as the expected worktree root' {
        $script:fixture=New-CloseoutFixture
        $lookalike=$fixture.DeliveryPath+'-lookalike'
        $null=New-Item -ItemType Directory -Path $lookalike
        [IO.File]::WriteAllText((Join-Path $lookalike 'evidence.txt'),'unrelated user bytes')
        $script:lookalike=$lookalike
        Mock Get-WorkflowCloseoutWorktrees {
            @([pscustomobject]@{Path=$script:fixture.RepoRoot;Head=$script:fixture.Landed;Branch='master';Locked=$false;Prunable=$false},
                [pscustomobject]@{Path=$script:lookalike;Head=$script:fixture.Accepted;Branch='feat/001-example';Locked=$false;Prunable=$false})
        }
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        $report.worktrees[0].reasons -join ';' | Should Match 'ownership is unresolved'
        [IO.File]::ReadAllText((Join-Path $lookalike 'evidence.txt')) | Should Be 'unrelated user bytes'
    }

    It 'reports retained cached remote refs while completing authorized local cleanup offline' {
        $script:fixture=New-CloseoutFixture
        $null=Invoke-FixtureGit $fixture @('remote','add','origin','https://example.invalid/offline-fixture.git')
        $null=Invoke-FixtureGit $fixture @('update-ref','refs/remotes/origin/feat/001-example',$fixture.Accepted)
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.localStatus | Should Be complete
        $report.status | Should Be incomplete
        $report.remoteBranches.Count | Should Be 1
        $report.remoteBranches[0].status | Should Be retained
        [string](Invoke-FixtureGit $fixture @('rev-parse','refs/remotes/origin/feat/001-example')) | Should Be $fixture.Accepted
    }

    It 'does not fabricate a remote owner from a suffix-lookalike cached branch ref' {
        $script:fixture=New-CloseoutFixture
        $null=Invoke-FixtureGit $fixture @('remote','add','origin','https://example.invalid/offline-fixture.git')
        $null=Invoke-FixtureGit $fixture @('update-ref','refs/remotes/origin/older/feat/001-example',$fixture.Accepted)
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.localStatus | Should Be complete
        $report.status | Should Be incomplete
        $report.remoteBranches.Count | Should Be 0
        $report.unknownRemotes[0] | Should Be origin
        [string](Invoke-FixtureGit $fixture @('rev-parse','refs/remotes/origin/older/feat/001-example')) | Should Be $fixture.Accepted
    }

    It 'isolates inherited Git hook locations and restores the exact environment after preview' {
        $script:fixture=New-CloseoutFixture
        $oldDir=[Environment]::GetEnvironmentVariable('GIT_DIR','Process')
        $oldIndex=[Environment]::GetEnvironmentVariable('GIT_INDEX_FILE','Process')
        try {
            [Environment]::SetEnvironmentVariable('GIT_DIR',(Join-Path $fixture.TempRoot 'foreign-git-dir'),'Process')
            [Environment]::SetEnvironmentVariable('GIT_INDEX_FILE',(Join-Path $fixture.TempRoot 'foreign-index'),'Process')
            $parameters=$fixture.PreviewParameters
            (Get-WorkflowCloseoutPreview @parameters).proofMethod | Should Be ancestry
            [Environment]::GetEnvironmentVariable('GIT_DIR','Process') | Should Be (Join-Path $fixture.TempRoot 'foreign-git-dir')
            [Environment]::GetEnvironmentVariable('GIT_INDEX_FILE','Process') | Should Be (Join-Path $fixture.TempRoot 'foreign-index')
        } finally {
            [Environment]::SetEnvironmentVariable('GIT_DIR',$(if ($null -eq $oldDir) {[NullString]::Value} else {$oldDir}),'Process')
            [Environment]::SetEnvironmentVariable('GIT_INDEX_FILE',$(if ($null -eq $oldIndex) {[NullString]::Value} else {$oldIndex}),'Process')
        }
    }

    It 'performs zero network calls for preview or unauthorized selected remote flags' {
        $script:fixture=New-CloseoutFixture
        Enable-CloseoutRemoteMock $fixture
        $parameters=$fixture.PreviewParameters.Clone(); $parameters.Remote='origin'; $parameters.PushArchiveTag=$true; $parameters.DeleteRemoteBranch=$true; $parameters.AuthorizeRemoteChanges=$true
        (Invoke-WorkflowCloseout @parameters).networkActionsEnabled | Should Be $false
        $parameters.Apply=$true; $parameters.AuthorizeRemoteChanges=$false
        (Invoke-WorkflowCloseout @parameters).status | Should Be incomplete
        $script:networkCalls.Count | Should Be 0
        $parameters=$fixture.PreviewParameters
        (Get-WorkflowCloseoutPreview @parameters).archiveTag.state | Should Be absent
    }

    It 'uses narrow remote leases and preserved annotated proof with idempotent mocked reconciliation' {
        $script:fixture=New-CloseoutFixture -Squash
        Enable-CloseoutRemoteMock $fixture
        $report=Invoke-CloseoutRemoteFixtureApply $fixture
        $report.status | Should Be complete
        $report.localStatus | Should Be complete
        $report.remoteStatus | Should Be complete
        $script:remoteState.Source | Should BeNullOrEmpty
        $script:remoteState.Tag | Should Be matching
        $script:networkCalls -join ';' | Should Match '--force-with-lease=refs/tags/archive/001-example:'
        $script:networkCalls -join ';' | Should Match ('--force-with-lease=refs/heads/feat/001-example:'+ $fixture.Accepted)
        $script:networkCalls -join ';' | Should Match ('--force-with-lease=refs/heads/master:'+ $fixture.Landed)
        $script:networkCalls -join ';' | Should Match '--atomic'
        $pushCount=@($script:networkCalls | Where-Object { $_ -match '^push ' }).Count
        (Invoke-CloseoutRemoteFixtureApply $fixture).status | Should Be complete
        @($script:networkCalls | Where-Object { $_ -match '^push ' }).Count | Should Be $pushCount
    }

    It 'retains unknown, missing and stale remote evidence while completing independent local cleanup' {
        foreach ($kind in @('unavailable','missing-target','changed-target','changed-source','conflicting-tag','missing-source')) {
            $script:fixture=New-CloseoutFixture
            Enable-CloseoutRemoteMock $fixture
            switch ($kind) {
                'unavailable' {$script:remoteState.FailQuery=$true}
                'missing-target' {$script:remoteState.Target=$null}
                'changed-target' {$script:remoteState.Target=$fixture.Base}
                'changed-source' {$script:remoteState.Source=$fixture.Base}
                'conflicting-tag' {$script:remoteState.Tag='conflicting'}
                'missing-source' {$script:remoteState.Source=$null}
            }
            $report=Invoke-CloseoutRemoteFixtureApply $fixture
            $report.status | Should Be incomplete
            $report.localStatus | Should Be complete
            $report.remoteStatus | Should Be incomplete
            @($script:networkCalls | Where-Object { $_ -match '^push ' }).Count | Should Be 0
            Remove-WorkflowFixture $fixture; $script:fixture=$null
        }
    }

    It 'rechecks remote target, source and tag before remote source deletion' {
        foreach ($kind in @('target','source','tag')) {
            $script:fixture=New-CloseoutFixture
            Enable-CloseoutRemoteMock $fixture
            $script:remoteState.ChangeAfterTag=$kind
            $report=Invoke-CloseoutRemoteFixtureApply $fixture
            $report.status | Should Be incomplete
            $report.localStatus | Should Be complete
            $report.remoteStatus | Should Be incomplete
            @($script:networkCalls | Where-Object { $_ -match ':refs/heads/feat/001-example$' }).Count | Should Be 0
            $script:remoteState.Source | Should Not BeNullOrEmpty
            Remove-WorkflowFixture $fixture; $script:fixture=$null
        }
    }

    It 'retains remote branches after either narrow lease rejects and safely retries' {
        foreach ($kind in @('tag','branch')) {
            $script:fixture=New-CloseoutFixture
            Enable-CloseoutRemoteMock $fixture
            if ($kind -eq 'tag') {$script:remoteState.FailPush=$true} else {$script:remoteState.FailDelete=$true}
            $report=Invoke-CloseoutRemoteFixtureApply $fixture
            $report.status | Should Be incomplete
            $script:remoteState.Source | Should Be $fixture.Accepted
            $script:remoteState.FailPush=$false; $script:remoteState.FailDelete=$false
            (Invoke-CloseoutRemoteFixtureApply $fixture).status | Should Be complete
            Remove-WorkflowFixture $fixture; $script:fixture=$null
        }
    }

    It 'requires remote annotated proof before selected remote deletion when archive push is not selected' {
        $script:fixture=New-CloseoutFixture
        Enable-CloseoutRemoteMock $fixture
        $report=Invoke-CloseoutRemoteFixtureApply $fixture -SkipTagPush
        $report.status | Should Be incomplete
        $report.remoteStatus | Should Be incomplete
        $script:remoteState.Source | Should Be $fixture.Accepted
        @($script:networkCalls | Where-Object { $_ -match '^push ' }).Count | Should Be 0
    }

    It 'validates the exact immutable annotation captured at the remote boundary before any push' {
        $script:fixture=New-CloseoutFixture
        Enable-CloseoutRemoteMock $fixture
        $script:remoteState.MoveLocalTagAtCapture=$true
        $parameters=$fixture.PreviewParameters.Clone(); $parameters.Apply=$true; $parameters.AuthorizeRemoteChanges=$true; $parameters.Remote='origin'; $parameters.PushArchiveTag=$true
        $report=Invoke-WorkflowCloseout @parameters
        $report.status | Should Be incomplete
        $report.results[-1].reason | Should Match 'annotation conflicts|archive'
        $script:remoteState.Source | Should Be $fixture.Accepted
        @($script:networkCalls | Where-Object { $_ -match '^push ' }).Count | Should Be 0
        [string](Invoke-FixtureGit $fixture @('rev-parse','feat/001-example')) | Should Be $fixture.Accepted
    }

    It 'retains the remote source when target or archive tag changes at the atomic push boundary' {
        foreach ($kind in @('target','tag')) {
            $script:fixture=New-CloseoutFixture
            Enable-CloseoutRemoteMock $fixture
            $script:remoteState.ChangeAtDelete=$kind
            $report=Invoke-CloseoutRemoteFixtureApply $fixture
            $report.status | Should Be incomplete
            $script:remoteState.Source | Should Be $fixture.Accepted
            $report.results[-1].reason | Should Match 'atomic target/tag lease rejected'
            $report.archiveTag.state | Should Be matching
            Remove-WorkflowFixture $fixture; $script:fixture=$null
        }
    }

    It 'reports deletion succeeded with changed proof as incomplete when a server omits unchanged ref lease checks' {
        foreach ($kind in @('target','tag')) {
            $script:fixture=New-CloseoutFixture
            Enable-CloseoutRemoteMock $fixture
            $script:remoteState.ChangeAtDelete=$kind; $script:remoteState.OmitUnchangedLeaseChecks=$true
            $report=Invoke-CloseoutRemoteFixtureApply $fixture
            $report.status | Should Be incomplete
            $report.remoteStatus | Should Be incomplete
            $script:remoteState.Source | Should BeNullOrEmpty
            $report.results[-1].reason | Should Match 'deletion succeeded but proof changed; local archive retained; owner reconciliation required'
            $report.archiveTag.state | Should Be matching
            [string](Invoke-FixtureGit $fixture @('rev-parse','archive/001-example^{commit}')) | Should Be $fixture.Accepted
            $report.remoteIsolation | Should Match 'owner/provider cooperation'
            Remove-WorkflowFixture $fixture; $script:fixture=$null
        }
    }
}

Describe 'Closeout retained detached and scratch inventory' {
    BeforeEach {
        $script:fixture=$null
        Mock Invoke-WorkflowCloseoutGit {
            if ($Arguments -contains 'ls-remote' -or $Arguments -contains 'push') { throw 'No network call is allowed in this fixture.' }
            & $script:closeoutGitImplementation $RepoRoot $Arguments $EnvironmentOverrides
        }
        Mock Get-WorkflowCloseoutWorktrees { & $script:closeoutWorktreeImplementation $RepoRoot }
        Mock Start-WorkflowCloseoutProofLock { & $script:closeoutProofLockImplementation $RepoRoot $Preview }
    }
    AfterEach { Remove-WorkflowFixture $script:fixture }

    It 'retains detached accepted-head work while independently removing eligible delivery work' {
        $script:fixture=New-CloseoutFixture -Squash
        $detached=Join-Path $fixture.TempRoot 'detached-experiment'
        $null=Invoke-FixtureGit $fixture @('worktree','add','--quiet','--detach',$detached,$fixture.Accepted)
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        Test-Path -LiteralPath $fixture.DeliveryPath | Should Be $false
        Test-Path -LiteralPath $detached | Should Be $true
        $report.branch.exists | Should Be $true
        $report.worktrees.Count | Should Be 1
        $report.worktrees[0].kind | Should Be detached
        $report.worktrees[0].eligible | Should Be $false
        $report.worktrees[0].reasons -join ';' | Should Match 'delivery cleanup permission does not apply'
    }

    It 'reports source-associated scratch from its existing marker without inheriting delivery deletion permission' {
        $script:fixture=New-CloseoutFixture
        $scratch=Join-Path $fixture.TempRoot 'marked-scratch'
        $null=Invoke-FixtureGit $fixture @('worktree','add','--quiet','--detach',$scratch,$fixture.Base)
        $admin=& $script:closeoutGitImplementation $scratch @('rev-parse','--absolute-git-dir')
        $common=& $script:closeoutGitImplementation $fixture.RepoRoot @('rev-parse','--path-format=absolute','--git-common-dir')
        $marker=@{kind='workflow-kit-scratch-v1'; repo=$fixture.RepoRoot; commonGitDir=$common.Output.Trim(); worktree=[IO.Path]::GetFullPath($scratch); base=$fixture.Base; integrationBranch='feat/001-example'} | ConvertTo-Json
        [IO.File]::WriteAllText((Join-Path $admin.Output.Trim() 'workflow-kit-scratch.json'),$marker,[Text.UTF8Encoding]::new($false))
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        Test-Path -LiteralPath $fixture.DeliveryPath | Should Be $false
        Test-Path -LiteralPath $scratch | Should Be $true
        $report.branch.exists | Should Be $true
        $report.worktrees[0].kind | Should Be scratch
        $report.worktrees[0].eligible | Should Be $false
    }

    It 'retains an accepted-head checkout whose association metadata cannot be inspected' {
        $script:fixture=New-CloseoutFixture -Squash
        $script:unknownAssociationPath=Join-Path $fixture.TempRoot 'unknown-association'
        $null=Invoke-FixtureGit $fixture @('worktree','add','--quiet','-b','inspection-failed',$script:unknownAssociationPath,$fixture.Accepted)
        Mock Invoke-WorkflowCloseoutGit {
            if ([IO.Path]::GetFullPath($RepoRoot) -eq [IO.Path]::GetFullPath($script:unknownAssociationPath) -and $Arguments -contains '--absolute-git-dir') {
                return [pscustomobject]@{ExitCode=1; Output=''; Error='fixture administration unavailable'}
            }
            & $script:closeoutGitImplementation $RepoRoot $Arguments $EnvironmentOverrides
        }
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        Test-Path -LiteralPath $fixture.DeliveryPath | Should Be $false
        Test-Path -LiteralPath $script:unknownAssociationPath | Should Be $true
        $report.worktrees[0].kind | Should Be unknown
        $report.worktrees[0].reasons -join ';' | Should Match 'administration is unknown'
    }
}

Describe 'Closeout accepted holds govern remote source deletion' {
    BeforeEach {
        $script:fixture=$null
        Mock Invoke-WorkflowCloseoutGit {
            if ($Arguments -contains 'ls-remote' -or $Arguments -contains 'push') { throw 'Fixture network command was not explicitly mocked; no actual query/push is permitted.' }
            & $script:closeoutGitImplementation $RepoRoot $Arguments $EnvironmentOverrides
        }
        Mock Get-WorkflowCloseoutWorktrees { & $script:closeoutWorktreeImplementation $RepoRoot }
        Mock Start-WorkflowCloseoutProofLock { & $script:closeoutProofLockImplementation $RepoRoot $Preview }
    }
    AfterEach { Remove-WorkflowFixture $script:fixture }

    It 'preserves an authorized remote archive while retaining the held remote source' {
        $script:fixture=New-CloseoutFixture -Held
        Enable-CloseoutRemoteMock $fixture
        $parameters=$fixture.PreviewParameters
        (Get-WorkflowCloseoutPreview @parameters).cleanupHolds[0] | Should Be 'preserve experiment'
        $report=Invoke-CloseoutRemoteFixtureApply $fixture
        $report.status | Should Be incomplete
        $report.remoteStatus | Should Be incomplete
        $script:remoteState.Source | Should Be $fixture.Accepted
        $script:remoteState.Tag | Should Be matching
        @($report.results | Where-Object { $_.action -eq 'push archive tag' -and $_.status -eq 'complete' }).Count | Should Be 1
        @($report.results | Where-Object { $_.action -eq 'delete remote branch' -and $_.status -eq 'retained' -and $_.reason -match 'accepted package cleanup holds' }).Count | Should Be 1
        @($script:networkCalls | Where-Object { $_ -match ':refs/heads/feat/001-example$' }).Count | Should Be 0
        Test-Path -LiteralPath $fixture.DeliveryPath | Should Be $true
        $report.branch.exists | Should Be $true
    }

    It 'keeps accepted holds binding when the working-copy hold declaration is deleted' {
        $script:fixture=New-CloseoutFixture -Held
        $specPath=Join-Path $fixture.DeliveryPath 'specs/001-example/spec.md'
        $withoutHold=[regex]::Replace([IO.File]::ReadAllText($specPath),'(?m)^\*\*Cleanup holds\*\*:[^\r\n]*\r?\n','')
        [IO.File]::WriteAllText($specPath,$withoutHold,[Text.UTF8Encoding]::new($false))
        Enable-CloseoutRemoteMock $fixture
        $parameters=$fixture.PreviewParameters
        (Get-WorkflowCloseoutPreview @parameters).cleanupHolds[0] | Should Be 'preserve experiment'
        $report=Invoke-CloseoutRemoteFixtureApply $fixture
        $report.status | Should Be incomplete
        $script:remoteState.Source | Should Be $fixture.Accepted
        $script:remoteState.Tag | Should Be matching
        @($report.results | Where-Object { $_.action -eq 'delete remote branch' -and $_.status -eq 'retained' }).Count | Should Be 1
        @($script:networkCalls | Where-Object { $_ -match ':refs/heads/feat/001-example$' }).Count | Should Be 0
        [IO.File]::ReadAllText($specPath) | Should Be $withoutHold
    }

    It 'validates ISO annotation dates after day twelve under en-GB without changing the proof tuple' {
        $script:fixture=New-CloseoutFixture -Held
        Enable-CloseoutRemoteMock $fixture
        $script:remoteState.ArchiveDateOverride='2026-10-13T00:08:20.2820305Z'
        $priorCulture=[Threading.Thread]::CurrentThread.CurrentCulture
        try {
            [Threading.Thread]::CurrentThread.CurrentCulture=[Globalization.CultureInfo]::GetCultureInfo('en-GB')
            $report=Invoke-CloseoutRemoteFixtureApply $fixture
            $report.archiveTag.state | Should Be matching
            $script:remoteState.Tag | Should Be matching
            $script:remoteState.Source | Should Be $fixture.Accepted
            $report.status | Should Be incomplete
            $body=[string](Invoke-FixtureGit $fixture @('for-each-ref','--format=%(contents)','refs/tags/archive/001-example'))
            $metadata=$body | ConvertFrom-Json
            $metadata.baseRevision | Should Be $fixture.Base
            $metadata.acceptedRevision | Should Be $fixture.Accepted
            $metadata.landedRevision | Should Be $fixture.Landed
        } finally { [Threading.Thread]::CurrentThread.CurrentCulture=$priorCulture }
    }

    It 'retains conflicting annotations with malformed calendar dates under en-GB' {
        $script:fixture=New-CloseoutFixture -Held
        Enable-CloseoutRemoteMock $fixture
        $script:remoteState.ArchiveDateOverride='2026-02-30T00:08:20.2820305Z'
        $priorCulture=[Threading.Thread]::CurrentThread.CurrentCulture
        try {
            [Threading.Thread]::CurrentThread.CurrentCulture=[Globalization.CultureInfo]::GetCultureInfo('en-GB')
            $report=Invoke-CloseoutRemoteFixtureApply $fixture
            $report.archiveTag.state | Should Be conflicting
            $report.status | Should Be incomplete
            $script:remoteState.Source | Should Be $fixture.Accepted
            $script:remoteState.Tag | Should Be absent
            @($script:networkCalls | Where-Object { $_ -match '^push ' }).Count | Should Be 0
        } finally { [Threading.Thread]::CurrentThread.CurrentCulture=$priorCulture }
    }
}

Describe 'Closeout literal ref ownership and prepared deletion guards' {
    BeforeEach {
        $script:fixture=$null
        Mock Invoke-WorkflowCloseoutGit {
            if ($Arguments -contains 'ls-remote' -or $Arguments -contains 'push') { throw 'Fixture network command was not explicitly mocked; no actual query/push is permitted.' }
            & $script:closeoutGitImplementation $RepoRoot $Arguments $EnvironmentOverrides
        }
        Mock Get-WorkflowCloseoutWorktrees { & $script:closeoutWorktreeImplementation $RepoRoot }
        Mock Start-WorkflowCloseoutProofLock { & $script:closeoutProofLockImplementation $RepoRoot $Preview }
    }
    AfterEach { Remove-WorkflowFixture $script:fixture }

    It 'retains a physically resolved source alias declared with different casing from the primary checkout' {
        $script:fixture=New-CloseoutFixture -NoWorktree
        $null=Invoke-FixtureGit $fixture @('switch','--quiet','feat/001-example')
        foreach ($relative in @('docs/specs.md','specs/001-example/spec.md')) {
            $path=Join-Path $fixture.RepoRoot $relative
            [IO.File]::WriteAllText($path,[IO.File]::ReadAllText($path).Replace('feat/001-example','FEAT/001-EXAMPLE'))
        }
        Save-FixtureRevision $fixture
        $fixture.Accepted=[string](Invoke-FixtureGit $fixture @('rev-parse','HEAD'))
        $null=Invoke-FixtureGit $fixture @('update-ref','refs/heads/master',$fixture.Accepted)
        $fixture.Landed=$fixture.Accepted
        $fixture.PreviewParameters.AcceptedRevision=$fixture.Accepted
        $fixture.PreviewParameters.LandedRevision=$fixture.Landed
        if ($IsWindows) { (& $script:closeoutGitImplementation $fixture.RepoRoot @('show-ref','--verify','--quiet','refs/heads/FEAT/001-EXAMPLE')).ExitCode | Should Be 0 }
        $parameters=$fixture.PreviewParameters
        $preview=Get-WorkflowCloseoutPreview @parameters
        $preview.status | Should Be incomplete
        $preview.reasons -join ';' | Should Match 'differently cased literal ref refs/heads/feat/001-example'
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        [string](Invoke-FixtureGit $fixture @('symbolic-ref','HEAD')) | Should Be 'refs/heads/feat/001-example'
        [string](Invoke-FixtureGit $fixture @('rev-parse','refs/heads/feat/001-example')) | Should Be $fixture.Accepted
        (& $script:closeoutGitImplementation $fixture.RepoRoot @('show-ref','--verify','--quiet','refs/tags/archive/001-example')).ExitCode | Should Be 1
        Test-Path -LiteralPath $fixture.RepoRoot | Should Be $true
    }

    It 'retains source work when the configured target names a physical case alias' {
        $script:fixture=New-CloseoutFixture
        $config=Get-FixtureConfig $fixture
        $config.targetBranch='MASTER'
        Set-FixtureConfig $fixture $config
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        $report.reasons -join ';' | Should Match 'requested refs/heads/MASTER has a differently cased literal ref refs/heads/master'
        Test-Path -LiteralPath $fixture.DeliveryPath | Should Be $true
        [string](Invoke-FixtureGit $fixture @('rev-parse','feat/001-example')) | Should Be $fixture.Accepted
    }

    It 'retains a differently cased archive ref without relabeling it absent or matching' {
        $script:fixture=New-CloseoutFixture
        $parameters=$fixture.PreviewParameters.Clone(); $parameters.Apply=$true; $parameters.AuthorizeLocalCleanup=$true; $parameters.DeleteLocalBranch=$true
        $null=Invoke-WorkflowCloseout @parameters
        Move-CloseoutFixtureLiteralRef $fixture 'refs/tags/archive/001-example' 'refs/tags/archive/001-EXAMPLE'
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        $report.archiveTag.state | Should Be conflicting
        $report.reasons -join ';' | Should Match 'differently cased literal ref refs/tags/archive/001-EXAMPLE'
        Test-Path -LiteralPath $fixture.DeliveryPath | Should Be $true
        [string](Invoke-FixtureGit $fixture @('rev-parse','refs/tags/archive/001-EXAMPLE^{commit}')) | Should Be $fixture.Accepted
    }

    It 'rejects symbolic delivery and configured target refs as unresolved ownership' {
        foreach ($kind in @('source','target')) {
            $script:fixture=New-CloseoutFixture
            if ($kind -eq 'source') { $null=Invoke-FixtureGit $fixture @('symbolic-ref','refs/heads/feat/001-example','refs/heads/master') }
            else { $null=Invoke-FixtureGit $fixture @('symbolic-ref','refs/heads/master','refs/heads/feat/001-example') }
            $report=Invoke-CloseoutFixtureApply $fixture
            $report.status | Should Be incomplete
            $report.reasons -join ';' | Should Match 'is symbolic; direct ref ownership and locking are unknown'
            Test-Path -LiteralPath $fixture.DeliveryPath | Should Be $true
            Remove-WorkflowFixture $fixture; $script:fixture=$null
        }
    }

    It 'rejects a symbolic archive alias even when it resolves the matching annotation object' {
        $script:fixture=New-CloseoutFixture
        $parameters=$fixture.PreviewParameters.Clone(); $parameters.Apply=$true; $parameters.AuthorizeLocalCleanup=$true; $parameters.DeleteLocalBranch=$true
        $null=Invoke-WorkflowCloseout @parameters
        $tagObject=[string](Invoke-FixtureGit $fixture @('rev-parse','refs/tags/archive/001-example'))
        $null=Invoke-FixtureGit $fixture @('update-ref','refs/tags/preserved-original',$tagObject)
        $null=Invoke-FixtureGit $fixture @('symbolic-ref','refs/tags/archive/001-example','refs/tags/preserved-original')
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        $report.archiveTag.state | Should Be conflicting
        $report.reasons -join ';' | Should Match 'is symbolic; direct ref ownership and locking are unknown'
        Test-Path -LiteralPath $fixture.DeliveryPath | Should Be $true
    }

    It 'retains a dangling symbolic source rather than reporting an archived source already absent' {
        $script:fixture=New-CloseoutFixture -NoWorktree
        $null=Invoke-CloseoutFixtureApply $fixture -WorktreesOnly
        $null=Invoke-FixtureGit $fixture @('symbolic-ref','refs/heads/feat/001-example','refs/heads/missing-source-referent')
        $parameters=$fixture.PreviewParameters
        $preview=Get-WorkflowCloseoutPreview @parameters
        $preview.status | Should Be incomplete
        $preview.reasons -join ';' | Should Match 'dangling or unlisted symbolic ref'
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        @($report.results | Where-Object { $_.action -eq 'delete local branch' -and $_.reason -eq 'already absent' }).Count | Should Be 0
        [string](Invoke-FixtureGit $fixture @('symbolic-ref','refs/heads/feat/001-example')) | Should Be 'refs/heads/missing-source-referent'
        [string](Invoke-FixtureGit $fixture @('rev-parse','refs/tags/archive/001-example^{commit}')) | Should Be $fixture.Accepted
    }

    It 'retains a dangling symbolic archive without creating or updating its missing referent' {
        $script:fixture=New-CloseoutFixture
        $null=Invoke-FixtureGit $fixture @('symbolic-ref','refs/tags/archive/001-example','refs/tags/missing-archive-referent')
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        $report.archiveTag.state | Should Be conflicting
        $report.reasons -join ';' | Should Match 'dangling or unlisted symbolic ref'
        @($report.results | Where-Object { $_.action -eq 'archive tag' }).Count | Should Be 0
        [string](Invoke-FixtureGit $fixture @('symbolic-ref','refs/tags/archive/001-example')) | Should Be 'refs/tags/missing-archive-referent'
        (& $script:closeoutGitImplementation $fixture.RepoRoot @('show-ref','--verify','--quiet','refs/tags/missing-archive-referent')).ExitCode | Should Be 1
        Test-Path -LiteralPath $fixture.DeliveryPath | Should Be $true
    }

    It 'retains an accepted source renamed only in casing at the native deletion boundary' {
        $script:fixture=New-CloseoutFixture -Squash -NoWorktree
        Mock Invoke-WorkflowCloseoutGit {
            if ($Arguments -contains 'branch' -and $Arguments -contains '-d') {
                $null=Invoke-FixtureGit $script:fixture @('branch','-m','feat/001-example','feat/literal-case-intermediate')
                $null=Invoke-FixtureGit $script:fixture @('branch','-m','feat/literal-case-intermediate','feat/001-EXAMPLE')
            }
            & $script:closeoutGitImplementation $RepoRoot $Arguments $EnvironmentOverrides
        }
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        @($report.results | Where-Object { $_.action -eq 'delete local branch' -and $_.status -eq 'retained' }).Count | Should Be 1
        if ($IsWindows) { $report.results[-1].reason | Should Match 'exact literal direct source/target/archive ref changed under the ref locks' }
        [string](Invoke-FixtureGit $fixture @('rev-parse','refs/heads/feat/001-EXAMPLE')) | Should Be $fixture.Accepted
        [string](Invoke-FixtureGit $fixture @('rev-parse','refs/tags/archive/001-example^{commit}')) | Should Be $fixture.Accepted
    }

    It 'rechecks literal target and archive names under their held proof locks' {
        foreach ($kind in @('target','tag')) {
            $script:fixture=New-CloseoutFixture -Squash -NoWorktree
            $script:literalProofRace=$kind
            Mock Invoke-WorkflowCloseoutGit {
                if ($Arguments -contains 'branch' -and $Arguments -contains '-d') {
                    if ($script:literalProofRace -eq 'target') { Move-CloseoutFixtureLiteralRef $script:fixture 'refs/heads/master' 'refs/heads/MASTER' }
                    else { Move-CloseoutFixtureLiteralRef $script:fixture 'refs/tags/archive/001-example' 'refs/tags/archive/001-EXAMPLE' }
                }
                & $script:closeoutGitImplementation $RepoRoot $Arguments $EnvironmentOverrides
            }
            $report=Invoke-CloseoutFixtureApply $fixture
            $report.status | Should Be incomplete
            $report.results[-1].reason | Should Match 'exact literal direct source/target/archive ref changed under the ref locks'
            [string](Invoke-FixtureGit $fixture @('rev-parse','refs/heads/feat/001-example')) | Should Be $fixture.Accepted
            $tag=if ($kind -eq 'target') {'refs/tags/archive/001-example^{commit}'} else {'refs/tags/archive/001-EXAMPLE^{commit}'}
            [string](Invoke-FixtureGit $fixture @('rev-parse',$tag)) | Should Be $fixture.Accepted
            Remove-WorkflowFixture $fixture; $script:fixture=$null
        }
    }

    It 'rejects a late symbolic source with the exact accepted OID at the native prepared guard' {
        $script:fixture=New-CloseoutFixture -NoWorktree
        Mock Invoke-WorkflowCloseoutGit {
            if ($Arguments -contains 'branch' -and $Arguments -contains '-d') {
                $null=Invoke-FixtureGit $script:fixture @('symbolic-ref','refs/heads/feat/001-example','refs/heads/master')
            }
            & $script:closeoutGitImplementation $RepoRoot $Arguments $EnvironmentOverrides
        }
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        $report.results[-1].reason | Should Match 'exact literal direct source/target/archive ref changed under the ref locks'
        [string](Invoke-FixtureGit $fixture @('symbolic-ref','refs/heads/feat/001-example')) | Should Be 'refs/heads/master'
        [string](Invoke-FixtureGit $fixture @('rev-parse','refs/heads/master')) | Should Be $fixture.Landed
    }

    It 'retains non-ASCII ref ownership while leaving valid Unicode delivered filenames intact' {
        $script:fixture=New-CloseoutFixture
        $config=Get-FixtureConfig $fixture
        $config.targetBranch='cible/épreuve'
        $null=Invoke-FixtureGit $fixture @('branch',$config.targetBranch,$fixture.Landed)
        Set-FixtureConfig $fixture $config
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        $report.reasons -join ';' | Should Match 'non-ASCII literal ref ownership is unverified'
        [IO.File]::ReadAllText((Join-Path $fixture.DeliveryPath 'résumé [notes] λ.txt')) | Should Be 'Unicode literal path bytes'
        [string](Invoke-FixtureGit $fixture @('rev-parse',$config.targetBranch)) | Should Be $fixture.Landed
    }

    It 'rejects a late differently cased sibling even when the exact accepted source remains' {
        $script:fixture=New-CloseoutFixture -Squash -NoWorktree
        $null=Invoke-FixtureGit $fixture @('pack-refs','--all')
        Mock Invoke-WorkflowCloseoutGit {
            if ($Arguments -contains 'branch' -and $Arguments -contains '-d') {
                $common=& $script:closeoutGitImplementation $RepoRoot @('rev-parse','--path-format=absolute','--git-common-dir')
                $path=Join-Path $common.Output.Trim() 'refs/heads/feat/001-EXAMPLE'
                $null=[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))
                [IO.File]::WriteAllText($path,$script:fixture.Accepted+"`n",[Text.UTF8Encoding]::new($false))
            }
            & $script:closeoutGitImplementation $RepoRoot $Arguments $EnvironmentOverrides
        }
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        $report.results[-1].reason | Should Match 'exact literal direct source/target/archive ref changed under the ref locks'
        $inventory=(& $script:closeoutGitImplementation $fixture.RepoRoot @('for-each-ref','--format=%(refname)')).Output
        @($inventory -split '\r?\n' | Where-Object { $_ -ceq 'refs/heads/feat/001-example' }).Count | Should Be 1
        @($inventory -split '\r?\n' | Where-Object { $_ -ceq 'refs/heads/feat/001-EXAMPLE' }).Count | Should Be 1
        [string](Invoke-FixtureGit $fixture @('rev-parse','refs/tags/archive/001-example^{commit}')) | Should Be $fixture.Accepted
    }

    It 'still deletes a literal accepted branch after composing its existing owner reference hook' {
        $script:fixture=New-CloseoutFixture -Squash -NoWorktree
        $hooks=Join-Path $fixture.TempRoot 'no-hooks'; $null=[IO.Directory]::CreateDirectory($hooks)
        $marker=Join-Path $fixture.TempRoot 'literal-owner-hook.log'
        $shellMarker="'"+$marker.Replace('\','/').Replace("'","'\''")+"'"
        $hook="#!/bin/sh`nrecords=`$(cat)`nprintf '%s\n%s\n' `"`$1`" `"`$records`" >> $shellMarker`nexit 0`n"
        $path=Join-Path $hooks 'reference-transaction'
        [IO.File]::WriteAllText($path,$hook,[Text.UTF8Encoding]::new($false))
        if (-not $IsWindows) { [IO.File]::SetUnixFileMode($path,([IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite -bor [IO.UnixFileMode]::UserExecute)) }
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be complete
        $report.archiveTag.state | Should Be matching
        [IO.File]::ReadAllText($marker) | Should Match 'prepared'
        [IO.File]::ReadAllText($marker) | Should Match 'refs/heads/feat/001-example'
        [IO.File]::ReadAllText($path) | Should Be $hook
        [string](Invoke-FixtureGit $fixture @('rev-parse','refs/heads/master')) | Should Be $fixture.Landed
    }
}

Describe 'Closeout registered checkout ref ownership' {
    BeforeEach {
        $script:fixture=$null
        Mock Invoke-WorkflowCloseoutGit {
            if ($Arguments -contains 'ls-remote' -or $Arguments -contains 'push') { throw 'Fixture network command was not explicitly mocked; no actual query/push is permitted.' }
            & $script:closeoutGitImplementation $RepoRoot $Arguments $EnvironmentOverrides
        }
        Mock Get-WorkflowCloseoutWorktrees { & $script:closeoutWorktreeImplementation $RepoRoot }
        Mock Start-WorkflowCloseoutProofLock { & $script:closeoutProofLockImplementation $RepoRoot $Preview }
    }
    AfterEach { Remove-WorkflowFixture $script:fixture }

    It 'retains a primary uppercase HEAD alias of an exact lowercase delivery ref' {
        $script:fixture=New-CloseoutFixture -NoWorktree
        $null=Invoke-FixtureGit $fixture @('switch','--quiet','feat/001-example')
        $null=Invoke-FixtureGit $fixture @('symbolic-ref','HEAD','refs/heads/FEAT/001-EXAMPLE')
        $parameters=$fixture.PreviewParameters
        $preview=Get-WorkflowCloseoutPreview @parameters
        $preview.status | Should Be incomplete
        $preview.branch.eligible | Should Be $false
        $preview.worktrees[0].kind | Should Be 'ref-alias'
        $preview.worktrees[0].branchRef | Should Be 'refs/heads/FEAT/001-EXAMPLE'
        $preview.worktrees[0].reasons -join ';' | Should Match 'case-alias source ref'
        $preview.worktrees[0].reasons -join ';' | Should Match 'primary checkout is protected'
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        [string](Invoke-FixtureGit $fixture @('rev-parse','refs/heads/feat/001-example')) | Should Be $fixture.Accepted
        [string](Invoke-FixtureGit $fixture @('symbolic-ref','HEAD')) | Should Be 'refs/heads/FEAT/001-EXAMPLE'
        Test-Path -LiteralPath $fixture.RepoRoot | Should Be $true
    }

    It 'retains a linked source alias while independently removing an eligible exact delivery checkout' {
        $script:fixture=New-CloseoutFixture
        $alias=& $script:closeoutGitImplementation $fixture.DeliveryPath @('symbolic-ref','HEAD','refs/heads/FEAT/001-EXAMPLE')
        $alias.ExitCode | Should Be 0
        $regular=Join-Path $fixture.TempRoot 'independent-delivery'
        $null=Invoke-FixtureGit $fixture @('worktree','add','--quiet','--detach',$regular,$fixture.Accepted)
        $attach=& $script:closeoutGitImplementation $regular @('symbolic-ref','HEAD','refs/heads/feat/001-example')
        $attach.ExitCode | Should Be 0
        $parameters=$fixture.PreviewParameters
        $preview=Get-WorkflowCloseoutPreview @parameters
        @($preview.worktrees | Where-Object { (Test-CloseoutFixturePath $_.path $fixture.DeliveryPath) -and $_.kind -eq 'ref-alias' -and -not $_.eligible }).Count | Should Be 1
        @($preview.worktrees | Where-Object { (Test-CloseoutFixturePath $_.path $regular) -and $_.eligible }).Count | Should Be 1
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        Test-Path -LiteralPath $regular | Should Be $false
        Test-Path -LiteralPath $fixture.DeliveryPath | Should Be $true
        [string](Invoke-FixtureGit $fixture @('rev-parse','refs/heads/feat/001-example')) | Should Be $fixture.Accepted
    }

    It 'preserves raw ref namespace casing instead of normalizing a primary HEAD alias' {
        $script:fixture=New-CloseoutFixture -NoWorktree
        $null=Invoke-FixtureGit $fixture @('switch','--quiet','feat/001-example')
        $null=Invoke-FixtureGit $fixture @('symbolic-ref','HEAD','refs/HEADS/feat/001-example')
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        $report.worktrees[0].kind | Should Be 'ref-alias'
        $report.worktrees[0].branchRef | Should Be 'refs/HEADS/feat/001-example'
        [string](Invoke-FixtureGit $fixture @('rev-parse','refs/heads/feat/001-example')) | Should Be $fixture.Accepted
    }

    It 'rejects a late registered case-alias checkout after native deletion has selected its exact source' {
        $script:fixture=New-CloseoutFixture -Squash -NoWorktree
        $script:lateAliasPath=Join-Path $fixture.TempRoot 'late-alias-checkout'
        Mock Invoke-WorkflowCloseoutGit {
            if ($Arguments -contains 'branch' -and $Arguments -contains '-d') {
                $null=Invoke-FixtureGit $script:fixture @('worktree','add','--quiet','--detach',$script:lateAliasPath,$script:fixture.Accepted)
                $alias=& $script:closeoutGitImplementation $script:lateAliasPath @('symbolic-ref','HEAD','refs/heads/FEAT/001-EXAMPLE')
                if ($alias.ExitCode) { throw 'private late checkout alias setup failed' }
            }
            & $script:closeoutGitImplementation $RepoRoot $Arguments $EnvironmentOverrides
        }
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        $report.results[-1].reason | Should Match 'registered checkout uses exact or case-alias source ref'
        Test-Path -LiteralPath $script:lateAliasPath | Should Be $true
        [string](Invoke-FixtureGit $fixture @('rev-parse','refs/heads/feat/001-example')) | Should Be $fixture.Accepted
        [string](Invoke-FixtureGit $fixture @('rev-parse','refs/tags/archive/001-example^{commit}')) | Should Be $fixture.Accepted
    }

    It 'retains accepted-head Unicode branch association while allowing independent delivery removal' {
        $script:fixture=New-CloseoutFixture
        $unicode=Join-Path $fixture.TempRoot 'unicode-accepted-checkout'
        $null=Invoke-FixtureGit $fixture @('worktree','add','--quiet','-b','feat/épreuve',$unicode,$fixture.Accepted)
        $parameters=$fixture.PreviewParameters
        $preview=Get-WorkflowCloseoutPreview @parameters
        @($preview.worktrees | Where-Object { (Test-CloseoutFixturePath $_.path $unicode) -and $_.kind -eq 'unknown' -and -not $_.eligible }).Count | Should Be 1
        ($preview.worktrees | Where-Object { Test-CloseoutFixturePath $_.path $unicode }).reasons -join ';' | Should Match 'non-ASCII literal ref ownership is unverified'
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        Test-Path -LiteralPath $fixture.DeliveryPath | Should Be $false
        Test-Path -LiteralPath $unicode | Should Be $true
        [string](Invoke-FixtureGit $fixture @('rev-parse','refs/heads/feat/001-example')) | Should Be $fixture.Accepted
    }

    It 'rejects a late accepted-head Unicode checkout without asserting distinct filesystem ownership' {
        $script:fixture=New-CloseoutFixture -NoWorktree
        $script:lateUnicodePath=Join-Path $fixture.TempRoot 'late-unicode-checkout'
        Mock Invoke-WorkflowCloseoutGit {
            if ($Arguments -contains 'branch' -and $Arguments -contains '-d') {
                $null=Invoke-FixtureGit $script:fixture @('worktree','add','--quiet','-b','feat/épreuve',$script:lateUnicodePath,$script:fixture.Accepted)
            }
            & $script:closeoutGitImplementation $RepoRoot $Arguments $EnvironmentOverrides
        }
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be incomplete
        $report.results[-1].reason | Should Match 'accepted-head checkout has unresolved direct ASCII branch ownership'
        Test-Path -LiteralPath $script:lateUnicodePath | Should Be $true
        [string](Invoke-FixtureGit $fixture @('rev-parse','refs/heads/feat/001-example')) | Should Be $fixture.Accepted
    }

    It 'retains the source when prepared registered inventory fails or is empty or malformed' {
        foreach ($kind in @('failure','empty','malformed')) {
            $script:fixture=New-CloseoutFixture -Squash -NoWorktree
            $shim=Join-Path $fixture.TempRoot 'prepared-git-shim'; $null=[IO.Directory]::CreateDirectory($shim)
            $realGit=(Get-Command git -CommandType Application | Select-Object -First 1).Source.Replace('\','/')
            $quotedGit="'"+$realGit.Replace("'","'\''")+"'"
            $script:preparedShim=$shim
            $wrapper=@'
#!/bin/sh
if [ "$1" = -c ] && [ "$2" = core.quotePath=true ] && [ "$3" = worktree ] && [ "$4" = list ] && [ "$5" = --porcelain ]; then
    __OUTCOME__
fi
exec __REAL_GIT__ "$@"
'@
            $outcome=switch ($kind) {
                'failure' {"echo 'private fixture inventory unavailable' >&2; exit 1"}
                'empty' {'exit 0'}
                'malformed' {"printf '%s\n' 'worktree private-fixture' 'HEAD invalid' 'branch refs/heads/master'; exit 0"}
            }
            $wrapper=$wrapper.Replace('__OUTCOME__',$outcome).Replace('__REAL_GIT__',$quotedGit)
            $path=Join-Path $shim 'git'
            [IO.File]::WriteAllText($path,($wrapper -replace "`r`n","`n")+"`n",[Text.UTF8Encoding]::new($false))
            if (-not $IsWindows) { [IO.File]::SetUnixFileMode($path,([IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite -bor [IO.UnixFileMode]::UserExecute)) }
            Mock Invoke-WorkflowCloseoutGit {
                if ($Arguments -contains 'branch' -and $Arguments -contains '-d') {
                    $overrides=if ($EnvironmentOverrides) {$EnvironmentOverrides.Clone()} else {@{}}
                    $overrides.GIT_EXEC_PATH=$script:preparedShim
                    return & $script:closeoutGitImplementation $RepoRoot $Arguments $overrides
                }
                & $script:closeoutGitImplementation $RepoRoot $Arguments $EnvironmentOverrides
            }
            $report=Invoke-CloseoutFixtureApply $fixture
            $report.status | Should Be incomplete
            $report.results[-1].reason | Should Match 'closeout-worktree-ownership: registered'
            [string](Invoke-FixtureGit $fixture @('rev-parse','refs/heads/feat/001-example')) | Should Be $fixture.Accepted
            [string](Invoke-FixtureGit $fixture @('rev-parse','refs/tags/archive/001-example^{commit}')) | Should Be $fixture.Accepted
            Remove-WorkflowFixture $fixture; $script:fixture=$null
        }
    }

    It 'accepts a quoted Unicode worktree path when its direct ASCII branch and head are distinct' {
        $script:fixture=New-CloseoutFixture -Squash -NoWorktree
        $unrelated=Join-Path $fixture.TempRoot 'registered résumé λ path'
        $null=Invoke-FixtureGit $fixture @('worktree','add','--quiet','-b','feat/unrelated',$unrelated,$fixture.Base)
        $report=Invoke-CloseoutFixtureApply $fixture
        $report.status | Should Be complete
        Test-Path -LiteralPath $unrelated | Should Be $true
        $report.archiveTag.state | Should Be matching
        [string](Invoke-FixtureGit $fixture @('rev-parse','refs/heads/feat/unrelated')) | Should Be $fixture.Base
    }
}
