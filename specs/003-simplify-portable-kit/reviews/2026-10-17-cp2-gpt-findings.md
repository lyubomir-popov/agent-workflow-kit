# CP2 GPT findings

**Reviewer**: GPT-5.6 Codex (`gpt-5.6-sol`, high reasoning)
**Reviewed revision**: `feat/003-simplify-portable-kit` at
`178bb956687ba64a473781949921580dfd501e9d` plus the current working diff,
including the review repairs and this findings record
**Verdict**: accept

## Findings

1. **Major — resolved in the reviewed working diff: the public hook callback
   bypassed the explicit-apply safety boundary.** At the branch tip,
   `wfk hooks run --repo <repo>` called cleanup with `--apply` even though the
   callback command had no `--apply` option. An isolated fixture proved that
   invoking it directly removed a clean landed worktree and its branch. The
   reviewed diff adds an `--apply` guard, makes a direct invocation preview by
   default, and has generated hook wrappers opt in explicitly. Focused fixtures
   now prove both preview preservation and applied cleanup. This resolves the
   FR-003 defect without weakening FR-015 automatic cleanup.

2. **Major — resolved in the reviewed working diff: a relative
   `core.hooksPath` failed when the target branch moved to a linked checkout.**
   Git resolves a relative hooks path from each invoking checkout. Installation
   at the branch tip wrote only the primary checkout's directory. In an
   isolated fixture, moving `main` to a linked checkout made
   `git hook run post-merge` fail with `cannot find a hook named post-merge`,
   and a landed worktree remained. Installation now resolves every available
   registered checkout's effective hooks directory and deduplicates shared
   directories. The focused composition fixture passes.

3. **Major — resolved in the reviewed working diff: cleanup could delete the
   local target branch when the target was expressed as a remote ref.** With
   `origin/HEAD` resolving to `origin/main` and the primary checkout detached,
   `wt clean --apply` treated idle local `main` as an ordinary landed branch
   and deleted `refs/heads/main`. The reviewed diff derives the local target
   counterpart for local and remote target refs and uses it in preview, fresh
   branch deletion, and hook guards. Focused fixtures preserve local `main`
   for both `origin/HEAD` and an explicit full remote ref while still deleting
   another landed idle branch.

4. **Minor — documented limit requiring the CP2 owner decision: `--orphans`
   does not remove an ownerless orphan.** Such directories are reported and
   kept even with both `--orphans` and `--apply`, because there is no repository
   through which the implementation can issue the FR-014-required
   `git worktree remove`, and recursive deletion is forbidden. The safe impact
   is disk usage and manual recovery/removal rather than automatic cleanup.
   This is recorded in `tasks.md`; it is not an owner-accepted amendment to
   FR-014.

5. **Minor — documented preservation limit: one unavailable worktree blocks
   pruning for its repository.** A missing path may be an unmounted drive, so
   cleanup keeps the registration and skips `git worktree prune`, including
   stale registrations. This avoids destroying recoverable metadata but leaves
   stale entries until the path returns or the owner handles them manually.

6. **Minor — documented hook coverage limit: future worktrees with a relative
   `core.hooksPath` need installation rerun.** The installer covers every
   available worktree registered at installation time, but it cannot place a
   wrapper in a checkout that does not yet exist without changing
   `core.hooksPath`. Hook files in an untracked relative directory also make
   that checkout untracked and therefore preserved by cleanup. The operator
   impact and reinstall step are documented in `docs/worktrees.md` and
   `tasks.md`.

7. **Minor — documented discovery limit: broad root scans deliberately skip
   dependency/cache directories and directory symlinks.** A repository below
   `node_modules`, `.venv`, `__pycache__`, `.pytest_cache`, or reachable only
   through a child symlink will not be found by the containing `--root`, despite
   FR-011's literal “every repo” wording. Passing that repository itself as a
   root is the documented workaround. Access and dubious-ownership failures
   likewise limit coverage without changing host trust configuration.

## Validation

- Full Python fixture suite before review repairs: ran 29, OK (skipped=1); the
  skipped case was the POSIX launcher on Windows.
- Focused repaired behavior: ran 18, OK (skipped=1) for hook and nested
  discovery coverage; ran 2, OK for remote-target preservation.
- All destructive reproductions used isolated temporary fixture repositories.
  No cleanup or hook installation was applied to a real repository.
- `git diff --check` passed on the final working diff. Windows emitted only the
  repository's expected LF-to-CRLF working-copy notices.

The accept verdict reflects the repaired destructive findings and permits the
numbered minor limits to remain recorded under FR-022. It does not clear CP2 or
accept a change to FR-014; those decisions remain with the owner.
