# On-demand operations

Read [AGENTS](../AGENTS.md) and resolve work through [the catalog](specs.md)
before acting. Command output reports repository state; it does not override
scope, package lifecycle or owner checkpoints.

## Terminals and authentication

Keep long-running workers in an inspectable foreground terminal. Before an
authorized scheduler execution, run its preview:

```console
wfk run --repo . --package <catalog-package> --agents <profiles> --json
```

Preview does not invoke worker authentication or a model. An applied run performs
the configured noninteractive authentication probe before dispatch. Codex and
Copilot probes fail closed on missing tools, malformed replies, timeouts or an
unauthenticated status. Complete interactive login outside the scheduler, then
start a new bounded run; the scheduler does not loop on authentication failures.
The standalone Claude Code adapter has not been qualified and ships without an
authentication probe, so preflight refuses it.

Git hosting authentication is separate from worker authentication. When a task
actually needs GitHub access, use `gh auth status`; do not treat a shell alias as
the GitHub CLI.

## Bounded work

Owner authorization persists inside the declared repository, package, task and
write scope. Re-read `tasks.md` and the checkpoint table between substantive
chunks. Keep durable findings in package `reviews/`; inbox entries are transient
handoffs and remain until received or durably transferred.

An applied scheduler run needs explicit `--package` values and finite limits.
The defaults are one task, eight hours and 1,800 seconds per worker. Permission
flags in worker profiles allow the process to operate without prompts; they do
not grant repository scope, clear gates, authorize review rounds, or authorize
pushes and merges.

Use the default reviewer only for an authorized review phase. It is
`copilot-opus`: Copilot CLI selecting `claude-opus-4.8`. That qualified route
does not qualify the standalone `claude` CLI. Save the actual reviewer identity
and reviewed revision. A checkpoint stops after two review rounds for an owner
decision.

## Recovery

Applied runs create a report and logs under the repository Git common directory
at `wfk/runs/<run-id>/`. Read the report before changing a retained checkout,
lease or rejected ref.

A package lease prevents concurrent runs. After a crash, verify the recorded
process and run directory before manually removing a stale lease; the scheduler
does not steal one. A protected worker commit is preserved at
`refs/wfk/rejected/<task>-<timestamp>` before the package branch is rewound.
The ref operation does not clean staged, unstaged, ignored or untracked files.

On timeout the scheduler interrupts the process, waits the configured grace
period, then terminates the process tree. Windows Job Objects contain descendants;
POSIX process groups cover processes that stay in the session. A deliberate
session escape and an abrupt power loss cannot be fully contained or finalized.
A hard termination can leave a report marked running.

Scheduler cleanup considers only worktrees created by that run and uses ordinary
Git removal without force. Reused checkouts and worktrees containing local bytes
are retained. Inspect and recover them manually; never use recursive deletion as
a fallback.

Prompt installation, hook installation, consumer adoption, live workers,
publishing and consumer migration are separate actions. Updating source files in
this kit does not update user-installed prompts or shared consumer paths.
