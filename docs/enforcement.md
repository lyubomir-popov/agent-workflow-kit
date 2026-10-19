# Enforcement coverage

The Python kit enforces repository facts only when a command or hook actually
runs. Instructions can require checks, but an arbitrary chat host or direct CLI
invocation can skip them. Local checks do not prove that prose is current, a
reviewer performed a review, or an owner granted authority.

| Surface | Automatic enforcement | Manual check | Material gap |
|---|---|---|---|
| `wfk lint` | None; callers invoke it | `wfk lint --repo . --json` | Read-only structural checks cannot prove semantic freshness or authorship. |
| `wfk run --apply` | Preflight, package gates, clean branch/worktree, auth probe, bounds, commit protection and report creation | Preview the same explicit packages without `--apply` | Direct model/CLI use bypasses scheduler controls; permission flags are not authorization. |
| Cleanup hooks | Installed post-merge/post-rewrite wrappers call target-branch cleanup | `wfk hooks install --repo .` previews installation | No local hook fires for a remote PR merge; an up-to-date pull may fire none. |
| Git pre-commit | The repository hook runs Python lint against the current worktree | Run lint and `git diff --check` explicitly | It does not construct an isolated staged snapshot or guarantee that partially staged content is what lint inspected. Hooks can be bypassed. |
| GitHub Actions | The committed workflow is configured for Windows, macOS and Linux | Inspect `.github/workflows/python.yml` | Configuration and local tests do not prove a remote run, enabled Actions or required branch protection. |
| Prompt sources | `wfk prompts install` previews or copies shipped files | Compare source and user prompt directories | Installed prompts are separate user assets and do not update when source changes. |

Per-host auto-loaded inventories and line/UTF-8 byte budgets live in
`.workflow-kit.json`. Lint counts only files declared as fully loaded; on-demand
documentation and skills do not consume the automatic budget. A declared
inventory is repository policy, not evidence of proprietary host behavior.

## Workflow and review checks

Version 2 lint validates catalog-to-branch routing, package owner files,
lifecycle/checkpoint values and links, review headers and severities, task
identities and gates, forbidden instruction state, and configured budgets.
Standard findings must be linked from their checkpoint. Newer findings can make
an older clearance stale; ambiguous same-date ordering is reported. Lint neither
dispatches a worker nor clears a gate.

For a declared version 1 config, Python lint remains read-only and reports
migration warnings, including v1 fields it ignores. Runtime config is strict:
malformed JSON, non-object config, non-integer versions, and unsupported versions
fail closed. Missing `workflowModelVersion` is unadopted; preview `wfk init
--repo .` and reconcile its checklist manually.

Scheduler commit protection audits the dispatched commit range. It rejects
changes to protected config/catalog and gate metadata, existing review records,
task identity/order/gate/manual declarations, or another task's checkbox. A
rejected tip is preserved under `refs/wfk/rejected/` before a guarded branch
rewind. This protects Git history, not arbitrary filesystem writes: dirty,
ignored and untracked bytes remain, and the worker permission mode is not a
filesystem sandbox.

Review records require the reviewer, full reviewed revision, one verdict and
numbered severities. The implementer answers findings in dispositions. Blocker
and major findings must be resolved; minor findings may move to the package's
Known limits. Two review rounds exhaust the automatic budget. Only an owner
decision clears the checkpoint.

## Git and CI limits

The shipped pre-commit hook is deliberately small:

```sh
repo=$(git rev-parse --show-toplevel)
exec "$repo/bin/wfk" lint --repo "$repo"
```

It reads the worktree. Therefore a commit with partial staging can differ from
what lint saw. Run `git diff --cached --check`, inspect the staged diff, and
avoid claiming staged-snapshot enforcement.

The GitHub Actions matrix is configured for `windows-latest`, `macos-latest`
and `ubuntu-latest`, on Python 3.10 and the current Python 3 release. It runs
the full Python unittest suite, CLI help and branch-aware lint. Remote execution
evidence must come from the hosting service; the repository configuration alone
does not supply it.
