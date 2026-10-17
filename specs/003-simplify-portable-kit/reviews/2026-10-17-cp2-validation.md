# Slice A validation evidence

**Scope**: `003/spec-r1`, CP1 through CP2 only
**Final code revision**: `6ed3022211a7e8697331b36fc6c6619075b75e58`
**Remediation base**: `b6a375e0341bda8ca1d82f8ecdbf106fd70c016b`
**Original slice code revision**: `716823f475b8f8b0a537f93372f353b150c41295`
**Original review base**: `de9c365c8b32e217f2acf0e39b9e9eb976bd0e9b`
**Local environment**: Windows, Git 2.52.0, Python 3.11.9, PowerShell 7

## Opus remediation validation (latest)

Required fixes follow [Opus round 2](2026-10-17-cp2-opus-findings.md) and its
[matching dispositions](2026-10-17-cp2-opus-dispositions.md). No third round ran.
Test-first regressions reproduced standalone branch deletion and fresh attached/
detached worktree removal. The activity fixture initially had a setup error on
Git's message-less first reflog entry; after correcting it, it failed on actual
recent-worktree removal. The `.husky` fixture failed both preview and apply
before hook preflight was repaired. These failures occurred in temp repos only.

`python -m unittest discover -s tests_python -v`: **46 run, OK (skipped=1)**,
80.231 seconds, on the final code. Tests cover default standalone preservation,
explicit branch preview/apply, immutable default/custom protection, actual HEAD
movement, recent HEAD/admin activity independently, old landed removal, missing
logs, invalid grace values, checkout hook refusal, all-or-nothing installation,
external/admin hook composition and the hook's omission of `--branches`.
Earlier fixture expectations were updated to use actual committed/landed work;
ordinary removal tests explicitly disable grace to isolate their own guard.

- Mandatory full legacy `pwsh -NoLogo -NoProfile -File ./tests/run-tests.ps1`
  on the remediation code: **284 passed, 0 failed, 0 skipped**, 1944.62 seconds.
  One full run on this final code; subsequent changes are records only.
- Strict lint, scheduler dry run, staged and unstaged whitespace checks pass.
  A stale next-task header was caught and reconciled before the local commit.
  The staged checker passed without bypass; no real worker was invoked.
- `git diff --check b6a375e..HEAD` passes at the remediation commit.
- Existing real-machine inventory below is retained as earlier evidence;
  discovery was unchanged, so the broad scan was not rerun just to refresh it.
- No real worktree/branch cleanup, hook installs, consumer writes or pushes.
- Logging and unavailable-entry pruning are deferred minor findings, recorded
  in tasks. All-ignored-file deletion is now explicit in docs and preview.
- Orphan manual removal is the implementer's recommendation; the owner retains
  the FR-014 amendment and CP2 decision. Disk size for ownerless orphans is not
  yet calculated by the existing `--size` path.

## Original slice test-first and fixture coverage

The first config run failed with `ModuleNotFoundError: No module named wfk`.
The worktree worker's full initial run executed 12 tests and produced 15 expected
failures (including landing-style subtests), all missing `wfk.__main__`. Hook
fixtures initially ran 11 tests: 7 failures, 3 errors and 1 platform skip from
missing implementation. Fixture setup/teardown succeeded.

`python -m unittest discover -s tests_python -v` before Opus: **36 run,
OK (skipped=1)** in 79.944 seconds. The POSIX launcher test is skipped on Windows.
Fixtures exercise fast-forward, merge, squash and rebase landing; later commits;
ignored output removal; dirty/untracked/locked/unlanded/primary/current/detached
and unavailable preservation; target precedence; ownerless orphans; local idle
branches; metadata locations; default/overridden creation; byte-for-byte Git
metadata preservation on listing/preview; composing hooks, stdin/arguments,
relative/absolute/shared hooks paths and spaced Windows launcher paths.

Review regressions were reproduced before repair: no-apply callback deletion,
relative hooks in linked target checkouts, and remote-target local branch loss.
The new nested-repository discovery regression also failed before its repair.
Final focused and complete Python runs pass. See findings/dispositions for the
individual defects; this file owns the aggregate validation results.

## Real-machine inventory (read-only)

Ran `python -m wfk wt ls --root <projects-folder> --json`, where the root is this
kit's parent, then compared normalized paths to independent per-repository
`git worktree list --porcelain -z`. The final comparison after discovery repair
found **133 worktrees across 55 readable unique Git repositories**, with **zero
missing or extra paths**. Listing also reported 55 landed idle branches and no
orphans in configured scratch roots. Runtime was 111.83 seconds.

The broader scan includes primary checkouts and five nested repositories beyond
the initial direct-child comparison. It is not the earlier 78-linked-worktree,
13-repository sample. Every extra nested repository was independently verified
through Git before the final exact comparison.

Coverage limits: Git refused two nested repos as dubious ownership:
`canonical-spacing-spec/.tmp/d2-pinned-design-tokens` and `d2-pinned-pragma`.
Traversal also reported an inaccessible `ontologies/gg/venv/lib64` entry.
No trust settings changed. These errors prevent an unrestricted all-repos claim.
The v1 ignored-field warning correctly names the legacy fields.

No real-repository cleanup, hook installation, prompt installation, worker run,
push, merge or rebase was performed. Destructive fixtures used unique temporary
directories; inventory's merge probes used temporary objects and optional Git
locks were disabled.

## Original checkpoint checks (before Opus)

- Full legacy `pwsh -NoLogo -NoProfile -File ./tests/run-tests.ps1`: **284 passed,
  0 failed, 0 skipped**, in 1754.35 seconds, on the original slice code.
- Strict legacy lint and scheduler dry run: clean before code commits; zero
  worker invocations. The preview stops before T007 at uncleared CP2. Spec 001's
  pre-existing manual T059 remains unchanged.
- Whitespace checks: unstaged, staged and `git diff --check de9c365..HEAD` pass.
- The existing staged pre-commit checker passed both implementation commits;
  the remediation attempt initially refused omitted package reviews, then
  passed after all related records were staged together. No hook was bypassed.
- Added CI matrix: Windows/macOS/Linux, Python 3.10/current, stdlib fixtures and
  CLI help. It is committed but has not run remotely; Python lint comes in B.
- Sandbox command startup failed in this session; authorized commands used
  the working reviewed escalation path. No fallback altered machine settings.

Known behavior limits and remaining owner decisions live in
[tasks](../tasks.md#known-limits). CP2 remains pending for the owner; slices B-D
are unimplemented and their gates are unchanged.
