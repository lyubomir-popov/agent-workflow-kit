# CP3 review: Spec 001 slice B

**Checkpoint**: CP3
**Scope**: `001/spec-r2`
**Reviewed revision**: `af8ed58ba17a0dff944c9f87e7774ac670234984`
**Reviewer**: Cline agent in VS Code, run at the owner's request as the CP3 reviewer; model identity is not independently attested
**Verdict**: accept with bounded corrections

Compared range: `dce8394..af8ed58`. `9e1819c` changes metadata only. This review
does not clear CP3; only the owner can.

## Summary

Slice B is fail-closed throughout. In every probe, unknown, changed or conflicting
evidence kept the worktree and branch. The proof model, preservation inventory,
literal-ref guards, staged-index hook scope and CI event ranges match FR-019–024
and the carryovers.

One gap breaks FR-024 (R1), and it combines badly with a slice A behavior (R2).
Both are safe: they only retain, never delete. They make closeout unusable in the
ordinary case where the target branch advances after landing. Correct both before
slice C rolls closeout out to consumers.

## Reproduced

- Full suite: `Passed: 258 Failed: 0 Skipped: 0` (1635.53 s).
- Strict lint: 0 errors, 0 warnings, 1 info. Dry run: target=main, manual T045,
  zero workers.
- `git diff --check dce8394..HEAD`: clean. Tree clean; main/master are `864cad5`.
- The slice A probes (ADV-1/2/3) still fail closed.
- No live cleanup, push or remote query. Every probe below ran in a disposable
  fixture repository.

## Findings

### CP3-R1 (major). Closeout cannot resume once the target advances

Refs: FR-024 ("resumable/idempotent", "Retry MUST reuse preserved proof safely"),
FR-020. Code: `workflow-closeout.ps1:300`, `:249-276` and `:712-723`.

Preview requires the landed revision to equal the current target tip (`:300`).
The archive tag's metadata pins `landedRevision` (`:272`), and a tag is matching
only if that value equals the current input. Probe results:
1. Preview at landing L1 is eligible (ancestry).
2. A first apply without `-DeleteLocalBranch` creates `archive/001-example`; the
   branch is retained.
3. One unrelated commit lands on the target (L2).
4. A retry with L1 is incomplete: "landed revision differs from current configured target".
5. A retry with L2 is incomplete: the tag is now "conflicting" (moved/conflicting proof).
6. A retry with L2 and `-OwnerConfirmed` is still conflicting.

No input completes closeout without deleting the archive tag by hand. Step 2 can
come from an interrupted run, a lock or hold on one worktree, or the owner tagging
before landing. On any active target, the target almost always advances first. This
is the documented resume path, and it fails.

Correction:
- Accept a landed revision that is an ancestor of the current literal target tip,
  and still check its exact equality or ancestry evidence.
- Treat a tag whose recorded landed revision is an ancestor of the current target
  as matching, and reuse that proof.
- Remote evidence should check `ancestor-of-remote-target` the same way.
- Add an interrupt → target-advance → retry fixture, for both ancestry and squash.

### CP3-R2 (major). Squash closeout needs the target frozen after landing

Refs: FR-020, FR-004 amendment (target registration). Code: `workflow-closeout.ps1:300,318`.

Squash proof compares the changed paths of `base..accepted` with the landed tree.
With R1, the only admissible landed value is the current tip. The source changes
`docs/specs.md` (archive row), and so does any later target commit that touches
the catalog, such as the next package's creation registration. Probe results:
- A squash landing with the tip equal to the squash commit gives changed-path equality.
- After a catalog-only registration commit, the squash commit as landed is rejected
  (R1). The current tip as landed fails equality, and owner confirmation is needed.

Every squash closeout started after the next package's registration therefore
requires owner confirmation.

Correction: after R1, compare against the identified landing commit (which must be
an ancestor of the target) rather than the tip. Fixture: squash, then a
registration commit, then closeout.

### CP3-R3 (minor). Closeout's docs omit the resume procedure

Refs: FR-024. Code: `README.md:189-235`.

The README says "Retry reuses matching proof", but gives no procedure:
- which landed revision to pass on retry;
- how to recover from a conflicting tag that closeout itself created.

The retention reasons ("refresh the exact landing evidence", "preserve it and resolve
explicitly") point the operator into the R1 loop. After R1/R2 land, document the
resume procedure.

## Checked without findings

These items come from code inspection plus the passing suite's fixtures. They were
not probed independently; only R1/R2 were.

- Proof: ancestry, squash changed-path equality and owner confirmation are each
  covered. Add, delete, rename, mode and Unicode wildcard-like paths use literal
  NUL-delimited pathspecs and strict UTF-8 decoding. A moved target, unrelated
  histories and an unavailable base all retain the source.
- Ref ownership: non-ASCII, differently cased, symbolic and duplicate literal refs
  are rejected. The prepared reference-transaction hook rechecks the source, target
  and archive refs under the locks, plus registered checkout aliases. Git < 2.29
  retains the branch.
- Preservation: the primary, invoking, locked, held, unpublished, dirty, linked and
  protected-evidence trees are retained. Dependency directories are scanned once,
  with a bound. No recursive fallback exists.
- Hook/CI: affected-package index scope is respected. Root/config/catalog edits
  widen the scope, and unrelated unstaged bytes are ignored. Missing nonzero event
  revisions fail.
- Remote: actions run only with explicit authorization and a configured remote.
  Leased atomic pushes are used, and when the server omits unchanged proof refs the
  result is reported incomplete. BQA-06 isolation stays an owner/provider question,
  as recorded.

## Owner decisions

1. Accept the R1/R2 corrections within slice B before clearing CP3. Recommended:
   closeout is currently unusable in the normal advancing-target case.
2. Alternatively, clear CP3 and require R1–R3 as the first slice C tasks, before any
   consumer rollout.
3. BQA-06 policy, Linux and remote CI remain owner/provider items, independent of CP3.

No gate was cleared, no commit or push made, and no slice C work started.
