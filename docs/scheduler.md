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

[Shipped defaults](../templates/scheduler-defaults.json) own the three argument
templates. Version 2 user config (`WFK_CONFIG`, otherwise
`~/.config/wfk/config.json`) merges first, then repository `.workflow-kit.json`.
Worker fields in version 1 configs are ignored with a warning; legacy version 1
prompt routing remains unchanged until retirement. Config is frozen for each run.

Authentication commands are deliberately unset: no real CLI was authorized for
qualification in slice C. Execution fails closed until you configure a verified,
cheap, noninteractive `authCommand`. A command merely existing or printing help
does not prove authentication. Do not configure login, a model request or another
billable operation as the probe. Worker and probe executable availability, clean
checkout, branch and gates are checked before task dispatch. Authentication
failure stops the whole run without a login loop.

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
are `{prompt}`, `{repo}`, `{package}`, `{task}`, `{model}` and `{review}`. A probe
is a fixed argument array with no placeholders. On Windows, `.cmd`/`.bat` launchers
are refused; configure a native executable (for example Node plus the CLI's
installed JavaScript entrypoint) instead of a shell wrapper. CLI flags and auth
probes must be qualified for the installed release before a live run.

`tierModels.<profile>.H|S|L` is the single model owner. Defaults are null, selecting
the CLI's configured model. To choose an explicit tier model, also supply that
profile's `modelArgs` argument array, such as `["--model", "{model}"]` when that
syntax is supported. The scheduler does not guess models or reasoning flags.
Optional `authExitCodes`, `quotaExitCodes`, `authPatterns` and `quotaPatterns`
classify documented CLI failures; literal patterns apply only to nonzero exits.
Configure these from verified behavior. Unknown failures remain `error`.

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
