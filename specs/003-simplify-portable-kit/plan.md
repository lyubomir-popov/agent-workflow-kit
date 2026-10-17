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

An initialized HEAD reflog alone is not evidence of work: require an actual
nonzero old-to-new OID change before marking a checkout landed. Use branch
reflogs for standalone branch candidates. Missing or unreadable evidence means
kept. Cleanup also keeps activity newer than `cleanupGraceHours` (default 24),
using the newest HEAD reflog timestamp and worktree admin directory mtime.
Re-read those guards immediately before removal. Tests set grace to zero only
when testing another exclusion/removal, and age fixture metadata explicitly
when verifying the default grace. No persistent proof ledger is needed.

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

## Slice D: retirement and documentation (after owner clears CP4)

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
