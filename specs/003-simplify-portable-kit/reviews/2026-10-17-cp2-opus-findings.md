# CP2 Opus findings: slice A worktree hygiene

**Checkpoint**: CP2
**Scope**: `003/spec-r1`
**Reviewer**: Opus (GitHub Copilot, Claude Opus 5.5)
**Reviewed revision**: `716823f475b8f8b0a537f93372f353b150c41295` (records at `1adc94d`)
**Verdict**: changes

Date: 2026-10-17. Round 2 of 2 for CP2 under FR-022.

## Summary

The core is sound and sized right: about 700 lines of stdlib Python, Git-metadata
discovery, squash-aware landing with isolated `merge-tree` objects, re-validation
before removal, no recursive deletion, composing hooks that never fail Git. I
reran the suite (36 tests, 1 skip, OK). Three reproduced problems remain with
"landed" being too broad and the hook target being too eager. Each would act
automatically once hooks are installed across the owner's repositories.

## Findings

1. **Major – standalone branch deletion catches branches that hold no landed work.**
   `clean` proposes `delete-branch` for every local branch that is an ancestor of
   the target and has no worktree. FR-014 only deletes a branch after removing
   its worktree. Reproduced in this repo (dry run): `feat/001-spec-first-workflow`
   – the declared branch of active Spec 001 – and `master` are both proposed for
   deletion. In a scratch repo, a just-created `develop` branch is too. The real
   inventory reports 55 such branches, and the hook would run this after every
   pull of the target. No commits are lost (they are in the target), but package
   routing breaks and owner branches disappear silently.
   *Fix*: list these branches only. Delete them only with an explicit
   `--branches` flag, never from the hook. Always keep a configurable protected
   list (default `main`, `master`, `develop`, `trunk`, `release/*`) and the
   target. Slice B adds catalog-declared branches to that list.

2. **Major – a fresh worktree counts as landed and is removed.**
   `wfk wt new feat/x` followed by `wfk wt clean` proposes `remove` for the new
   worktree: its tip is the target tip, so it is an ancestor. Reproduced in a
   scratch repo. With hooks installed, an agent that has just created its
   worktree loses it when the owner pulls the target in another terminal.
   *Fix*: treat a branch or detached HEAD as landed only if it has moved since
   creation. The worktree's `HEAD` reflog having a single entry is a cheap test.
   Also keep worktrees with activity inside a grace period (default 24 h,
   configurable), using the newest of the HEAD reflog entry and the admin
   directory's mtime. Add a fixture: `wt new` then `clean --apply` keeps it.

3. **Major – `hooks install` writes into checkout-relative hooks directories.**
   With `core.hooksPath=.husky` (common in JS repos), the preview targets
   `<checkout>/.husky/post-merge` and `post-rewrite` in the primary and in every
   linked worktree. Those are tracked or committable files containing absolute,
   machine-specific Python and kit paths. The known limit admits the untracked
   copies then make every such worktree "untracked files" – so installing the
   cleanup hook stops cleanup in that repo.
   *Fix*: when the resolved hooks directory is inside any worktree, refuse with
   an explanation and one-line manual composition instructions. Add a fixture.

4. **Minor – hook failures are invisible.** The wrapper discards all output and
   exits 0, so a moved kit or changed Python stops cleanup silently. Append one
   result line to `<git-common-dir>/wfk/hook.log`, and have `wt ls` warn when the
   last recorded hook run failed.

5. **Minor – prunable registrations never clear.** Pruning is skipped whenever
   any registration is unavailable, so the two prunable `%TEMP%/agent-loop-worktrees`
   entries persist. Consider pruning only when the missing path's parent
   directory exists (deleted, not unmounted), or an explicit `--prune`.

6. **Minor – "ignored output" means all ignored files.** `--force` removal also
   deletes ignored `.env*`, local notes and `tmp/` evidence. State this plainly in
   [worktrees](../../../docs/worktrees.md) and in `clean` dry-run output.

## Orphan limit (owner disposition requested)

Recommend accepting the limit and amending FR-014 to "orphans are listed with
size; removal is manual". Orphans have no Git metadata to prove they are clean,
the only default scratch root belongs to the retired scheduler, and automatic
removal would need the recursive deletion the kit deliberately avoids.

## Remediation scope

Findings 1–3 are required before CP2; each needs one fixture. Findings 4–6 may
be fixed or recorded as known limits. Per FR-022 no third review round starts
automatically: GPT fixes, records dispositions and validation, and the owner
decides whether to clear CP2 on that evidence or ask for a targeted check.
