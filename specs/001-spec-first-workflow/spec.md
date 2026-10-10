# Feature specification: Spec-first agent workflow

**Feature branch**: `feat/001-spec-first-workflow`
**Created**: 2026-10-10
**Status**: Draft, awaiting owner-run Opus adversarial review
**Input**: Bring the kit up to date with the frequently used repositories.
Prevent staleness and instruction growth, remove overlapping legacy state,
complete worktree cleanup after spec delivery, and support bounded cross-repo
orchestration. The owner requested a spec before implementation.

## User scenarios and testing

### User story 1: Resume from one current work record (Priority: P1)

As the owner, I want a fresh agent to find the current spec, next action, and
blockers without reconciling several versions of the same state.

**Why this priority**: Competing instructions can restart superseded work.
Keeping them short does not resolve disagreement.

**Independent test**: Resume an example with an active spec, a parked spec,
and historical records. Find the next task and gate from their owners.

**Acceptance scenarios**:

1. **Given** an active package and inbox pointer, **when** a chat resumes,
   **then** the package's current tasks and gate govern it; an old handover
   cannot authorize different work.
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
   findings remain and unresolved actions have an owner in `tasks.md`.
3. **Given** an empty inbox and unresolved blocking verdict, **when** the
   scheduler runs, **then** the gate still prevents continuation.
4. **Given** exhausted remediation rounds, **when** reported, **then** the
   outcome is incomplete rather than finished.

### User story 4: Finish delivery with safe cleanup (Priority: P1)

As the owner, I want completed spec worktrees cleaned up during closeout,
with local work and parked experiments protected.

**Why this priority**: Forgotten directories accumulate; indiscriminate
cleanup can discard work that only exists in a checkout.

**Independent test**: Close normal and squash-merged examples alongside
dirty, protected, unpublished, and unverified examples. Remove only eligible
targets and report why others remain.

**Acceptance scenarios**:

1. **Given** verified delivery, preserved evidence, and an authorized clean
   worktree, **when** closeout applies, **then** it archives the package,
   updates pointers, removes the eligible worktree, and reconciles branches.
2. **Given** untracked reviews, unpublished work, or ignored user files,
   **when** evaluated, **then** cleanup preserves them until preservation
   is verified; age does not establish eligibility.
3. **Given** a squash-merge claim without accepted-head proof, **when**
   evaluated, **then** cleanup reports an unknown and retains the worktree.
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
4. **Given** an unmigrated consumer, **when** diagnosed, **then** migration
   needs are reported without silently changing its repository.

### User story 6: Coordinate repositories from a bounded brief (Priority: P2)

As the owner, I want one spec coordinating related product work, with each
worker holding its repository context and a complete current brief.

**Why this priority**: This generalizes the October 10 spacing workflow,
after the basic ownership and lifecycle controls are dependable.

**Independent test**: Give two example repositories one brief. Process
overlapping-file units sequentially within each repo and stop at calibration.

**Acceptance scenarios**:

1. **Given** a cross-repo unit, **when** dispatched, **then** one orchestrator
   owns the brief and progress; each worker writes only its assigned area.
2. **Given** successive units sharing files, **when** processed, **then** they
   run sequentially within a repo; authorized independent repos may run in parallel.
3. **Given** an incomplete brief, **when** a worker needs an unstated decision,
   **then** it returns the gap instead of loading history or inventing a rule.
4. **Given** worker returns, **when** integrated, **then** the orchestrator
   inspects actual changes and updates one programme work record.

### Edge cases

- The default branch is `master`, or delivery targets a different declared branch.
- Newer decisions live in an active worktree rather than the primary checkout.
- A branch is missing, checkout fails, or a scratch worker is intentionally detached.
- Archive moves leave live links targeting the old location.
- Reviews are unreceived, uncommitted, missing verdicts, or stale for the scope.
- Task checkboxes contradict a blocking review; a brief changes during execution.
- Ignored dependency output and ignored user evidence share a checkout.
- Worktrees are locked, contain junctions, or have prefix-lookalike paths.
- Merge providers are unavailable, refs are stale, or a branch was squash-merged.
- Old experiments are held intentionally; a repo has no active spec.
- An external governing draft must retain its stable path.
- An existing commit hook must be preserved; an editor ignores repo instructions.

## Requirements

### Functional requirements

#### Ownership and lean entry points

- **FR-001**: The default work-tracking model MUST use `specs/`,
  `docs/specs.md`, `AGENT-INBOX.md`, and `INBOX.md`. Instructions and human
  overview remain supported, with detailed material read on demand.
- **FR-002**: Each package MUST declare one current work owner. After
  planning, `tasks.md` owns next actions, blockers, checkpoints, and validation
  references. Before planning, `spec.md` holds draft/review state; a draft
  MUST NOT be executable merely because it has a feature branch.
- **FR-003**: `spec.md` MUST own intent/acceptance, `plan.md` approach and
  responsibilities, and `reviews/` saved requests/findings. A package README
  routes to these owners and MUST NOT duplicate current work state.
- **FR-004**: The catalog MUST hold ordered concise entries: identity,
  location, owner, and coarse lifecycle. Detailed task state stays in the
  package. Completed entries move to an on-demand archive index. A bounded
  candidate section may retain unpromoted ideas, with at most ten entries;
  overflow moves to on-demand product direction, not another execution queue.
- **FR-005**: Inbox entries MUST name recipient/scope, artifact link, and
  requested action. Remove entries only after receipt and resolution or
  durable transfer. A concise current resume pointer may remain; lint MUST
  allow unread handoff links and MUST NOT require destructive inbox drainage.
- **FR-006**: Migration MUST retire root `STATUS.md`, `TODO.md`, and
  `HISTORY.md` as active owners. Useful state moves to packages/catalog;
  history becomes inactive records or remains recoverable in Git. Stable
  product direction may remain on demand; root roadmaps MUST cease to be
  required cold-start or execution inputs.
- **FR-007**: Root `AGENTS.md` MUST contain invariants and routing. Agent
  adapters MUST point to the same owners. Operational detail and skills load
  only for relevant work. Small fixes MUST remain possible without a spec
  package or an extra status channel.

#### Automatic checks and staleness

- **FR-008**: Quick workflow health checks MUST be read-only and identify
  installed automatic triggers. Kit worker launchers MUST check before
  dispatch. Migrated repositories MUST have a local commit check and a CI
  backstop; existing hooks must be preserved or composed with. Instructions
  require checks at session start/end and scope changes. Unsupported hosts
  and skipped hooks MUST be reported as enforcement gaps.
- **FR-009**: Checks MUST enforce physical line counts, including blanks,
  and UTF-8 byte size. Default budgets are:

  | Surface | Maximum lines | Maximum bytes |
  |---|---:|---:|
  | Root `AGENTS.md` | 100 | 12,288 |
  | Each always-loaded agent adapter | 15 | 2,048 |
  | Root `AGENT-INBOX.md` | 60 | 8,192 |
  | Active `docs/specs.md` | 100 | 12,288 |
  | Each review request | 30 | 6,144 |

  Other automatically loaded instruction files MUST be declared and budgeted.
  Exceptions require owner authorization, a reason, and bounded expiry;
  an unbounded exception MUST NOT disable enforcement.
- **FR-010**: Quick checks MUST detect missing owners/links, duplicate
  package identities, retired execution routers, branch/package mismatch,
  and handoffs naming tasks or scopes declared closed/superseded. Active
  root routers MUST NOT accumulate completed entries or historical narratives.
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
- **FR-015**: Checkpoints MUST be declared before execution. Automation
  MUST stop for missing, blocking, or superseded required verdicts; task
  completion and empty inboxes do not substitute. Follow-up review covers
  unresolved blocking findings. Additional loops need a named reason and
  owner direction; no automatic unlimited re-review is permitted.
- **FR-016**: Scheduler discovery MUST use declared lifecycle and package
  ownership, including an explicitly located active worktree. It MUST NOT
  infer actionability from exact display text such as `In Progress`, numeric
  order alone, or the current branch. Draft, parked, review-blocked, and
  cleanup-only packages MUST NOT enter implementation automatically.
- **FR-017**: Worker preflight MUST verify repo, package, branch/base,
  worktree, write scope, and authorization. Checkout failure MUST stop the
  operation. Detached scratch workers need an explicit integration target;
  fallback to an unrelated branch is forbidden. Default branches MUST NOT
  be assumed to be `main`.
- **FR-018**: Exhausted remediation, worker failure, dirty primary state,
  or failed integration MUST report an incomplete/blocked outcome and preserve
  recoverable work. Required unfinished tasks/findings prevent completion.
  Failure policies MUST NOT skip gates or retry the same unchanged task indefinitely.

#### Closeout and worktree lifecycle

- **FR-019**: Closeout MUST offer read-only preview and separately apply
  authorized steps: verify delivery, preserve artifacts, archive the package,
  update live links/catalog, remove eligible worktrees, and reconcile eligible
  local/remote branches.
- **FR-020**: Merge proof MUST identify the target and accepted source
  revision. Normal delivery may use ancestry; squash/rebase needs verifiable
  merge records connecting the accepted head to the landed change. Patch
  similarity or branch names alone are insufficient. Unknown proof retains
  the worktree and branch.
- **FR-021**: Cleanup MUST inspect tracked/untracked changes, ignored user
  content, unpublished commits, locks, and explicit holds. Only declared
  disposable generated/dependency content may be excluded from preservation.
  Clean tracked status alone is insufficient. Existing old worktrees are
  inventory candidates, never implicitly abandoned work.
- **FR-022**: Cleanup MUST honor repo/session authorization. Ordinary
  `git worktree remove` is the default. Automatic force, recursive filesystem
  fallback, dependency links, and deletion through symlinks/junctions are
  forbidden. Necessary exceptions remain separately authorized operations
  under the target repository's rules.
- **FR-023**: Destructive targets MUST be normalized, checked against the
  intended repo/worktree and managed location, and revalidated immediately
  before mutation. Prefix-lookalike paths and unresolved links MUST be
  rejected. The primary checkout MUST never be a cleanup target.
- **FR-024**: Closeout MUST be resumable/idempotent. Evidence must be durably
  preserved before its source worktree disappears. Archive/catalog changes
  MUST be committed on the intended surviving branch before dependent deletion.
  `Merged, cleanup pending` records unfinished cleanup; each retained target
  has a concise package-owned reason. Separate parked owner-held work does
  not prevent another completed spec from closing.

#### Cross-repository orchestration

- **FR-025**: Cross-repo features MUST declare one orchestrator/package,
  implementation repos, write boundaries, dependencies, targets, and review
  checkpoints. Consumer packages may own local product acceptance while
  linking to the programme; they MUST NOT copy its progress record.
- **FR-026**: Briefs MUST be complete and bounded: outcome/rule, relevant
  values/sources, mapped files, write scope, acceptance, checks, exclusions,
  and expected return. The orchestrator maps once and owns brief edits.
  Workers return missing decisions; concurrent workers MUST NOT both edit
  a shared brief or progress table. Default brief budget: 80 lines/12,288 bytes.
- **FR-027**: Workers SHOULD persist across related units where supported.
  Overlapping-file units MUST run sequentially within each repo; authorized
  independent repos may run in parallel. Resumption loads current brief and
  repo rules. A changed brief MUST invalidate an in-flight result until reconciled.
- **FR-028**: Returns MUST identify commits or preserved changes, a reviewable
  artifact or no-visible-change explanation, validation outcome, and questions.
  The orchestrator inspects results, updates progress once, and presents
  concrete decisions in plain words. Unrelated failures may be recorded once
  with reproduced baseline evidence; they MUST NOT be represented as passes.
- **FR-029**: Checks/reviews MUST scale to the affected contract. Repeated
  cross-repo work needs an early calibration checkpoint. Ordinary handoffs
  need no sealed manifests, receipt hashes, or provenance ledgers. Existing
  captured-evidence/vendor integrity requirements remain protected. Role/model
  preferences have one owner and MUST respect host capability differences.

#### Migration and delivery boundary

- **FR-030**: Adoption MUST have explicit versioned activation and a preview
  of every legacy file disposition. Activation MUST reconcile instructions,
  resume agents, Spec Kit pointers, prompts, launchers, validators, and
  scheduler behavior together. Interrupted migration MUST remain recoverable
  and MUST NOT report completion with competing execution owners active.
- **FR-031**: Existing prompt names, including `/freshen-status`, MUST route
  to the new owner through a documented alias or report deprecation. Migrated
  repos MUST NOT execute legacy TODO-driven work or recreate its files.
  Unmigrated consumers receive read-only migration diagnostics until adoption
  is requested. External-kit ownership and local product rules MUST survive.
- **FR-032**: This feature MUST self-host the accepted model in the kit and
  provide a tested adoption procedure. It MUST NOT modify portfolio/reference
  repos, purge their worktrees, publish changes, or launch their workers.
  Portfolio adoption follows kit acceptance as separate authorized work.

### Key entities

- **Spec package**: Intent, plan, current work, reviews, optional briefs;
  one identity and declared current work owner.
- **Catalog entry**: Identity, location, owner, priority order, coarse
  lifecycle; routing rather than another task narrative.
- **Handoff**: Recipient/scope, artifact link, requested action, receipt state;
  transient except for a concise current resume pointer.
- **Checkpoint**: Scope/revision, reviewer, verdict, unresolved blocking
  findings; controls advancement.
- **Worktree disposition**: Repo, branch/target, merge evidence, preservation
  and holds, closeout outcome; inventory plus a concise package record.
- **Worker brief**: One orchestrator-owned bounded instruction, revision
  identity, and disjoint implementation write scopes.

## Success criteria

### Measurable outcomes

- **SC-001**: A new session finds its package, next action, and blocker from
  at most four root entry files and the owning package's current work section,
  without reading retired global state files.
- **SC-002**: Every above-budget example fails routine checks, including
  long-line byte overflow. Fourteen simulated daily updates expose introduced
  mechanical drift at the next trigger without a manual audit request.
- **SC-003**: Scope-reset examples identify every declared closed/superseded
  execution pointer; parked work stays parked without date churn. Semantic
  reconciliation limits are reported explicitly.
- **SC-004**: Saved reviews survive triage. Continuation examples start zero
  beyond-gate tasks for missing/blocking/obsolete verdicts, branch failures,
  or exhausted remediation.
- **SC-005**: Closeout examples cover normal/squash delivery, unknown proof,
  tracked/untracked/ignored evidence, unpublished commits, holds, locks, path
  escapes, and interruption. No protected content is lost; repeated closeout
  performs no new destructive action on completed targets.
- **SC-006**: Eligible verified closeout removes its worktree and reconciles
  branches/pointers. Deferred cleanup always has a visible reason and cannot
  be mistaken for a fully closed spec.
- **SC-007**: Two-repo orchestration uses one brief and programme work record,
  produces inspectable results, and stops at calibration without duplicate writers.
- **SC-008**: The migrated example and kit pass new ownership/budget checks;
  live routers contain no retired-state references. Preserved history/product
  invariants remain accessible; an external-kit example keeps external ownership.
- **SC-009**: The owner's Opus spec review is received and blocking findings
  resolved before implementation. Delivery records include declared checks,
  required verdicts, and the closeout disposition.

## Assumptions

- Inspected workflows are evidence, not universal consumer rules. See
  [the source audit](evidence/workflow-audit.md) for contexts and limits.
- Numerical budgets are proposed defaults for review, not constraints already
  imposed on consumers. Full specifications and findings are read on demand.
- The goal is enforced ownership/lifecycle; no causal token or time savings
  are claimed and no general autonomous semantic audit is promised.
- Current kit instructions remain active during review. Spec Kit is installed
  for specification work; runtime workflow changes await accepted implementation.
- Planning and detailed implementation tasks follow the owner-run Opus review.
  The draft gate is [the saved request](reviews/2026-10-10-opus-spec-review-request.md).
