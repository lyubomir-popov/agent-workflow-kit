# On-demand operations

Read [AGENTS](../AGENTS.md) for scope, owners, and validation before using this
procedure. Resolve work from [the catalog](specs.md); command output does not
override lifecycle, owner checkpoints, or authorization.

## Terminals and browsers

Use foreground VS Code integrated terminals the user can inspect when available.
Reuse a small number of terminals; record those you start and close hung or
unneeded sessions before finishing. Do not open external/background windows as
an invisible substitute. Use Chrome for Playwright/browser automation when the
task permits browser choice. Tool-specific host constraints still apply.

## Authentication

Before an authorized unattended Copilot run or tier dispatch, verify existing
Copilot CLI authentication. If output says `No authentication information found`
or `Please use /login to sign in to use Copilot`, stop automation.
Open an interactive integrated terminal, run `copilot`, and complete `/login`.
If the tool cannot drive that UI, ask the user to complete login and resume after
confirmation. Do not retry unauthenticated unattended runs. Where GitHub access
is needed, use `gh auth status`; do not mistake a shell `gh` alias for the CLI.

## Bounded autonomous work

Owner authorization to continue persists within the declared scope. Execute
small planned task bursts, validate substantive chunks, and keep the package
task header current. Narrow broad tasks before dispatch; prefer sequential
single-repo sessions over holding several repos in one context.
Commit checkpoints only when authorized. Re-read tasks and checkpoints between
chunks and preserve failures for inspection; exhaustion is incomplete.
No autonomous instruction authorizes beyond-gate work or an unrequested delta
review. Persist durable findings in package reviews and send only a transient
link through the inbox. Leave a bounded next action for a fresh session.

## Launch and recovery

Run quick lint and scheduler dry run before an authorized live launch.
Inspect checkout failures, configured target, scratch root, and entry/task gates.
Model preferences live only in `agent-loop.ps1`'s `TierDispatchMap`; use
`-UseTierDispatch` or an explicit owner override rather than copying a model table.
CLI support can differ from editor support; unsupported models/effort require
a reported failure or an authorized fallback.
Keep workers foreground and inspect preserved worktree paths on failure.
Do not recursively delete residue or force-remove ordinary delivery worktrees.

Shared prompt installation and consumer migration are separate authorized work.
Source prompts remain in `prompts/`; installation copies user-level assets and
must never happen as an incidental documentation refresh.
