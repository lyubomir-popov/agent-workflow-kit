# Bounded local scheduler

Preview without invoking any worker or authentication command:

```console
wfk run --repo . --package specs/003-simplify-portable-kit --agents codex --json
```

Execution needs `--apply` and explicit, repeatable `--package` selections. Defaults
are one task, eight hours total and 1,800 seconds per worker; set `--max-tasks`,
`--max-hours` and `--task-timeout` to positive finite values. Preview is not
authorization to execute. Gates, manual tasks and non-active packages stop work.
No task completion or reviewer verdict grants owner clearance.

The package branch must have a clean linked worktree or be unoccupied so the
scheduler can create its canonical worktree. If that branch occupies the primary
checkout, prepare a linked checkout manually first. The scheduler never switches
the primary branch, cherry-picks, pushes or merges. A package lease in the shared
Git directory prevents duplicate runs, including from different linked checkouts.
After a crash, inspect the lease's PID/run before manually removing a stale lock;
the scheduler never steals one automatically.

## Profiles and preflight

[Shipped defaults](../templates/scheduler-defaults.json) own the provider argument
templates. Version 2 user config (`WFK_CONFIG`, otherwise
`~/.config/wfk/config.json`) merges first, then repository `.workflow-kit.json`.
Worker fields in version 1 configs are ignored with a warning. Both integer
versions use the Python workflow; version 2 is the runtime contract. Missing
versions need a previewed `wfk init` and manual adoption, while invalid or
unsupported versions fail closed. Config is frozen for each run.

Codex uses `codex login status`. Copilot uses its bundled SDK's read-only
`auth.getStatus` JSON-RPC request through `--headless --stdio`; the standard-library
helper requires `isAuthenticated: true` and prints no account/token payload.
It does not create a model session or initiate login. Both probes fail closed on
missing tools, malformed responses, timeout or unauthenticated status. A command
merely existing or printing help does not prove authentication. Claude was absent
on the qualification machine; its probe remains unset rather than claiming
unverified behavior. Configure and qualify a cheap noninteractive probe before
using it. Worker/probe availability, clean checkout, branch and gates are checked
before task dispatch. Authentication failure stops the run without a login loop.

The default reviewer is `copilot-opus`: the Copilot adapter selecting
`claude-opus-4.8` through `modelArgs`. Its profile tier map applies to every task
tier without changing the implementing Copilot H/S/L preferences. It uses the
same verified Copilot auth probe and native npm resolution. This is Claude Opus
through Copilot, not qualification of the standalone `claude` adapter; that
adapter remains disabled until its own authentication probe is qualified.

For example, a disposable fixture profile can use a native Python executable:

```json
{
  "workflowModelVersion": 2,
  "workers": {
    "fixture": {
      "command": ["/absolute/python", "/absolute/fake.py", "work"],
      "input": "stdin",
      "authCommand": ["/absolute/python", "/absolute/fake.py", "auth"],
      "quotaExitCodes": [7],
      "authExitCodes": [3]
    }
  }
}
```

Commands are argument arrays, never shell strings. Supported worker placeholders
are `{prompt}`, `{repo}`, `{package}`, `{task}`, `{model}`, `{effort}` and `{review}`.
A probe is a fixed argument array with no placeholders. On Windows, known npm
shims resolve via validated package metadata to native Node plus the installed
entrypoint. Raw `.cmd`/`.bat`/`.ps1` and unrecognized wrappers are never executed;
prompt text never passes through `cmd.exe`. Native executables remain supported.
CLI flags and auth probes must be qualified for the installed release.

`tierModels.H|S|L` is the shared model/effort owner: H is `gpt-5.4`/`xhigh`, S is
`gpt-5.4`/`high`, and L is `gpt-5.4-mini` without an explicit effort. Codex and
Copilot opt into that table with `useTierModels`; their `modelArgs` and
`effortArgs` supply provider syntax. Codex uses a
`cliDefaultForModels` guard: these two Copilot aliases omit `--model` for Codex,
which uses its configured model while retaining the selected effort. An explicit
compatible Codex model override is passed through. Explicit `tierModels.<profile>.<tier>`
string/null overrides remain compatible, and an object can override model plus
effort together. Claude does not receive GPT model IDs; select Claude models in
its own profile overrides after qualification. Its CLI default otherwise applies.
The restored unattended flags permit local edits/commits without user prompts:
Codex bypasses its approval/sandbox prompts, Copilot uses allow-all/no-ask-user
autopilot with five continuations, and Claude's documented equivalent is
`--dangerously-skip-permissions`. These flags do not authorize a live run or a
new repository scope. Qualification remains bounded by the owner's instructions.
Optional `authExitCodes`, `quotaExitCodes`, `authPatterns` and `quotaPatterns`
classify documented CLI failures; literal patterns apply only to nonzero exits.
Configure these from verified behavior. Unknown failures remain `error`.

The installed CLI help and [official Codex configuration reference](https://developers.openai.com/codex/config-reference)
establish Codex effort syntax; [Claude's CLI reference](https://code.claude.com/docs/en/cli-reference)
documents its permission flag and auth-status command. Documentation alone is
not a claim that an unavailable Claude installation was live-qualified.

CP4's owner-authorized scratch run passed with Copilot. Codex's first attempt
rejected the Copilot alias; after the compatibility guard was restored, the owner
explicitly authorized one additional task, which authenticated and committed
successfully using the CLI's configured model. Claude was unavailable and remains
unqualified. Reports for both Codex attempts are preserved in the package evidence;
qualification of all three live providers is not claimed.

## Outcomes, recovery and evidence

A task is `done` only when its checkbox is checked, at least one commit exists,
the worker succeeds and the checkout is clean. Other outcomes are `no-progress`,
`uncommitted`, `timeout`, `quota`, `auth`, `gate-violation` and `error`; an interrupted
run is reported explicitly. Quota fallback follows only `--agents a,b,c` order and
requires a clean checkout without partial commits. Other task failures stop that
package; only another explicitly selected package may continue. Authentication
or interruption stops everything. There are no automatic task retries.

Every worker commit is audited, including an intermediate edit reverted later.
Protected fields include config/catalog, spec headers and gates, existing review
records, task identities/order/gate/manual declarations and other task checkboxes.
A violating tip is saved under `refs/wfk/rejected/<task>-<timestamp>` before a
compare-and-swap branch rewind. Only refs move: staged, unstaged, ignored and
untracked bytes remain. Inspect the report and recovery ref before manual repair.

An actual run initializes `wfk/runs/<UTC-run-id>/report.md` and logs under the
repository's Git common directory before preflight. The printed report path is
also in JSON output, even for auth failures, crashes or Ctrl-C. Reports list
commits, outcomes, logs and retained worktrees. An abrupt power loss or SIGKILL
can leave its initialized report marked running; no process can finalize after
forced termination. OS process trees receive an interrupt, then a configurable
`scheduler.grace` (default two seconds), then termination. Windows Job Objects
contain descendants; POSIX process groups require descendants to remain in their
session (deliberate `setsid` escape is outside this containment).

Cleanup considers only worktrees created by that run and keeps the existing
branch protection, landing and activity grace guards. Reused checkouts remain.
Removal uses Git without force, so ignored/local bytes can block deletion. There
is no folder-deletion fallback or branch deletion.

## Optional saved review

Add `--review --review-checkpoint CP4` and optionally `--reviewer <profile>` only
when that phase is authorized. After successful task progress, the reviewer saves
new findings in the package. Missing or invalid findings produce `review-missing`.
A sole validated new evidence record can be committed by the scheduler; existing
records are immutable. Changes after round one may invoke the implementing
profile to commit corrections plus numbered dispositions, followed by round two.
Two independent findings across runs exhaust the budget; no third starts.
Reviewer acceptance leaves the owner checkpoint pending. Only the named new
record is permitted through the commit guard for each review/address dispatch.
