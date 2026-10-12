# agent-workflow-kit

Canonical workflow scripts, reusable VS Code prompt sources, and a lean
repository convention for human plus agent coding sessions.

## Start and ownership

Read [AGENTS](AGENTS.md), then [the catalog](docs/specs.md). The first current
package routes a session to its declared branch/worktree. Package `spec.md`
owns intent, lifecycle and checkpoints; `plan.md` owns approach; `tasks.md`
owns execution and its bounded current-work header. Package `reviews/` keeps
requests, findings and dispositions. Inbox entries are transient links, never
standing resume instructions.

| Surface | Owner/purpose |
|---|---|
| AGENTS.md | Static invariants, routing, precedence and check triggers |
| CLAUDE.md; Copilot adapter | Thin routes to AGENTS |
| docs/specs.md | Ordered package/branch routing and at most ten candidates |
| INBOX.md | User notes; preserve unread/unresolved items |
| AGENT-INBOX.md | Agent handoffs naming recipient/scope, artifact, requested action |
| ROADMAP.md | On-demand product direction; not an execution queue |
| .workflow-kit.json | Version, target, scratch/disposable policy and host budgets |
| .specify/memory/constitution.md | Durable principles |
| docs/operations.md | Terminal, authentication, autonomy and recovery procedure |
| docs/enforcement.md | Host trigger matrix and enforcement gaps |

Retired root STATUS/TODO/HISTORY remain 2–3 line catalog placeholders until
slice C follows owner-installed dual-mode prompts. Do not expand them. Former
open TODO ideas are catalog candidates; resolved owner acceptance remains in
package dispositions. All previous HISTORY content is preserved in Git:
`git log -- HISTORY.md` locates earlier revisions and
`git show <revision>:HISTORY.md` reads one without recreating a root owner.
The optional legacy resume agent is retired.

Small local fixes can act directly. Governed behavior changes use a package;
load Spec Kit assets only when relevant. Its project infrastructure/templates
live in `.specify/`, with on-demand skills in `.agents/skills/speckit-*/` and
`.claude/skills/speckit-*/`. Local `.specify/feature.json` is an ignored
convenience cursor, never authorization. Select the explicit package or catalog
and verify its branch. Vendor skills cannot write feature-marker blocks or plan
references into AGENTS/CLAUDE or override owner checkpoints. Preview upgrades
and preserve customized templates/constitution.

Project templates in `.specify/templates/overrides/` declare the spec-owned
lifecycle/checkpoint block and bounded task header. The prerequisite helper's
`-RequireTasks` flag also checks the next task gate; it cannot bypass that check
with a completed checklist or `-PathsOnly`. Pure path inspection remains available
without `-RequireTasks`. Vendor skill files are unchanged.

## Slice and consumer boundary

The first delivery slice covers kit-local ownership, lifecycle/checks, scheduler
gates and Spec Kit integration. Closeout belongs to slice B; full migration
tooling and dual-mode prompt conversion belong to slice C. Each slice requires
its owner checkpoint before the next begins; read package gates for current
authorization. No README statement replaces their state.

Repositories without `workflowModelVersion` retain legacy behavior. Existing
`canonicalMirrorMode: external` alone does not activate spec-first mode; malformed
new config fails. Consumer rollout requires separate authorization and must
preserve local product rules and external-kit ownership. Do not copy placeholders
into a consumer and claim completed migration. Preview/disposition legacy content
before activation; the complete adoption/rollback procedure is a later slice.
Installing user-level prompts is a separate authorization, not self-hosting.

## Validation and drift checks

Run quick checks at session start/end, scope changes, and before dispatch:

```powershell
pwsh -NoLogo -NoProfile -File ./workflow-kit.ps1 -Command lint -RepoRoot . -Strict
pwsh -NoLogo -NoProfile -File ./agent-loop.ps1 -DryRun -RepoRoot .
```

Before commits, also run relevant fixture tests and `git diff --check`.
Read [enforcement coverage](docs/enforcement.md) before claiming host automation.
Lint is read-only, local, and needs no network/model calls. It checks declared
owners/links, lifecycle/checkpoints, branch routing, physical lines and UTF-8
bytes, per-host aggregates, stale declared task/scope handoffs, retired routers
and forbidden instruction markers. Findings use stable IDs; size checks cannot
establish semantic freshness. Unread inbox links are allowed.

With `bin/` on PATH:

```powershell
workflow-kit lint
workflow-kit lint -Strict
workflow-kit lint -Json
workflow-kit diff
```

Direct invocation and external mirror configuration:

```powershell
pwsh -NoLogo -NoProfile -File /path/to/agent-workflow-kit/workflow-kit.ps1 -Command lint -RepoRoot $PWD
pwsh -NoLogo -NoProfile -File /path/to/agent-workflow-kit/workflow-kit.ps1 -Command diff -RepoRoot $PWD -KitRoot /path/to/agent-workflow-kit
```

A consumer may use `{"canonicalMirrorMode":"external"}` in its existing
`.workflow-kit.json` to suppress missing mirrored script/launcher/prompt assets
while still comparing mirrored assets that exist. This preserves legacy mode.

## Scheduler and launchers

Versioned Spec Kit creation switches to a clean configured target, commits only
the draft package's catalog row there, then creates the feature branch from that
commit and writes its draft spec from the project override. A dirty checkout or
failed target switch stops incomplete; creation never pushes. On the target,
missing local package branches produce an informational "fetch the declared
branch" finding. Package edits still require their declared branch. This kit's
target is `main`; consumers use their own configured target.
On failure, creation restores the original branch (or detached head), retains
registration and partial artifacts, and reports any restoration failure alongside
the creation failure. The target must already contain the versioned config and
project overrides. This kit's main at `864cad5` predates slice A, so new packages,
including Spec 002, cannot be created until slice A is delivered to main. CP2
remains the owner boundary; this remediation does not merge slice A early.

`agent-loop.ps1` dispatches isolated workers. `-Agent Auto` chooses Codex from
a Codex environment and Copilot otherwise. In spec-first mode, discovery reads
package lifecycle/checkpoints and declared branches; only authorized active work
with cleared entry/task gates runs. Checkout failure stops. Reviews stay in
package `reviews/`; exhausted remediation reports incomplete. The configured
target replaces default-branch guesses; failed integration/dirty state preserves
recoverable workers. Managed scratch markers live in Git administration storage,
not package files, and cleanup never uses recursive filesystem fallback.

Model preferences live only in `agent-loop.ps1`'s `TierDispatchMap`; use
`-UseTierDispatch` or explicit owner overrides. Prompt frontmatter is an
invocation asset; consult its actual source rather than duplicating model tables.

```powershell
# Read-only previews; live runs require their own authorized scope.
agent-loop -Workflow SpecKit -DryRun
pwsh -NoLogo -NoProfile -File /path/to/agent-workflow-kit/agent-loop.ps1 -Workflow SpecKit -RepoRoot $PWD -DryRun

# Invocation controls for authorized live runs:
agent-loop -Workflow SpecKit -Agent Auto -MaxTasks 3 -TaskTimeoutSeconds 3600 -MaxContinues 25 -MaxAddressRounds 3 -OnFailure stop -UseTierDispatch
agent-loop -Model <owner-selected-model> -ReasoningEffort low

# Unmigrated legacy repositories only:
agent-loop -Workflow Todo -DryRun
agent-loop -Workflow Todo -MaxTasks 3
agent-loop -Workflow Todo -TaskSection "### Batch tasks"
```

Legacy TODO mode supports checkbox queues and active-lane tables; legacy
bookkeeping does not create a new root queue in migrated repositories.
Read [operations](docs/operations.md) for authentication, foreground terminals,
bounded autonomous bursts and failure recovery.

All launchers resolve the canonical script relative to `bin/`:
`agent-loop`, `workflow-kit`, and `install-vscode-prompts`, each with POSIX
and Windows `.cmd` wrappers. Consumers need Git and PowerShell 7+; live launches
need the selected authenticated CLI and an authorized integration target.

```powershell
# PowerShell profile:
$agentLoopBin = '<path-to-agent-workflow-kit>/bin'
$env:PATH = "$agentLoopBin$([System.IO.Path]::PathSeparator)$env:PATH"
```

```bash
export PATH="/path/to/agent-workflow-kit/bin:$PATH"
```

## Reusable VS Code prompts

Canonical definitions live in `prompts/`. Current source guards retire legacy
root-state procedures when they encounter placeholders; full dual-mode
conversion and installing refreshed shared prompts await separate authorization.
Existing consumer prompt bodies remain available until that transition.

| Command | Purpose |
|---|---|
| /whats-next | Orientation and recommended next authorized task |
| /freshen-status | Compatibility entry point; route retired status to its package owner |
| /audit-workflow | Mechanical workflow drift inspection |
| /run-validation | Run declared validation and report results |
| /overnight | Authorized bounded scheduler launch; honor owner checkpoints |
| /proceed-autonomously | Legacy alias for /overnight |
| /orchestrate | Tier/complexity routing and bounded delegated work |
| /repo-health-audit | Saved domain/architecture audit when requested |
| /audit-diagram-generator | Targeted diagram-generator architecture audit |
| /competing-audit | Independent perspectives and synthesized findings |
| /simo-plan-sweep | Tighten phased implementation plans |
| /simo-sweep | Requested post-change critical review |
| /sync-all-repos | Explicitly authorized workspace commit/push operation |

Prompt YAML frontmatter declares descriptions, mode and invocation model.
Model IDs are maintained in prompt sources; reusable dispatch preferences are
owned by `TierDispatchMap`, with procedures in `prompts/orchestrate.prompt.md`.

## Install or refresh prompts (separate authorization)

The installer writes VS Code global user prompt assets. Once authorized:

```powershell
git clone git@github.com:lyubomir-popov/agent-workflow-kit.git
cd agent-workflow-kit
pwsh -NoLogo -NoProfile -File ./install-vscode-prompts.ps1

# Refresh an existing clone:
git pull
pwsh -NoLogo -NoProfile -File ./install-vscode-prompts.ps1

# PATH wrapper:
install-vscode-prompts
```

Reload VS Code after installation. Re-running overwrites the same prompt files.
Default destinations are Windows `%APPDATA%/Code/User/prompts`, macOS
`~/Library/Application Support/Code/User/prompts`, and Linux
`~/.config/Code/User/prompts`. Existing Insiders profiles are detected; override
destinations with `-TargetPath <path>` (one or more) or `-IncludeInsiders`.

Product direction can grow into `docs/roadmap/` or `docs/vision/` on demand;
it must not become an extra status, handoff, or execution queue.
