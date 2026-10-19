# Implementation plan: simplify and port the kit

Scope: [003/spec-r1](spec.md). Authorization and stopping points belong to
[the checkpoints](spec.md#checkpoints); execution belongs to [tasks](tasks.md).

## Architecture

Use a standard-library-only `wfk/` Python package at the kit root, invoked by
`python -m wfk`. `bin/wfk` and `bin/wfk.cmd` locate Python 3.10+ and add the kit
root to the module search path, independent of the caller's working directory.
`cli.py` owns argparse and human/JSON output; `git.py` wraps argument-vector
Git calls; `config.py` owns configuration and target selection. Keep modules
small and return plain dictionaries at the CLI boundary.

Expose `wt new|ls|clean`, `hooks install`, then `lint`, `new`, `init`, `prompts
install` and `run` in their authorized slices. Every command has `--json`;
rewriting/deleting commands preview unless `--apply` is present. Creation via
`wt new` is explicit and immediate. Unsupported future commands fail clearly.

## Configuration v2

Keep this repository's v1 config and PowerShell paths working until slice D.
Python accepts `workflowModelVersion: 2`, `targetBranch`, `worktreeRoot`,
`scratchRoots`, and user-level `repoRoots`. Relative repo paths resolve from
the repository; relative user paths resolve from the user config directory.
`{temp}` expands through Python's tempfile directory. User config lives at
`~/.config/wfk/config.json`, overridable by `WFK_CONFIG` for tests and operators.
Repo settings override user defaults. Unknown versions fail. When reading v1,
name the ignored v1 fields in diagnostics; use its shared `targetBranch`.
Later slices add worker templates, tier models, budgets and scheduler policy to
this single config owner; no duplicate model table.

## Slice A: worktree hygiene (CP1 to CP2)

Discover repositories beneath configured/explicit roots by walking directories,
skipping Git internals and dependency caches, deduplicating by Git common
directory. Ask each Git common directory for `worktree list --porcelain -z`;
never infer linked worktree locations from directory names. Include landed local
branches without a checkout. Status comes from porcelain Git output with
optional locks disabled, so real-repository inventory is read-only.

Resolve the target from repo config, `origin/HEAD`, then local main/master.
Prove landing by ancestry or by a successful `merge-tree --write-tree` whose
tree equals the target tree. A failed/uncertain probe means kept, with reason.
Git's merge-tree may create unreachable objects; run that probe in a temporary
object directory with the repository objects as alternates to keep inventory
read-only. Do not replace landing proof with patch-ID heuristics.

Cleanup rechecks state before mutation, excludes primary/current, locked,
unavailable, dirty, untracked and unlanded checkouts, and uses Git removal only.
Ignored output may require Git's force removal after the checks. Delete local
landed branches only after checkout removal and a fresh checkout/landing check;
never remote refs. Prune only applicable repositories, preserving unavailable
registrations. Orphan discovery checks `.git` links only inside configured
scratch roots, reports uncertainty, and never follows symlinks to delete data.

Hooks compose in the effective hooks directory without changing core.hooksPath.
Preserve existing hook execution and arguments, use an idempotent marked block,
and guard cleanup by the resolved target branch. Hook failures never fail Git.
Document that remote PR merges trigger no local hook; the next local target pull
does. Ship an AGENTS template directing agents to `wfk wt new`.

### CP2 corrections from the owner's Opus handoff

Standalone branches are listed only unless `clean --branches --apply` is
explicit. Always protect the target and `main`, `master`, `develop`, `trunk`,
`release/*`; `protectedBranches` adds repo/user patterns. Hook cleanup omits
`--branches`. Catalog branch protection joins in slice B.

The [owner correction](reviews/2026-10-17-cp2-owner-decision.md) supersedes the
permanent HEAD movement requirement. An unmoved landed worktree becomes eligible
outside `cleanupGraceHours` (default 24). Activity uses the newest HEAD reflog
timestamp and admin-directory mtime; empty/expired logs fall back to mtime alone.
Unreadable/malformed nonempty logs remain uncertain and keep the checkout.
Standalone branch deletion retains its separate branch-reflog movement check.
Re-read those guards immediately before removal. Tests set grace to zero only
when testing another exclusion/removal, and age fixture metadata explicitly
when verifying the default grace. No persistent proof ledger is needed.
List ownerless orphans with disk size and a manual-removal reason; never remove
them through an ordinary recursive filesystem operation, even with `--orphans`.

Refuse hook installation when the effective directory falls inside any
registered checkout's ordinary files (relative or absolute); Git's own admin
directories remain allowed. Refuse before writing any wrapper or backup, and
provide manual composition instructions. Silent hook failures and conservative
pruning remain explicit minor limits. Document that force removal deletes all
ignored files, including secrets and local evidence, and say so in preview.
Two CP2 rounds are exhausted; remediation ends at the owner's evidence decision,
without another independent review or automatic delta request.

Use `unittest`, temporary Git repos, isolated config/home and fake identities.
Write failing acceptance fixtures before implementation: all four landing styles,
all safety exclusions, nonstandard paths, missing dirs, unknown targets, local
branches, orphans, launchers and existing hooks. Compare the owner's inventory
to independent per-repo Git output, without applying cleanup or hooks there.

## Slice B: workflow core (after owner clears CP2)

Port catalog/package/checkpoint parsing and offline lint into focused modules.
Add `new`, non-overwriting `init`, prompt installation and saved-review prompt.
Keep vendor Spec Kit files unmodified; wrapper additions stay in Python. Test
branch-aware catalogs, broken links, review headers, budgets, gate states and
adoption preservation with temporary repositories. Remove retired placeholders
only in this slice. Stop at CP3.

`workflow.py` resolves checked-out declared owners before local refs and keeps
catalog parsing, review labels, gates and task selection together. Lint is an
offline CLI consumer. Version 1 historical formats produce migration warnings;
version 2 requires a complete accepting owner record, latest dated findings
links and at most two checkpoint links. Same-date ordering is reported as
ambiguous rather than inferred. Workflow commands require explicit adoption;
standalone worktree commands do not. Cleanup unions caller/target catalogs for
protection and re-reads that protection at mutation time.

`adoption.py` creates missing files exclusively and reports collisions for manual
merge, including invalid local config. New packages use the target's project
spec template and minimal draft plan/tasks. An owners-only provisional draft ref
makes the package resolvable before committing owners plus registration on the
target; the feature ref then advances to that registration commit. This avoids a
catalog-only dangling commit or a permanent missing-branch exception. Failures
preserve the recovery checkout, files, index and refs. `prompts.py` previews both
editor destinations and replaces differing regular files only with `--apply`;
links/non-file collisions stay manual. No vendor content is modified or linted.

### CP3 required correction

Init consumes `templates/init/config.json` for default full-load file and host
budgets. It seeds missing thin CLAUDE/Copilot adapters so a new adoption is
lint-clean, preserves existing config/adapters byte-for-byte and names missing
or empty budget fields in the manual merge checklist. The 200-line AGENTS
regression exercises lint after adoption. CP3 rounds are exhausted; minor
findings 2–4 remain in tasks' Known limits, and remediation ends at the owner's
decision without another review or slice C work.

## Slice C: scheduler (after owner clears CP3)

Use one package worktree and a common-directory lock. Keep adapters declarative:
Codex `codex exec`, Copilot `copilot -p`, Claude `claude -p`; settle exact auth
probe commands against installed CLI help before implementation. No assumed
login probe is authoritative until tested. Preflight before dispatch, then
sequential task outcomes, fallback quota handling, protected-range rejection,
interrupt/grace/process-tree termination, durable logs/reports and bounded
saved-review rounds. Use fake worker executables for every outcome, hangs,
child processes, protected edits, Ctrl-C and crash reporting. No live workers.
Stop at CP4.

### CP3-authorized slice C implementation contracts

The owner authorizes fake workers only, including preflight. Shipped worker
arguments remain declarative defaults; auth probes default to unset and fail
closed until an operator configures a verified noninteractive command. No real
CLI is invoked to discover authentication in this slice. Configuration and tier
models are frozen before dispatch; version 1 ignores scheduler overrides.

`scheduler.py` selects explicitly authorized packages, rechecks their gates,
leases a common-directory package lock and uses a clean non-primary branch
worktree. It never moves the primary checkout. Preview is read-only; execution
requires `--apply`. Reports are initialized before preflight and finalized on
failure or interruption. Quota fallback is bounded by the supplied agent order;
authentication stops the run. Only newly created, clean, landed worktrees are
considered for Git-only cleanup, without force or branch deletion.

`processes.execute(argv, cwd, log, timeout, grace, input_text, env)` streams logs
to disk and contains the process tree on Windows and POSIX. `protection.audit`
examines every new commit, including changes later reverted. Rejection first
saves a recovery ref, then rewinds the branch with an expected-old-value check;
index, worktree and untracked bytes are preserved. Existing evidence remains
immutable; an optional review dispatch may create only its named new record.

Optional review runs use a dispatch callback with the same process/protection
guards, save findings and dispositions in the package, and enforce two rounds
across runs. A reviewer verdict never clears an owner gate. Missing findings
produce `review-missing`. Independent review, fake-worker validation and the
legacy final-code suite precede the CP4 request; slice D remains blocked.

### CP4 owner-authorized remediation contracts

The 2026-10-19 owner decision supersedes the fake-only qualification limit for
one trivial task per provider in a new disposable repository. Existing project
repositories, hooks/installations, pushes/merges and slice D remain excluded.
No third independent review starts; remediation ends at the owner's CP4 decision.

Port the approved H/S/L model and effort map into the scheduler defaults, with
per-provider argument templates and the existing unattended permission flags.
Authentication probes must be cheap, noninteractive and verified against the
installed tool in scratch; unavailable/unauthenticated agents are reported, not
installed, logged in or substituted. Local help/status discovery precedes the
single bounded `wfk run --apply --max-tasks 1` qualification per available agent.

`launchers.resolve(argv, cwd=None)` returns a native argument vector. On Windows
it resolves recognized npm shims to Node plus a validated installed entrypoint
or a vendor native binary; shell script text is never executed or evaluated.
Unknown wrappers fail closed. The original prompt remains one argument (or
stdin), never cmd.exe text. Both preflight and dispatch use that resolved vector;
the process primitive retains its raw batch refusal and process-tree ownership.

Keep the Linux parent-path repairs as explicit slice D work required before CP5.
The primary-checkout refusal may print a correctly quoted configured-target
switch command, without running it. Save red/green, live reports and sanitized
logs, dispositions, final validation and the bounded owner-decision request.

The installed Copilot CLI has no status subcommand; its bundled SDK uses
`auth.getStatus` over Content-Length-framed JSON-RPC (`--headless --stdio`).
Use a small standard-library helper for this read-only request, require an
explicit boolean `isAuthenticated`, suppress raw auth payloads and leave all
descendants in the existing runner's process tree. No model session or login
flow is allowed in preflight. Codex uses its installed `login status`. Claude
is absent from the standard local locations and PATH; record unavailability
rather than installing it or claiming live qualification.

Preserve `Test-CodexCompatibleModel`'s existing distinction: the shared
`gpt-5.4`/mini names are Copilot aliases; Codex uses its configured model for
those names, via declarative `cliDefaultForModels`, and retains tier effort.
The single Codex live attempt exposed the omitted guard; restore it with fake
regressions and do not silently run an additional live task or select a new model.

## Slice D: retirement and documentation (after owner clears CP4)

The [slice D handover](reviews/2026-10-19-slice-d-handover.md) now authorizes
this phase and owns its order: T029, T030, read-only consumer inventory, T015,
T016, T017. Keep Python parent-file collisions nonfatal without overwriting
the blocking file. Run full Windows and WSL suites before proceeding to T030.

Use a named `copilot-opus` profile for the default reviewer. It shares the
installed Copilot adapter/authentication path, takes its model from a single
profile tier map and never changes the implementing Copilot tier preferences.
Confirm the available Claude Opus model from the installed CLI before the one
authorized scratch review phase. Use a fake prerequisite task so this scope
starts no extra real implementing worker. Preserve the findings, actual model
evidence, process logs and unchanged primary checkout. Claude Code remains
unqualified; no installation is necessary for this chosen review route.

Inventory consumer references read-only before retirement. Preserve the final
PowerShell revision under the local `v1-powershell` tag. Replace the tracked
commit-hook entry with portable Python lint and verify it before deletion;
do not install cleanup hooks or alter other repositories. Retire only kit-owned
PowerShell sources/tests/launchers, keeping vendor Spec Kit assets intact.
Migrate this repo to v2 with explicit compatibility treatment of older package
records; do not rewrite accepted Spec 001 evidence to satisfy new lint rules.

After retirement use Python lint, an explicit-package scheduler preview and
Git whitespace checks for quick validation. Local Windows/WSL executions can
prove those platforms; macOS CI results require a later authorized push and
must never be claimed from the workflow definition alone. Save any such limit
at CP5 while completing all locally authorized implementation and checks.

Tag the last PowerShell revision locally, retire old code/tests and staged
checker, migrate this config to v2, rewrite human-facing README with a workflow
diagram and move reference material to docs. Run Python tests and Python lint
in CI on windows-latest, macos-latest and ubuntu-latest (Python 3.10 minimum
and a current version). Slice A adds a Python fixture matrix alongside the
unchanged legacy job; Python lint joins it when slice B implements that command.
No push, install, consumer edits or release is implicit. Stop at CP5.

## Validation and reviews

Keep the legacy quick checks and pre-commit hook throughout slices A-C.
Before code commits run changed Python fixtures plus quick checks; at CP2 run
one full legacy suite on final code and all Python fixtures. Save evidence once
in the package, including test-first failures, inventory comparison and known
limits. Save independent findings and dispositions, integrate justified fixes,
then write a review request under 30 lines naming the reviewed commit. At most
two rounds per checkpoint; Opus and owner clearance remain external gates.
