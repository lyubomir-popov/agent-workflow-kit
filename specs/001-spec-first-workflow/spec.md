# Feature specification: Spec-first agent workflow

**Feature branch**: `feat/001-spec-first-workflow`
**Created**: 2026-10-10
**Lifecycle**: active
**Scope**: `001/spec-r2`; supersedes `001/spec-r1` (`059405a`)
**Superseded tasks**: none.

<a id="checkpoints"></a>
**Checkpoints**:

| ID | Gate | Verdict link | State |
|---|---|---|---|
| CP1 | Opus spec review | [Opus findings](reviews/2026-10-10-opus-spec-review.md); [owner acceptance, 2026-10-11](reviews/2026-10-11-author-dispositions.md#owner-acceptance-and-amendments-2026-10-11) | owner-cleared |
| CP2 | Opus slice A review | [Opus findings](reviews/2026-10-11-opus-slice-a-review.md); [author dispositions](reviews/2026-10-11-cp2-author-dispositions.md) | pending |
| CP3 | Opus slice B review | Pending owner-run review after slice B | pending |
| CP4 | Opus slice C review | Pending owner-run review after slice C | pending |

**Input**: Bring the kit up to date with the frequently used repositories.
Prevent staleness and instruction growth, remove overlapping legacy state,
and complete worktree cleanup after spec delivery. Cross-repo orchestration
moves to Spec 002. [Author dispositions](reviews/2026-10-11-author-dispositions.md)
record the owner's acceptance and amendments dated 2026-10-11. CP1 is
owner-cleared; later slice checkpoints remain pending.

## User scenarios and testing

### User story 1: Resume from one current work record (Priority: P1)

As the owner, I want a fresh agent to find the current spec, next action, and
blockers without reconciling several versions of the same state.

**Why this priority**: Competing instructions can restart superseded work.
Keeping them short does not resolve disagreement.

**Independent test**: Resume an example with an active spec, a parked spec,
and historical records. Find the next task and gate from their owners.

**Acceptance scenarios**:

1. **Given** an active catalog entry and a transient inbox handoff, **when** a
   chat resumes, **then** the catalog routes to the declared-branch package;
   its lifecycle/checkpoints and tasks govern work, not an old handover.
2. **Given** a scope reset, **when** work records are reconciled, **then** old
   instructions become historical, live routers point to the new scope, and
   completed preparation is not described as next work.
3. **Given** a small local fix, **when** no new governed behavior or cross-repo
   decision is needed, **then** the agent acts without a full spec package or
   another root task list.

### User story 2: Detect drift without requesting a cleanup sweep (Priority: P1)

As the owner, I want routine checks to catch growing entry files, broken
pointers, and obsolete state before another two weeks pass.

**Why this priority**: Remembering to request an audit has proved unreliable.

**Independent test**: Simulate fourteen daily handover appends and scope
changes. Routine checks expose the introduced mechanical drift without a
manual health prompt.

**Acceptance scenarios**:

1. **Given** an entry file above its line or byte budget, **when** checked,
   **then** it fails with its measured excess and owning destination;
   compressing the content into long lines cannot pass.
2. **Given** a handoff naming a closed task or superseded scope, **when** its
   declared state is checked, **then** it is flagged; changing a date does
   not clear the finding.
3. **Given** parked work, **when** its age increases, **then** age alone
   neither requires edits nor makes it actionable.
4. **Given** an unsupported agent host, **when** integration is reported,
   **then** enforcement gaps are named; the kit does not claim to enforce
   every chat interaction on that host.

### User story 3: Keep reviews durable and checkpoints binding (Priority: P1)

As the owner, I want Opus findings to survive chat changes and inbox triage,
and automation to stop at the checkpoints I designated.

**Why this priority**: Lost findings and bypassed gates invalidate completion.

**Independent test**: Save a blocking review, hand it over through inbox
links, and attempt continuation. The review survives and beyond-gate work stops.

**Acceptance scenarios**:

1. **Given** a spec review, **when** handed off, **then** the saved request
   and separate findings live in the package; the inbox carries links.
2. **Given** a received review, **when** its inbox entry is removed, **then**
   findings and per-finding dispositions remain in the package; before planning
   they do not require a new root queue or premature `tasks.md`.
3. **Given** an empty inbox and unresolved blocking verdict, **when** the
   scheduler runs, **then** the gate still prevents continuation.
4. **Given** exhausted remediation rounds, **when** reported, **then** the
   outcome is incomplete rather than finished.
5. **Given** author corrections, **when** checks pass, **then** CP1 still stops
   planning until the owner accepts dispositions and sets `owner-cleared`;
   no delta review starts without the owner's request.

### User story 4: Finish delivery with safe cleanup (Priority: P1)

As the owner, I want completed spec worktrees cleaned up during closeout,
with local work and parked experiments protected.

**Why this priority**: Forgotten directories accumulate; indiscriminate
cleanup can discard work that only exists in a checkout.

**Independent test**: Close normal and squash-merged examples alongside
dirty, protected, unpublished, and unverified examples. Remove only eligible
targets and report why others remain.

**Acceptance scenarios**:

1. **Given** a final delivery commit setting `delivered` and moving the catalog
   entry, **when** the accepted head lands and cleanup is authorized, **then**
   closeout removes eligible worktrees/branches without writing to the target;
   the package path and number remain reserved.
2. **Given** untracked reviews, unpublished work, or ignored user files,
   **when** evaluated, **then** cleanup preserves them until preservation
   is verified; age does not establish eligibility.
3. **Given** a squash merge, **when** every branch-changed file matches the
   target at the accepted head, **then** automatic proof can pass; otherwise
   owner confirmation is required and unknown proof retains the worktree.
4. **Given** interrupted closeout, **when** retried, **then** completed steps
   remain completed and no evidence is deleted or duplicate state recreated.

### User story 5: Adopt one coherent workflow (Priority: P1)

As the owner, I want migration to preserve useful information and leave one
operating model in the kit and, later, portfolio.

**Why this priority**: Partial adoption recreates the duplication being fixed.

**Independent test**: Preview and apply a legacy-example migration, interrupt
and resume it, then check all live routers and legacy-content dispositions.

**Acceptance scenarios**:

1. **Given** legacy files, **when** previewed, **then** destinations, obsolete
   content, conflicts, and changed routers are visible before activation.
2. **Given** successful migration, **when** an old entry point runs, **then**
   it uses the new owners or reports deprecation; it cannot recreate retired
   files or bypass a gate.
3. **Given** an external-kit consumer, **when** migrated, **then** external
   asset ownership and local product invariants survive.
4. **Given** an unmigrated consumer, **when** shared prompts or launchers run,
   **then** its legacy workflow still operates; migration preview stays read-only
   and updated prompt installation requires separate authorization.

### User story 6: Moved to Spec 002

Cross-repo briefs, worker ownership/returns, sequencing, and calibration are
deferred to the candidate in [the catalog](../../docs/specs.md).

### Edge cases

- Both `main` and `master` exist; only the configured target branch governs delivery.
- Newer decisions live on the package's declared branch in an active worktree;
  primary-checkout copies are snapshots, not competing owners.
- A branch is missing, checkout fails, or a scratch worker is intentionally detached.
- Catalog archive moves preserve package paths and reserve feature numbers.
- Reviews are unreceived, uncommitted, missing verdicts, or stale for the scope.
- Task checkboxes contradict an uncleared gate; scope IDs change during execution.
- Ignored dependency output and ignored user evidence share a checkout.
- Worktrees are locked, contain junctions, or have prefix-lookalike paths.
- Merge providers are unavailable, refs are stale, or a branch was squash-merged.
- Old experiments are held intentionally; a repo has no active spec.
- An external governing draft must retain its stable path.
- An existing commit hook must be preserved; an editor ignores repo instructions.
- A Spec Kit upgrade attempts to overwrite customized templates or the constitution.
- Vendor skills inject marker blocks, or a stale local feature cursor names closed work.
- Landed work remains terminally `delivered`, whether cleanup completes or retains
  a worktree; `closed` means withdrawn or abandoned without delivery.
- An annotated `archive/<package-id>` tag preserves proof before branch deletion;
  pushing it requires authorization, and an interrupted closeout can reuse it.
- Retained worktrees, unknown proof, and dirty state are computed from Git/config
  during preview; package-owned holds must already be declared before delivery.

## Requirements

### Functional requirements

#### Ownership and lean entry points

- **FR-001**: The default work-tracking model MUST use `specs/`,
  `docs/specs.md`, `AGENT-INBOX.md`, and `INBOX.md`. Instructions and human
  overview remain supported, with detailed material read on demand.
- **FR-002**: `spec.md` MUST own lifecycle/checkpoints for the package's whole
  life (FR-033). After planning, `tasks.md` owns task state, next actions,
  task blockers, and validation references. Its top current-work header MUST
  stay within 25 physical lines/4,096 UTF-8 bytes, naming next task IDs,
  blockers, and checkpoint links, not copying lifecycle or gate state.
  Historical task detail stays below it; no new root queue is introduced.
- **FR-003**: `spec.md` MUST own intent/acceptance, `plan.md` approach and
  responsibilities, and `reviews/` saved requests/findings. A package README
  routes to these owners and MUST NOT duplicate current work state.
  A consumer package MUST link to its coordinating package and MUST NOT copy
  that package's progress; orchestration implementation is outside Spec 001.
- **FR-004**: `docs/specs.md` MUST be the single current-work pointer, with
  ordered concise entries naming identity, repo-relative package path, and
  declared branch, never absolute worktree paths. Its first active entry is
  the resume pointer. Lifecycle is owned only by `spec.md`; if displayed in
  the catalog it MUST be derived and lint-checked for equality, not separately
  authored. Delivered entries move to an archive section in the same catalog;
  packages do not move. A bounded
  candidate section may retain unpromoted ideas, with at most ten entries;
  overflow moves to on-demand product direction, not another execution queue.
- **FR-005**: Inbox entries MUST name recipient/scope, artifact link, and
  requested action. Remove entries only after receipt and resolution or
  durable transfer. Inboxes MUST NOT hold standing resume pointers. Lint MUST
  allow unread handoff links and MUST NOT require destructive inbox drainage.
  Review handoffs transfer into package reviews/dispositions, not a root queue.
- **FR-006**: Migration MUST retire root `STATUS.md`, `TODO.md`, and
  `HISTORY.md` as active owners. Useful state moves to packages/catalog;
  history becomes inactive records or remains recoverable in Git. Stable
  product direction may remain on demand; root roadmaps MUST cease to be
  required cold-start or execution inputs. Kit self-hosting in slice A MUST
  leave each retired file as a 2–3 line placeholder pointing to `docs/specs.md`,
  preventing installed legacy prompts from recreating it. Slice C removes these
  placeholders after the owner installs the dual-mode prompts. Open TODO items
  move to catalog candidates (at most ten) or `ROADMAP.md`; HISTORY content
  remains recoverable in Git or moves to an on-demand archive. Nothing useful
  may be lost.
- **FR-007**: Root `AGENTS.md` MUST contain invariants and static routing to
  `docs/specs.md`, never the active spec or per-feature state. `CLAUDE.md` MUST
  contain only `@AGENTS.md`; Copilot instructions become a one- or two-line
  pointer, or are removed if all used hosts read AGENTS. The resume agent is
  retired. Destinations for existing rules are specified in FR-036. Detail and skills load
  only for relevant work. Small fixes MUST remain possible without a spec
  package or an extra status channel.

#### Automatic checks and staleness

- **FR-008**: Automatic checks MUST meet these independently testable clauses:
  1. Quick health checks are read-only and report installed triggers.
  2. Kit worker launchers check before dispatch and refuse blocking findings.
  3. Migrated repos have a local commit check, composing with existing hooks.
  4. The kit delivers a CI backstop or explicitly reports its absence as a gap;
     consumer migrations likewise report missing CI rather than claiming enforcement.
  5. Instructions require checks at session start/end and scope changes.
  6. A per-host matrix covers VS Code Copilot Chat, Copilot CLI, Codex, and
     Claude Code: actual automatic/manual triggers, skipped hooks, and unsupported
     enforcement. Instructions alone MUST NOT be reported as automatic enforcement.
- **FR-009**: Checks MUST enforce physical line counts, including blanks,
  and UTF-8 byte size. Default budgets are:

  | Surface | Maximum lines | Maximum bytes |
  |---|---:|---:|
  | Root `AGENTS.md` | 100 | 12,288 |
  | Each always-loaded agent adapter | 15 | 2,048 |
  | Root `AGENT-INBOX.md` | 60 | 8,192 |
  | Active `docs/specs.md` | 100 | 12,288 |
  | Each review request | 30 | 6,144 |
  | `tasks.md` current-work header | 25 | 4,096 |
  | Aggregate always-loaded instructions, per host | 150 | 16,384 |

  Review findings are exempt from request budgets and read on demand. The
  catalog budget applies to its live routing sections, not its on-demand archive.
  Other automatically loaded files MUST be declared and budgeted in FR-035 config.
  Aggregate budgets count the content each host actually loads, including vendor
  content if loaded in full; unknown loading is a reported gap, not zero.
  Vendor skill files are exempt from authored per-file budgets, not the inventory.
  Exceptions require owner authorization, reason, and expiry in that config;
  splitting content across files or unbounded exceptions MUST NOT evade enforcement.
- **FR-010**: Quick checks MUST detect missing owners/links, duplicate
  package identities, retired execution routers, branch/package mismatch,
  and handoffs naming tasks or scopes declared closed/superseded. Active
  root routers MUST NOT accumulate completed entries or historical narratives.
  Declared-branch packages take precedence over primary-checkout snapshots;
  local worktrees resolve through `git worktree list`. Package edits off the
  catalog-declared branch MUST fail, not rewrite the snapshot to match it.
- **FR-011**: Checks MUST distinguish mechanical evidence from semantic
  judgment. Passing size checks or restamping dates MUST NOT establish prose
  freshness. Scope reset and closeout MUST include comparing live routing
  prose with the package's declared current work.
- **FR-012**: Age alone MUST NOT reactivate parked work, clear checkpoints,
  or justify deletion. Diagnostics MUST name the conflicting artifact or
  excess and a concrete repair. Human and machine-readable reports MUST use
  stable finding identities and meaningful failure outcomes.
- **FR-013**: Routine checks MUST avoid broad archives, generated output,
  and sibling reads, and require no network or model calls. Missing remote
  merge evidence is unknown. Timers, external scheduled services, and a full
  architecture audit on every interaction are outside this feature.

#### Reviews and unattended execution

- **FR-014**: Required reviews MUST have separate saved requests and
  findings in the owning package, naming scope, reviewed revision, actual
  known reviewer identity, verdict, and actionable findings. Inbox links and
  task dispositions MUST preserve the full reviews through triage/archive.
  Author self-checks MUST NOT impersonate independent or Opus reviews.
- **FR-015**: Checkpoints MUST be declared before execution. Agents record
  per-finding dispositions: fixed at a revision/section, rejected with reason,
  or deferred to a named owner/spec. Only the owner sets `owner-cleared` after
  accepting dispositions and the saved verdict; agents MUST NOT clear gates.
  Delta reviews happen only on owner request. Automation MUST stop for uncleared
  checkpoints or missing/blocking/superseded required verdicts; task checkboxes,
  an empty inbox, or answering a Spec Kit "proceed anyway" prompt cannot override.
  File records cannot prevent a dishonest agent; enforcement is in kit launchers
  and checks, with host gaps reported honestly.
- **FR-016**: Scheduler discovery MUST use declared lifecycle and package
  ownership, resolving declared branches to local worktrees. It MUST NOT
  infer actionability from exact display text such as `In Progress`, numeric
  order alone, or the current branch. Only `active` packages with cleared entry
  gates are unattended implementation candidates. `draft`, `review`, `ready`,
  `parked`, `delivered`, `closed`, and `superseded` are not automatic task queues.
- **FR-017**: Worker preflight MUST verify repo, package, branch/base,
  worktree, write scope, and authorization. Checkout failure MUST stop the
  operation. Detached scratch workers need an explicit integration target;
  fallback to an unrelated branch is forbidden. Default branches MUST NOT
  be assumed to be `main`; the repo config MUST declare its target branch.
- **FR-018**: Exhausted remediation, worker failure, dirty primary state,
  or failed integration MUST report an incomplete/blocked outcome and preserve
  recoverable work. Required unfinished tasks/findings prevent completion.
  Failure policies MUST NOT skip gates or retry the same unchanged task indefinitely.

#### Closeout and worktree lifecycle

- **FR-019**: Closeout MUST offer read-only preview and separately apply
  authorized steps: verify delivery, preserve artifacts, remove eligible
  worktrees, and reconcile eligible local/remote branches. The final commit
  on the delivery branch MUST set `Lifecycle: delivered` and move its catalog
  entry to the archive section, so a squash carries both. Package directories
  MUST stay in `specs/`; closeout MUST NOT write to the target branch. Before
  deleting the delivery branch, closeout MUST create an annotated
  `archive/<package-id>` tag on the accepted head as preserved proof (FR-020).
  Pushing this tag requires authorization.
- **FR-020**: Merge proof MUST identify the target and accepted source
  revision. Automatic proof is ancestry, or, for squash delivery, exact equality
  on the target with the branch head for every path the branch changed relative
  to its declared base, including additions, deletions, modes, and renames.
  Otherwise owner confirmation is required. Before branch deletion, the annotated
  `archive/<package-id>` tag MUST point to the accepted head; its message records
  target, landed commit, proof method (`ancestry`, `changed-path equality`, or
  `owner confirmation`), and date. This tag preserves proof without a new state
  file or target-branch write. Closeout may use the network only when authorized;
  tag pushes require authorization. Similarity, a provider claim alone, branch names,
  and missing/stale refs are not proof. Unknown proof retains worktree and branch.
- **FR-021**: Cleanup MUST meet these preservation clauses:
  1. Inspect tracked/untracked changes, ignored content, unpublished commits,
     locks, and package-owned holds; clean tracked status alone is insufficient.
  2. Exempt only disposable generated/dependency patterns from FR-035 config;
     a tracked file or known evidence MUST NOT become disposable by pattern match.
  3. Use kit defaults `node_modules/`, `.venv/`, `.pytest_cache/`,
     `__pycache__/`, and `coverage/`; repo overrides require explicit declaration.
  4. Declare package-owned holds before delivery, so deleting a local marker
     cannot remove a hold. Compute cleanup status, including retained worktrees,
     unknown proof, and dirty state, from Git/config during preview; do not persist it.
  5. Preserve evidence and non-disposable ignored content before deletion.
  6. Treat existing old worktrees as inventory candidates, never abandoned by age.
- **FR-022**: Cleanup MUST honor repo/session authorization. Ordinary
  `git worktree remove` is the default for delivery worktrees; automatic force
  is forbidden for that class. A kit-created scratch worktree MUST have both
  a kit marker and containment under the configured managed root. Only that
  class may use `git worktree remove --force`, after integration/preservation
  proof and checks for non-disposable untracked/ignored content. Recursive
  filesystem fallback and deletion through symlinks/junctions remain forbidden
  in every class. Report residue for later Git pruning; do not erase it recursively.
- **FR-023**: Destructive targets MUST be normalized, checked against the
  intended repo/worktree and managed location, and revalidated immediately
  before mutation. Prefix-lookalike paths and unresolved links MUST be
  rejected. The primary checkout MUST never be a cleanup target.
- **FR-024**: Closeout MUST be resumable/idempotent. Evidence must be durably
  preserved before its source worktree disappears, including owner-confirmed
  proof when automatic proof fails, using the annotated archive tag (FR-020).
  The final delivery commit carries lifecycle and catalog changes (FR-019);
  cleanup MUST NOT add a target-branch commit or new state file. `delivered` is
  the terminal lifecycle for landed work and does not assert cleanup complete;
  `closed` means ended without delivery (withdrawn or abandoned). No post-merge
  documentation change is required. Retention reasons and cleanup status are
  computed from Git/config in the preview, not persisted; package-owned holds
  are declared before delivery. Retry MUST reuse preserved proof safely.
  Separate parked/held work does not prevent other eligible cleanup.

#### Cross-repository orchestration – moved to Spec 002

- **FR-025**: Moved to Spec 002 – programme boundaries and consumer ownership.
- **FR-026**: Moved to Spec 002 – complete, bounded, single-writer briefs.
- **FR-027**: Moved to Spec 002 – persistent workers, sequencing, revised briefs.
- **FR-028**: Moved to Spec 002 – returns cite the executed brief revision; consumer task ownership is explicit.
- **FR-029**: Moved to Spec 002 – proportional checks and early calibration.

#### Migration and delivery boundary

- **FR-030**: Adoption MUST meet these transition clauses:
  1. Preview every legacy file/section disposition, conflicts, and router changes.
  2. Flag tracked scratch such as `tmp/`; do not silently delete or ignore it.
  3. Activate through the versioned per-repo config in FR-035, reconciling
     instructions, resume agents, Spec Kit cursors, validators, and scheduler.
  4. Shared prompts/launchers choose spec-first mode when the new config model
     version is present, legacy mode otherwise; invalid config fails explicitly.
     Existing external-mirror config alone MUST NOT activate spec-first mode.
  5. Preserve recoverable state during interruption and rollback; competing
     execution owners MUST NOT be reported as a completed migration.
  6. Treat installing updated user-level prompts as a separately authorized
     activation step, outside kit self-hosting; do not silently run the installer.
  7. Retain legacy mode until all portfolio repos migrate, then retire it in
     separately authorized work; do not impose new behavior on unmigrated repos.
- **FR-031**: Existing prompt names, including `/freshen-status`, MUST route
  to the new owner through a documented alias or report deprecation. Migrated
  repos MUST NOT execute legacy TODO-driven work or recreate its files.
  Unmigrated consumers keep functional legacy prompts/launchers; their migration
  diagnostics are read-only until adoption is requested. External-kit ownership
  and local product rules MUST survive.
- **FR-032**: This feature MUST self-host the accepted model in the kit and
  provide a tested adoption procedure. It MUST NOT modify portfolio/reference
  repos, purge their worktrees, publish changes, or launch their workers.
  Portfolio adoption follows kit acceptance as separate authorized work.

#### Lifecycle and checkpoint declarations

- **FR-033**: The top block in `spec.md` MUST remain the sole lifecycle owner
  for the whole package life. The fixed `**Lifecycle**:` key accepts only
  `draft`, `review`, `ready`, `active`, `parked`, `delivered`, `closed`, `superseded`:
  intent, review, authorized planning, execution, hold, terminal landed delivery,
  ended without delivery (withdrawn or abandoned), or replaced scope respectively.
  `delivered` remains terminal after cleanup; no post-merge documentation change
  to `closed` is needed. Transitions require
  the phase's owner authorization and gates; `ready` is not unattended execution.
  Its `**Checkpoints**:` table MUST have ID, gate, verdict link, state columns.
  States are `pending`, `findings-received`, `owner-cleared`, `superseded`;
  only the owner authors `owner-cleared`. Saved review artifacts name checkpoint,
  reviewed scope/revision, reviewer, and verdict. Each scope has a stable package
  ID plus revision; the block names superseded scope IDs and task IDs. Tasks have
  stable IDs in `tasks.md`. A scope change invalidates affected prior clearances;
  unaffected clearance is retained only with explicit owner acceptance.

#### Spec Kit integration

- **FR-034**: Kit integration MUST preserve the ownership model:
  1. Lint fails on `SPECKIT` marker blocks in AGENTS/CLAUDE; AGENTS forbids them.
     Vendor skills remain unedited; their instructions cannot override this rule.
  2. `.specify/feature.json` is ignored, untracked local convenience, never an
     owner. Explicit package selection or the catalog resolves the feature;
     selection must agree with its declared branch. Neither a branch-name guess,
     `main` fallback, nor an unchecked local cursor authorizes package work.
  3. Packages remain at their original `specs/` paths after delivery/closeout;
     numbering includes all packages, reserving closed/superseded identities.
  4. Upgrades MUST preview and preserve kit-customized templates and constitution;
     rerunning `specify init --here` must not silently overwrite them.
  5. The constitution owns durable principles, linked from static AGENTS; it
     MUST NOT hold current spec, task, gate, routing, or operational state.
  6. Vendor skills are on-demand assets, with budget/loading treatment in FR-009;
     implementation/checklist commands MUST obey FR-015 regardless of their prompts.

#### Configuration and instruction migration

- **FR-035**: `.workflow-kit.json` MUST be the one per-repo workflow config,
  preserving existing external-mirror settings. It declares `workflowModelVersion`,
  target branch, disposable patterns, managed scratch root, budget exceptions
  (authorization/reason/expiry), and automatically loaded files with host/budget.
  Absence of the new version selects legacy mode; a valid new version selects
  spec-first mode. Holds and merge proof remain package-owned. This config and
  the package's `spec.md` block are the only new persistent state homes; no
  activation sidecar, review ledger, or additional state database is introduced.
- **FR-036**: Migrate every current Copilot-contract section to these owners,
  preserving product invariants and dropping obsolete STATUS/TODO/HISTORY rules:

  | Current section(s) | Destination |
  |---|---|
  | What this repo is; key surfaces | README overview; static AGENTS routing |
  | Documentation structure; instruction file scope; what goes where; agent file roles | AGENTS ownership map under this spec; legacy maps dropped |
  | Source-of-truth precedence; token discipline; repo boundary | AGENTS invariants, preserving code/data and docs distinctions |
  | Planning threshold; agent workflow; session start/during/end; inbox pattern | AGENTS concise spec-first rules; relevant prompts for procedures |
  | History rules | Retired; preserved history on demand/Git |
  | Validation; full/targeted validation | AGENTS trigger rule; README usage and `/run-validation` checks |
  | Agent environment; CLI authentication | `/overnight` or one on-demand operations doc |
  | Commit message discipline | AGENTS short invariant |
  | Autonomous continuation; maximizing run length | `/orchestrate` and `/overnight` procedures respecting gates |
  | Tier routing; orchestrator vs subagent execution | `/orchestrate` guidance |
  | Concrete model preferences | `agent-loop.ps1` or config it reads, one owner; other surfaces link |
  | Cross-repo coordination | AGENTS consumer-link rule; brief/worker details deferred to Spec 002 |
  | How to use boilerplate | README migration procedure |

  `.github/agents/agent.md` is retired; no destination becomes another status file.

#### Delivery slices

- **FR-037**: Delivery MUST proceed in slices with owner-run Opus checkpoints:
  A – ownership, lifecycle, lint/budgets, scheduler gates, Spec Kit alignment,
  and self-hosting; B – closeout; C – migration procedure and prompt dual mode.
  Self-hosting A may activate only kit-local instructions/config; it MUST NOT
  install shared prompts or claim B/C complete. Slice A leaves root `STATUS.md`,
  `TODO.md`, and `HISTORY.md` as 2–3 line catalog placeholders (FR-006); slice C
  removes them only after the owner installs dual-mode prompts. `plan.md` covers
  all three slices briefly; `tasks.md` details slice A only, with one-line
  placeholders for B and C. Before A, declare CP2 (after A),
  CP3 (after B), CP4 (after C) in the same checkpoint table. Beyond-slice work
  stops until the owner clears that checkpoint. Spec 002 may start after A,
  on separate authorization; no package is created by this revision.

### Key entities

- **Spec package**: Intent/acceptance and lifecycle/checkpoints in `spec.md`,
  approach in `plan.md`, task state in `tasks.md`, saved reviews/dispositions.
- **Catalog entry**: Identity, repo-relative location, declared branch, priority;
  the sole resume pointer, with lifecycle only as a checked derived view.
- **Handoff**: Recipient/scope, artifact link, requested action, receipt state;
  transient, not a standing resume pointer.
- **Checkpoint**: Package table ID/gate/verdict link/state, with reviewed scope,
  reviewer, and findings in linked artifacts; only the owner clears advancement.
- **Worktree disposition**: Repo, branch/target, merge evidence, preservation
  and pre-delivery package holds; cleanup outcome/reasons computed from Git/config
  in preview, with proof preserved in an annotated archive tag.
- **Workflow config**: One versioned per-repo policy declaration (FR-035),
  separate from package lifecycle and task state.

## Success criteria

### Measurable outcomes

- **SC-001**: A new session finds its package, next action, and blocker from
  at most four entry files: `AGENTS.md`, `docs/specs.md`, `AGENT-INBOX.md`,
  `INBOX.md`; then its declared-branch `spec.md` block and bounded `tasks.md`
  header. Host adapters are included in the always-loaded budget, not additional
  manual resume steps. No retired global state or local feature cursor is needed.
- **SC-002**: Every above-budget example fails routine checks, including
  long-line byte overflow. Fourteen simulated daily updates expose introduced
  mechanical drift at the next trigger without a manual audit request; split-file
  aggregate overflow and marker injection also fail. The host matrix names gaps.
- **SC-003**: Scope-reset examples identify every declared closed/superseded
  execution pointer; parked work stays parked without date churn. Semantic
  reconciliation limits are reported explicitly.
- **SC-004**: Saved reviews survive triage. Continuation examples start zero
  beyond-gate tasks for missing/blocking/obsolete verdicts, branch failures,
  exhausted remediation, or author-disposed findings without owner clearance.
  No automatic delta review runs; only owner-authored clearance advances a gate.
- **SC-005**: Closeout examples cover normal/squash delivery, unknown proof,
  tracked/untracked/ignored evidence, unpublished commits, holds, locks, path
  escapes, and interruption. No protected content is lost; repeated closeout
  performs no new destructive action on completed targets. Squash tests exercise
  all changed-path equality and owner confirmation. Before branch deletion,
  an annotated `archive/<package-id>` tag on the accepted head preserves the
  target, landed commit, proof method, and date; tag pushes require authorization.
  Scratch force tests require
  marker/root proof; delivery worktrees never inherit scratch permissions.
- **SC-006**: Eligible verified closeout removes its worktree and reconciles
  branches. The delivery commit carries the archived catalog entry and `delivered`
  state; cleanup makes zero target-branch writes, new state files, or package moves.
  Landed work remains terminally `delivered`; `closed` means withdrawn/abandoned
  without delivery, and no post-merge documentation change is needed. Retained
  targets have reasons computed from Git/config in preview; cleanup status is
  not persisted, and package-owned holds were declared before delivery.
- **SC-007**: Moved to Spec 002 – two-repo brief, returns, and calibration tests.
- **SC-008**: The migrated example and kit pass new ownership/budget checks;
  live routers contain no retired-state references. Preserved history/product
  invariants remain accessible; an external-kit example keeps external ownership.
  An unmigrated example still executes legacy prompts/launchers; installer changes
  are not applied. Tracked scratch appears in migration preview.
- **SC-009**: The owner's Opus spec review is received and blocking findings
  dispositioned and CP1 owner-cleared before planning/implementation. Slice A,
  B, and C checks pass independently, and each next slice starts zero work before
  its owner-cleared checkpoint. Delivery records preserve checks and closeout proof.

## Assumptions

- Inspected workflows are evidence, not universal consumer rules. See
  [the source audit](evidence/workflow-audit.md) for contexts and limits.
- Numerical budgets are proposed defaults for review, not constraints already
  imposed on consumers. Full specifications and findings are read on demand.
- Spec 002 remains a candidate, sourced from spacing/BF and the Jira bridge;
  returns must cite brief revisions and consumer `tasks.md` write ownership there.
- The goal is enforced ownership/lifecycle; no causal token or time savings
  are claimed and no general autonomous semantic audit is promised.
- Current kit instructions remain active until slice A replaces them. Spec Kit
  is installed for specification work; runtime changes follow the accepted plan.
- The owner's 2026-10-11 instruction accepts dispositions and clears CP1 with
  the recorded amendments. Planning and detailed slice A tasks are authorized;
  implementation becomes `active` after tasks exist. CP2/CP3/CP4 stay pending,
  and downstream repository changes remain outside this authorization.
