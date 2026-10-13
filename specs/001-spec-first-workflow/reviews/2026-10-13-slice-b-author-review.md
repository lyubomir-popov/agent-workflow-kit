# Slice B author and delegated QA findings

**Checkpoint**: CP3
**Scope**: `001/spec-r2`
**Reviewed revision**: `af8ed58ba17a0dff944c9f87e7774ac670234984`
**Reviewer**: Codex, Spec 001 implementer, with bounded delegated QA
**Verdict**: author-ready for owner-run CP3 review; no checkpoint acceptance

Date: 2026-10-13. Compare `dce8394..af8ed58ba17a0dff944c9f87e7774ac670234984`. Slice B code/fixture work
is complete under [owner approval](2026-10-12-slice-b-plan-approval.md);
Spec 001 remains active and CP3 remains pending. This is not an Opus review.
No live cleanup, unattended worker, merge, push, consumer edit, prompt install,
vendor edit, remote-default change or slice C implementation occurred.

## Provenance and scope

The closeout and preservation implementers used `gpt-6.1-sol` for complex Git
proof/preservation work. The staged-hook implementer used `gpt-5.6-sol`.
Preservation independently reviewed root-owned archive/CI/CLI changes;
staged_hook independently reviewed closeout, which it did not implement.
Root integrated, reproduced findings, repaired the code and performed its own
adversarial checks. Worker summaries were checked against actual diffs/fixtures.
All fixture windows were sequential; the full suite validates the integrated
working checkout before each area commit. No independent Opus verdict is claimed.

Read [validation and FR/test map](../evidence/slice-b-validation.md),
[dispositions](2026-10-13-cp3-author-dispositions.md),
[plan](../plan.md#slice-b-plan-for-owner-approval), and
[review request](2026-10-13-opus-slice-b-review-request.md).

## Complete finding register

### BQA-01 — Major

- Provenance: preservation (independent of root).
- Finding: Quoted/newline Git filenames could evade archived-package prefix checks for non-ASCII paths.
- Correction: NUL-delimited changed/untracked inventories and exact archive ownership checks.
- Verification: Carryover.Tests.ps1: quoted Unicode archive path.
- Code: `af8ed58ba17a0dff944c9f87e7774ac670234984`.
- Disposition: fixed for author validation; CP3 acceptance remains owner-only.

### BQA-02 — Minor

- Provenance: preservation.
- Finding: Human closeout output omitted base, accepted/landed revisions and archive tag identity/state.
- Correction: Human output includes exact evidence plus separate local/remote outcomes.
- Verification: Carryover.Tests.ps1: CLI JSON/human preview and unauthorized apply.
- Code: `17b3535` (additional CLI fixture at `af8ed58ba17a0dff944c9f87e7774ac670234984`).
- Disposition: fixed for author validation; CP3 acceptance remains owner-only.

### BQA-03 — Coverage

- Provenance: preservation.
- Finding: CI tests lacked a genuinely diverged PR, unavailable/unrelated PR histories and nested root whitespace.
- Correction: Added those offline event fixtures; recursive root comparison checks nested files.
- Verification: CI.Tests.ps1: divergent PR, unavailable/unrelated histories, nested root.
- Code: `af8ed58ba17a0dff944c9f87e7774ac670234984`.
- Disposition: fixed for author validation; CP3 acceptance remains owner-only.

### BQA-04 — Major

- Provenance: staged_hook (independent of closeout).
- Finding: Native branch -d could delete a source ref concurrently moved to an ancestor of the accepted revision.
- Correction: Prepared reference-transaction guard resolves the exact source tip while Git holds its lock; native checkout protection remains.
- Verification: Closeout.Tests.ps1: ancestor tip race, unpublished tip race, newly checked-out branch.
- Code: `17b3535`.
- Disposition: fixed for author validation; CP3 acceptance remains owner-only.

### BQA-05 — Major

- Provenance: staged_hook.
- Finding: A locally moved tag at the remote capture boundary could supply a different annotation object.
- Correction: Revalidate the captured immutable object type, peel, exact metadata and preview object ID before pushing that immutable ID.
- Verification: Closeout.Tests.ps1: captured immutable annotation race.
- Code: `17b3535`.
- Disposition: fixed for author validation; CP3 acceptance remains owner-only.

### BQA-06 — Major; bounded residual

- Provenance: staged_hook.
- Finding: Source-only remote deletion leases did not protect target/tag proof changing at the push boundary.
- Correction: Atomic source/target/tag refspecs with narrow leases and final evidence query; if a server omits unchanged refs and deletion succeeds with changed proof, report the actual deletion as incomplete and preserve local archive.
- Verification: Closeout.Tests.ps1: atomic proof-ref races and server no-op omission.
- Code: `17b3535`.
- Disposition: bounded residual; Cross-ref server isolation remains unverified. Repository owner/provider must resolve live-operation policy; this session authorizes no remote mutation.

### BQA-07 — Major

- Provenance: root integration.
- Finding: Command config appends multivalued branch.merge; the existing first merge entry could defeat archive-based native deletion proof.
- Correction: Child-only temporary system config places archive merge proof first; preserves persistent config and composes the caller hook.
- Verification: Closeout.Tests.ps1: squash deletion with configured upstream, unpublished race and caller hook.
- Code: `17b3535`.
- Disposition: fixed for author validation; CP3 acceptance remains owner-only.

### BQA-08 — Major

- Provenance: root integration.
- Finding: Archive/target proof could move between preview and local source deletion.
- Correction: Verify-only prepared transactions hold both proof refs stable while the native source deletion runs; unsupported capability retains source.
- Verification: Closeout.Tests.ps1: stable archive/landed proof locks and unsupported locks.
- Code: `17b3535`.
- Disposition: fixed for author validation; CP3 acceptance remains owner-only.

### BQA-09 — Major

- Provenance: root integration.
- Finding: Replacement decoding of invalid Git filename bytes could yield false path equality.
- Correction: Strict UTF-8 decoding fails to unknown/incomplete; drain subprocess bytes before decoding to avoid blocked pipes.
- Verification: Closeout.Tests.ps1: exact Unicode wildcard-like paths and decoder failure.
- Code: `17b3535`.
- Disposition: fixed for author validation; CP3 acceptance remains owner-only.

### BQA-10 — Minor

- Provenance: root integration.
- Finding: A suffix-lookalike cached ref could fabricate remote ownership of the delivery branch.
- Correction: Match exact configured remote plus exact source ref; uncached configured remotes remain unknown.
- Verification: Closeout.Tests.ps1: suffix-lookalike remote ref.
- Code: `17b3535`.
- Disposition: fixed for author validation; CP3 acceptance remains owner-only.

### BQA-11 — Major

- Provenance: root integration.
- Finding: Preview silently omitted associated detached and marked scratch trees while computing package completion.
- Correction: Retain accepted-head detached/unknown and source-associated marked scratch candidates; do not inherit delivery remove/force permission, preserve branch, allow independent eligible worktrees.
- Verification: Closeout.Tests.ps1: retained detached/scratch/unknown association Describe (3 cases).
- Code: `17b3535`.
- Disposition: fixed for author validation; CP3 acceptance remains owner-only.

### BQA-12 — Major

- Provenance: root integration.
- Finding: Accepted package cleanup holds were local branch reasons only, so authorized remote source deletion could ignore them.
- Correction: Expose accepted cleanupHolds and recheck them before remote deletion; separately authorized archive preservation remains allowed. Working-copy hold deletion cannot cancel accepted holds.
- Verification: Closeout.Tests.ps1: remote held source and deleted working hold.
- Code: `17b3535`.
- Disposition: fixed for author validation; CP3 acceptance remains owner-only.

### BQA-13 — Major

- Provenance: targeted fixture diagnosis.
- Finding: After UTC day 12, automatic ISO JSON DateTime decoding followed by en-GB string reparsing falsely conflicted valid archive annotations.
- Correction: Accept typed DateTime/DateTimeOffset or invariant parsed strings only, retaining all exact object/revision checks and rejecting malformed calendars.
- Verification: Closeout.Tests.ps1: deterministic day13/en-GB and February30 rejection.
- Code: `17b3535`.
- Disposition: fixed for author validation; CP3 acceptance remains owner-only.

### BQA-14 — Major

- Provenance: root integration.
- Finding: PowerShell case-insensitive comparison could treat an archived edit branch as a case-distinct configured target.
- Correction: Exact case-sensitive target and delivery-transition branch comparisons.
- Verification: Carryover.Tests.ps1: differently cased target.
- Code: `af8ed58ba17a0dff944c9f87e7774ac670234984`.
- Disposition: fixed for author validation; CP3 acceptance remains owner-only.

### BQA-15 — Integration

- Provenance: root integration.
- Finding: Preservation needed immutable BOM-aware holds and per-package delivery scope; unrelated holds must not prevent independent cleanup.
- Correction: Shared blob decoder, accepted/base hold checks, scoped delivery holds, conservative scratch holds and shallow bounded link-safe inventory.
- Verification: Preservation.Tests.ps1: encoded/scoped/base holds, directory summaries, nested evidence and links.
- Code: `2a4a6ef`.
- Disposition: fixed for author validation; CP3 acceptance remains owner-only.

### BQA-16 — Integration

- Provenance: root integration.
- Finding: Index snapshots needed correct environment restoration, source cached remote inventory and valid command-only creation registration context; affected-package filtering initially required unrelated untracked reviews.
- Correction: Restore unset env values correctly; preserve exact refs and remote names without fetch URLs; forward only validated command hint; explicit affected-package filtering.
- Verification: HookScope.Tests.ps1 (13 cases), Hook.Tests.ps1 and SpecKit.Tests.ps1 real-hook registration.
- Code: `af8ed58ba17a0dff944c9f87e7774ac670234984`.
- Disposition: fixed for author validation; CP3 acceptance remains owner-only.

### BQA-17 — Blocking (fixed before CP3)

- Provenance: root integration and closeout inspection.
- Finding: Windows physical ref lookup resolves case aliases; matching OIDs plus case-sensitive worktree mapping can overlook a checked-out source or misname proof refs. Old-code private fixture apply actually deleted a checked-out lowercase primary source through an uppercase declaration and reported complete; production refs were never mutated. The inverse case (exact lowercase literal source with uppercase worktree HEAD alias) was also found by final inspection: case-sensitive routing omitted it, so ref-only prepared checks were insufficient. An old-code private inverse probe likewise reported eligible/no worktrees and complete after deleting the checked-out physical source, with final source resolution exit 128; kit refs were not touched.
- Correction: Full literal ASCII ref inventory rejects case aliases, case siblings and symbolic/dangling ownership; no-deref proof locks plus composed prepared hook revalidate exact source/target/tag names and OIDs. Non-ASCII ref names retain conservatively, without restricting Unicode filenames. Retain checked-out source aliases and independently revalidate registered worktree checkout names in the prepared deletion guard.
- Verification: Closeout.Tests.ps1: 'Closeout literal ref ownership and prepared deletion guards' (13 cases) and 'Closeout registered checkout ref ownership' (8 cases), including inverse primary/linked aliases, late checkout guards, unknown inventory and quoted Unicode paths.
- Code: `af8ed58ba17a0dff944c9f87e7774ac670234984`.
- Disposition: fixed for author validation; CP3 acceptance remains owner-only.

## Final assessment and remaining boundaries

All concrete local blockers above have regression coverage. The exact ref-case
failure was reproduced only in a disposable fixture: old code declared an
uppercase source while the primary checked-out literal source was lowercase;
preview omitted it and native deletion removed that checked-out physical ref.
The probes did not mutate kit refs; main/master remain unchanged. The corrected thirteen
ownership cases passed 13/13 in 66.11s before full validation.
Final checkout guards additionally passed 8/8 in 73.02s; the earlier 13 cases
passed unchanged final production code in the combined run. Both original and
inverse physical alias deletions were reproduced only in private fixtures.

BQA-06 has a bounded residual. Narrow leases and atomic push are requested,
but a server may omit unchanged target/tag refs. The final query then reports
the actual deletion as incomplete and preserves the local archive; it cannot
undo a successful remote deletion or attest server isolation. Repository owner
and provider own live-operation policy. Network tests are mocks and no live
remote mutation is authorized. This remains explicit for CP3 judgment.

Non-ASCII ref names are conservatively retained, because Windows case ownership
is unverified; Unicode filenames in exact changed-path proof remain supported.
Unavailable locking capability, ambiguous ownership and unsupported cleanup
retain work rather than discarding it.

Linux and remote CI have not run. Main/master remain `864cad5`; new packages
including Spec 002 require slice A on main. Delivery/pushing main, switching
the remote default and retiring master remain owner operations.
The earlier vendor/integration whitespace baseline remains separately scoped
maintenance owned by the Spec 001 implementer, with no vendor edits/exclusions.
The documented self-hosted code-integrity/filesystem sandbox gap remains;
this slice does not claim to pin worker checking code or sandbox its writes.

Final full suite: Passed: 258 Failed: 0 Skipped: 0 Pending: 0 Inconclusive: 0; 1282.45 seconds.
Strict lint: 0 errors, 0 warnings, 1 semantic-limit info. Dry run: target=main,
manual T045, zero workers. Worktree/index and dce8394/53fc575 ranges are clean.
CP3 remains pending. Only the owner may accept the saved review and clear it;
slice C and live operations require their own authorized scope.
