# Opus adversarial specification review: Spec 001

- **Review date**: 2026-10-11 (requested 2026-10-10).
- **Reviewed revision**: `059405a` on `feat/001-spec-first-workflow` – spec, author
  checklist, source audit, review request, plus kit scripts, prompts, and the
  installed Spec Kit at that revision.
- **Reviewer**: GitHub Copilot agent in VS Code Insiders, on a model the host
  reports as Claude Opus 5.5. This identity is host-reported, not independently
  attested. The spec author's model is unknown to me.
- **Verdict**: **accept with bounded corrections**. The direction is right and the
  audit's kit observations reproduce. Resolve B1–B6 in `spec.md` before planning.
  M-items may be resolved in the spec or carried into `plan.md` with a named owner.

## Verified observations

- `agent-loop.ps1` L759 matches exact `In Progress`; L1180–1182 continues on the
  current branch after checkout failure; L1214–1228 prints "Finished spec package"
  after `MaxAddressRounds` even when inbox findings remain; L1368 uses
  `worktree remove --force` and L1378 falls back to recursive `Remove-Item`.
- `workflow-kit.ps1` L136–140 requires `TODO.md`, `STATUS.md`, `HISTORY.md`.
- `install-vscode-prompts.ps1` L13–27 installs into user-level prompt folders shared
  by every repo on the machine.
- The kit has no `.github/workflows/`, no Git hooks, and no `.gitignore`.
  `tmp/hello.txt` and `tmp/world.txt` are tracked.
- `origin/main` (`a0f3bf4`, stale ancestor) and `origin/master` (`864cad5`,
  `origin/HEAD`) both exist. `prompts/repo-health-audit.prompt.md` L72 says to push
  to `origin/main`.
- The fact "Spec 001 awaits Opus review" is currently stated in nine places:
  `AGENTS.md`, `README.md`, `STATUS.md`, `TODO.md`, `docs/specs.md`,
  `AGENT-INBOX.md`, the constitution's governance section, the author checklist,
  and the spec header. This is transitional, but it shows the failure mode the
  spec targets: clearing one gate needs nine edits.

## Blocking findings

### B1. No declared lifecycle or gate record

Refs: FR-002, FR-004, FR-010, FR-015, FR-016, key entities.

The spec forbids inferring actionability from display text, order, or branch,
but never says where lifecycle and checkpoint state are declared or which values
they take. The spec's own header (`Status: Draft, awaiting owner-run Opus
adversarial review`) is display text of the forbidden kind. Without a declared
vocabulary FR-010 (closed or superseded handoffs), FR-015 (missing, blocking, or
superseded verdicts), and FR-016 cannot be tested, and implementation will
regress to string matching.

Correction – add a requirement that defines:

1. One closed lifecycle vocabulary, for example `draft`, `review-blocked`,
   `ready`, `in-progress`, `parked`, `delivered-cleanup-pending`, `closed`,
   `superseded`.
2. One declaration site per package: a small structured block in `spec.md`
   before planning and in `tasks.md` after; exactly one is authoritative at a time.
3. Checkpoint records as structured entries: id, scope revision, required
   reviewer class, verdict file link, state.
4. Identifiers for superseded scopes and tasks, so handoffs can be matched.

### B2. Several current-work pointers; catalog duplicates lifecycle

Refs: FR-004, FR-005, FR-007, SC-001.

The catalog holds "coarse lifecycle"; the package declares lifecycle;
`AGENT-INBOX.md` may keep "a concise current resume pointer"; `AGENTS.md` holds
"routing"; Spec Kit keeps `.specify/feature.json`. Up to five places name current
work. That is the Spec 024 README/tasks drift reproduced at repo level.

Correction:

- The package declaration is the sole lifecycle owner. The catalog holds identity,
  location (branch plus repo-relative path), and priority order. If it displays
  lifecycle, lint verifies equality with the package; it is never authored there.
- `AGENTS.md` routing is static: it points to the catalog and never names the
  active spec.
- Choose one resume pointer (recommended: the catalog's first active entry) and
  remove the inbox resume-pointer allowance from FR-005.
- Name the four root entry files SC-001 counts.

### B3. The installed Spec Kit contradicts the spec, which never mentions it

Refs: FR-001, FR-007, FR-009, FR-010, FR-015, FR-016, FR-017, FR-019.

- `speckit-plan` writes the plan path between `SPECKIT` markers in `AGENTS.md`
  (`.agents/skills/speckit-plan/SKILL.md` L148) and `CLAUDE.md`
  (`.claude/skills/speckit-plan/SKILL.md` L151). That injects per-feature state
  into always-loaded files, against FR-007 and the 15-line adapter budget.
- `.specify/feature.json` is a committed singleton "active feature" pointer.
  After merge, the target branch points at a closed spec; concurrent features
  conflict on it.
- `.specify/scripts/powershell/common.ps1` resolves the feature from
  `SPECIFY_FEATURE` or the branch name and falls back to the literal `main` (L104),
  against FR-016 and FR-017.
- `create-new-feature.ps1` numbers features from top-level `specs/` directories
  and live branches (L52–117). Archiving a package (FR-019) and deleting its branch
  makes its number reusable, so closeout manufactures the duplicate identities
  FR-010 must detect.
- `speckit-implement`'s checklist gate is an interactive "proceed anyway?"
  question (L81–86) – a soft gate, not the FR-015 checkpoint.
- `.specify/memory/constitution.md` is a fourth rule surface beside `AGENTS.md`,
  `.github/copilot-instructions.md`, and adapters, with no assigned role.

Correction – add a "Spec Kit integration" requirement group:

- Marker updates to `AGENTS.md`/`CLAUDE.md` are disabled or limited to one static,
  budgeted line.
- `feature.json` is a local cursor (ignored), never an owner.
- Feature resolution uses the declared package, not a branch fallback.
- Archived packages keep their numbers reserved (archive where the numberer scans,
  or make the numberer read the archive index).
- Unattended implementation cannot pass a blocking checkpoint by answering "yes".
- Spec Kit upgrades (`specify init --here`) must not overwrite kit-customized
  templates or the constitution; vendor-managed skill files are excluded from
  authored budgets but appear in the always-loaded inventory where a host loads them.
- The constitution either owns principles (with `AGENTS.md` linking) or is retired.

### B4. Shared user-level prompts change unmigrated repositories

Refs: FR-030, FR-031, FR-032.

Prompts install into the user prompt folder, which every repo uses. Updating
`/whats-next`, `/orchestrate`, `/overnight`, or `/freshen-status` for the new model
changes behavior in Generator, Planning, Registry, and BF main before they migrate.
FR-031's read-only diagnostics would replace their daily `/whats-next`. FR-032
forbids modifying portfolio repos but not changing their behavior through global
prompts and launchers.

Correction: shared prompts and launchers detect the repo's declared workflow
model version (the FR-030 activation marker) and run the matching mode. Legacy mode
stays supported until the owner retires it after portfolio adoption. Alternatively,
version prompt names. Installing updated prompts is a separately authorized
activation step, not part of kit self-hosting.

### B5. Review termination and clearing authority are undefined

Refs: FR-014, FR-015, SC-009, user story 3.

If the author agent declares blocking findings resolved, the gate is
self-certified. If every correction needs the reviewer, rounds can repeat
indefinitely. "Additional loops need a named reason and owner direction" leaves
unclear whether the first follow-up is automatic. Today the gate is an unchecked
checklist box any agent can tick.

Correction:

- For each blocking finding, the author records a disposition: fixed at revision X,
  rejected with reason, or deferred with an owner.
- The gate clears when the owner accepts the dispositions, or when one delta
  review limited to the blocking findings returns none.
- At most one automatic follow-up; further rounds need owner direction.
- Gate state lives in the B1 checkpoint record, never a checklist box; the
  scheduler clears only on a verdict file plus a checkpoint record.
- State plainly that file-based verdicts do not stop a dishonest agent; the
  enforced boundary is the kit's own launchers and checks.

### B6. Closeout cannot finish for the owner's actual merge patterns

Refs: FR-013, FR-020, FR-024, user story 4.

- A local `git merge --squash`, or a repo without a merge provider, produces no
  merge record. FR-020 then always yields unknown and `Merged, cleanup pending`
  accumulates – the problem user story 4 targets.
- FR-024 requires archive and catalog commits on the surviving branch before
  deletion. For squash or PR flows that is a direct write to the target branch,
  which may need its own PR and authorization.
- Squash proof from provider records needs network; FR-013 bars network only for
  routine checks, but the spec does not say closeout may use it.

Correction:

- Make archive and catalog update the final commit on the delivery branch
  (lifecycle `delivered-cleanup-pending`), so the squash carries it and
  post-merge closeout needs no target-branch write.
- Accept owner attestation as a proof source alongside ancestry and provider
  records, recorded in the package as target, landed commit, and accepted head.
- Closeout may query the network when authorized; offline means unknown.

## Major findings

### M1. Per-file budgets can be evaded by splitting

Refs: FR-007, FR-009, FR-029.

This session loaded `AGENTS.md`, `CLAUDE.md`, and `.github/copilot-instructions.md`
together. Add an aggregate always-loaded budget per host. Decide the fate of
`.github/copilot-instructions.md` (296 lines, 19,265 bytes): a 15-line adapter or a
declared, budgeted file. Its tier routing, model preferences, CLI authentication,
and terminal rules have no named destination. Model preferences are already
duplicated between that file and `agent-loop.ps1` (`TierDispatchMap`, comments at
L100–104); FR-029 should name the single owner.

### M2. Status growth moves into `tasks.md`

Refs: FR-002, SC-001.

The 618- and 549-line status files will reappear as long `tasks.md` files; Spec
024 reached T109. SC-001 assumes a "current work section" the Spec Kit tasks
template lacks. Require a bounded current-work header at the top of `tasks.md`
(lifecycle, next task IDs, blockers, checkpoints; for example 25 lines) and budget it.

### M3. Worktree-resident state and branch divergence

Refs: FR-010, FR-016, edge cases, constitution principle V.

The "newer decisions live in an active worktree" edge case is listed but not
resolved. A catalog on the target branch cannot store absolute worktree paths.
Store the branch; resolve branch to worktree locally with `git worktree list`.
A package is authored only on its declared branch; copies elsewhere are snapshots,
and lint flags package edits off that branch. State precedence: the declared-branch
package beats a primary-checkout copy.

### M4. Scratch worktrees need a separate class

Refs: FR-022.

Forbidding force everywhere reverses the Windows hardening that fixed real
temp-worktree residue. For kit-created scratch worktrees under a managed root with
a marker, allow `git worktree remove --force` after verifying integration and no
non-disposable untracked content. Keep recursive filesystem deletion forbidden;
report residue for later pruning. Delivery worktrees keep FR-022 as written.

### M5. Disposable content and holds have no declaration site

Refs: FR-021.

With nothing declared, every ignored file is protected and any worktree with
`node_modules`, `.venv`, or `.pytest_cache` is never eligible. Define one per-repo
configuration location (shared with budget exceptions, declared auto-loaded files,
target branch, and model version) and a kit default disposable list. Holds live in
the package record, not only inside the worktree.

### M6. Returns must cite the brief revision

Refs: FR-026, FR-027, FR-028.

FR-027 invalidates in-flight results when a brief changes, but FR-028 does not
require returns to name the brief revision executed. Add it. Also state who writes
a consumer package's `tasks.md` in cross-repo work, so one-writer-per-area covers it.

### M7. Declared target branch

Refs: FR-017, edge cases.

The kit itself has a stale `main` and a current `master`, and one prompt pushes to
`origin/main`. Require a declared target branch per repo and add the edge case
"both `main` and `master` exist".

### M8. Scope is too large for one delivery

Refs: FR-025–FR-032.

Thirty-two requirements span lint, scheduler, closeout, migration, hooks and CI,
and orchestration. Slice delivery with checkpoints: A, ownership, lifecycle, lint,
and scheduler gates, self-hosted; B, closeout; C, migration and prompt dual-mode.
Move user story 6 and FR-025–FR-029 to Spec 002; FR-032 already forbids portfolio
launches and SC-007 is fixture-only. Name the package structured block (B1) and
the per-repo configuration (M5) as the only new state homes, to keep "no state
database" honest.

## Minor findings

- **m1** (FR-008): the kit has no CI; self-hosting must add a backstop or report the gap.
- **m2** (FR-009): state that review findings files are exempt from the 30-line request budget.
- **m3** (FR-008): deliver a per-host enforcement matrix (VS Code Copilot Chat,
  Copilot CLI, Codex, Claude Code) naming available triggers.
- **m4** (FR-005): until implementation, current rules drain `AGENT-INBOX.md`.
  Triage this findings link into the package, not `TODO.md`.
- **m5** (FR-030): migration preview should flag tracked scratch such as `tmp/`.
- **m6**: FR-008, FR-021, and FR-030 each bundle five to eight obligations; number
  sub-clauses so tasks and checks can cite them.

## Request questions

| Question | Assessment |
|---|---|
| Ownership without duplicate state | Partial – B1, B2 |
| Budgets and honest enforcement | Line and byte rules sound; aggregate missing (M1), `tasks.md` growth (M2), host matrix (m3) |
| Freshness, divergence, scope resets | Freshness limits honest (FR-011); divergence open (M3); resets need B1 identifiers |
| Checkpoints without endless reviews | Not yet – B5 |
| Safe closeout | Not yet – B6, M4, M5, number reuse in B3 |
| Orchestration | Mostly sound – M6; defer per M8 |
| Migration and compatibility | Not yet – B4, B3, M1 |
| Practical scope | Too broad – M8 |

## Owner decisions

Recorded 2026-10-11 from the owner's chat confirmation. Where a decision differs
from a correction above, the decision governs.

1. **Lifecycle (B1)**: one structured block at the top of `spec.md`, authoritative
   for the package's whole life; `tasks.md` owns tasks and next actions only. Fixed
   key `**Lifecycle**:` with values `draft`, `review`, `ready`, `active`, `parked`,
   `delivered`, `closed`, `superseded`. A `**Checkpoints**:` table below it with
   columns ID, gate, verdict link, state. No switching of authority to `tasks.md`.
2. **Resume pointer (B2)**: `docs/specs.md` is the single current-work pointer.
   `AGENTS.md` routes to it statically and never names the active spec; the inbox
   carries transient handoffs only. Catalog lifecycle, if shown, is lint-checked
   against `spec.md`, never authored independently.
3. **Spec Kit (B3)**:
   - Lint fails if `SPECKIT` marker blocks appear in `AGENTS.md` or `CLAUDE.md`;
     `AGENTS.md` states not to add them. Vendor skill files are not edited.
   - `.specify/feature.json` is ignored, never committed or treated as an owner.
   - Packages are never moved on closeout: they stay in `specs/` with
     `Lifecycle: closed`; only the catalog entry moves to an archive section of
     `docs/specs.md`. Numbers stay reserved and links stay valid.
4. **Prompt transition (B4)**: shared prompts and launchers run in new mode when
   the repo has the new workflow config file, legacy mode otherwise. Legacy mode is
   removed after all portfolio repos migrate. Installing the updated prompts is a
   separate authorized step.
5. **Gate clearing (B5)**: only the owner sets a checkpoint to `owner-cleared`.
   Agents record per-finding dispositions but never clear a gate. Delta reviews
   happen only when the owner requests one. Most repos have a single contributor.
6. **Closeout (B6)**:
   - The final commit on the delivery branch sets `Lifecycle: delivered` and moves
     the catalog entry; the squash carries it, so closeout never writes to the target.
   - Automatic proof: ancestry for normal merges; for squash, every file the branch
     changed is identical on the target to the branch head. Otherwise closeout asks
     the owner, and the confirmation (target, landed commit, accepted head) is
     recorded in the package as proof.
   - Then remove the worktree and delete the branch, under FR-021–FR-023.
7. **Instruction files (M1)**: `AGENTS.md` is the single main file (≤100 lines,
   invariants and routing). `CLAUDE.md` is one line, `@AGENTS.md`.
   `.github/copilot-instructions.md` becomes a one- or two-line pointer to
   `AGENTS.md` (or is deleted if every used host reads `AGENTS.md`).
   `.github/agents/agent.md` is retired. The current 296-line content moves:
   invariants to `AGENTS.md`; STATUS/TODO/HISTORY rules are dropped; model-tier
   preferences are owned by `agent-loop.ps1` (or a config it reads) and linked
   elsewhere; tier routing guidance goes to the `/orchestrate` prompt; Copilot CLI
   login and terminal rules go to the `/overnight` prompt or one on-demand ops doc.
8. **Orchestration (M8)**: user story 6 and FR-025–FR-029 move to a new Spec 002,
   started after Spec 001's first delivery slice. Spec 002 generalizes from two
   real cases: canonical-spacing-spec with baseline-foundry, and the Jira bridge.
   Spec 001 keeps one rule: a consumer repo's package links to the coordinating
   package and never copies its progress. The workflow kit's relation to consumers
   is distribution, covered by migration (decisions 3 and 4).

No implementation was performed, no checklist item was marked, and no gate state
was changed.
