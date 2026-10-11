# Opus slice A review: Spec 001

- **Checkpoint**: CP2
- **Scope**: `001/spec-r2`, slice A only
- **Reviewed revision**: `8674e425877053c1c5da45c201aae845b2043b48` (handoff `ae0af49` read for metadata)
- **Reviewer**: GitHub Copilot agent in VS Code Insiders; host-reported model Claude Opus 5.5.
  Identity is host-reported, not independently attested. Implementation author: Codex agent.
- **Verdict**: accept with bounded corrections. Slice A delivers the ownership model,
  versioned lint, gated scheduling and scratch safety it claims. Fix CPA-B1 and CPA-B2
  before slice B starts; carry CPA-M1–M5 into slice B planning or fix first.

## Reproduced

- Strict lint: 0 errors/warnings, 1 semantic-limit info. Scheduler dry run stops at
  CP2 with zero workers. Working tree clean. The 86-test suite was not rerun.
- No slice B/C implementation is claimed: T016/T017 are unchecked placeholders.
  Repo state shows no push and no vendor skill edit. Prompt installation and
  consumer edits were not independently verified outside this repository.
- Probe in a disposable clone (deleted afterwards): with the declared feature branch
  deleted, lint fails `package-owner … missing on declared branch` although the
  package files exist in the checkout. With the branch present, an uncommitted
  package edit on another branch fails `package-branch`.

## Blocking findings

### CPA-B1. The launcher does not enforce what the enforcement doc claims

Refs: FR-015, FR-016, SC-004; `workflow-scheduler.ps1` `Start-WorkflowScheduler`;
`agent-loop.ps1` `Invoke-SpecKitWorkerPhase` integration; `docs/enforcement.md`.

Worker commits are cherry-picked with no check of what they changed. A worker can,
in one run:
- set a later checkpoint to `owner-cleared` and add a review file with
  `Verdict: accept`, after which the next loop iteration passes `Get-WorkflowGateProblem`;
- change `**Lifecycle**` or `**Scope**`;
- tick tasks other than the focused one, including tasks behind an uncleared gate.

`git cherry-pick` does not run the pre-commit hook, and the worker can use
`--no-verify` in scratch. The next preflight only checks shape, which fabricated
records pass. `docs/enforcement.md` says owner-only clearance is "checked by kit
launchers"; it is not. FR-015 places enforcement in the launchers, so this is the
gap slice A was meant to close.

Correction: before cherry-pick, compare the scratch range against the base:
- reject changes to the `spec.md` block before the first `##` heading
  (lifecycle, scope, superseded IDs, checkpoints);
- reject added or modified files in `reviews/` whose content carries a
  `Verdict:` line;
- reject newly completed tasks other than the focused task ID.

On rejection, keep the scratch worktree and return `worker-incomplete`. Add fixture
tests for each case. Reword the enforcement doc to match what is checked.

### CPA-B2. Legacy mode regresses for unmigrated repositories

Refs: FR-030.7, FR-031, FR-022; `Remove-WorkflowScratch`; legacy TODO loop in
`agent-loop.ps1`; `Build-SpecKitPrompt`; `Test-PackageReviewHasActiveFindings`.

- **Scratch accumulates on every legacy TODO task.** The loop's `finally` removes
  scratch after `Commit-Bookkeeping`. `Remove-WorkflowScratch` then requires the
  scratch tree to equal the integration tip, which the bookkeeping commit has
  changed. The removal fails and only a warning is printed. The mirrored
  `agent-loop.ps1` brings back the stale-worktree problem in every unmigrated
  consumer.
- **Clean failed runs are kept too.** `keepWorktree` now defaults to `$true`, so
  clean scratch from failed runs is preserved as well.
- **Legacy reviews changed location.** Legacy SpecKit prompts now write reviews to
  `<package>/reviews/agent-review.md`, not `AGENT-INBOX.md`. Remediation treats a
  missing file as active findings.

The validation evidence does not record these behaviour changes, although FR-030.7
says legacy repos keep their behaviour.

Correction:
- Drop whole-tree equality. Work is proven integrated by ancestry, or by
  `git cherry` showing every scratch commit as patch-equivalent, plus equality of
  the paths the scratch changed (the FR-020 rule).
- Remove clean scratch after a failure with zero commits.
- Either gate the review-destination and remediation changes on the versioned
  config, or record them as intended FR-018 fixes for legacy mode.
- Add a legacy TODO-loop fixture with a bookkeeping commit.

## Major findings

### CPA-M1. Archived packages and target-side delivery fail under the slice A model

Refs: FR-010, FR-019, FR-024, FR-034.3; `Get-WorkflowPackages`,
`Read-WorkflowPackageFile`, `package-branch` check.

- After closeout deletes the delivery branch, every archived row errors, because
  rows resolve through `git show <branch>:<path>`. CI's branch-restore step only
  delays this until the remote branch is gone.
- On the target, committing a squash of package changes fails `package-branch`,
  because archived rows are not exempt, so the kit's own hook blocks delivery.
- The amended spec relies on `archive/<package-id>` tags, but the model has no
  rule for archived rows. A spec test uses `archive/eight` as a branch value
  without a defined contract.

Correction (slice A model, before B):
- Archived rows resolve from the current checkout.
- The package-branch edit rule applies only to non-archived rows.
- The final delivery commit (lifecycle `delivered`, row moved to Archive) is
  accepted on the configured target.
- Add failing tests now; B implements tagging.

### CPA-M2. Slice placeholders become dispatchable

Refs: FR-016, FR-037; `tasks.md` T016/T017.

When the owner clears CP2, the scheduler would hand "T016 Slice B: closeout…" to
an unattended worker as one task, skipping slice B planning.

Correction: let the scheduler skip, or stop at, tasks tagged `(manual)`, and tag
T016/T017 that way. Alternatively, return lifecycle to `ready` at each slice
boundary until the next slice's tasks are authored.

### CPA-M3. Spec Kit alignment lives in vendor scripts that an upgrade overwrites

Refs: FR-034.2–4.

Slice A edits `.specify/scripts/powershell/common.ps1`, `check-prerequisites.ps1`
and `create-new-feature.ps1`. Rerunning `specify init --here` or upgrading
restores the branch fallback, cursor resolution and soft gates without any
signal. The enforcement doc defers this to manual preview.

By code reading, two more gaps:
- In versioned mode, `create-new-feature.ps1` neither adds a catalog row nor writes
  the lifecycle block, so the following plan or tasks command refuses the new
  package until manual edits (`Select-WorkflowPackage` requires a catalog row).
- No test covers create → plan.

Correction:
- Add a lint check, when the version is active, that the integration sentinels
  (`Get-SpecKitWorkflowConfig` and the `RequireTasks` gate) are present.
- Add the catalog row and lifecycle block on creation (or document the manual
  step in the template), and test create → plan.

### CPA-M4. CI branch restore will probably fail on push

Refs: FR-008.4; `.github/workflows/workflow.yml`.

`git branch --force <current> origin/<current>` fails for the checked-out branch
on push events, which `actions/checkout` creates locally. If that ref sorts last
(for example `master`), the GitHub pwsh wrapper exits with that code. This has
not run remotely.

Correction: skip the current branch and check `$LASTEXITCODE` per ref.

### CPA-M5. Scratch inspection does not scale to dependency trees

Refs: FR-021, FR-022; `Remove-WorkflowScratch`.

`ls-files --others --ignored` lists every file under `node_modules/`. Each file
then gets `Assert-WorkflowNoLinks`, which walks up its parent directories, after a
full `Get-ChildItem -Recurse`. JavaScript consumers will hit this.

Correction: use `--directory`, accept a disposable top-level directory as a unit
after one reparse-point scan, and test with a large fixture.

## Minor findings

- **CPA-m1** (FR-009): the `copilot-chat` inventory omits `CLAUDE.md`. VS Code
  loaded it alongside `AGENTS.md` and the Copilot adapter in this session. Declare
  it, or mark it `unknown`.
- **CPA-m2** (FR-008.3): the hook rejects any unstaged edit to any package's
  spec/tasks/reviews, which blocks unrelated commits. Limit the check to packages
  touched by the staged diff, or document it.
- **CPA-m3**: `workflow-checks.ps1` has a redundant `-in @('active','ready') -and -eq 'active'` condition.
- **CPA-m4** (FR-017): for a non-local package, the scheduler switches the primary
  checkout's branch and doesn't restore it or report the original.
- **CPA-m5**: `Get-CanonicalMirrorFiles` adds `workflow-*.ps1` but not
  `workflow-hook.ps1`/`.githooks/pre-commit`. Resolve this in slice C.
- **CPA-m6**: record legacy-mode behaviour changes in the validation evidence as
  intended fixes or deviations (see CPA-B2).

## Request focus

| Area | Assessment |
|---|---|
| Declared-branch precedence, activation, legacy safety | Precedence sound; legacy regressions (B2); archived rows (M1) |
| Budgets, exceptions, inventory, markers, stale handoffs | Sound and tested; inventory gap (m1) |
| Checkpoints, verdict scope, vendor gates, unchanged retries | Parsing sound; launcher integrity missing (B1); upgrade fragility (M3) |
| Checkout/integration failure, timeout evidence, scratch containment | Sound; legacy removal (B2); scale (M5) |
| Migration, preservation, numbering, hooks, CI | Placeholders and numbering sound; CI step (M4); hook scope (m2) |
| Honest limits | Mostly honest; enforcement doc overclaims launcher checks (B1) |

No gate was cleared, no delta review started, and no slice B/C work begun.
