# Slice B implementation validation

Date: 2026-10-13. Author: Codex, Spec 001 implementer.
Runtime: Windows, PowerShell 7.6.6, Git 2.52.0.windows.1, Pester 3.4.0.
Starting accepted plan: `dce8394`; [owner approval](../reviews/2026-10-12-slice-b-plan-approval.md).
Scope: FR-019–024 and CPA-M5/m2/m5/r4/ADV-5. CP3 remains pending. All implementation
tasks are manual; no live cleanup, unattended worker, merge, push, consumer change,
vendor skill edit, prompt installation or external review is performed.

## Focused author and delegated fixture checks

| Area | Result | Seconds |
|---|---|---|
| Root CI event ranges and archive/mirror carryovers | 14 passed, 0 failed | 24.99 |
| Preservation + existing Scheduler/Worker regressions | 70 passed, 0 failed | 260.08 |
| Final scoped/BOM-aware/shallow-first preservation inventory | 13 passed, 0 failed | 23.24 |
| Staged hook baseline | 6 passed, 0 failed | 13.71 |
| Final affected-index scope, Unicode paths and cached remote inventory | 13 passed, 0 failed | 38.36 |
| Spec Kit including real-hook creation registration | 35 passed, 0 failed | 83.44 |
| Closeout proof, local guards and mocked remote reconciliation | 39 passed, 0 failed | 418.47 |
| Final retained detached/scratch/unknown association | 3 passed, 0 failed | 24.76 |
| Final CI event ranges, archive/mirror carryovers and CLI output | 18 passed, 0 failed | 31.73 |
| Accepted remote holds and invariant/typed annotation dates | 4 passed, 0 failed | 48.00 |
| Exact-case archive target and human local/remote output, CI/carryovers | 19 passed, 0 failed | 34.25 |
| Literal source/target/archive ownership and prepared deletion guards | 13 passed, 0 failed | 66.11 |
| Final registered checkout ownership, inverse aliases and guard inventory | 8 passed, 0 failed | 73.02 |

These are implementation checks, not an independent/Opus checkpoint verdict.
Fixture windows are sequential. Cleanup/network operations are tested in isolated
Git fixtures or through mocks; no production cleanup or network push is run.

The staged hook's initial scope run reported 12 passed/1 failed: affected-package
filtering incorrectly included another package's untracked review. Explicit array
binding/filtering fixed that case before the clean run above. Git environment
restoration, command-only registration forwarding, source remote-cache copying
and NUL-delimited paths were checked in that round. An initial preservation test
command treated a comma-separated path as one file and ran no fixtures; it was
corrected before the recorded runs. No overlapping full fixture suites were run.

Closeout initially exposed inherited Git environment restoration and absent-tag
query problems; those were corrected before the successful focused run. An
initial exact-source hook treated Git's unspecified all-zero old OID as a
mismatch and safely retained legitimate deletions. It now reads the actual tip
under the prepared ref lock, and tests both ancestor and unpublished-tip races.
Archive/target verification locks and captured immutable tag metadata were then
added; tests retain source refs if that capability or proof is unavailable.
Failed closeout runs were 0 passed/31 failed (3.53s), then 8/23 (94.07s),
before a clean 31/31 (317.85s). Later verifier hardening initially reported
26 passed/11 failed (306.32s); the all-zero old-OID correction preceded the
successful 39-case run. The final file also contains the three retained-association
cases, run separately above and included together in the full suite below.

Root integration also found that remote deletion did not honor accepted cleanup
holds. Four final fixtures cover held sources, deletion of working hold bytes,
valid ISO day-13 annotation dates under en-GB, and malformed February-30 rejection.
The first hold runs failed 0/2 in 25.33s, 24.87s and 26.05s. Raw proof tuples
matched: UTC date rollover exposed PowerShell's automatic JSON DateTime decoding,
whose string conversion was subsequently reparsed in en-GB. Typed date handling
and invariant string parsing corrected that independent fail-closed bug without
relaxing object/revision checks. Intermediate runs passed 3/3 in 37.00s and 4/4
in 47.81s before the final restricted-type run above. Invalid date values retain
conflicting annotations and make no push. Root's archive rule now compares Git
branch names exactly; a case-distinct configured target is tested.

## Acceptance map

| Requirement/finding | Validated fixture coverage |
|---|---|
| FR-019/020 | Closeout preview read-only, final delivered/archive records, exact accepted/base/landed identity, ancestry/squash changed-tree entries, mode/add/delete/rename/literal Unicode paths, conflicting/missing proof and annotated archive tag |
| FR-021/022/023, CPA-M5 | Directory summaries and one bounded subtree scan; tracked precedence, nested evidence, ignored secrets, links/junctions, dirty/index changes, locks, accepted/base holds and encoded holds; scratch marker/containment and integration proof; delivery uses ordinary Git removal |
| FR-024 | Matching tag reuse, conflicting/lightweight tag retention, interruption/retry, immediate ref/status/checkout revalidation, mixed held/eligible candidates, explicit local versus remote outcomes |
| CPA-m2 | Affected staged contract snapshot, unrelated unstaged bytes, broad root/config/catalog scope, indexed injection/deletion/rename/new review, creation registration command hint, unchanged source index/branch/status |
| CPA-m5 | Hook/library canonical inventory, missing/drifted assets, external mode suppression and legacy compatibility, no installation |
| CPA-r4 | Archived edits restricted to configured target, narrow initial delivery transition on declared branch, deleted source branch and target squash regressions |
| ADV-5 | Committed PR/push ranges, first-push merge-base/parent/root fallback, nonzero missing/malformed evidence fails, committed error caught on a clean worktree |

## Known boundaries

Main/master remain at `864cad5`; new packages including Spec 002 still wait for
slice A delivery to main. Remote CI and Linux execution remain unverified.
The earlier `864cad5..75ddc89` vendor/integration whitespace is a separately
reported baseline; no vendor edits or new-error path exclusions are made.
Remote apply tests mock network commands, and real operational authorization is
separate from approval to implement code. No claim of cross-process transaction
isolation or a code-integrity/filesystem sandbox is made.

## Per-commit full validation

Each commit requires the full Pester runner, strict lint, scheduler dry run,
worktree/index whitespace checks and `dce8394..HEAD` committed-range verification.
The full runs exercise the integrated working checkout, including later-area
changes still unstaged while commits are split by area. Each area also has the
focused evidence above. Final handoff checks cover the fully committed code.

1. Preservation/scope chunk (`2a4a6ef`): `Passed: 232 Failed: 0 Skipped: 0 Pending: 0 Inconclusive: 0`;
   `Tests completed in 1025.41s`. Strict lint: 0 errors,
   0 warnings, 1 semantic-limit info. Dry run: target=main, stops at manual T037,
   zero workers. Worktree/index whitespace and `dce8394..HEAD` range checks pass.
   Main remains an ancestor; main/master remain at `864cad5`.
2. Closeout/CLI/mirror chunk (`17b3535`): `Passed: 237 Failed: 0 Skipped: 0 Pending: 0 Inconclusive: 0`;
   `Tests completed in 999.49s`. Strict lint: 0 errors, 0 warnings, 1 info.
   Dry run: target=main, manual T040, zero workers. Worktree/index and reviewed
   range whitespace checks pass; the staged hook also passes. No live cleanup,
   worker, network query/push or target-branch mutation is performed.
   The first post-suite lint detected the inbox's completed T037 pointer;
   advancing the handoff to remaining T040–T044 resolved it before commit.
   The staged whitespace check caught a new blank line at the end of the
   closeout fixture file; removing that formatting residue made the check pass.

The first integration-area full run passed `Passed: 237 Failed: 0 Skipped: 0 Pending: 0 Inconclusive: 0`
in 1024.85s. Before committing that area, a read-only root check established that
Windows Git resolves `refs/heads/FEAT/001-SPEC-FIRST-WORKFLOW` even though its
literal inventory lists only lowercase `feat/001-spec-first-workflow`. Source
and proof identity therefore need literal inventory checks in addition to OIDs.
T037/T039 were reopened for that correction, preserving all production refs;
the corrected source receives new focused cases and a fresh full run before commit.
The old-code private probe confirmed the consequence: uppercase declared source,
lowercase primary HEAD and literal inventory; preview reported eligible with
zero candidates, then native `branch -d` through the alias removed the checked-out
lowercase ref and reported complete. The fixture retained its archive and was
disposed safely. No production ref was mutated. Literal source/target/tag and
direct-ref ownership checks are required before apply and under prepared locks.

The final literal-ref fixtures pass 13/13 in 66.11s. Both edited scripts parse
with zero errors. Initial runs reported 1 passed/8 failed (13.22s), caused by a
helper variable colliding with PowerShell's automatic `$Matches`, and 8 passed/1
failed (49.69s), because Git on Windows rejected the fixture's case-only rename
before reaching the guard. A private two-step rename corrected the probe, and
11/11 passed in 58.08s before the two dangling-symbolic cases were added. The
final checks require exact literal direct source/target/tag ownership, reject
case siblings and symbolic/dangling refs, and recheck names/OIDs after the caller
hook under no-deref proof locks and the native source lock. Non-ASCII ref names
are conservatively retained; Unicode delivered filenames remain supported.

The subsequent full run passed `Passed: 250 Failed: 0 Skipped: 0 Pending: 0 Inconclusive: 0`
in 1149.23s. No commit followed: final inspection found the inverse alias case,
where the source's literal name is exact but a checked-out worktree HEAD uses
a differently cased physical alias. Exact-only worktree routing omitted it,
and the ref-only prepared guard was insufficient. T037/T039 reopened again;
the correction retains ambiguous checkout aliases and independently revalidates
registered checkout names in the prepared guard. The final code gets focused
regressions and a fresh full suite before commit; production refs remain untouched.
The inverse private probe confirmed the same loss: lowercase declaration and
literal source, uppercase primary HEAD; preview was eligible with zero candidates,
and apply reported complete after deleting the checked-out lowercase physical
source (subsequent source resolution exited 128). Only the fixture's target and
archive remained. The correction therefore covers checkout metadata as well as
literal ref identity. No actual kit source or target ref was removed.

The final production source passed all 13 earlier literal-ref cases in a combined
19 passed/2 failed run (126.21s). The two new failures were fixture path identity
assertions comparing Git's slash spelling with Windows backslashes; full-path
platform comparison corrected those assertions without changing production code.
The eight registered-checkout cases then passed 8/8 in 73.02s. Both edited files
parse with zero errors; whitespace is clean. Preview retains raw namespace/source
aliases and ambiguous accepted-head branch ownership, including non-ASCII refs;
an independent eligible delivery tree can still be removed. The prepared guard
reads quoted porcelain after the caller hook, checks registered checkout names,
and retains failed/empty/malformed inventory. It observes that prepared state;
it does not lock other processes' HEAD files or claim global filesystem isolation.

3. Final enforcement/ref-ownership chunk (`af8ed58`): `Passed: 258 Failed: 0 Skipped: 0 Pending: 0 Inconclusive: 0`;
   `Tests completed in 1256.56s`. This fresh run includes all 21 literal/checkout
   ownership regressions together with staged scope, CI ranges and existing A
   fixtures. Strict lint: 0 errors, 0 warnings, 1 semantic-limit info. Dry run:
   target=main, manual T044, zero workers. Worktree/index and dce8394/53fc575
   range whitespace checks pass. The staged hook passes with 0 errors/warnings;
   its private snapshot adds an expected no-installed-hook info because its hooks
   are deliberately disabled. Main is an ancestor, main/master remain 864cad5.
   The previous 250-case state was not committed.

## CP3 handoff

Final code revision: `af8ed58ba17a0dff944c9f87e7774ac670234984`.
The subsequent handoff commit changes package/review metadata only. Full findings
and a finding-to-test/commit map are in the [author review](../reviews/2026-10-13-slice-b-author-review.md)
and [dispositions](../reviews/2026-10-13-cp3-author-dispositions.md); the
[bounded request](../reviews/2026-10-13-opus-slice-b-review-request.md) is for the owner.
CP3 stays pending; T045 is the manual review action, and slice C is not started.
No author/delegated check constitutes Opus or owner acceptance.

4. Handoff metadata chunk: `Passed: 258 Failed: 0 Skipped: 0 Pending: 0 Inconclusive: 0`;
   `Tests completed in 1282.45s`. The full suite runs again after adding the
   request/findings/dispositions and T045 owner handoff, with code unchanged from
   af8ed58. Strict lint: 0 errors, 0 warnings, 1 semantic-limit info. Dry run:
   target=main, manual T045, zero workers. Worktree/index and dce8394/53fc575
   range whitespace and the staged contract hook pass. The request is 24 lines,
   3130 UTF-8 bytes, within its 30-line/6144-byte budget. CP3 remains pending.

## CP3 correction round, 2026-10-14

Received [Cline review](../reviews/2026-10-13-opus-slice-b-review.md) of af8ed58:
accept with bounded corrections CP3-R1/R2/R3. The reviewer records Cline, with
model identity unattested; this evidence does not call it verified Opus.
Reviewer-reported full result: 258 passed, 0 failed, 0 skipped in 1635.53s;
strict lint, zero-worker dry run and dce8394 range clean; main/master unchanged.
Those are the reviewer's checks, distinct from the implementer's runs below.

The implementer selects the recommended corrections inside the existing approved
slice B scope. CP3 stays pending, with no claim of owner clearance or acceptance.
Original landing/source/base proof stays immutable while target-tip snapshots
serve locks/leases. Unknown or removed landing ancestry retains cleanup; archive
tags are not deleted or retargeted to make retries pass. BQA-06 remains explicit,
and Linux/remote CI/new-package prerequisites are unchanged. Review-base for this
round: 9e1819c; retain dce8394/53fc575 range checks as well.

Review-save validation (code unchanged from 9e1819c):
`Passed: 258 Failed: 0 Skipped: 0 Pending: 0 Inconclusive: 0`;
`Tests completed in 1421.33s`. Strict lint: 0 errors, 0 warnings, 1 info.
Dry run: target=main, manual T046, zero workers. Worktree/index and reviewed
range whitespace checks pass; main/master remain 864cad5, main an ancestor.
The review's Cline attribution and unattested model identity are preserved.

Focused R1/R2 correction: `Closeout immutable landing and advancing targets`
passed 14/14 in 256.27s on its first run; two existing frozen-target tests were
revised/moved, twelve new cases added. Both edited files parse with zero errors;
whitespace checks pass. Coverage includes ancestry/squash interrupted retries
with unchanged tag object ID, squash followed by catalog registration, changed
explicit landing rejected even with owner confirmation, rewind/unrelated/missing
proof, captured-tip lock races, observed remote-tip leases/no-op refspecs, unknown
remote objects without fetch, refreshed remote snapshots, BQA-06 descendant
snapshot change, early partial/promisor declaration retention and offline defaults.

Independent read-only QA by staged_hook (gpt-5.6-sol, not the closeout implementer)
found no concrete R1/R2 defect. It found CP3-Q1 (minor): an unauthorized selected
local action returns before a separately authorized selected remote action can
run; the reverse combination already continues authorized local work. Repair is
bounded to existing FR-019 permission separation, with a mocked regression.
This is author QA, not Opus or owner acceptance. No review was started externally.

CP3-Q1 focused regression, `Closeout separate local and remote authorization`:
1/1 passed in 15.14s on its first run. The mocked remote reconciliation completes
while both unauthorized local actions remain retained and the local branch,
worktree content and status remain unchanged. Production and fixture parsers
report zero errors; whitespace is clean.

CLI/documentation integration: `tests/Carryover.Tests.ps1` passed 7/7 in 32.06s.
Its existing CLI case now advances the target with another catalog registration,
then checks JSON and human output against the original landing and separate
current target tip. Preview and unauthorized apply remain read-only. README
instructions retain the original tuple and recover it from the immutable tag;
they never prescribe deleting or retargeting an archive to make a retry pass.

Offline object proof adds child-only `GIT_NO_LAZY_FETCH=1` plus conservative early
retention for declared partial-clone/promisor/filter configuration. The
[Git 2.52 source](https://raw.githubusercontent.com/git/git/v2.52.0/promisor-remote.c)
honors that variable before fetch; the
[Git 2.29 source](https://raw.githubusercontent.com/git/git/v2.29.0/promisor-remote.c)
lacks that guard and also creates a promisor from filter configuration alone.
The early configuration bound avoids relying on an unsupported environment flag.
This does not claim Linux/provider verification or concurrent config isolation.

Correction code chunk validation:
`Passed: 271 Failed: 0 Skipped: 0 Pending: 0 Inconclusive: 0`;
`Tests completed in 1748.51s`. The full run includes all R1/R2/Q1 regressions
and the expanded CLI case together with the existing slice A/B suite. Strict
lint: 0 errors, 0 warnings, 1 semantic-limit info. Dry run: target=main, manual
T048, zero workers. Worktree/index and 9e1819c/dce8394/53fc575 range whitespace
checks pass; the staged contract hook passes. Main remains an ancestor and
main/master remain 864cad5319ea48aaa60557d4361fb9a803df675c. No fixture failure
was encountered in the correction full run; no source was changed during it.
