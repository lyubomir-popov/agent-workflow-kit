# Implementation plan: Spec-first agent workflow

**Branch**: `feat/001-spec-first-workflow` | **Date**: 2026-10-12 | **Spec**: [spec.md](spec.md)

## Summary

Self-host a versioned, spec-owned workflow while retaining legacy launcher behavior
for repositories without the version. Deliver three slices with owner checkpoints;
slice A corrections are accepted at `75ddc89`. The owner's October 12 clearance
initially authorized slice B planning only. The subsequent continuation approves
implementation of the plan below; live cleanup, unattended runs, merging to main
and pushing remain separately authorized owner actions.

## Technical context

PowerShell 7 and Git; no new runtime dependency, network, or model calls in lint.
Markdown packages and `.workflow-kit.json` are the owners. Pester 3.4 is installed;
use compatible disposable Git fixtures under the OS temporary directory. Windows
is verified locally; CI checks Windows and Linux. No performance claim is needed.

## Constitution check

| Principle | Before and after design |
|---|---|
| I Owner scope/review | CP1/CP2 accepted; subsequent owner continuation approves B code/fixtures; stop at pending CP3 without operational mutations or unrequested external review. |
| II One owner per fact | Catalog routes; spec owns lifecycle/gates; tasks own execution; shared parser, no sidecar state. |
| III Preserve work | Read-only checks; preserve failed workers; marked, contained scratch only; Git history retains legacy content. |
| IV Proportional verification | Fixture acceptance/failure tests, parser checks, lint/dry run/diff check per commit. |
| V Canonical tooling | Kit only; external-mirror config survives; no prompt install or consumer edits. |

The initial constitution check passed without an exception. Subsequent bounded
correction choices and maintenance deferrals are recorded below and in reviews.

## Structure and responsibilities

- `workflow-model.ps1`: shared config, catalog/worktree, lifecycle/checkpoint,
  task/gate parsing and local package selection. Library only, no execution state.
- `workflow-kit.ps1`: version switch, lean routing/budget/ownership diagnostics,
  human/JSON findings; preserve legacy lint and external-mirror diff.
- `agent-loop.ps1`: consume shared model, preflight and task gates, clean
  integration target, package review routing, marked contained scratch workers.
- `.specify/scripts/powershell/`: adapt resolution/numbering to declared owners;
  vendor skills stay untouched. `.specify/feature.json` becomes ignored/untracked.
- Root adapters/catalog, `docs/operations.md`, README, prompt sources and
  principles-only constitution: migrate every FR-036 section to its named owner.
- `.githooks/pre-commit`, `.github/workflows/workflow.yml`, `docs/enforcement.md`:
  compose local hooks, CI backstop and honest per-host gaps.
- `workflow-checks.ps1`, `workflow-scheduler.ps1`, `workflow-hook.ps1`: on-demand
  script libraries and commit entry point; they store no workflow state.
- `tests/`: compatible Pester runner and isolated Git fixtures.

## Slices and acceptance

**A** (FR-001–018, 033–036, A parts of 037): implement the above; tasks declare
an entry checkpoint and optional per-task `(gate: CPn)` overrides. Recheck before
each dispatch. Future pending checkpoints do not block earlier authorized tasks.
Keep root legacy files as 2–3 line catalog placeholders; preserve TODO ideas in
catalog candidates/roadmap and HISTORY in Git. Source prompt procedures receive
FR-036 rules; shared installation and full dual-mode prompt conversion await C.
Save a bounded CP2 request and transient inbox link after validated implementation.

**B**, after owner approval of this plan and implementation scope: implement preview/apply closeout, delivery
commit/catalog archive, exact merge proof, annotated archive tags, preservation
and idempotent cleanup. `delivered` is terminal; no target documentation write.

**C**, after CP3 owner clearance: migration preview/apply/rollback, dual-mode
prompt tooling and adoption examples. Prompt installation needs separate owner
authorization; then remove kit placeholders. Stop at CP4 for owner acceptance.

## Validation and limits

CP2 carryovers included in the proposed slice B plan: CPA-M5 scratch inspection scaling,
CPA-m2 staged hook package scoping, and CPA-m5 hook/mirror coverage for the later
rollout. Named owner: Codex (Spec 001 implementer), after owner plan approval.
The [initial CP2 dispositions](reviews/2026-10-11-cp2-author-dispositions.md) and
[delta dispositions](reviews/2026-10-12-cp2-delta-author-dispositions.md) record scope
and evidence; CP2 delta remediation remains CP1-gated. The owner selected target
registration on 2026-10-12: switch to a clean configured target, commit only the
new catalog row there, then branch and write the draft spec from the override.
Target lint reports unavailable local package branches as info with a fetch hint.
This kit now targets main; generic fixtures retain master to test configuration.
CPA-r1/r2 are authorized corrections; CPA-r4 archive edit restrictions are deferred
to the slice B plan, owned by Codex (Spec 001 implementer).
T026–T029 implemented and recorded that earlier owner scope. The subsequent
planning-only acceptance is linked from spec.md. The subsequent owner continuation
approves B code and fixtures; CP3 remains the stopping boundary before slice C.

The subsequent adversarial review identifies ADV-1–5. Creation captures the
original branch/detached head and restores it on failure, preserving registration
and partial artifacts; a restoration error is reported alongside the primary
error. The configured target must already have slice A's versioned owners and
overrides. This kit's main at 864cad5 lacks them, so creation (including Spec 002)
waits for slice A delivery. This correction performs no early merge. Gate review
record protection and all gate labels share one parser; existing reviews are
immutable during worker integration and new gate metadata is rejected. Git blob
bytes use the same BOM-aware decoding as filesystem reads. Orphans in available
local/cached refs are errors; configured but uncached remote inventory is unknown.
Creation passes a command-scoped hint only for a new staged catalog row, with
HEAD/index proof; persisted hints and existing orphans cannot use the exception.
These fixes landed in slice A; the owner subsequently cleared CP2 for planning
only, accepting revision 75ddc89. T036 records subsequent plan approval; all
implementation tasks remain manual because unattended execution is unauthorized.
ADV-5 author validation checks worktree, index and the reviewed commit range.
Ranged CI checking is proposed below. The older vendor/integration whitespace
baseline remains separate maintenance, owned by Codex (Spec 001 implementer);
no vendor skill edits are proposed.

Fixture tests cover resume, lifecycle states, declared worktrees/branch mismatch,
gates and verdicts, fourteen drift updates, lines/bytes/aggregate budgets, markers,
inboxes and stale IDs, reserved numbering, failed checkout/worker/integration,
exhausted remediation and scratch preservation. See [quickstart](quickstart.md).
Checks detect mechanical drift; semantic freshness and dishonest gate edits need
human judgment. Hook installation and host limitations are reported explicitly.

## Slice B plan for owner approval

Status: initial code/fixture implementation complete, 2026-10-13; CP3 corrections
received from Cline on 2026-10-14, with model identity unattested. CP3 stays pending.
The implementer takes the review's recommended correction route inside slice B:
keep the original landing tuple, require its ancestry in the current target, and
bind local locks/remote leases to separately captured current tips. Tag proof and
source/landing comparisons remain immutable; unknown ancestry retains cleanup.
T046/T047/T049 corrections and focused fixtures are complete; T048 records the
271-case full acceptance result and returns the corrected code to the owner.
Owner: Codex (Spec 001 implementer). [Correction request](reviews/2026-10-14-cp3-correction-review-request.md)
pins code at 8569b125980cf2f630829ec71565df9909c7896a; [dispositions](reviews/2026-10-14-cp3-author-correction-dispositions.md)
map R1/R2/R3 and independent author QA Q1. [Evidence](evidence/slice-b-validation.md)
records checks. T045 remains the manual owner review/acceptance and identity
judgment; this author handoff neither clears CP3 nor attests the Cline model.
Authority: [owner plan approval](reviews/2026-10-12-slice-b-plan-approval.md), extending
the [CP2 planning-only acceptance](reviews/2026-10-12-cp2-owner-planning-acceptance.md).
Requirements: FR-019–024, relevant FR-008/010/013/018, SC-005/006 and the five
carryovers below. The owner approved the plan at dce8394 by replying "continue"
to its handoff. T036 records approval; T037–T044 declare implementation and fixture
validation work, all manual. The earlier planning commit changed no code, hooks,
CI, tags, branches or worktrees. Code work may now proceed; operational mutations
outside isolated fixtures remain separately authorized.
Slice C remains behind CP3; no migration or prompt installation is included.

### Closeout interface and evidence

Propose a versioned `closeout` command in `workflow-kit.ps1`, backed by a separate
`workflow-closeout.ps1` library using the existing model. Preview is the default
and performs no writes, network calls or model calls. Human and JSON output name
the package, configured target, declared base, accepted source revision, landed
target revision, proof method, archive tag, worktree/branch candidates, proposed
actions and retention reasons. Git/config are the source of computed status;
no status sidecar or post-merge target documentation commit is introduced.
Legacy lint/diff behavior remains available without silently activating closeout.

Apply requires explicit accepted/base/landed revisions and selected actions,
plus owner authorization for those actions. Repo configuration supplies policy,
not permission. Missing or changed evidence returns incomplete and preserves the
affected target. Recompute the preview and revalidate repo identity, containment,
links, locks, holds, refs and worktree contents immediately before each mutation;
do not trust a saved preview as deletion authorization. Offline local cleanup
must not delete/push remote refs. Network reconciliation, remote branch deletion
and archive-tag pushes require separate owner scope and stay disabled by default.

The delivery commit is prepared on the declared package branch: set lifecycle
`delivered`, move the catalog row to Archive without moving the package, and
declare holds before delivery. Landing that commit is an owner operation; closeout
does not merge, rewrite the configured target or advance lifecycle after landing.
Resolve archived records from the target checkout even after source-branch removal.
CPA-r4 will restrict archived package edits to the configured target while
preserving the already-tested final delivery/squash transition there.
These are reusable closeout behaviors exercised in fixtures. Implementing slice B
does not mark Spec 001 delivered or archive it while slice C remains unfinished.
Owner-authorized landing of slice A on main is separate from final package
delivery and cleanup; this planning change performs neither.

### Proof, preservation and action order

1. Validate the accepted source commit and final delivery records. Resolve the
   declared base and target/landed commit explicitly. Prove ancestry, or compare
   the source and target tree entries for every source-changed path relative to
   base. Compare additions, deletions, blob identity, modes and both sides of
   renames; unrelated target bookkeeping is allowed. Patch similarity or cached
   provider claims are insufficient. Missing/stale evidence is unknown. Owner
   confirmation must name the exact source, target and landed commits and be
   durably recorded in the annotated archive tag before source deletion.
2. Inventory tracked, staged, untracked, ignored and unpublished work, locks and
   package holds from the accepted revision. A deleted working-copy hold does
   not cancel the accepted hold. Tracked files and known evidence remain protected
   even under a disposable pattern. Protected evidence blocks removal until an
   owner-authorized preservation destination and byte/ref verification establish
   durable preservation. Never stage or discard user evidence automatically.
3. Create the annotated `archive/<package-id>` tag on the accepted source head
   before deleting its branch. Record target, landed commit, proof method and
   date as FR-020 requires. A matching existing annotated tag is reusable; a
   lightweight, conflicting or moved tag blocks apply rather than being rewritten.
4. Remove only eligible delivery worktrees with ordinary `git worktree remove`.
   No delivery worktree gets automatic force permission; dirty disposable content
   that ordinary removal refuses is retained with an actionable explanation.
   The primary checkout, locked/held worktrees and unresolved links are protected.
   Scratch force remains a distinct path requiring its existing marker, managed
   containment and complete preservation/integration proof. No recursive fallback.
5. Delete only authorized eligible local branches after rechecking the archive
   tag and confirming no worktree uses the branch. Preserve unpublished commits.
   Interrupted retries reuse verified proof, treat already-completed actions as
   complete, and report residue for Git pruning rather than deleting directories.
   One retained candidate must not prevent independent eligible cleanup.

### Proposed implementation sequence and carryovers

All rows are accepted implementation scope owned by Codex (Spec 001 implementer).
They define acceptance evidence to add; they do not claim test completion or
authorize live cleanup, unattended workers, merging or pushing.

| Order | Proposed change and files | Acceptance evidence to add |
|---|---|---|
| 1 | Closeout preview/model and exact merge proof in `workflow-closeout.ps1`, `workflow-model.ps1`, `workflow-kit.ps1` | `tests/Closeout.Tests.ps1`: preview leaves Git/content unchanged; normal ancestry and squash equality pass; added/deleted/renamed/mode-only paths compare; divergent path, wrong base, unknown/stale refs and mismatched accepted revision retain work |
| 2 | Preservation inventory and CPA-M5 scaling in the closeout library and existing `workflow-scheduler.ps1` scratch helpers | Large dependency fixture: directory summaries avoid per-file repeated parent scans; one bounded reparse-point traversal checks each disposable subtree; links/junctions, nested evidence, tracked content under disposable paths, ignored secrets, holds and unpublished commits still block. Assert scan counts rather than a fragile wall-clock threshold |
| 3 | Archive tags, authorized local apply, revalidation and resumable cleanup | `tests/Closeout.Tests.ps1`: correct/reused/conflicting tags; interruption after each mutation; changed refs/status after preview; primary/locked/held worktrees; prefix-lookalike paths; no target writes, recursive fallback or delivery force; mixed retained/eligible candidates; mocked remote actions default off |
| 4 | CPA-r4 archived-edit restriction in `workflow-checks.ps1`/hook validation | `tests/Workflow.Tests.ps1`: archived edits pass on configured target and fail on other branches; archive after source-branch deletion still resolves; final delivered/archive squash on target still passes; generic master target fixtures remain |
| 5 | CPA-m2 staged-package scoping in `workflow-hook.ps1` | `tests/Workflow.Tests.ps1`: unrelated package's unstaged changes no longer block an unrelated commit; validate affected contract bytes from the index; staged config/catalog/root changes expand checks to affected/all governed packages; deletion/rename/new review and staged injection cannot bypass checks |
| 6 | CPA-m5 canonical mirror inventory decision in `workflow-kit.ps1` and enforcement docs | Propose adding `workflow-hook.ps1` and `.githooks/pre-commit` to canonical diff inventory; `tests/Workflow.Tests.ps1` detects missing/drifted hook assets while preserving external-mirror configuration and legacy mode. Inventory changes do not install consumer hooks or implement slice C adoption |
| 7 | ADV-5 committed-range CI checking in `.github/workflows/workflow.yml`, `tests/CI.Tests.ps1`, quickstart/enforcement docs | Exercise actual CI step on a committed whitespace error with a clean worktree; PR uses validated base/head merge base, push uses validated before/after. Fail rather than silently passing an unavailable nonzero base; first/new-branch push uses configured-target merge base, or HEAD's parent when that base equals HEAD, or the empty tree for a root commit. Check Git exit codes and cover both event shapes offline |
| 8 | Full acceptance, FR/finding evidence and owner CP3 handoff | Full suite, strict lint, dry run, worktree/index/range checks before each commit; retain CP3 pending. Save a bounded review request and inbox handoff; an independent review runs only when the owner requests it |

For CPA-M5, directory summaries are not permission to skip nested evidence or
links. Use Git's directory inventory to avoid dependency-file expansion, retain
tracked/evidence precedence, and scan each candidate disposable subtree once
without following reparse points. Reuse this inventory for scratch and delivery
assessment while retaining their different removal permissions.

For CPA-m2, root/config/catalog changes can affect every package; do not limit
validation solely to literal package paths. Validate affected contracts from an
index-based view, preserving declared-branch routing and staged final-delivery
checks; unrelated unstaged bytes must not substitute for index owners or block
unrelated commits. Retain all current staged-injection regression tests.

For ADV-5, use event-local commit evidence and the CI checkout's complete history;
never compare every push to an unrecorded moving main tip. A clean working tree
is not whitespace evidence. An all-zero push-before value selects the documented
first-push fallback; a nonzero but unavailable event revision fails. A first-push
merge base equal to HEAD falls back to HEAD's parent, or Git's empty tree for a
root commit, so the check cannot succeed merely by comparing HEAD with itself.
Existing `864cad5..75ddc89` vendor/integration issues
are a separately reported baseline, not a reason to ignore new errors. Do not
edit vendor skill files or hide failures with path exclusions. If an event's
required range includes that older baseline, report it honestly; baseline cleanup
requires separately scoped maintenance. Remote CI execution remains unverified
until the owner pushes and observes it.

### Approval and delivery boundaries

T036 records the owner's approval of this plan at dce8394, extending the earlier
planning-only clearance to code and fixture implementation. The accepted scope
covers the interface, proof and preservation policy and all five carryovers.
Unattended execution, real cleanup, merging and pushing remain separately scoped
owner actions; approving code work does not silently authorize them. CP3 guards
slice C after slice B review and acceptance.

New packages, including Spec 002, still wait for slice A to land on main. This
plan does not propose an early merge. Main/master remain at 864cad5 and the remote
default is unchanged. Owner steps remain delivery/push of main, switching the
remote default, and retiring master. No remote CI success is claimed. The older
whitespace baseline and CPA-r3 self-hosted code-integrity limit remain explicit
gaps; cross-repository orchestration, consumer rollout and prompt installation
are outside this plan.
