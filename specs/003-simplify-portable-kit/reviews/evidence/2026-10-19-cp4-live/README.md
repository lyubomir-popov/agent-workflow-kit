# CP4 scratch qualification evidence

Latest: the owner subsequently replied "Authorize one additional Codex scratch
task" on 2026-10-19, against committed source `fe50d76`, capped at 90 seconds in
this existing disposable repo. That one task passed in 37.765 seconds and made
one commit `e4f279578c50cfc71befc30d1f72117393d8c952`. Its separate
[confirmation](codex-final/confirmation.json), [report](codex-final/report.md),
[result](codex-final/result.json), auth/task logs and zero-context commit patch
preserve the final-source check. Exact marker bytes, only the T001 checkbox/two
intended paths, clean worktree, unchanged clean primary and no remotes were
independently asserted. The CLI used its configured `gpt-6.1-sol`, high effort,
approval never and danger-full-access. Pre-existing plugin/shell-snapshot/MCP
startup warnings did not block completion; no credential values were captured.
Two whitespace-only display lines in the copied task log were trimmed to pass
repository whitespace checks; the original remains at the reported scratch path.
The confirmation records both SHA-256 hashes. No event text or task bytes changed.
The original attempt/results below are historical and remain unchanged.

Authority: [owner decision](../../2026-10-19-cp4-owner-decision.md). Only the new
temporary repository named in `summary.json` was used. Its synthetic CP1 records
authorize fixture tasks only and never clear this project's CP4.

Each CLI run used `python -m wfk run --repo <scratch>/repo --package <package>
--agents <provider> --apply --max-tasks 1 --max-hours 0.05 --task-timeout 90 --json`.
User WFK config was isolated, no provider command/model overrides were supplied,
Git used a fixture identity and an empty hooks directory, and no remotes existed.

| Provider | Package | Actual worker attempts | Result |
|---|---|---|---|
| Codex | `specs/001-codex` | 1 | Authenticated; permission/sandbox/effort flags accepted; account rejected `gpt-5.4` before any commit |
| Copilot | `specs/002-copilot` | 1 | Authenticated and completed T001; marker bytes verified and one local commit |
| Claude | `specs/003-claude` | 0 | CLI unavailable; preflight stopped and saved a report |

The Codex attempt exposed a missing legacy compatibility guard. The final source
restores `Test-CodexCompatibleModel` behavior declaratively: Copilot's two GPT-5.4
aliases omit `--model` for Codex, leaving its configured model and tier effort.
At the initial handoff no second task had run and final-source Codex live
qualification was unconfirmed. The separately authorized passing follow-up above
resolves that limit without erasing the original failed attempt or selecting a
replacement model. `summary.json` retains the original phase's outcomes.

Claude was absent from the Windows PATH and checked `.local/bin`, npm and
`.claude/local` locations, and from WSL PATH. No install, login or platform/tool
substitution was attempted. Its `authCommand` remains unset pending qualification.

Each provider directory preserves the actual JSON result, Markdown report and
available logs. Original absolute log paths remain in the copied reports; the
matching basenames here are durable copies. Copilot's silent task log is empty;
its result, exact-byte check, commit ID and `copilot-commit.patch` are the proof
of completion. No fabricated log output was added.

`summary.json` checks that the scratch primary HEAD remained its initial commit,
its worktree stayed clean, no remotes appeared, and only the Copilot marker plus
its task checkbox changed. Its commit is
`98a8cdc20199f155c87776e8abe9d81ab0ed8b45`.
The patch uses zero context and trims display-only blank indentation to satisfy
repository whitespace checks; its changed file content and commit ID are intact.

Logs were reviewed and scanned for OpenAI/GitHub credential formats and bearer
tokens before copying; zero redactions were needed. Credential files and raw
Copilot auth payloads were never copied. The probe prints only authentication
success/failure. Scratch worktrees and reports remain at their recorded paths;
no cleanup application was performed.
