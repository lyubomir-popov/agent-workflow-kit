# Slice B implementation validation

Date: 2026-10-13. Author: Codex, Spec 001 implementer.
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

## Acceptance map

| Requirement/finding | Planned or implemented fixture coverage |
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

1. Preservation/scope chunk: `Passed: 232 Failed: 0 Skipped: 0 Pending: 0
   Inconclusive: 0`; `Tests completed in 1025.41s`. Strict lint: 0 errors,
   0 warnings, 1 semantic-limit info. Dry run: target=main, stops at manual T037,
   zero workers. Worktree/index whitespace and `dce8394..HEAD` range checks pass.
   Main remains an ancestor; main/master remain at `864cad5`.
