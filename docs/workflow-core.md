# Portable workflow commands

Run `python -m wfk` from the kit checkout, or put `bin/` on `PATH` and use
`wfk` from another repository. Git 2.38+ and Python 3.10+ are required; the
implementation uses only the Python standard library.

```text
wfk lint --repo . --json
wfk init --repo .
wfk init --repo . --apply
wfk new small-feature --repo .
wfk new small-feature --repo . --apply
wfk prompts install
wfk prompts install --apply
```

## Configuration and lint

Workflow commands require `.workflow-kit.json` with
`workflowModelVersion: 1` or `2`. Malformed JSON, a non-object root, a string
such as `"2"`, and unsupported versions fail closed. Missing version means the
repository is unadopted: run `wfk init --repo .` as a preview and reconcile the
manual checklist before applying adoption.

Version 2 is the current runtime contract. Version 1 can be inspected by the
Python commands for migration: shared target settings remain usable, and each
ignored v1 field is named in warnings. This does not recreate the retired
PowerShell scheduler or legacy TODO routing. A repository that still needs that
implementation must use a separate checkout pinned to `v1-powershell`.

`lint` is offline and read-only. Current catalog packages resolve from their
declared branch's checkout, including uncommitted owner edits, or the local
branch ref when no checkout exists. Archived packages resolve from the caller's
checkout. A cached remote branch is not substituted for a missing local owner.

Checks cover owner files, lifecycle, checkpoint states and links, review headers
and finding severities, task identities and gates, instruction state, and
configured per-file/host budgets. Only declared fully auto-loaded files consume
budgets. Lint reports mechanical errors and version 1 migration warnings; it
cannot prove prose freshness, reviewer identity or owner authorization.

## Adopt an existing repository

`wfk init --repo .` previews missing config, project templates, catalog,
inboxes and instruction skeletons. `--apply` creates only missing paths with
exclusive creation. Existing files remain byte-for-byte unchanged and appear in
a manual merge checklist. Review and commit the adoption yourself. Init does not
install hooks, prompts or worker tools.

New configs use [the init template](../templates/init/config.json), including
per-host auto-loaded file budgets. If a config already exists, init preserves it
and names missing settings for manual reconciliation.

## Create a package

`wfk new <short-name> --repo .` previews the next number, branch and configured
target. `--apply` creates complete package owners and the catalog registration
through Git commits while keeping the caller's branch unchanged. It never
pushes. The target must be clean and available; failure preserves partial
artifacts and reports a recovery path. The generated CP1 remains pending, so
creation does not authorize implementation.

Project templates under `.specify/templates/overrides/` are the extension
point. Vendor Spec Kit scripts and skills remain unmodified; catalog registration
and task gate checks belong to Python.

This checkout's Spec Kit vendor scripts use PowerShell 7 (`pwsh`); they are
separate from the Python kit's Git/Python-only requirements. On macOS or Linux,
install `pwsh` to use these scripts, or reinitialize Spec Kit with its `sh`
scripts. Keep vendor scripts unmodified. The `.specify/feature.json` cursor
selects the package for vendor tools; it does not authorize work or clear gates.

Terminal archived packages can declare `**Review format version**: 1` in their
spec header to retain historical v1 review compatibility after a repository
upgrade. This applies only to lint for archived `delivered`, `closed` or
`superseded` packages. Active packages and scheduler gates remain strict, and
standard findings still require complete headers and severities.

## Install reusable prompts

`wfk prompts install` previews every shipped prompt in the VS Code and VS Code
Insiders user prompt directories. `--apply` creates or replaces regular prompt
files. Parent/file collisions and links are preserved with a checklist. Platform
locations use APPDATA on Windows, Application Support on macOS and
XDG_CONFIG_HOME or `~/.config` on Linux.

Installed prompts route integer config versions 1 and 2 through the current
Python workflow. Version 1 produces ignored-field diagnostics. A missing version
routes to an init preview and manual adoption; invalid or unsupported versions
stop. Retired behavior is available only from a separate `v1-powershell`
checkout. Installing prompts does not migrate consumers.

Prompt frontmatter does not pin a model; reusable prompts inherit the invoking
host's current selection, following the
[VS Code prompt-file frontmatter contract](https://code.visualstudio.com/docs/agent-customization/prompt-files).
Automated reviews use the reviewer profile in
`templates/scheduler-defaults.json` plus explicit config overrides.

Use `prompts/review.prompt.md` for saved findings and matching dispositions.
A checkpoint has at most two review rounds before an owner decision.

See [worktree commands](worktrees.md) and [the scheduler](scheduler.md) for
cleanup, dispatch, evidence and recovery details.
