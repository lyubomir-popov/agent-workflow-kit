# Slice A author validation

Date: 2026-10-11. Implementation revision: `8674e425877053c1c5da45c201aae845b2043b48`.
Author: Codex implementation agent. This is self-check evidence, not an Opus verdict.

## Commits

| Revision | Result |
|---|---|
| `34dc84a` | Record owner clearance and amendments |
| `ec01eb0` | Run Spec Kit plan/tasks workflows; authorize active A task record |
| `a3e4075` | Self-host owners, shared read-only checks, gates, scratch safety and Spec Kit alignment |
| `8674e42` | Hook/CI backstop, project template/prerequisite gates, source procedures and usage |

The review handoff commit contains only this evidence, request, inbox link and
package task/checkpoint metadata. Its revision is discoverable with `git log`.

## Task-to-requirement map

| Tasks | Requirements / acceptance |
|---|---|
| T001 | FR-035 config/version/target/inventory |
| T002 | FR-002–004, 010, 015–017, 033 shared ownership and declaration parsing |
| T003 | FR-013/018 isolated compatible Pester fixtures |
| T004–006 | FR-001–007, 010–012, 036–037; SC-001/003 ownership, adapters, preservation, routing |
| T007–008 | FR-005, 008–013, 034–035; SC-002/003 budgets, drift, stable reports and non-destructive inboxes |
| T009 | FR-008.1–6 hook, CI and host matrix |
| T010–012 | FR-014–018, 036; SC-004 gates, failures, package reviews; FR-022/023 scratch safety boundary |
| T013 | FR-034 cursor, reserved numbering, branch selection, principles and project overrides |
| T014 | FR-007, 032, 034–037 instruction/prompt procedure destinations and legacy compatibility |
| T015 | FR-014–015/037, SC-009 author validation and owner review request |
| T016/T017 | Future B/C placeholders only; no implementation or acceptance claim |

## Checks and outcomes

- `pwsh -NoLogo -NoProfile -File ./tests/run-tests.ps1`: **86 passed, 0 failed,
  0 skipped**, Pester 3.4, latest implementation run 136.36 seconds.
- Strict kit lint: zero errors/warnings; informational semantic-freshness limit.
- Real-kit scheduler executed only with `-DryRun`: no workers; previews A work
  and stops before the first beyond-gate task. Final handoff preview stops at CP2.
- `git diff --check` and staged equivalent pass; changed PowerShell parses.
- Fixtures exercise all eight lifecycles, declared worktrees and branch mismatch,
  verdict/gate/scope failures, checkout failures, dirty integration, unchanged
  progress, exhausted remediation/caps, production worker integration into a
  different declared worktree, timeout with ignored evidence, and scratch protections.
- Budget fixtures cover long-line bytes, blank lines, aggregate split files,
  task/request bounds, marker injection, exceptions, fourteen simulated daily
  appends, unknown host loading, unread inbox preservation and ended/superseded IDs.
- Spec Kit fixtures cover explicit/catalog selection, spoofed env/cursor,
  reserved local identities, failed checkout, configured base, marked detached
  worktrees, and prerequisite gates that completed checklists cannot bypass.
- Hook fixtures reject staged injection hidden by clean worktree bytes, require
  staged review preservation and retain legacy/external-mirror lint behavior.
- No vendor skill, installer, launcher wrapper or sibling-repository edits.
  No push, network/model calls in checks, or real worker/cleanup execution.

## Enforcement gaps and implementation choices

[The host matrix](../../../docs/enforcement.md) distinguishes installed kit
preflight/commit checking from manual chat triggers. The kit local hook is installed;
no pre-existing hook was present. Hooks can be skipped. CI is committed for Windows
and Linux but has not run remotely; Linux execution is not claimed from local tests.
Unknown/global host context and proprietary loading need host evidence. Scope/prose
judgment, direct CLI bypasses, dishonest clearance edits and external Spec Kit
upgrade preview remain human responsibilities; worker scope is a focused prompt,
not a filesystem sandbox. Read-only analyze using vendor `-RequireTasks` also obeys
its gate; inspect paths without that flag when reviewing blocked work.

The shared libraries and staged-contract hook are implementation choices, adding
no activation/lifecycle state home. Project overrides adapt the vendor templates;
vendor skills remain unedited. Source retirement guards protect the owner-directed
placeholders; full version-selected dual-mode prompts and installation are deferred.
Sequential new package IDs are enforced: versioned `-Timestamp` and identity reuse
through `-AllowExistingBranch` are rejected. Unseen remote-only identities cannot
be reserved without separately authorized network evidence. No intentional deviation
from the accepted A boundary; the first activation commit spans coupled owners/scripts
to keep the version switch coherent, followed by a separate procedure/hook commit.

## Legacy-mode behavior changes accepted for CP2 remediation

The owner's 2026-10-11 CPA-B2 decision permits recording these as intentional
FR-018 fixes for unmigrated consumers. They are exceptions to unchanged legacy
behavior under FR-030.7, rather than a claim that legacy behavior is identical:

- Legacy SpecKit review findings now live at `<package>/reviews/agent-review.md`
  instead of `AGENT-INBOX.md`; the root inbox carries a transient link.
- Missing saved reviews, absent accepting verdicts and unchecked findings remain
  active findings. Failed or exhausted bounded remediation reports incomplete.
- Legacy prompts preserve findings/dispositions in the package and update task
  headers instead of writing an AGENTS handover or draining the root inbox.
- Failed declared-branch checkout stops instead of falling back to another branch.
- Scratch cleanup requires a kit marker, managed-root containment and preservation
  proof; recursive filesystem deletion is removed. Failed runs retain commits,
  dirty files and protected ignored/untracked evidence; clean zero-commit runs
  are removed. Ancestry, or patch equivalence plus scratch-changed-path equality,
  permits unrelated integration bookkeeping without requiring whole-tree equality.

The production legacy TODO-loop fixture uses a mocked worker, cherry-picks its
commit and adds the scheduler's separate TODO bookkeeping commit, then verifies
scratch removal. All execution is confined to disposable fixture repositories.

## Owner follow-up

Review the saved CP2 and owner-requested delta findings and
[delta dispositions](../reviews/2026-10-12-cp2-delta-author-dispositions.md), choose
CPA-R3 and triage remaining minors before deciding CP2 clearance and slice B scope.
Required B/C work and acceptance remain unfinished. No further review was launched
by the implementer.

## CP2 remediation validation

Date: 2026-10-11. Validated code revision: `d0c80af`; this handoff adds only owners,
dispositions and evidence. The earlier 86-test record above remains historical.
The author's fixtures and checks do not clear CP2 or establish an independent verdict.

| Commit | Result | Full suite before commit |
|---|---|---|
| `3303e4f` | Save exactly the Opus findings and inbox | 86 passed |
| `691b668` | Worker owner-block/verdict/task integration rejection; T018 onward | 90 passed |
| `bc6f0f5` | Scratch changed-path proof, clean failure removal, legacy TODO bookkeeping | 94 passed |
| `95be292` | Archived delivery, manual stops, branch restoration and host inventory | 101 passed |
| `d0c80af` | Spec Kit sentinels/create-to-plan and CI branch restore | 106 passed |

All successful commit validations ran `tests/run-tests.ps1`, strict lint,
`agent-loop.ps1 -DryRun`, and `git diff --check`; staged whitespace and the local
commit check also passed. Latest code run: **106 passed, 0 failed, 0 skipped**,
Pester 3.4, 144.95 seconds. Strict lint: zero errors/warnings, one semantic-limit
info. Dry run dispatches zero workers and stops at the manual T016 boundary.
The handoff keeps CP2 pending and links both findings and dispositions.

| Finding | Fixture/check evidence |
|---|---|
| CPA-B1 | Worker.Tests: owner-block rejection; added/modified verdict rejection; unrelated task rejection; reverted owner edit; successful focused task plus spec-body edit |
| CPA-B2 | Worker.Tests: legacy TODO cherry-pick plus bookkeeping; clean zero-commit timeout/exit/no-progress removal; legacy clean failure; ignored evidence preservation. Scheduler.Tests: patch equivalence with divergent changed path preserves scratch |
| CPA-M1 | Workflow.Tests: archive resolves after branch deletion; staged target delivery squash passes actual hook and final commit |
| CPA-M2 | Scheduler.Tests: manual entry means incomplete/zero dispatch; next manual boundary stops. SpecKit.Tests: RequireTasks/PathsOnly also stops manual task |
| CPA-M3 | Workflow.Tests: missing/overwritten integration in each of common/check-prerequisites/create-new-feature. SpecKit.Tests: create catalog-owned draft → setup-plan succeeds |
| CPA-M4 | CI.Tests: actual step skips current branch sorting last; failed ref stops before a later ref |
| CPA-m1 | Workflow.Tests: CLAUDE.md copilot-chat inventory is required |
| CPA-m3 | Existing lifecycle/lint regressions and strict lint; redundant conjunction removed with identical active-only behavior |
| CPA-m4 | Scheduler.Tests: original primary branch is reported/restored after failure and success |
| CPA-m6 | Explicit legacy-mode behavior section above; legacy Worker.Tests bookkeeping/failure fixtures |
| CPA-M5, CPA-m2, CPA-m5 | Deferred to future slice B planning; named owner Codex (Spec 001 implementer); no implementation/test completion claim |

All workers are mocks and all create/plan, branch deletion, squash, bookkeeping
and cleanup tests use isolated local Git fixtures. The CI step is exercised offline
with synthetic remote refs; remote CI and Linux execution are unverified. No live
worker, push, prompt installation, vendor skill edit, sibling edit, slice B/C
implementation, tag/closeout implementation, or delta review was performed.

## CP2 delta remediation validation

Date: 2026-10-12. Code revision: `fcca278`. Author: Codex, Spec 001 implementer.
The owner-requested [delta findings](../reviews/2026-10-11-opus-slice-a-delta-review.md)
record the independent 106/106 run at `60a4f00` (232 seconds). The earlier no-delta
statements describe that original handoff; the owner subsequently requested the
saved delta review. This author round fixes R1/R2 under CP1 and leaves CP2 pending.

| Commit | Result | Full suite before commit |
|---|---|---|
| `2e4959a` | Save exactly the supplied delta review and inbox | 106 passed, 213.24 seconds |
| `fcca278` | Protect task declarations/order and versioned workflow policy; share task parsing and update worker instructions/coverage limits | 115 passed, 391.02 seconds |

The focused worker run passed **18/18**, 133.93 seconds. The full code run passed
**115 tests, 0 failed, 0 skipped**. Fixture runs were sequential. Before committing,
strict lint, scheduler dry run and whitespace checks also passed; lint reports
zero errors/warnings and one semantic-limit info. The metadata handoff links both
review rounds and dispositions, with CP2 still pending and T025 manual.
The metadata handoff repeated the full suite: **115 passed, 0 failed, 0 skipped**,
321.16 seconds; strict lint, dry run and whitespace checks passed again.

| Finding | Acceptance fixtures/checks |
|---|---|
| CPA-R1 | Worker.Tests: reject entry-checkpoint change/removal; existing gate removal/change/addition; manual removal/addition; added unchecked ID; removed ID; moving later work ahead of a manual boundary; a gate edit reverted by a later commit |
| CPA-R1 permitted edits | Existing production integration test now starts with the future task already declared; focused completion, both task descriptions, Next tasks/Blockers header fields and spec body edits still integrate |
| CPA-R2 | Worker.Tests: reject budget-exception, target, host-budget and config-deletion changes, plus a policy edit restored by a later commit |
| R1/R2 preservation | Every rejected fixture returns worker-incomplete, retains its scratch worktree, preserves the primary head and leaves the focused primary task unchecked |
| CPA-r3 | Enforcement documentation states the current-checkout preflight/code-integrity limit; no code pinning claim or implementation |
| CPA-R3, CPA-r1/r2/r4 | Pending owner choice/triage, with no implementation completion claim; delta dispositions record the remaining scope |

No actual worker process ran. No target write, push, prompt installation, vendor
skill edit, sibling-repository edit, slice B/C implementation or further Opus
review was performed. Original CPA-M5/CPA-m2/CPA-m5 deferrals remain unchanged.
