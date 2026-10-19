# Feature specification: Simplify and port the kit

**Feature branch**: `feat/003-simplify-portable-kit`
**Created**: 2026-10-17
**Lifecycle**: active
**Scope**: `003/spec-r1`
**Superseded tasks**: none.

<a id="checkpoints"></a>
**Checkpoints**:

| ID | Gate | Verdict link | State |
|---|---|---|---|
| CP1 | Owner spec acceptance | [request](reviews/2026-10-17-cp1-request.md); [owner acceptance](reviews/2026-10-17-cp1-owner-acceptance.md) | owner-cleared |
| CP2 | Slice A review: worktree hygiene | [Opus findings](reviews/2026-10-17-cp2-opus-findings.md); [owner clearance](reviews/2026-10-18-cp2-owner-clearance.md) | owner-cleared |
| CP3 | Slice B review: workflow core | [Opus findings](reviews/2026-10-18-cp3-opus-findings.md); [owner clearance](reviews/2026-10-19-cp3-owner-clearance.md) | owner-cleared |
| CP4 | Slice C review: scheduler | [Opus findings](reviews/2026-10-19-cp4-opus-findings.md); [owner clearance](reviews/2026-10-19-cp4-owner-clearance.md) | owner-cleared |
| CP5 | Slice D review: retirement and docs | [independent findings](reviews/2026-10-19-cp5-independent-findings.md); [review request](reviews/2026-10-19-cp5-review-request.md) | findings-received |

**Input**: Spec 001 was meant as a small hardening pass and grew to ~4,500
lines of PowerShell plus a matching test suite, mostly around closeout proofs
and edge cases raised by successive adversarial reviews. The owner works on
Windows, macOS and Linux, runs seven active repositories in parallel, and needs:
a kit that runs everywhere without PowerShell; reliable discovery and cleanup
of the worktrees and branches that accumulate across those repositories; a
scheduler that can burn unused model quota overnight and report honestly; and
saved Markdown reviews so findings never live only in a chat window. Roles:
GPT implements, Opus reviews and advises on architecture, the owner clears gates.

## Context and evidence

Measured on the owner's machine on 2026-10-17 (`git worktree list` across
`H:/WSL_dev_projects`): 78 linked worktrees in 13 repositories, in at least
nine location patterns – `<repo>-worktrees/`, `<repo>-prNN/`, `.claude/worktrees/`,
`tmp/`, `.tmp/`, `temp/`, `%TEMP%/agent-loop-worktrees/` (already prunable),
`C:/codex-qualification/`, `C:/Users/<user>/codex-worktrees/` and `Q:/codex-worktrees/`.
`pragma` alone has 26. The most common owner-chosen convention is the sibling
`<repo>-worktrees/` folder.

The existing scheduler (`agent-loop.ps1`, ~2,100 lines) has these known
weaknesses: no authentication check before launch, quota/rate limits surface
only as timeouts, "exit 0 with no commit" stops the run, hard kill on timeout,
cherry-pick into the primary checkout requires it to stay clean, Windows-first
CLI resolution, and only Codex/Copilot workers.

## User scenarios and testing

### User story 1: Find and remove stale worktrees everywhere (Priority: P1)

As the owner, I want one command that shows every worktree across my repos –
wherever an agent put it – and safely removes the ones whose work has landed.

**Why this priority**: Gigabytes of stale checkouts are hidden in temp folders
today, and nothing cleans them. This works on any Git repo without adopting
the rest of the kit, so it pays off immediately in all seven repositories.

**Independent test**: Fixture repos with worktrees in sibling, nested, temp and
host-native locations, covering fast-forward, merge-commit, squash and rebase
landings plus unmerged, dirty, untracked-file, locked, detached and missing-
directory cases. Listing finds all; cleaning removes exactly the integrated
clean ones.

**Acceptance scenarios**:

1. **Given** worktrees in any location, **when** I list from a root folder,
   **then** every worktree Git knows about is shown with its repo, branch,
   state, landing status, age and (on request) disk size.
2. **Given** a worktree whose branch landed by squash merge, **when** I clean,
   **then** it and its local branch are removed, including ignored build output.
3. **Given** a worktree with uncommitted or untracked files, unlanded commits,
   or a lock, **when** I clean, **then** it is kept and the reason is shown.
4. **Given** I pull the target branch after a PR merge in a repo with kit hooks
   installed, **when** the pull completes, **then** landed clean worktrees for
   that repo are removed without any further command.

### User story 2: Run unused quota overnight and trust the report (Priority: P1)

As the owner, I want to start a bounded unattended run before bed and, in the
morning, read one report that says what each task did and why the run stopped.

**Why this priority**: The current scheduler sometimes works; when it fails the
cause is unclear, so it is not used.

**Independent test**: A fake worker CLI scripted to succeed, make no change,
leave uncommitted files, hang, print a quota or auth error, crash, and edit a
protected gate file. Each case yields its named outcome and a report.

**Acceptance scenarios**:

1. **Given** an expired login, **when** a run starts, **then** it stops before
   any task with "authentication required" and the command to fix it.
2. **Given** the first agent runs out of quota, **when** a fallback agent is
   configured, **then** the run continues on the fallback; otherwise it stops
   with outcome `quota`.
3. **Given** a worker that hangs, **when** the task timeout passes, **then** it
   is interrupted, then killed with its child processes, its commits are kept,
   and the run moves on as the failure policy says.
4. **Given** any ending – success, failure, Ctrl-C or crash – **then** a run
   report exists listing each task, its outcome, commits, duration and agent.

### User story 3: Every review is a saved file (Priority: P1)

As the owner, I want reviewers to write findings into the package, so I never
paste reviews between chats and the reason for each change stays on record.

**Independent test**: Run the review prompt against a fixture package; a
findings file appears with the required header; the chat reply only names the
file and verdict.

**Acceptance scenarios**:

1. **Given** a review request, **when** a reviewer finishes, **then** findings
   are saved under package `reviews/` with reviewer, reviewed revision, verdict
   and numbered findings with severities.
2. **Given** two review rounds at a checkpoint, **when** major findings remain,
   **then** no third round starts automatically; the owner decides.

### User story 4: Same kit on Windows, macOS and Linux (Priority: P2)

As the owner, I want the same commands on every machine with only Git and
Python installed.

**Independent test**: CI runs the full test suite and lint on all three
operating systems.

### User story 5: Adopt the kit in an existing repo quickly (Priority: P2)

As the owner, I want to add the kit to one of my repos in minutes without it
overwriting anything, and to read a README that explains it in plain language.

**Independent test**: Initialise a fixture repo that already has AGENTS.md and
README.md; no existing file changes; a checklist names the manual merges.

### Edge cases

- Package branch already checked out in the primary checkout when a run starts.
- Worktree directory deleted by hand (prunable) or orphan directory whose
  repository forgot it.
- Target branch unknown (no config, no `origin/HEAD`).
- Branch landed, then received more commits.
- Worktree on a removable or network drive that is not currently mounted.
- Worker commits to files outside the task, or checks off a different task.
- Two runs started against the same package.

## Requirements

### Platform and shape

- **FR-001**: All kit tooling MUST run on Windows, macOS and Linux with only
  Git ≥ 2.38 and Python ≥ 3.10 (standard library). No PowerShell, Bash-only
  syntax or third-party packages.
- **FR-002**: One command, `wfk`, MUST provide the subcommands `wt`, `run`,
  `lint`, `new`, `init`, `hooks` and `prompts`. Launchers: `bin/wfk` (POSIX sh)
  and `bin/wfk.cmd` (Windows), each locating Python 3 portably.
- **FR-003**: Commands that delete or rewrite MUST default to a dry run and act
  only with `--apply`. All commands MUST offer `--json`.
- **FR-004**: Reusable artifacts MUST NOT contain drive letters, user names or
  OS-specific path separators.

### Worktree hygiene (slice A)

- **FR-010**: New worktrees MUST default to `<repo-parent>/<repo>-worktrees/<branch-slug>`,
  overridable per repo. `wfk wt new <branch> [--from <rev>]` creates them; the
  scheduler uses the same location.
- **FR-011**: `wfk wt ls` MUST discover worktrees from Git metadata, not from
  folder conventions: the current repo by default, or every repo under one or
  more `--root` folders (also settable in a user-level config). Each row shows
  repo, path, branch or detached commit, tracked changes, untracked files,
  locked, prunable, landing status, last commit date and, with `--size`, disk use.
  It also lists landed local branches that have no worktree.
- **FR-012**: `wfk wt ls` MUST report orphan directories under configured
  scratch roots (defaults include the old `agent-loop-worktrees` temp folder)
  whose `.git` link points to a missing or unaware repository.
- **FR-013**: A worktree is *landed* when its branch or detached commit is an ancestor
  of the target or `git merge-tree --write-tree <target> <rev>` produces
  the target's own tree (covers squash and rebase landings). The target comes
  from repo config, then `origin/HEAD`, then `main`/`master`; output names
  which. Unknown target means nothing is landed. Cleanup
  MUST keep worktrees with activity in the last 24 hours by default,
  configurable via `cleanupGraceHours`; activity is the newer of the newest
  HEAD reflog timestamp and worktree admin-directory mtime. Movement is not
  required once outside that grace period. Use admin-directory mtime alone
  when the HEAD reflog is empty or expired.
- **FR-014**: `wfk wt clean --apply` MUST remove only worktrees that are not the
  primary checkout or the current directory, not locked, have no tracked
  changes and no untracked non-ignored files, and are landed. It MUST use
  `git worktree remove` (no recursive filesystem deletion), then delete the
  local branch when landed, unprotected and not checked out elsewhere, then run
  `git worktree prune`. Standalone branches are listed only unless `--branches`
  is explicitly requested; hooks MUST NOT request that flag. Always protect the
  target and `main`, `master`, `develop`, `trunk`, `release/*`; configurable
  `protectedBranches` adds patterns. Protected worktrees are also kept. Slice B
  adds catalog-declared branch protection. Kept items list their reason. Remote branches are never
  touched. Orphan directories are listed with size; removal is manual.
- **FR-015**: `wfk hooks install` MUST add `post-merge` and `post-rewrite`
  hooks that run `wfk wt clean --apply --quiet` for that repo when the target
  branch is checked out. It MUST compose with existing hooks, never change
  `core.hooksPath`, and never fail the Git operation.
  Hook installation MUST refuse a resolved hooks directory inside any checkout's
  ordinary files, such as `.husky`, without writing files, and print manual
  composition instructions. Git administrative hook storage remains allowed.
  Documentation MUST state
  that no Git hook fires when a PR merges remotely; cleanup runs at the next
  local pull of the target. `wfk run` also cleans its own worktrees at the end.
- **FR-016**: The AGENTS template MUST tell agents to create worktrees with
  `wfk wt new`. Worktrees created by hosts in their own locations are still
  discovered and cleaned under FR-011–014.

### Workflow core (slice B)

- **FR-020**: The ownership model of Spec 001 stays: catalog `docs/specs.md`,
  package `spec.md` (intent, lifecycle, checkpoints), `plan.md`, `tasks.md`,
  `reviews/`, and the two inboxes. Retired root placeholders
  (`STATUS.md`, `TODO.md`, `HISTORY.md`) are deleted; Git keeps their history.
- **FR-021**: Each review MUST be saved as
  `reviews/<date>-<checkpoint>-<reviewer>-findings.md` with header fields
  Reviewer, Reviewed revision and Verdict (`accept`, `changes`, `blocker`), and
  numbered findings each marked blocker, major or minor. The author answers in
  a matching `-dispositions.md`. A shipped `/review` prompt MUST tell the
  reviewer to write the file and reply in chat only with its path and verdict.
- **FR-022**: Review economy: the implementer MUST fix blocker and major
  findings; minor ones may be deferred to a "Known limits" list in `tasks.md`.
  A checkpoint gets at most two review rounds; after that the owner accepts,
  cuts scope or reopens the plan. No extra adversarial round without an owner
  request.
- **FR-023**: Each checkpoint row MUST link at most the latest findings and the
  latest owner decision; earlier records are reachable from the decision.
- **FR-024**: `wfk lint` MUST check, read-only and offline: catalog rows
  resolve to packages on their declared branches, package owner files exist,
  lifecycle and checkpoint values are valid, checkpoint links resolve, review
  headers are complete, no feature state or vendor marker blocks sit in
  AGENTS/CLAUDE, and auto-loaded files meet their configured line and byte
  budgets. Budgets apply only to auto-loaded files.
- **FR-025**: `wfk new <short-name>` MUST create the package branch, draft the
  spec from the project template and register the catalog row on the target,
  in an order that passes lint at every commit. It never pushes.
- **FR-026**: Spec Kit scripts and skills MUST be used unmodified from the
  vendor. Kit additions (catalog registration, next-task gate check) live in
  `wfk`; lint no longer inspects vendor script contents.
- **FR-027**: `wfk init` MUST add missing kit files (config, templates,
  catalog, inboxes, AGENTS skeleton) to an existing repo without overwriting
  any file, and print a checklist of manual merges.
- **FR-028**: `wfk prompts install` MUST install the prompt files to the VS
  Code and VS Code Insiders user prompt folders on all three operating systems.
  Prompts MUST reference only existing commands.

### Scheduler (slice C)

- **FR-030**: `wfk run` MUST dispatch only tasks from active packages whose
  entry checkpoint is cleared and whose next task is not behind an uncleared
  gate.
- **FR-031**: Workers are adapters for Codex, Copilot CLI and Claude Code,
  defined as command templates in config with shipped defaults. Model tiers
  live in one config location, replacing `TierDispatchMap`.
- **FR-032**: A package runs in one worktree on its declared branch (FR-010
  location, or an existing clean worktree of that branch); tasks run in
  sequence and commit directly to that branch. The scheduler MUST NOT write to
  the primary checkout or cherry-pick. A lock file prevents two runs on one
  package.
- **FR-033**: Before the first task, preflight MUST verify the worker CLI
  exists and is authenticated (a cheap, non-interactive check per adapter),
  the run worktree is clean and on the declared branch. Any failure starts no
  task.
- **FR-034**: Each task MUST end with exactly one outcome: `done` (its task
  checked off and at least one commit), `no-progress`, `uncommitted` (worktree
  left dirty and preserved), `timeout`, `quota`, `auth`, `gate-violation` or
  `error`. Quota and auth detection use per-adapter exit codes and output
  patterns that config can extend.
- **FR-035**: Failure policy: `quota` switches to the next agent in
  `--agents` (ordered fallback list) or stops the run; `auth` stops the run;
  task-level outcomes stop that package and continue with the next authorized
  package. No automatic retry.
- **FR-036**: Timeouts MUST interrupt the worker, wait a grace period, then
  kill the whole process tree on every OS. Commits made so far stay.
- **FR-037**: After each task, commits that change the spec header or
  checkpoint table, `.workflow-kit.json`, any existing file under `reviews/`,
  or check off a task other than the dispatched one MUST be moved off the
  package branch to `refs/wfk/rejected/<task>-<timestamp>`, with outcome
  `gate-violation`.
- **FR-038**: An optional review phase dispatches the configured reviewer with
  the `/review` procedure; a missing findings file is outcome `review-missing`.
  Address rounds follow FR-022.
- **FR-039**: Every run MUST write a Markdown report and worker logs under the
  repository's Git common directory (`wfk/runs/<timestamp>/`), including on
  Ctrl-C or crash, and print its path. Limits: `--max-tasks`, `--max-hours`,
  `--task-timeout`.

### Retirement and docs (slice D)

- **FR-040**: After slices A–C are accepted, remove the PowerShell scripts,
  PowerShell tests, staged-snapshot pre-commit checker, `closeout`, `migrate`,
  `diff`/external-mirror mode and legacy TODO scheduling. Tag the last
  PowerShell revision `v1-powershell` locally; unmigrated repos pin that tag.
- **FR-041**: `.workflow-kit.json` becomes version 2. `wfk` MUST name v1 fields
  it ignores rather than fail silently.
- **FR-042**: CI MUST run the Python tests and `wfk lint` on Windows, macOS and
  Linux.
- **FR-043**: README MUST be written for a human: what the kit is, install,
  the main commands with one example each, and the workflow in one diagram.
  Reference detail moves to `docs/`.

### Out of scope

Cross-repository orchestration (Spec 002 candidate); deleting remote branches
(enable the host's auto-delete of merged branches instead); OS-scheduled
background cleanup; moving existing worktrees into the canonical location;
the closeout archive-tag proofs of Spec 001.

## Success criteria

- **SC-001**: Full test suite and lint pass in CI on Windows, macOS and Linux.
- **SC-002**: On the owner's machine, `wfk wt ls --root <projects-folder>` lists
  every worktree reported by per-repo `git worktree list` (78 on 2026-10-17)
  plus orphans in configured scratch roots.
- **SC-003**: Fixture tests show zero removals of dirty, untracked, unlanded,
  locked or primary worktrees, and removal of every clean landed one across
  all four landing styles.
- **SC-004**: Fixture tests produce each scheduler outcome from FR-034, and a
  report exists after normal end, Ctrl-C and crash.
- **SC-005**: With a fake quota error on the first agent and a fallback
  configured, the run continues without owner action.
- **SC-006**: A fixture repo is adopted with `wfk init` with no existing file
  changed.
- **SC-007**: No review in this package exists only in chat: every checkpoint
  row links a saved findings file.

## Assumptions

- Owner machines have Git ≥ 2.38 (2.52 on the Windows machine) and Python 3.10+
  (`python` 3.11.9 on Windows; `python3` on macOS/Linux).
- Codex, Copilot CLI and Claude Code each offer a non-interactive mode and a
  way to detect missing login; exact commands are settled in the plan.
- Spec 001's ownership model is sound; this package replaces its
  implementation, not its intent. Spec 001's delivery or supersession is a
  separate owner decision.
- Repos not yet migrated keep working by pinning `v1-powershell`.
