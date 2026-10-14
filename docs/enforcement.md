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
validates versioned staged contracts in an isolated index snapshot. Partial
staging of affected changed owners is refused; unrelated unstaged package edits
do not block unrelated commits. Root/config/catalog changes expand package scope.
Staged marker/budget violations cannot hide behind different worktree bytes, and
required review/owner deletions are refused. Git callers can bypass hooks
(`--no-verify`), and an alternate hooks path can skip it. Lint reports actual kit
hook presence; a path alone does not prove future callers will honor it.

The kit's `.github/workflows/workflow.yml` supplies a Windows/Linux CI backstop
for published changes, using quick checks and fixture tests. Local files alone do
not prove a remote run, enabled Actions, or required branch protection. Offline
validation and unpushed commits have no CI coverage; missing consumer CI is an
explicit adoption gap. Repo authorization governs publication.
CI's whitespace step uses committed event evidence: PR merge-base/head or push
before/after. First pushes use the configured target merge base, falling back to
the parent or root empty-tree comparison when that base equals the event head.
Unavailable nonzero event revisions fail. Offline tests exercise these cases;
remote CI remains unverified. Author validation also checks worktree/index and
the range from the reviewed starting revision. The older vendor/integration
whitespace baseline remains separately reported maintenance, owned by the Spec
001 implementer; no vendor cleanup or exclusion of new whitespace is claimed.

Versioned kit launchers reject worker revisions that alter the spec block before
its first level-two heading, change `.workflow-kit.json`, alter the task entry
checkpoint or existing gate/manual annotations, add/remove/reorder task IDs,
modify or delete an existing file under `reviews/`, add a new review carrying
any recognized gate label (Verdict, Accepted scope, Checkpoint, Scope, Reviewer,
Reviewed revision), or newly complete a task other than
the focused package/task ID. Task descriptions and current-work header fields
other than the entry checkpoint remain editable. Rejected ranges remain in
scratch and report worker-incomplete before cherry-pick. Launchers validate saved
gate records but cannot attest who authored clearance already present at the base.
Owner-only clearance remains a governance rule. Stale prose/scope reconciliation still
requires human judgment. Full consumer migration remains slice C work and is not
claimed by this matrix. Mirror diagnostics now include hook assets and shared
libraries; inventory coverage does not install a consumer hook.

Closeout preview uses local Git/config and computes retention without state
sidecars. Apply requires explicit action authorization and accepted/base/landed
evidence, then revalidates proof, annotated archive tags and each candidate.
Delivery worktrees use ordinary Git removal; only marked contained scratch may
use force after preservation/integration proof. Directory-level disposable
inventory avoids repeated per-file parent scans but still checks nested evidence
and reparse points. Accepted holds cannot be cancelled by deleting working bytes.
Archived edits require the configured target, with a narrow final-delivery
transition allowed on the previously declared package branch.
Local branch deletion requires supported Git reference transactions and composes
the effective caller hook with an exact accepted-old-ID guard during prepared
deletion. Temporary command configuration binds the merge check to archive proof
without persisting policy. Verify-only prepared transactions hold archive/target
proof stable during deletion; unsupported locking retains the branch.
The original landed commit remains the immutable delivery/tree/tag proof anchor
and must be an ancestor of the current target. Locks capture the current literal
target tip separately. Remote ancestry requires local commit objects; its leases
and no-op target refspec use the observed remote tip, avoiding a target rewind.
Declared partial-clone/promisor repositories remain unsupported for offline
closeout proof; unavailable ancestry retains cleanup without automatic fetch.
Literal source, target and archive names must match the full ref inventory and
be direct refs. Filesystem case aliases or symbolic ownership are incomplete,
even if their resolved object IDs match. Prepared deletion checks the literal
names and IDs again after the composed caller hook, under the proof/source locks.
It also independently checks registered worktree checkout names for source
aliases. Preview retains those aliases; this observes the prepared state and
does not lock other processes' HEAD files or attest global filesystem isolation.
Non-ASCII ref names are retained conservatively; their Windows case ownership is
unverified. This bound does not restrict Unicode filenames in changed-path proof.
Detached accepted-head and source-associated scratch trees remain retained inventory,
without inheriting delivery removal permission.
Remote apply is disabled unless explicitly authorized;
its tests mock network commands. It validates the captured annotation object and
retains a held remote source even if working-copy hold bytes are removed;
authorized archive-tag preservation can still proceed. It
uses atomic source/target/tag leases, then requires a final evidence query. Servers
can omit unchanged no-op refs; if proof changes after deletion, outcome is
incomplete with the actual deletion and local preservation reported. Local tests
do not attest live host/provider behavior or cross-process transaction isolation.
Real cleanup, unattended runs and publication remain owner
operations, and implementation of slice B does not claim Spec 001 delivered.

Gate validation and worker-range rejection share one parser for every gate
label, supporting plain, single-emphasis and bold labels with an optional list
prefix. Newly added unlabelled worker notes are allowed; existing records are
immutable during worker integration. Owner sessions can still author records.
Git blob reads and filesystem reads share UTF-8 defaults and BOM detection,
including UTF-16/UTF-32 review metadata; the label parser sees the same text.
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
