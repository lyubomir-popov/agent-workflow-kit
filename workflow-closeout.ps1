# Versioned closeout. Preview stays offline and read-only; local and remote
# actions require separate authorization, fresh evidence and preservation checks.
. (Join-Path $PSScriptRoot 'workflow-model.ps1')
. (Join-Path $PSScriptRoot 'workflow-preservation.ps1')

function New-WorkflowCloseoutGitStartInfo {
    param([string]$RepoRoot, [string[]]$Arguments, [hashtable]$EnvironmentOverrides)
    $start=[Diagnostics.ProcessStartInfo]::new('git')
    $start.UseShellExecute=$false; $start.RedirectStandardOutput=$true; $start.RedirectStandardError=$true
    # Invalid filename bytes are unknown evidence, never replacement-character
    # pathspecs that could make unequal source/target entries both appear absent.
    $start.StandardOutputEncoding=[Text.UTF8Encoding]::new($false,$true)
    foreach ($name in @('GIT_DIR','GIT_COMMON_DIR','GIT_WORK_TREE','GIT_INDEX_FILE','GIT_OBJECT_DIRECTORY','GIT_ALTERNATE_OBJECT_DIRECTORIES','GIT_NAMESPACE')) { $null=$start.Environment.Remove($name) }
    if ($EnvironmentOverrides) {
        foreach ($name in $EnvironmentOverrides.Keys) {
            if ($null -eq $EnvironmentOverrides[$name]) { $null=$start.Environment.Remove($name) }
            else { $start.Environment[$name]=[string]$EnvironmentOverrides[$name] }
        }
    }
    # Never lazily fetch proof objects. Older Git can ignore this variable, so
    # closeout also rejects declared partial/promisor repositories before reads.
    $start.Environment['GIT_NO_LAZY_FETCH']='1'
    foreach ($argument in (@('--no-optional-locks','-C',$RepoRoot)+$Arguments)) { $start.ArgumentList.Add($argument) }
    return $start
}

function Invoke-WorkflowCloseoutGit {
    param([string]$RepoRoot, [string[]]$Arguments, [hashtable]$EnvironmentOverrides)
    $start=New-WorkflowCloseoutGitStartInfo $RepoRoot $Arguments $EnvironmentOverrides
    $process=[Diagnostics.Process]::Start($start)
    $bytes=[IO.MemoryStream]::new()
    # Drain bytes before strict decoding so a bad byte cannot stop the reader
    # while Git is still writing a large inventory into its pipe.
    $stdout=$process.StandardOutput.BaseStream.CopyToAsync($bytes); $stderr=$process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    try {
        try { $null=$stdout.GetAwaiter().GetResult(); $decoded=$start.StandardOutputEncoding.GetString($bytes.ToArray()) }
        catch { throw 'closeout-git: strict UTF-8 decoding failed; filename/ref evidence is unknown and cleanup is retained.' }
        return [pscustomobject]@{ExitCode=$process.ExitCode; Output=$decoded; Error=$stderr.GetAwaiter().GetResult()}
    }
    finally { $bytes.Dispose(); $process.Dispose() }
}

function Stop-WorkflowCloseoutProofLock {
    param($Lock)
    $problem=$null
    try {
        if (-not $Lock.Process.HasExited) {
            $Lock.Process.StandardInput.WriteLine('abort'); $Lock.Process.StandardInput.Flush(); $Lock.Process.StandardInput.Close()
            if (-not $Lock.Process.WaitForExit(15000)) { $Lock.Process.Kill($true); $Lock.Process.WaitForExit(); $problem='proof verification process timed out; inspect Git residue manually; no filesystem fallback' }
        }
        $errorText=$Lock.ErrorTask.GetAwaiter().GetResult().Trim()
        if ($Lock.Process.ExitCode -ne 0) { $problem="proof verification transaction failed: $errorText" }
    } catch { $problem="proof verification transaction release failed: $($_.Exception.Message)" }
    finally { $Lock.Process.Dispose() }
    return $problem
}

function Start-WorkflowCloseoutProofLock {
    param([string]$RepoRoot,$Preview)
    $start=New-WorkflowCloseoutGitStartInfo $RepoRoot @('update-ref','--stdin')
    $start.RedirectStandardInput=$true
    $start.StandardInputEncoding=[Text.UTF8Encoding]::new($false)
    $process=[Diagnostics.Process]::Start($start)
    $process.StandardInput.NewLine="`n"
    $lock=[pscustomobject]@{Process=$process; ErrorTask=$process.StandardError.ReadToEndAsync()}
    try {
        $process.StandardInput.WriteLine('start')
        $process.StandardInput.WriteLine('option no-deref')
        $process.StandardInput.WriteLine("verify refs/tags/$($Preview.archiveTag.name) $($Preview.archiveTag.objectId)")
        $process.StandardInput.WriteLine("verify refs/heads/$($Preview.targetBranch) $($Preview.targetRevision)")
        $process.StandardInput.WriteLine('prepare'); $process.StandardInput.Flush()
        foreach ($expected in @('start: ok','prepare: ok')) {
            $line=$process.StandardOutput.ReadLineAsync()
            if (-not $line.Wait(15000) -or $line.GetAwaiter().GetResult() -cne $expected) { throw 'Git verify-only transaction did not acknowledge prepared tag/target locks; retain source branch' }
        }
        if ($process.HasExited) { throw 'Git prepared proof lock exited unexpectedly; retain source branch' }
        return $lock
    } catch {
        $release=Stop-WorkflowCloseoutProofLock $lock
        throw "closeout-proof-lock: $($_.Exception.Message) $release"
    }
}

function Resolve-WorkflowCloseoutCommit {
    param([string]$RepoRoot,[string]$Revision)
    if (-not $Revision -or $Revision.StartsWith('-') -or $Revision -match '[\r\n\x00]') { throw 'closeout-evidence: an explicit valid commit revision is required.' }
    $result=Invoke-WorkflowCloseoutGit $RepoRoot @('rev-parse','--verify',"$Revision^{commit}")
    if ($result.ExitCode) { throw "closeout-evidence: commit is unavailable: $Revision." }
    return $result.Output.Trim()
}

function Assert-WorkflowCloseoutOfflineProofRepository {
    param([string]$RepoRoot)
    $config=Invoke-WorkflowCloseoutGit $RepoRoot @('config','--get-regexp','^(extensions\.partialclone|remote\..*\.(promisor|partialclonefilter))$')
    if ($config.ExitCode -eq 0) { throw 'closeout-evidence: declared partial-clone/promisor repositories have unsupported offline proof; retain cleanup without fetching objects.' }
    if ($config.ExitCode -ne 1) { throw 'closeout-evidence: partial-clone/promisor configuration is unknown; retain cleanup without object reads or fetch.' }
}

function Assert-WorkflowCloseoutLandingAncestor {
    param([string]$RepoRoot,[string]$Landed,[string]$TargetRevision,[string]$Context)
    $type=Invoke-WorkflowCloseoutGit $RepoRoot @('cat-file','-t',$TargetRevision)
    if ($type.ExitCode -or $type.Output.Trim() -cne 'commit') { throw "closeout-evidence: $Context tip is not a locally available commit; retain cleanup without fetching objects." }
    $ancestry=Invoke-WorkflowCloseoutGit $RepoRoot @('merge-base','--is-ancestor',$Landed,$TargetRevision)
    if ($ancestry.ExitCode -eq 1) { throw "closeout-evidence: original landed revision is not an ancestor of $Context; retain cleanup and preserve the original landing tuple." }
    if ($ancestry.ExitCode -ne 0) { throw "closeout-evidence: original landing ancestry to $Context is unavailable; retain cleanup without fetching objects." }
}

function Get-WorkflowCloseoutLiteralRef {
    param([string]$RepoRoot,[string]$Name)
    # Files-backend lookups can resolve a differently cased physical path.
    # Enumerate every literal name without a requested-name prefix, and reject
    # symbolic refs: locking a referent does not establish this ref's ownership.
    if ($Name -match '[^\x20-\x7e]') { throw "closeout-ref-ownership: non-ASCII literal ref ownership is unverified for $Name; retain cleanup." }
    $inventory=Invoke-WorkflowCloseoutGit $RepoRoot @('for-each-ref','--format=%(refname)%00%(objectname)%00%(symref)')
    if ($inventory.ExitCode) { throw "closeout-ref-ownership: literal ref inventory unavailable for $Name; retain cleanup." }
    $literalEntries=@()
    foreach ($line in ($inventory.Output -split '\r?\n' | Where-Object { $_ })) {
        $fields=$line.Split([char]0)
        if ($fields.Count -ne 3 -or $fields[1] -notmatch '^(?:[0-9a-f]{40}|[0-9a-f]{64})$') { throw 'closeout-ref-ownership: literal ref inventory is malformed; retain cleanup.' }
        if ([string]::Equals($fields[0],$Name,[StringComparison]::OrdinalIgnoreCase)) {
            if ($fields[0] -cne $Name) { throw "closeout-ref-ownership: requested $Name has a differently cased literal ref $($fields[0]); retain cleanup." }
            if ($fields[2]) { throw "closeout-ref-ownership: $Name is symbolic; direct ref ownership and locking are unknown; retain cleanup." }
            $literalEntries+=,[pscustomobject]@{name=$fields[0]; exists=$true; objectId=$fields[1]}
        }
    }
    if ($literalEntries.Count -gt 1) { throw "closeout-ref-ownership: duplicate literal ref $Name; retain cleanup." }
    if ($literalEntries.Count) { return $literalEntries[0] }
    # Dangling symbolic refs may be omitted by for-each-ref and look absent to
    # show-ref. Never let archive creation follow such a ref to its referent.
    $symbolic=Invoke-WorkflowCloseoutGit $RepoRoot @('symbolic-ref','--quiet',$Name)
    if ($symbolic.ExitCode -eq 0) { throw "closeout-ref-ownership: $Name is a dangling or unlisted symbolic ref; retain cleanup." }
    if ($symbolic.ExitCode -ne 1) { throw "closeout-ref-ownership: symbolic ref ownership is unavailable for $Name; retain cleanup." }
    $physical=Invoke-WorkflowCloseoutGit $RepoRoot @('show-ref','--verify','--quiet',$Name)
    if ($physical.ExitCode -ne 1) { throw "closeout-ref-ownership: $Name cannot be established as an exact literal ref or safely absent; retain cleanup." }
    return [pscustomobject]@{name=$Name; exists=$false; objectId=$null}
}

function Get-WorkflowCloseoutWorktrees {
    param([string]$RepoRoot)
    $result=Invoke-WorkflowCloseoutGit $RepoRoot @('worktree','list','--porcelain','-z')
    if ($result.ExitCode) { throw 'closeout-inventory: cannot read Git worktree inventory.' }
    $trees=@(); $current=$null
    foreach ($field in $result.Output.Split([char]0)) {
        if ($field.StartsWith('worktree ')) {
            if ($current) { $trees+=$current }
            $current=[pscustomobject]@{Path=$field.Substring(9); Head=''; Branch=''; BranchRef=''; Locked=$false; Prunable=$false}
        } elseif ($current) {
            if ($field.StartsWith('HEAD ')) { $current.Head=$field.Substring(5) }
            elseif ($field.StartsWith('branch ')) {
                $current.BranchRef=$field.Substring(7)
                $current.Branch=if ($current.BranchRef.StartsWith('refs/heads/',[StringComparison]::Ordinal)) {$current.BranchRef.Substring(11)} else {$current.BranchRef}
            }
            elseif ($field -match '^locked(?: |$)') { $current.Locked=$true }
            elseif ($field -match '^prunable(?: |$)') { $current.Prunable=$true }
        }
    }
    if ($current) { $trees+=$current }
    return $trees
}

function Get-WorkflowCloseoutWorktreeBranchRef {
    param($Tree)
    if ($Tree.PSObject.Properties['BranchRef']) { return [string]$Tree.BranchRef }
    if ($Tree.Branch) { return "refs/heads/$($Tree.Branch)" }
    return ''
}

function Get-WorkflowCloseoutDeliveryRecord {
    param([string]$RepoRoot,[string]$Revision,[string]$PackageId)
    $catalog=Read-WorkflowGitFile $RepoRoot $Revision 'docs/specs.md'
    if ($null -eq $catalog) { throw "closeout-delivery: catalog missing at $Revision." }
    $entries=@(Get-WorkflowCatalog $RepoRoot -Text $catalog | Where-Object { $_.Id -eq $PackageId -or (Split-Path $_.RelativePath -Leaf) -eq $PackageId })
    if ($entries.Count -ne 1 -or -not $entries[0].Archived) { throw "closeout-delivery: exactly one archived package is required at $Revision." }
    $entry=$entries[0]
    $spec=Read-WorkflowGitFile $RepoRoot $Revision "$($entry.RelativePath)/spec.md"
    $header=($spec -split '(?m)^##\s',2)[0]
    $branches=[regex]::Matches($header,'(?im)^\*\*Feature branch\*\*:[ \t]*([^\r\n]+)')
    $lifecycles=[regex]::Matches($header,'(?im)^\*\*Lifecycle\*\*:[ \t]*([^\r\n]+)')
    if ($branches.Count -ne 1 -or $lifecycles.Count -ne 1 -or
        $lifecycles[0].Groups[1].Value.Trim() -cne 'delivered' -or
        $branches[0].Groups[1].Value.Trim().Trim('`') -cne $entry.Branch) {
        throw "closeout-delivery: source/landed record must declare delivered and its catalog branch at $Revision."
    }
    $holds=@([regex]::Matches($header,'(?im)^\*\*(?:Cleanup holds|Worktree holds|Holds|Hold)\*\*:\s*([^\r\n]+)') | ForEach-Object { $_.Groups[1].Value.Trim().Trim('`') } | Where-Object { $_ -notmatch '^(none|no)\.?$' })
    foreach ($section in [regex]::Matches($spec,'(?ims)^##\s+(?:Cleanup holds|Worktree holds|Holds)\s*\r?\n(.*?)(?=^##\s|\z)')) {
        $hold=$section.Groups[1].Value.Trim()
        if ($hold -and $hold -notmatch '^(none|no)\.?$') { $holds+=$hold }
    }
    return [pscustomobject]@{Entry=$entry; Holds=$holds}
}

function Get-WorkflowCloseoutRetainedAssociation {
    param([string]$RepoRoot,$Tree,[string]$Accepted,[string]$SourceBranch,[string]$CommonGitDir)
    $reasons=@()
    $branchRef=Get-WorkflowCloseoutWorktreeBranchRef $Tree
    $sourceRef="refs/heads/$SourceBranch"
    $kind=if (-not $branchRef -and $Tree.Head -ceq $Accepted) {'detached'} else {$null}
    if ($branchRef -cne $sourceRef -and [string]::Equals($branchRef,$sourceRef,[StringComparison]::OrdinalIgnoreCase)) {
        $kind='ref-alias'; $reasons+="registered checkout uses case-alias source ref $branchRef; delivery ownership is unresolved"
    } elseif ($branchRef -and $Tree.Head -ceq $Accepted) {
        try { $literal=Get-WorkflowCloseoutLiteralRef $RepoRoot $branchRef; if (-not $literal.exists) { throw 'registered branch has no exact literal ref' } }
        catch { $kind='unknown'; $reasons+='accepted-head checkout has unresolved branch ownership: '+$_.Exception.Message }
    }
    try {
        Assert-WorkflowNoLinks $Tree.Path
        if (Test-Path -LiteralPath $Tree.Path) {
            $admin=Invoke-WorkflowCloseoutGit $Tree.Path @('rev-parse','--absolute-git-dir')
            if ($admin.ExitCode) { throw 'registered worktree administration is unknown' }
            $adminPath=[IO.Path]::GetFullPath($admin.Output.Trim())
            $commonPath=[IO.Path]::GetFullPath($CommonGitDir)
            if ($adminPath -ne $commonPath) { $null=Resolve-WorkflowRelativePath $commonPath ([IO.Path]::GetRelativePath($commonPath,$adminPath)) }
            $markerPath=Join-Path $adminPath 'workflow-kit-scratch.json'
            if (Test-Path -LiteralPath $markerPath) {
                Assert-WorkflowNoLinks $markerPath
                $kind='unknown scratch'
                $marker=[IO.File]::ReadAllText($markerPath) | ConvertFrom-Json -ErrorAction Stop
                if ($marker.kind -ne 'workflow-kit-scratch-v1' -or
                    [IO.Path]::GetFullPath([string]$marker.worktree) -ne [IO.Path]::GetFullPath($Tree.Path) -or
                    [IO.Path]::GetFullPath([string]$marker.commonGitDir) -ne $commonPath) { throw 'scratch marker ownership is unknown' }
                if ($marker.integrationBranch -ceq $SourceBranch) { $kind='scratch' }
                elseif ($kind -ne 'detached' -and $Tree.Head -cne $Accepted) { return $null }
                else { $kind='detached' }
            }
        }
    } catch {
        if (-not $kind -and $Tree.Head -ceq $Accepted) { $kind='unknown' }
        if ($kind) { $reasons+=$_.Exception.Message }
    }
    if (-not $kind) { return $null }
    $reasons+="$kind worktree requires separate integration/preservation authorization; delivery cleanup permission does not apply"
    return [pscustomobject]@{path=$Tree.Path; head=$Tree.Head; branch=$Tree.Branch; branchRef=$branchRef; kind=$kind; eligible=$false; reasons=$reasons}
}

function Test-WorkflowCloseoutChangedPaths {
    param([string]$RepoRoot,[string]$Base,[string]$Accepted,[string]$Landed)
    # Disabling rename detection includes both sides of renames. Literal pathspecs
    # and NUL separators preserve unusual filenames and prevent wildcard proof.
    $diff=Invoke-WorkflowCloseoutGit $RepoRoot @('diff','--no-renames','--name-only','-z',$Base,$Accepted,'--')
    if ($diff.ExitCode) { throw 'closeout-proof: changed-path inventory unavailable.' }
    $paths=@($diff.Output.Split([char]0) | Where-Object { $_.Length })
    if (-not $paths.Count) { return $false }
    $chunks=@(); $chunk=@(); $length=0
    foreach ($path in $paths) {
        if ($chunk.Count -and $length+$path.Length -gt 6000) { $chunks+=,@($chunk); $chunk=@(); $length=0 }
        $chunk+=$path; $length+=$path.Length+3
    }
    if ($chunk.Count) { $chunks+=,@($chunk) }
    foreach ($chunk in $chunks) {
        $source=Invoke-WorkflowCloseoutGit $RepoRoot (@('--literal-pathspecs','ls-tree','-z',$Accepted,'--')+$chunk)
        $target=Invoke-WorkflowCloseoutGit $RepoRoot (@('--literal-pathspecs','ls-tree','-z',$Landed,'--')+$chunk)
        if ($source.ExitCode -or $target.ExitCode) { throw 'closeout-proof: tree-entry evidence unavailable.' }
        if ($source.Output -cne $target.Output) { return $false }
    }
    return $true
}

function Get-WorkflowCloseoutArchiveTag {
    param([string]$RepoRoot,[string]$Name,[string]$PackageId,[string]$Base,[string]$Accepted,[string]$Target,[string]$Landed,[string]$TagObject)
    $tag=[pscustomobject]@{name=$Name; state='absent'; objectId=$null; proofMethod=$null; reasons=@()}
    try { $literal=Get-WorkflowCloseoutLiteralRef $RepoRoot "refs/tags/$Name" }
    catch { $tag.state='conflicting'; $tag.reasons=@($_.Exception.Message); return $tag }
    if (-not $literal.exists) {
        if ($TagObject) { $tag.state='conflicting'; $tag.reasons=@('captured archive proof has no current exact literal tag ref; retain cleanup') }
        return $tag
    }
    if ($TagObject -and $literal.objectId -cne $TagObject) { $tag.state='conflicting'; $tag.reasons=@('captured archive proof differs from the exact literal tag ref; retain cleanup'); return $tag }
    if (-not $TagObject) {
        $object=Invoke-WorkflowCloseoutGit $RepoRoot @('rev-parse','--verify',"refs/tags/$Name")
        if ($object.ExitCode) { $tag.state='conflicting'; $tag.reasons=@('archive tag object unavailable'); return $tag }
        $TagObject=$object.Output.Trim()
        if ($TagObject -cne $literal.objectId) { $tag.state='conflicting'; $tag.reasons=@('archive tag object changed during literal ownership verification; retain cleanup'); return $tag }
    }
    $tag.objectId=$TagObject
    $type=Invoke-WorkflowCloseoutGit $RepoRoot @('cat-file','-t',$TagObject)
    $head=Resolve-WorkflowCloseoutCommit $RepoRoot $TagObject
    $body=Invoke-WorkflowCloseoutGit $RepoRoot @('cat-file','tag',$TagObject)
    $parts=$body.Output -split '\r?\n\r?\n',2
    try { $metadata=$parts[1] | ConvertFrom-Json -ErrorAction Stop } catch { $metadata=$null }
    $date=[datetime]::MinValue
    # Newer PowerShell parses ISO JSON dates as DateTime. Its string conversion
    # uses invariant month/day order, so reparsing with the host's en-GB culture
    # falsely rejects valid annotations after day 12 of a month.
    $validDate=$metadata -and ($metadata.date -is [datetime] -or $metadata.date -is [datetimeoffset] -or
        ($metadata.date -is [string] -and [datetime]::TryParse($metadata.date,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind,[ref]$date)))
    if ($type.ExitCode -or $type.Output.Trim() -ne 'tag' -or $head -cne $Accepted -or $body.ExitCode -or
        $parts[0] -notmatch ('(?m)^object '+[regex]::Escape($Accepted)+'$') -or $parts[0] -notmatch '(?m)^type commit$' -or
        $parts[0] -cnotmatch ('(?m)^tag '+[regex]::Escape($Name)+'$') -or
        -not $metadata -or $metadata.version -ne 1 -or $metadata.packageId -cne $PackageId -or
        $metadata.baseRevision -cne $Base -or $metadata.acceptedRevision -cne $Accepted -or
        $metadata.targetBranch -cne $Target -or $metadata.landedRevision -cne $Landed -or
        $metadata.proofMethod -notin @('ancestry','changed-path equality','owner confirmation') -or
        -not $validDate) {
        $tag.state='conflicting'; $tag.reasons=@('existing archive tag is lightweight, moved, or has conflicting/missing proof; preserve it and inspect its original base/accepted/landed tuple before retrying; do not substitute the current target tip for the original landed revision')
    } else { $tag.state='matching'; $tag.proofMethod=$metadata.proofMethod }
    return $tag
}

function Get-WorkflowCloseoutPreviewCore {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RepoRoot,[Parameter(Mandatory)][string]$PackageId,
        [string]$AcceptedRevision,[string]$BaseRevision,[string]$LandedRevision,[switch]$OwnerConfirmed)
    $report=[pscustomobject]@{version=1; status='incomplete'; repoRoot=$RepoRoot; packageId=$PackageId; targetBranch=$null; targetRevision=$null;
        baseRevision=$BaseRevision; acceptedRevision=$AcceptedRevision; landedRevision=$LandedRevision; proofMethod='unknown';
        archiveTag=$null; cleanupHolds=@(); worktrees=@(); branch=$null; remoteBranches=@(); unknownRemotes=@(); remoteInventory='cached only'; remoteIsolation='network actions disabled'; localStatus='incomplete'; remoteStatus='disabled'; actions=@(); results=@(); reasons=@(); networkActionsEnabled=$false}
    try {
        $config=Get-WorkflowConfig $RepoRoot
        if (-not $config) { throw 'closeout-config: versioned workflow configuration is required.' }
        Assert-WorkflowNoLinks $RepoRoot
        Assert-WorkflowCloseoutOfflineProofRepository $RepoRoot
        $report.repoRoot=[IO.Path]::GetFullPath($RepoRoot)
        $report.targetBranch=[string]$config.targetBranch
        $base=Resolve-WorkflowCloseoutCommit $RepoRoot $BaseRevision
        $accepted=Resolve-WorkflowCloseoutCommit $RepoRoot $AcceptedRevision
        $landed=Resolve-WorkflowCloseoutCommit $RepoRoot $LandedRevision
        $report.baseRevision=$base; $report.acceptedRevision=$accepted; $report.landedRevision=$landed
        $targetRef=Get-WorkflowCloseoutLiteralRef $RepoRoot "refs/heads/$($config.targetBranch)"
        if (-not $targetRef.exists) { throw 'closeout-ref-ownership: configured target has no exact literal ref; retain cleanup.' }
        $target=$targetRef.objectId
        $report.targetRevision=$target
        # Delivery/equality and archive metadata remain pinned to the explicit
        # original landing. Only the moving literal target tip is captured anew.
        Assert-WorkflowCloseoutLandingAncestor $RepoRoot $landed $target 'the current configured target'
        foreach ($head in @($accepted,$landed)) {
            $ancestry=Invoke-WorkflowCloseoutGit $RepoRoot @('merge-base','--is-ancestor',$base,$head)
            if ($ancestry.ExitCode) { throw 'closeout-evidence: declared base is not an ancestor of both source and landing.' }
        }
        $sourceRecord=Get-WorkflowCloseoutDeliveryRecord $RepoRoot $accepted $PackageId
        $report.cleanupHolds=@($sourceRecord.Holds)
        $landedRecord=Get-WorkflowCloseoutDeliveryRecord $RepoRoot $landed $PackageId
        if ($sourceRecord.Entry.RelativePath -cne $landedRecord.Entry.RelativePath -or $sourceRecord.Entry.Branch -cne $landedRecord.Entry.Branch) { throw 'closeout-delivery: source and landed package ownership differ.' }
        $entry=$sourceRecord.Entry; $id=Split-Path $entry.RelativePath -Leaf; $report.packageId=$id
        if ($entry.Branch -ceq $config.targetBranch) { throw 'closeout-delivery: delivery branch cannot be the configured target.' }
        $report.archiveTag=Get-WorkflowCloseoutArchiveTag $RepoRoot "archive/$id" $id $base $accepted $config.targetBranch $landed
        if ($report.archiveTag.state -eq 'conflicting') { $report.reasons+=$report.archiveTag.reasons }
        $ancestry=Invoke-WorkflowCloseoutGit $RepoRoot @('merge-base','--is-ancestor',$accepted,$landed)
        if ($ancestry.ExitCode -eq 0) { $report.proofMethod='ancestry' }
        elseif ($ancestry.ExitCode -eq 1) {
            $mergeBase=Invoke-WorkflowCloseoutGit $RepoRoot @('merge-base',$accepted,$landed)
            if ($mergeBase.ExitCode -or $mergeBase.Output.Trim() -cne $base) { throw 'closeout-evidence: declared base differs from source/landing merge base.' }
            if (Test-WorkflowCloseoutChangedPaths $RepoRoot $base $accepted $landed) { $report.proofMethod='changed-path equality' }
            elseif ($OwnerConfirmed -or ($report.archiveTag.state -eq 'matching' -and $report.archiveTag.proofMethod -eq 'owner confirmation')) { $report.proofMethod='owner confirmation' }
            else { $report.reasons+='exact changed-path equality failed; owner confirmation of these exact revisions is required' }
        } else { throw 'closeout-proof: ancestry evidence unavailable.' }
        if ($report.archiveTag.state -eq 'matching' -and $report.archiveTag.proofMethod -ne $report.proofMethod) { $report.reasons+='existing archive tag proof method differs; preserve it and resolve explicitly' }
        $ref=Get-WorkflowCloseoutLiteralRef $RepoRoot "refs/heads/$($entry.Branch)"
        $branchExists=$ref.exists
        $branchReasons=@()
        if ($branchExists -and (Resolve-WorkflowCloseoutCommit $RepoRoot "refs/heads/$($entry.Branch)") -cne $accepted) { $branchReasons+='branch ref differs from accepted revision; preserve unpublished commits' }
        if (-not $branchExists -and $report.archiveTag.state -ne 'matching') { $report.reasons+='source branch missing without matching annotated archive proof' }
        if ($sourceRecord.Holds.Count) { $branchReasons+='accepted package declares cleanup holds: '+($sourceRecord.Holds -join '; ') }
        $trees=@(Get-WorkflowCloseoutWorktrees $RepoRoot)
        if (-not $trees.Count) { throw 'closeout-inventory: no primary worktree could be identified.' }
        $common=Invoke-WorkflowCloseoutGit $RepoRoot @('rev-parse','--path-format=absolute','--git-common-dir')
        if ($common.ExitCode) { throw 'closeout-inventory: repository identity unavailable.' }
        $primary=[IO.Path]::GetFullPath($trees[0].Path)
        $sourceRef="refs/heads/$($entry.Branch)"
        foreach ($tree in $trees | Where-Object { (Get-WorkflowCloseoutWorktreeBranchRef $_) -ceq $sourceRef }) {
            $reasons=@($branchReasons)
            if ([IO.Path]::GetFullPath($tree.Path) -eq $primary) { $reasons+='primary checkout is protected' }
            elseif ([IO.Path]::GetFullPath($tree.Path) -eq $report.repoRoot) { $reasons+='invoking checkout is protected; rerun cleanup from the primary checkout' }
            if ($tree.Locked) { $reasons+='worktree is locked' }
            if ($tree.Prunable -or -not (Test-Path -LiteralPath $tree.Path)) { $reasons+='worktree residue requires explicit Git pruning; no filesystem fallback' }
            if ($tree.Head -cne $accepted) { $reasons+='worktree head differs from accepted source; preserve unpublished commits' }
            try {
                Assert-WorkflowNoLinks $tree.Path
                $identity=Invoke-WorkflowCloseoutGit $tree.Path @('rev-parse','--path-format=absolute','--git-common-dir')
                $actualRoot=Invoke-WorkflowCloseoutGit $tree.Path @('rev-parse','--show-toplevel')
                if ($identity.ExitCode -or $identity.Output.Trim() -cne $common.Output.Trim() -or $actualRoot.ExitCode -or
                    [IO.Path]::GetFullPath($actualRoot.Output.Trim()) -ne [IO.Path]::GetFullPath($tree.Path)) { throw 'worktree repository/path ownership is unresolved' }
                $inventory=Get-WorkflowPreservationInventory -RepoRoot $RepoRoot -WorktreePath $tree.Path -Config $config -PackageRelativePath $entry.RelativePath
                $reasons+=@($inventory.Reasons)
            } catch { $reasons+=$_.Exception.Message }
            $reasons+=@($report.reasons)
            $report.worktrees+=[pscustomobject]@{path=$tree.Path; head=$tree.Head; branch=$tree.Branch; branchRef=(Get-WorkflowCloseoutWorktreeBranchRef $tree); kind='delivery'; eligible=($reasons.Count -eq 0); reasons=$reasons}
        }
        foreach ($tree in $trees | Where-Object { (Get-WorkflowCloseoutWorktreeBranchRef $_) -cne $sourceRef }) {
            $association=Get-WorkflowCloseoutRetainedAssociation $RepoRoot $tree $accepted $entry.Branch $common.Output.Trim()
            if ($association) {
                if ([IO.Path]::GetFullPath($tree.Path) -eq $primary) { $association.reasons+='primary checkout is protected' }
                elseif ([IO.Path]::GetFullPath($tree.Path) -eq $report.repoRoot) { $association.reasons+='invoking checkout is protected' }
                $report.worktrees+=$association
            }
        }
        if (@($report.worktrees | Where-Object { $_.kind -ne 'delivery' }).Count) { $branchReasons+='associated detached/scratch/alias work requires separate integration/preservation reconciliation; source branch retained' }
        if (@($trees | Where-Object { (Get-WorkflowCloseoutWorktreeBranchRef $_) -ceq $sourceRef }).Count) { $branchReasons+='branch is checked out in a worktree; remove eligible worktrees first' }
        $branchReasons+=@($report.reasons)
        $report.branch=[pscustomobject]@{name=$entry.Branch; exists=$branchExists; eligible=($branchReasons.Count -eq 0); reasons=$branchReasons}
        $remotes=Invoke-WorkflowCloseoutGit $RepoRoot @('remote')
        if ($remotes.ExitCode) { throw 'closeout-inventory: remote configuration unavailable.' }
        $remoteNames=@($remotes.Output -split '\r?\n' | Where-Object { $_ })
        $remoteRefs=Invoke-WorkflowCloseoutGit $RepoRoot @('for-each-ref','--format=%(refname) %(objectname)','refs/remotes/')
        if ($remoteRefs.ExitCode) { throw 'closeout-inventory: cached remote inventory unavailable.' }
        foreach ($line in ($remoteRefs.Output -split '\r?\n' | Where-Object { $_ })) {
            $fields=$line.Split(' ',2)
            foreach ($remoteName in $remoteNames) {
                if ($fields[0] -ceq "refs/remotes/$remoteName/$($entry.Branch)") {
                    $report.remoteBranches+=[pscustomobject]@{remote=$remoteName; name=$fields[0]; revision=$fields[1]; status='retained'; reason='remote reconciliation and archive tag push require separate owner authorization; network actions are disabled'}
                }
            }
        }
        $report.unknownRemotes=@($remoteNames | Where-Object { $_ -cnotin @($report.remoteBranches.remote) })
        if ($report.unknownRemotes.Count) { $report.remoteInventory='unknown; configured remotes have no cached delivery branch ref; network reconciliation is disabled' }
        if ($report.proofMethod -ne 'unknown' -and -not $report.reasons.Count) {
            if ($report.archiveTag.state -eq 'absent') { $report.actions+='create annotated archive tag' }
            foreach ($tree in $report.worktrees | Where-Object eligible) { $report.actions+="remove worktree: $($tree.path)" }
            if ($report.branch.exists -and $report.branch.eligible) { $report.actions+="delete local branch: $($entry.Branch)" }
            $report.status=if (-not $branchExists -and -not $report.worktrees.Count) { 'complete' }
                elseif (@($report.worktrees | Where-Object { -not $_.eligible }).Count -or ($branchExists -and -not $report.branch.eligible -and -not @($report.worktrees | Where-Object eligible).Count)) { 'incomplete' }
                else { 'eligible' }
        }
    } catch { $report.reasons+=$_.Exception.Message }
    $report.localStatus=$report.status
    if ($report.status -eq 'complete' -and ($report.remoteBranches.Count -or $report.remoteInventory.StartsWith('unknown'))) { $report.status='incomplete' }
    return $report
}

function Get-WorkflowCloseoutPreview {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RepoRoot,[Parameter(Mandatory)][string]$PackageId,
        [string]$AcceptedRevision,[string]$BaseRevision,[string]$LandedRevision,[switch]$OwnerConfirmed)
    # Native Git calls in the shared read-only model must use the selected repo,
    # even when launched by a hook with another index/worktree in its environment.
    $saved=@{}
    foreach ($name in @('GIT_DIR','GIT_COMMON_DIR','GIT_WORK_TREE','GIT_INDEX_FILE','GIT_OBJECT_DIRECTORY','GIT_ALTERNATE_OBJECT_DIRECTORIES','GIT_NAMESPACE')) {
        $saved[$name]=[Environment]::GetEnvironmentVariable($name,'Process')
        [Environment]::SetEnvironmentVariable($name,[NullString]::Value,'Process')
    }
    $saved['GIT_OPTIONAL_LOCKS']=[Environment]::GetEnvironmentVariable('GIT_OPTIONAL_LOCKS','Process')
    [Environment]::SetEnvironmentVariable('GIT_OPTIONAL_LOCKS','0','Process')
    try { return Get-WorkflowCloseoutPreviewCore @PSBoundParameters }
    finally {
        foreach ($name in $saved.Keys) {
            $value=if ($null -eq $saved[$name]) {[NullString]::Value} else {$saved[$name]}
            [Environment]::SetEnvironmentVariable($name,$value,'Process')
        }
    }
}

function Get-WorkflowCloseoutRemoteEvidence {
    param([string]$RepoRoot,$Preview,[string]$Remote,[switch]$AuthorizeRemoteChanges)
    $evidence=[pscustomobject]@{remote=$Remote; status='incomplete'; targetRevision=$null; sourceExists=$false; tagState='unknown'; tagObject=$null; reasons=@()}
    try {
        if (-not $AuthorizeRemoteChanges) { throw 'remote evidence query requires explicit remote authorization' }
        Assert-WorkflowCloseoutOfflineProofRepository $RepoRoot
        $configured=Invoke-WorkflowCloseoutGit $RepoRoot @('remote')
        if ($configured.ExitCode -or -not $Remote -or $Remote.StartsWith('-') -or $Remote -cnotin @($configured.Output -split '\r?\n')) { throw 'remote closeout requires an explicitly named configured remote' }
        if ($Preview.reasons.Count -or -not $Preview.branch -or $Preview.archiveTag.state -ne 'matching') { throw 'remote closeout requires current matching local annotated archive proof' }
        $localTag=Invoke-WorkflowCloseoutGit $RepoRoot @('rev-parse','--verify',"refs/tags/$($Preview.archiveTag.name)")
        if ($localTag.ExitCode) { throw 'local archive tag object is unavailable' }
        $evidence.tagObject=$localTag.Output.Trim()
        $captured=Get-WorkflowCloseoutArchiveTag $RepoRoot $Preview.archiveTag.name $Preview.packageId $Preview.baseRevision $Preview.acceptedRevision $Preview.targetBranch $Preview.landedRevision -TagObject $evidence.tagObject
        if ($captured.state -ne 'matching' -or $captured.objectId -cne $Preview.archiveTag.objectId) { throw 'local archive tag changed or captured annotation conflicts; retain remote refs and local proof' }
        $targetRef="refs/heads/$($Preview.targetBranch)"; $sourceRef="refs/heads/$($Preview.branch.name)"; $tagRef="refs/tags/$($Preview.archiveTag.name)"
        $inventory=Invoke-WorkflowCloseoutGit $RepoRoot @('ls-remote','--',$Remote,$targetRef,$sourceRef,$tagRef,"$tagRef^{}")
        if ($inventory.ExitCode) { throw "remote refs unavailable: $($inventory.Error.Trim())" }
        $refs=@{}
        foreach ($line in ($inventory.Output -split '\r?\n' | Where-Object { $_ })) {
            if ($line -notmatch '^([0-9a-f]{40,64})\s+(refs/\S+)$' -or $refs.ContainsKey($Matches[2])) { throw 'remote ref evidence is malformed or duplicated' }
            $refs[$Matches[2]]=$Matches[1]
        }
        if (-not $refs.ContainsKey($targetRef)) { $evidence.reasons+='remote target is missing; retain remote refs' }
        else {
            $evidence.targetRevision=$refs[$targetRef]
            Assert-WorkflowCloseoutLandingAncestor $RepoRoot $Preview.landedRevision $evidence.targetRevision 'the observed remote target'
        }
        $evidence.sourceExists=$refs.ContainsKey($sourceRef)
        if ($evidence.sourceExists -and $refs[$sourceRef] -cne $Preview.acceptedRevision) { $evidence.reasons+='remote source differs from accepted revision; preserve unpublished remote commits' }
        $evidence.tagState=if (-not $refs.ContainsKey($tagRef)) {'absent'}
            elseif ($refs[$tagRef] -ceq $evidence.tagObject -and $refs.ContainsKey("$tagRef^{}") -and $refs["$tagRef^{}"] -ceq $Preview.acceptedRevision) {'matching'}
            else {'conflicting'}
        if ($evidence.tagState -eq 'conflicting') { $evidence.reasons+='remote archive tag is lightweight, moved or conflicting; never overwrite it' }
        if (-not $evidence.sourceExists -and $evidence.tagState -ne 'matching') { $evidence.reasons+='remote source missing without matching preserved annotated archive proof' }
        if (-not $evidence.reasons.Count) { $evidence.status='verified' }
    } catch { $evidence.reasons+=$_.Exception.Message }
    return $evidence
}

function Invoke-WorkflowCloseoutRemoteActions {
    param([string]$RepoRoot,[hashtable]$PreviewParameters,[string]$Remote,[switch]$PushArchiveTag,[switch]$DeleteRemoteBranch,[switch]$AuthorizeRemoteChanges)
    if (-not $AuthorizeRemoteChanges) { return [pscustomobject]@{results=@([pscustomobject]@{action='remote reconciliation'; target=$Remote; status='retained'; reason='explicit remote authorization required'}); evidence=$null; complete=$false; status='incomplete'} }
    $results=@(); $remoteProof=$null; $deletionProof=$null
    foreach ($action in @('push archive tag','delete remote branch')) {
        if (($action -eq 'push archive tag' -and -not $PushArchiveTag) -or ($action -eq 'delete remote branch' -and -not $DeleteRemoteBranch)) { continue }
        $local=Get-WorkflowCloseoutPreview @PreviewParameters
        if ($action -eq 'delete remote branch' -and $local.cleanupHolds.Count) {
            $results+=[pscustomobject]@{action=$action; target=$Remote; status='retained'; reason='accepted package cleanup holds prohibit remote source deletion: '+($local.cleanupHolds -join '; ')}
            continue
        }
        $remoteProof=Get-WorkflowCloseoutRemoteEvidence $RepoRoot $local $Remote -AuthorizeRemoteChanges
        if ($remoteProof.status -ne 'verified') {
            $results+=[pscustomobject]@{action=$action; target=$Remote; status='retained'; reason=($remoteProof.reasons -join '; ')}; continue
        }
        $tagRef="refs/tags/$($local.archiveTag.name)"; $sourceRef="refs/heads/$($local.branch.name)"
        if ($action -eq 'push archive tag') {
            if ($remoteProof.tagState -eq 'matching') { $results+=[pscustomobject]@{action=$action; target="$Remote/$tagRef"; status='complete'; reason='matching annotated tag already preserved'}; continue }
            # An immutable object refspec and empty expected tag lease allow only
            # creation; a concurrent/conflicting tag can never be overwritten.
            $result=Invoke-WorkflowCloseoutGit $RepoRoot @('push','--porcelain',"--force-with-lease=${tagRef}:",'--',$Remote,"$($remoteProof.tagObject):$tagRef")
        } else {
            if ($remoteProof.tagState -ne 'matching') {
                $results+=[pscustomobject]@{action=$action; target="$Remote/$sourceRef"; status='retained'; reason='push matching annotated archive proof before remote source deletion'}; continue
            }
            if (-not $remoteProof.sourceExists) { $results+=[pscustomobject]@{action=$action; target="$Remote/$sourceRef"; status='complete'; reason='already absent with preserved annotated proof'}; continue }
            $targetRef="refs/heads/$($local.targetBranch)"
            $result=Invoke-WorkflowCloseoutGit $RepoRoot @('push','--atomic','--porcelain',"--force-with-lease=${sourceRef}:$($local.acceptedRevision)",
                "--force-with-lease=${targetRef}:$($remoteProof.targetRevision)","--force-with-lease=${tagRef}:$($remoteProof.tagObject)",'--',$Remote,
                "$($remoteProof.targetRevision):$targetRef","$($remoteProof.tagObject):$tagRef",":$sourceRef")
            if (-not $result.ExitCode) { $deletionProof=[pscustomobject]@{targetRevision=$remoteProof.targetRevision; tagObject=$remoteProof.tagObject} }
        }
        $results+=[pscustomobject]@{action=$action; target=$Remote; status=$(if ($result.ExitCode) {'retained'} else {'complete'}); reason=$result.Error.Trim()}
    }
    $local=Get-WorkflowCloseoutPreview @PreviewParameters
    $remoteProof=Get-WorkflowCloseoutRemoteEvidence $RepoRoot $local $Remote -AuthorizeRemoteChanges
    # Some servers omit unchanged target/tag refspecs from their transaction.
    # Leases plus --atomic therefore are not a claim of cross-ref isolation.
    # Always observe the final proof and expose a deletion whose proof changed.
    $snapshotChanged=$deletionProof -and ($remoteProof.targetRevision -cne $deletionProof.targetRevision -or $remoteProof.tagObject -cne $deletionProof.tagObject -or $remoteProof.tagState -ne 'matching')
    if ($remoteProof.status -ne 'verified' -or $snapshotChanged) {
        foreach ($result in $results | Where-Object { $_.action -eq 'delete remote branch' -and $_.status -eq 'complete' -and $_.reason -ne 'already absent with preserved annotated proof' }) {
            $result.status='incomplete'
            $changedReason=if ($snapshotChanged) {'captured target/tag snapshot changed after deletion'} else {$remoteProof.reasons -join '; '}
            $result.reason='deletion succeeded but proof changed; local archive retained; owner reconciliation required: '+$changedReason
        }
    }
    $complete=$remoteProof.status -eq 'verified' -and -not $snapshotChanged -and $remoteProof.tagState -eq 'matching' -and -not $remoteProof.sourceExists
    return [pscustomobject]@{results=$results; evidence=$remoteProof; complete=$complete; isolation='server no-op ref transaction isolation is unverified; owner/provider cooperation remains required'; status=$(if (@($results | Where-Object status -ne 'complete').Count -or $remoteProof.status -ne 'verified') {'incomplete'} else {'complete'})}
}

function Invoke-WorkflowCloseoutDeleteBranch {
    param([string]$RepoRoot,$Preview)
    # branch.merge is multivalued: command -c appends and Git uses its first
    # entry. A temporary child-only system config places immutable archive proof
    # first, without changing repository/global branch policy. The native -d
    # path still checks worktree use and whether a racing tip is in this proof.
    $path=$null; $hookPath=$null; $directory=$null; $proofLock=$null; $result=$null
    try {
        Assert-WorkflowCloseoutOfflineProofRepository $RepoRoot
        $version=Invoke-WorkflowCloseoutGit $RepoRoot @('version')
        if ($version.ExitCode -or $version.Output -notmatch 'git version (\d+)\.(\d+)' -or [version]::new([int]$Matches[1],[int]$Matches[2]) -lt [version]'2.29') { throw 'Git reference-transaction hooks require version 2.29 or newer; preserve this branch' }
        $existing=Invoke-WorkflowCloseoutGit $RepoRoot @('rev-parse','--path-format=absolute','--git-path','hooks/reference-transaction')
        if ($existing.ExitCode) { throw 'effective reference-transaction hook path is unknown; preserve this branch' }
        Assert-WorkflowNoLinks ([IO.Path]::GetTempPath())
        $directory=Join-Path ([IO.Path]::GetTempPath()) ('workflow-closeout-'+[guid]::NewGuid().ToString('N'))
        $null=[IO.Directory]::CreateDirectory($directory)
        Assert-WorkflowNoLinks $directory
        $path=Join-Path $directory 'proof.config'
        $hookPath=Join-Path $directory 'reference-transaction'
        Assert-WorkflowNoLinks $path
        $name=$Preview.branch.name.Replace('\','\\').Replace('"','\"')
        $tag=("refs/tags/$($Preview.archiveTag.name)").Replace('\','\\').Replace('"','\"')
        $text='[branch "'+$name+'"]'+"`n"+'    merge = "'+$tag+'"'+"`n"
        [IO.File]::WriteAllText($path,$text,[Text.UTF8Encoding]::new($false))
        $hook=@'
#!/bin/sh
records=$(cat) || exit 1
if [ -x __EXISTING__ ]; then
    printf '%s\n' "$records" | __EXISTING__ "$@"
    owner_status=$?
    [ "$owner_status" = 0 ] || exit "$owner_status"
fi
if [ "$1" = prepared ]; then
    # Do not use a requested-name prefix: on case-insensitive filesystems an
    # alias can resolve the expected OID while literal ownership has changed.
    inventory=$(git for-each-ref --format='%(refname) %(objectname) %(symref)') || exit 1
    validate_literal_ref() {
        expected_ref=$1
        expected_oid=$2
        non_ascii=$(printf '%s' "$expected_ref" | LC_ALL=C tr -d '\040-\176') || return 1
        [ -z "$non_ascii" ] || return 1
        folded_expected=$(printf '%s' "$expected_ref" | LC_ALL=C tr '[:upper:]' '[:lower:]') || return 1
        found=no
        while IFS=' ' read -r literal oid symbolic; do
            folded_literal=$(printf '%s' "$literal" | LC_ALL=C tr '[:upper:]' '[:lower:]') || return 1
            if [ "$folded_literal" = "$folded_expected" ] && [ "$literal" != "$expected_ref" ]; then
                return 1
            fi
            if [ "$literal" = "$expected_ref" ]; then
                [ "$found" = no ] && [ -z "$symbolic" ] && [ "$oid" = "$expected_oid" ] || return 1
                found=yes
            fi
        done <<CLOSEOUT_LITERAL_REFS
$inventory
CLOSEOUT_LITERAL_REFS
        [ "$found" = yes ]
    }
    source_record=no
    while IFS=' ' read -r old new ref; do
        if [ "$ref" = __REF__ ]; then
            source_record=yes
            # Native branch -d can omit expected-old and report a zero oldOID.
            # At prepared, Git holds this ref's lock; resolve its actual current
            # value under that lock instead of treating zero as accepted proof.
            actual=$(git rev-parse --verify "$ref^{commit}") || exit 1
            case "$old" in
                __ACCEPTED__|0000000000000000000000000000000000000000|0000000000000000000000000000000000000000000000000000000000000000) ;;
                *) actual=unknown-old-value ;;
            esac
            if [ "$actual" != __ACCEPTED__ ]; then
                echo 'closeout-ref-changed: exact accepted source tip changed under the ref lock; branch retained' >&2
                exit 1
            fi
        fi
    done <<CLOSEOUT_REF_RECORDS
$records
CLOSEOUT_REF_RECORDS
    if [ "$source_record" != yes ]; then
        echo 'closeout-ref-ownership: expected literal source is missing from the prepared transaction; branch retained' >&2
        exit 1
    fi
    # Source is locked by native -d; target/tag by the held verify-only
    # transaction. All three must still be literal, direct refs at these OIDs.
    if ! validate_literal_ref __REF__ __ACCEPTED__ ||
       ! validate_literal_ref __TARGET_REF__ __TARGET_REVISION__ ||
       ! validate_literal_ref __TAG_REF__ __TAG_OBJECT__; then
        echo 'closeout-ref-ownership: exact literal direct source/target/archive ref changed under the ref locks; branch retained' >&2
        exit 1
    fi
    # Native -d compares logical branch names. Independently observe registered
    # HEAD aliases at prepared state; this does not lock HEADs or assert global
    # isolation against a later noncooperating checkout edit.
    worktrees=$(git -c core.quotePath=true worktree list --porcelain) || {
        echo 'closeout-worktree-ownership: registered worktree inventory unavailable; branch retained' >&2
        exit 1
    }
    folded_source=$(printf '%s' __REF__ | LC_ALL=C tr '[:upper:]' '[:lower:]') || exit 1
    validate_checkout() {
        [ "$checkout_started" = yes ] || return 0
        case "$checkout_head" in ''|*[!0-9a-f]*) return 1 ;; esac
        case "${#checkout_head}" in 40|64) ;; *) return 1 ;; esac
        if [ -n "$checkout_branch" ]; then
            [ "$checkout_state" = attached ] || return 1
            folded_branch=$(printf '%s' "$checkout_branch" | LC_ALL=C tr '[:upper:]' '[:lower:]') || return 1
            if [ "$folded_branch" = "$folded_source" ]; then
                echo 'closeout-worktree-ownership: registered checkout uses exact or case-alias source ref; branch retained' >&2
                return 1
            fi
            if [ "$checkout_head" = __ACCEPTED__ ] && ! validate_literal_ref "$checkout_branch" "$checkout_head"; then
                echo 'closeout-worktree-ownership: accepted-head checkout has unresolved direct ASCII branch ownership; branch retained' >&2
                return 1
            fi
        else
            [ "$checkout_state" = detached ] || return 1
            if [ "$checkout_head" = __ACCEPTED__ ]; then
                echo 'closeout-worktree-ownership: accepted-head detached checkout requires separate preservation reconciliation; branch retained' >&2
                return 1
            fi
        fi
        return 0
    }
    checkout_seen=no
    checkout_started=no
    checkout_head=
    checkout_branch=
    checkout_state=
    while IFS= read -r line; do
        case "$line" in
            'worktree '*)
                validate_checkout || {
                    echo 'closeout-worktree-ownership: registered checkout ownership is unresolved; branch retained' >&2
                    exit 1
                }
                checkout_seen=yes; checkout_started=yes; checkout_head=; checkout_branch=; checkout_state=
                ;;
            'HEAD '*)
                [ "$checkout_started" = yes ] && [ -z "$checkout_head" ] || exit 1
                checkout_head=${line#HEAD }
                ;;
            'branch '*)
                [ "$checkout_started" = yes ] && [ -z "$checkout_state" ] || exit 1
                checkout_branch=${line#branch }; checkout_state=attached
                ;;
            detached)
                [ "$checkout_started" = yes ] && [ -z "$checkout_state" ] || exit 1
                checkout_state=detached
                ;;
            locked|'locked '*|prunable|'prunable '*|'') ;;
            *)
                echo 'closeout-worktree-ownership: registered worktree inventory malformed or unsupported; branch retained' >&2
                exit 1
                ;;
        esac
    done <<CLOSEOUT_WORKTREES
$worktrees
CLOSEOUT_WORKTREES
    if [ "$checkout_seen" != yes ] || ! validate_checkout; then
        echo 'closeout-worktree-ownership: registered checkout ownership is unresolved; branch retained' >&2
        exit 1
    fi
fi
exit 0
'@
        $shellRef="'"+("refs/heads/$($Preview.branch.name)").Replace("'","'\''")+"'"
        $shellAccepted="'"+$Preview.acceptedRevision+"'"
        $shellExisting="'"+$existing.Output.Trim().Replace('\','/').Replace("'","'\''")+"'"
        $shellTarget="'"+("refs/heads/$($Preview.targetBranch)").Replace("'","'\''")+"'"
        $shellTag="'"+("refs/tags/$($Preview.archiveTag.name)").Replace("'","'\''")+"'"
        $hook=$hook.Replace('__REF__',$shellRef).Replace('__ACCEPTED__',$shellAccepted).Replace('__EXISTING__',$shellExisting).
            Replace('__TARGET_REF__',$shellTarget).Replace('__TARGET_REVISION__',("'"+$Preview.targetRevision+"'")).
            Replace('__TAG_REF__',$shellTag).Replace('__TAG_OBJECT__',("'"+$Preview.archiveTag.objectId+"'"))
        [IO.File]::WriteAllText($hookPath,($hook -replace "`r`n","`n")+"`n",[Text.UTF8Encoding]::new($false))
        if (-not $IsWindows) { [IO.File]::SetUnixFileMode($hookPath,([IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite -bor [IO.UnixFileMode]::UserExecute)) }
        $proofLock=Start-WorkflowCloseoutProofLock $RepoRoot $Preview
        $result=Invoke-WorkflowCloseoutGit $RepoRoot @('-c',"branch.$($Preview.branch.name).remote=.",'-c',"core.hooksPath=$directory",'branch','-d','--',$Preview.branch.name) @{GIT_CONFIG_SYSTEM=$path; GIT_CONFIG_NOSYSTEM=$null}
    } catch { $result=[pscustomobject]@{ExitCode=1; Output=''; Error="local branch retained: temporary proof configuration failed: $($_.Exception.Message)"} }
    finally {
        if ($proofLock) {
            $release=Stop-WorkflowCloseoutProofLock $proofLock
            if ($release) { $result.ExitCode=1; $result.Error+=" $release" }
        }
        foreach ($temporary in @($hookPath,$path) | Where-Object { $_ }) {
            try { Assert-WorkflowNoLinks $temporary; [IO.File]::Delete($temporary) }
            catch { $result.ExitCode=1; $result.Error+=" temporary proof residue requires explicit single-file cleanup: $temporary" }
        }
        if ($directory) {
            try { Assert-WorkflowNoLinks $directory; [IO.Directory]::Delete($directory) }
            catch { $result.ExitCode=1; $result.Error+=" temporary proof directory retained; no recursive fallback: $directory" }
        }
    }
    return $result
}

function Invoke-WorkflowCloseout {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RepoRoot,[Parameter(Mandatory)][string]$PackageId,
        [string]$AcceptedRevision,[string]$BaseRevision,[string]$LandedRevision,[switch]$OwnerConfirmed,
        [switch]$Apply,[switch]$AuthorizeLocalCleanup,[switch]$RemoveWorktrees,[switch]$DeleteLocalBranch,
        [switch]$AuthorizeRemoteChanges,[string]$Remote,[switch]$PushArchiveTag,[switch]$DeleteRemoteBranch)
    $parameters=@{RepoRoot=$RepoRoot; PackageId=$PackageId; AcceptedRevision=$AcceptedRevision; BaseRevision=$BaseRevision; LandedRevision=$LandedRevision; OwnerConfirmed=$OwnerConfirmed}
    $preview=Get-WorkflowCloseoutPreview @parameters
    if (-not $Apply) { return $preview }
    $localSelected=$RemoveWorktrees -or $DeleteLocalBranch
    $remoteSelected=$PushArchiveTag -or $DeleteRemoteBranch
    if (-not $localSelected -and -not $remoteSelected) {
        $preview.status='incomplete'; $preview.reasons+='apply requires explicit local cleanup authorization for local actions and at least one selected action'; return $preview
    }
    if ($localSelected -and -not $AuthorizeLocalCleanup) {
        if (-not ($remoteSelected -and $AuthorizeRemoteChanges -and $Remote)) {
            $preview.status='incomplete'; $preview.reasons+='apply requires explicit local cleanup authorization for local actions and at least one selected action'; return $preview
        }
        # A missing local grant must not suppress a separately authorized remote
        # action. Record each denied local action and suppress its mutations;
        # archive preservation for the authorized remote path remains allowed.
        if ($RemoveWorktrees) { $preview.results+=[pscustomobject]@{action='remove worktree'; target=$RepoRoot; status='retained'; reason='selected worktree removal requires explicit local cleanup authorization'} }
        if ($DeleteLocalBranch) { $preview.results+=[pscustomobject]@{action='delete local branch'; target=$(if ($preview.branch) {$preview.branch.name} else {$PackageId}); status='retained'; reason='selected local branch deletion requires explicit local cleanup authorization'} }
        $preview.localStatus='incomplete'
        $RemoveWorktrees=$false; $DeleteLocalBranch=$false; $localSelected=$false
    }
    if ($remoteSelected -and (-not $AuthorizeRemoteChanges -or -not $Remote)) {
        $preview.remoteStatus='incomplete'
        $preview.results+=[pscustomobject]@{action='remote reconciliation'; target=$Remote; status='retained'; reason='selected remote actions require explicit remote authorization and a configured remote name'}
        if (-not $localSelected) { $preview.status='incomplete'; return $preview }
    }
    $results=@()
    $results+=@($preview.results)
    if ($preview.reasons.Count -or $preview.proofMethod -eq 'unknown') { return $preview }
    # Freeze resolved commits: a moving revision such as HEAD cannot silently
    # authorize a different accepted/landed commit during immediate revalidation.
    $parameters.AcceptedRevision=$preview.acceptedRevision; $parameters.BaseRevision=$preview.baseRevision; $parameters.LandedRevision=$preview.landedRevision
    if ($preview.archiveTag.state -eq 'absent') {
        $fresh=Get-WorkflowCloseoutPreview @parameters
        if ($fresh.reasons.Count -or $fresh.proofMethod -eq 'unknown') { return $fresh }
        $message=[ordered]@{version=1; packageId=$fresh.packageId; baseRevision=$fresh.baseRevision; acceptedRevision=$fresh.acceptedRevision;
            targetBranch=$fresh.targetBranch; landedRevision=$fresh.landedRevision; proofMethod=$fresh.proofMethod; date=[datetime]::UtcNow.ToString('o')} | ConvertTo-Json -Compress
        $result=Invoke-WorkflowCloseoutGit $RepoRoot @('-c','tag.gpgsign=false','tag','-a',$fresh.archiveTag.name,$fresh.acceptedRevision,'-m',$message)
        $results+=[pscustomobject]@{action='archive tag'; target=$fresh.archiveTag.name; status=$(if ($result.ExitCode) {'incomplete'} else {'complete'}); reason=$result.Error.Trim()}
        if ($result.ExitCode) { $fresh.status='incomplete'; $fresh.reasons+='archive tag creation failed; all source cleanup retained'; $fresh.results=$results; return $fresh }
    }
    if ($RemoveWorktrees) {
        foreach ($candidate in $preview.worktrees) {
            $fresh=Get-WorkflowCloseoutPreview @parameters
            if ($fresh.reasons.Count) {
                $results+=[pscustomobject]@{action='remove worktree'; target=$candidate.path; status='retained'; reason=($fresh.reasons -join '; ')}; continue
            }
            $current=@($fresh.worktrees | Where-Object path -eq $candidate.path)
            if (-not $current.Count) { $results+=[pscustomobject]@{action='remove worktree'; target=$candidate.path; status='complete'; reason='already absent'}; continue }
            if ($fresh.reasons.Count -or -not $current[0].eligible -or $fresh.archiveTag.state -ne 'matching') {
                $reasons=@($fresh.reasons)+@($current[0].reasons)
                if ($fresh.archiveTag.state -ne 'matching') { $reasons+='matching annotated archive proof is required immediately before removal' }
                $results+=[pscustomobject]@{action='remove worktree'; target=$candidate.path; status='retained'; reason=($reasons -join '; ')}; continue
            }
            $result=Invoke-WorkflowCloseoutGit $RepoRoot @('worktree','remove','--',$candidate.path)
            $results+=[pscustomobject]@{action='remove worktree'; target=$candidate.path; status=$(if ($result.ExitCode) {'retained'} else {'complete'}); reason=$result.Error.Trim()}
        }
    }
    if ($DeleteLocalBranch) {
        $fresh=Get-WorkflowCloseoutPreview @parameters
        if ($fresh.branch -and -not $fresh.branch.exists -and $fresh.archiveTag.state -eq 'matching' -and -not $fresh.reasons.Count) {
            $results+=[pscustomobject]@{action='delete local branch'; target=$fresh.branch.name; status='complete'; reason='already absent'}
        } elseif ($fresh.branch -and $fresh.branch.eligible -and $fresh.archiveTag.state -eq 'matching' -and -not $fresh.reasons.Count) {
            $result=Invoke-WorkflowCloseoutDeleteBranch $RepoRoot $fresh
            $results+=[pscustomobject]@{action='delete local branch'; target=$fresh.branch.name; status=$(if ($result.ExitCode) {'retained'} else {'complete'}); reason=$result.Error.Trim()}
        } else { $results+=[pscustomobject]@{action='delete local branch'; target=$(if ($fresh.branch) {$fresh.branch.name} else {$PackageId}); status='retained'; reason=(@($fresh.reasons)+@($fresh.branch.reasons) -join '; ')} }
    }
    $remoteResult=$null
    if ($remoteSelected -and $AuthorizeRemoteChanges -and $Remote) {
        $remoteResult=Invoke-WorkflowCloseoutRemoteActions -RepoRoot $RepoRoot -PreviewParameters $parameters -Remote $Remote -PushArchiveTag:$PushArchiveTag -DeleteRemoteBranch:$DeleteRemoteBranch -AuthorizeRemoteChanges
        $results+=@($remoteResult.results)
    }
    $final=Get-WorkflowCloseoutPreview @parameters; $final.results=$results
    if ($final.reasons.Count -or @($results | Where-Object status -ne 'complete').Count) { $final.status='incomplete' }
    elseif ((-not $DeleteLocalBranch -or -not $final.branch.exists) -and (-not $RemoveWorktrees -or -not $final.worktrees.Count)) { $final.status='complete' }
    else { $final.status='incomplete' }
    $localFailures=@($results | Where-Object { $_.action -in @('archive tag','remove worktree','delete local branch') -and $_.status -ne 'complete' })
    $final.localStatus=if ($localFailures.Count -or $final.reasons.Count -or ($DeleteLocalBranch -and $final.branch.exists) -or ($RemoveWorktrees -and $final.worktrees.Count)) {'incomplete'} else {'complete'}
    if ($remoteResult) {
        $final.networkActionsEnabled=$true; $final.remoteStatus=$remoteResult.status; $final.remoteIsolation=$remoteResult.isolation
        if ($remoteResult.complete) {
            $final.remoteBranches=@($final.remoteBranches | Where-Object { $_.remote -cne $Remote })
            $final.unknownRemotes=@($final.unknownRemotes | Where-Object { $_ -cne $Remote })
            $final.remoteInventory=if ($final.unknownRemotes.Count) {'unknown; other configured remotes remain unverified'} else {'authorized selected remote verified'}
        }
    } elseif ($remoteSelected) { $final.remoteStatus='incomplete' }
    if ($final.status -eq 'complete' -and ($final.branch.exists -or $final.worktrees.Count -or $final.remoteBranches.Count -or $final.remoteInventory.StartsWith('unknown'))) { $final.status='incomplete' }
    return $final
}
