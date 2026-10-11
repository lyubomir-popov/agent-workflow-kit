# Enforcement coverage

Instructions require quick lint at session start/end and scope changes; they
cannot force an arbitrary chat host to run it. Explicit kit workers run preflight
before dispatch. Local/read-only checks do not establish semantic freshness.

| Host | Instruction/loading inventory | Actual automatic trigger | Manual trigger | Gaps |
|---|---|---|---|---|
| VS Code Copilot Chat | AGENTS, CLAUDE and Copilot adapter are declared loaded; prompt files are invocation assets | Kit launcher preflight when launcher is used | Session lint, /run-validation, scheduler dry run | Chat can skip checks; adapter links may require explicit loading; host context loading beyond declared files is unknown |
| Copilot CLI | AGENTS plus declared Copilot adapter, depending on host support | Kit launcher preflight when dispatched | Session lint and explicit dry run | Direct CLI bypasses launcher; no claim every turn checks gates |
| Codex | AGENTS; vendor skills on demand | Kit launcher preflight when dispatched | Session lint and explicit dry run | Direct chats/CLI can skip checks; user/global instructions are outside repo enforcement |
| Claude Code | CLAUDE imports AGENTS; skills on demand | Kit launcher preflight when used | Session lint and explicit dry run | Direct chat can skip checks; user/global context loading is unknown |

Per-host configured inventories and line/UTF-8 byte budgets live in
`.workflow-kit.json`. Count files actually loaded once per host, including full
vendor content when loaded; unknown loading is a gap, never zero. A declared
inventory is local policy, not evidence of proprietary host behavior.

## Git and CI

The kit provides `.githooks/pre-commit` and `workflow-hook.ps1`. Self-hosting installs
the wrapper in the kit's effective local hooks directory, preserving an existing
hook by composition when present. Consumer activation is separate: compose its
existing hook rather than replacing it or resetting `core.hooksPath`. The checker
refuses partial staging of governing owners so staged marker/budget violations
cannot hide behind different worktree bytes. Git callers can bypass hooks
(`--no-verify`), and an alternate hooks path can skip it. Lint reports actual kit
hook presence; a path alone does not prove future callers will honor it.

The kit's `.github/workflows/workflow.yml` supplies a Windows/Linux CI backstop
for published changes, using quick checks and fixture tests. Local files alone do
not prove a remote run, enabled Actions, or required branch protection. Offline
validation and unpushed commits have no CI coverage; missing consumer CI is an
explicit adoption gap. Repo authorization governs publication.

Versioned kit launchers reject worker revisions that alter the spec block before
its first level-two heading, change `.workflow-kit.json`, alter the task entry
checkpoint or existing gate/manual annotations, add/remove/reorder task IDs,
add or modify a review carrying a recognized plain/bold verdict label, or newly complete a task other than
the focused package/task ID. Task descriptions and current-work header fields
other than the entry checkpoint remain editable. Rejected ranges remain in
scratch and report worker-incomplete before cherry-pick. Launchers validate saved
gate records but cannot attest who authored clearance already present at the base.
Owner-only clearance remains a governance rule. Stale prose/scope reconciliation still
requires human judgment. Cleanup and full consumer migration remain later slices
and are not claimed by this matrix.

The single-emphasis verdict-label mismatch is recorded as CPA-r1 in the
[delta findings](../specs/001-spec-first-workflow/reviews/2026-10-11-opus-slice-a-delta-review.md).
During self-hosting, preflight child processes load the scripts in the current
checkout. A worker's edits to checking/scheduling code can change subsequent
preflight behavior; the launcher does not pin preflight code to the starting
revision. These checks provide no code-integrity or filesystem sandbox.

Worker preflight checks repository/package, branch/base, marker, task and gate;
the focused prompt declares write scope. CLI permission modes do not provide a
filesystem sandbox for that scope. Direct vendor/CLI invocations can bypass kit
entry points. Versioned lint fails when the common resolver, RequireTasks gate or
feature-creation catalog integration sentinels are missing from the three Spec Kit
scripts. This detects overwritten integrations at the next check; it does not
attest vendor behavior or intercept the external `specify init` CLI. Upgrades still
require a manual preview preserving project overrides/constitution.
