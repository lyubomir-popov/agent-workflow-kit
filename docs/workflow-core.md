# Portable workflow commands

Run `python -m wfk` from the kit, or put `bin/` on PATH and use `wfk` from
the repository you want to manage. Git 2.38+ and Python 3.10+ are required.

```text
wfk lint --repo . --json
wfk init --repo .
wfk init --repo . --apply
wfk new small-feature --repo .
wfk new small-feature --repo . --apply
wfk prompts install
wfk prompts install --apply
```

`lint` is offline and read-only. Current catalog packages resolve from their
declared branch's checkout (including uncommitted owner edits), or the local
branch ref when there is no checkout. Archived packages resolve from the caller's
checkout. Workflow commands require an explicit config version 1 or 2; legacy
repositories receive adoption instructions. Standalone worktree commands remain
available without adopting the workflow. A cached remote branch is not silently used instead of a local owner;
missing local branches produce an actionable fetch/create diagnostic.

Checks cover owner files, lifecycle, checkpoint states and links (including
anchors), review headers and finding severities, task identities/gates, instruction
markers/state and configured per-file/host budgets. Only fully auto-loaded files
consume budgets; on-demand documentation and vendor sources are not inspected.
Lint reports mechanical errors; it cannot prove that prose is current or that a
reviewer actually performed the requested review.

Version 1 remains supported during retirement. Its existing nonstandard review
headers and checkpoint rows with more than two links produce migration warnings;
version 2 treats those as errors. Standard `*-findings.md` files require complete
headers in either version. Gate selection separately requires a saved accept
verdict and owner acceptance of the current scope. It stops at pending, missing,
blocking, manual or obsolete gates. Version 2 requires a complete accepting owner
decision in one record; a disposed historical finding cannot veto that decision.
Lint does not dispatch workers or clear gates.
Standard version 2 findings must be linked from their checkpoint, and a newer
dated findings file blocks a stale clearance. Same-date ordering produces an
ambiguity warning; the owner selects the latest record explicitly.

`init` previews missing files. With `--apply` it adds config, project override
templates, catalog, inboxes and an AGENTS skeleton using exclusive file creation.
Existing files remain byte-for-byte intact, with a manual merge checklist. Review
and commit adoption before creating a package. It does not install Git hooks,
worker tools or user prompts.

New configs use the [default budget template](../templates/init/config.json):
AGENTS.md gets 100 lines/12,288 bytes; CLAUDE.md and Copilot instructions each
get 15 lines/2,048 bytes. Each host gets an aggregate 150 lines/16,384 bytes.
Init adds missing thin CLAUDE/Copilot adapters so these declarations lint clean.
If configuration already exists, init preserves it and names missing or empty
`autoLoadedFiles` and `hostBudgets` fields for manual merging from that template.

`new` previews the numbered package, declared branch and configured local target.
With `--apply` it consumes the target's project spec template, seeds a draft with
pending gates and minimal plan/tasks, and commits complete owners plus catalog on
the target. It first prepares an owners-only draft commit/ref so branch-aware lint
can resolve the new package during the target registration commit, then advances
the feature ref to that commit. Every committed catalog is resolvable; there is
no missing-branch exemption. The temporary draft commit uses Git's normal object
storage. The caller's branch is unchanged; an unoccupied target uses a temporary
Git worktree. A target checked out elsewhere or a dirty target is refused. A
failure preserves partial files/index/refs and names the recovery checkout.
Nothing is pushed, and CP1 remains pending.

Spec Kit scripts and skills are not edited or inspected by these commands.
Project templates are the extension point; catalog registration and the next-task
gate check live in Python. Earlier PowerShell/vendor integrations remain for
version 1 until the separately gated retirement slice.

`prompts install` previews every shipped prompt in both VS Code and Insiders user
prompt folders. `--apply` replaces differing regular prompt files; preserve any
customizations first. Links and non-file collisions are kept with manual
instructions. Platform locations use APPDATA on Windows, Application Support on
macOS and XDG_CONFIG_HOME (or `~/.config`) on Linux. Prompt routing supports both
config generations. See [the scheduler](scheduler.md) for bounded dispatch,
profile qualification, reports and recovery. Live worker use requires separate
authorization; the slice C validation uses fake worker CLIs only.

Use `/review` to save findings and matching dispositions in package `reviews/`.
It requires actual reviewer/revision identity, severity-marked findings and a
single verdict. After two rounds, the owner decides; no extra round or checkpoint
clearance happens automatically.

See [worktree commands](worktrees.md) for cleanup, catalog branch protection and
manual orphan removal.
