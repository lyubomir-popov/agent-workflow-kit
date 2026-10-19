# CP4 scratch qualification evidence

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
No second task was run, and no supported-model substitution was attempted.
Consequently this archive does not claim final-source Codex live qualification.

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
