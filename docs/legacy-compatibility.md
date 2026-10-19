# Legacy compatibility

The Python kit has retired the PowerShell scripts, closeout and migration
commands, external-mirror diff mode, staged-snapshot checker and legacy TODO
scheduler. The local annotated tag `v1-powershell` identifies the last
PowerShell revision.

Repositories that still depend on those files must use a separate checkout or
worktree pinned to the tag and repoint their launchers or shared paths:

```console
git -C <agent-workflow-kit> worktree add --detach <compatibility-path> v1-powershell
```

Inspect the destination and choose a path outside the active Python checkout
before running that Git command. The tag itself does not move a consumer that
references the primary kit checkout. Do not replace the Python checkout with
the tag while other consumers use it.

Consumers that reference a shared kit path need either a separate pinned
checkout plus repointed paths, or a v2 migration. Repositories containing local
mirrors keep those independent copies and need their own migration or
replacement. Use the current package evidence for the authoritative inventory;
do not infer consumer state from this general reference.

## Adopt the Python workflow

From the Python kit, preview adoption:

```console
wfk init --repo <consumer-repository> --json
```

Review the checklist, preserve repository-specific instructions and existing
files, then repeat with `--apply` when adoption is authorized. Init creates
only missing paths. Reconcile the version 2 config and prose manually, run
`wfk lint --repo <consumer-repository> --json`, and migrate shared launch
paths separately. No Python command performs an automatic legacy migration.

Version 1 configs can be inspected by Python commands. The output names ignored
v1 fields so the repository does not silently appear fully adopted. Missing
`workflowModelVersion` means unadopted; malformed, non-integer and unsupported
versions fail closed. The version 2 scheduler keeps its normal gate checks even
when branch-aware lint reads older package sources; diagnostics never downgrade
those checks or silently adopt a repository.

Prompt source changes and `wfk init` do not update global VS Code prompt
installations. Preview `wfk prompts install` and apply it separately when
authorized.
