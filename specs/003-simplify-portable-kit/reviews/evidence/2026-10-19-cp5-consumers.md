# CP5 consumer inventory before PowerShell retirement

Date: 2026-10-19  
Scope: read-only inventory under `H:\WSL_dev_projects` before T015  
Search terms: `agent-loop.ps1`, `workflow-kit.ps1`, legacy `bin/agent-loop`,
`bin/workflow-kit`, `bin/install-vscode-prompts` launchers, and
`canonicalMirrorMode`

## Method and limits

- Enumerated repository roots with a bounded directory walk that skipped Git
  metadata, dependencies, caches, generated output and large-data conventions.
- Collapsed linked worktrees by the absolute `git rev-parse --git-common-dir`.
  The walk found 88 checkouts, 52 unique Git common directories and 36 linked
  worktree duplicates. No traversed directory was unavailable.
- Used ripgrep first, then `git grep` to restrict the reported matches to files
  tracked in each primary checkout's current worktree. No referenced script was
  executed.
- This proves only the scanned current tracked files under
  `H:\WSL_dev_projects`; it does not cover untracked files, other roots, user
  prompt installations or branches visible only in linked worktrees.

## Operational consumers

These ten active repositories need a v2 migration or an explicit PowerShell
compatibility arrangement before the kit primary checkout loses the legacy
files.

| Repository | Dependency route | Current tracked operational matches (match count; line numbers) |
|---|---|---|
| `a4-generator` | Shared sibling kit checkout | `.github/copilot-instructions.md` (4; 57,169,188,204); `.workflow-kit.json` (1; 2); `package.json` (1; 29); `README.md` (2; 55,64) |
| `baseline-foundry` | Local mirrored PowerShell copy | `bin/agent-loop` (1; 11); `bin/agent-loop.cmd` (1; 4); `prompts/overnight.prompt.md` (5; 8,13,21,25,28); `prompts/proceed-autonomously.prompt.md` (5; 8,13,21,25,28). Tracked local files also include `agent-loop.ps1`, `install-vscode-prompts.ps1` and both prompt-installer launchers. |
| `design-documentation-planning` | Shared kit path placeholder | `.github/copilot-instructions.md` (2; 158,166) |
| `design-foundry` | Shared sibling kit checkout | `.github/copilot-instructions.md` (2; 161,173) |
| `diagram-generator` | Shared sibling kit checkout | `.github/prompts/overnight.prompt.md` (3; 9,20,30) |
| `diagram-registry` | Shared sibling kit checkout | `.workflow-kit.json` (1; 2); `README.md` (1; 51) |
| `lightning-talks` | Shared sibling kit checkout | `.github/copilot-instructions.md` (2; 148,156); `README.md` (2; 72,78) |
| `ontologies` | `gg` launcher calls shared sibling kit | `gg/bin/agent-loop.cmd` (1; 4); `gg/README.md` (1; 347); `gg/TODO.md` (1; 64). `gg/bin/install-vscode-prompts.cmd` is also tracked and calls the shared kit installer. |
| `portfolio` | Shared sibling kit checkout | `.github/copilot-instructions.md` (2; 223,240); `docs/specs.md` (1; 28) |
| `repo-workflow-boilerplate` | Local mirrored PowerShell copy | `.github/agents/agent.md` (1; 60); `.github/copilot-instructions.md` (2; 117,159); `bin/agent-loop` (1; 11); `bin/agent-loop.cmd` (1; 4); `docs/specs.md` (1; 20); `prompts/overnight.prompt.md` (5; 8,13,19,23,26); `prompts/proceed-autonomously.prompt.md` (5; 8,13,19,23,26); `README.md` (9; 123,143,178,183,187,188,189,190,205); `STATUS.md` (6; 5,9,37,39,40,50). Tracked local files also include `agent-loop.ps1`, `install-vscode-prompts.ps1` and both prompt-installer launchers. |

The eight shared-path consumers are `a4-generator`,
`design-documentation-planning`, `design-foundry`, `diagram-generator`,
`diagram-registry`, `lightning-talks`, `ontologies` and `portfolio`.
Creating the local `v1-powershell` tag does not move any of them: after the
primary kit checkout becomes Python-only, continued legacy use requires a
separate checkout/worktree at `v1-powershell` plus repointed paths, or migration
to v2. The two repositories with local mirrors retain their checked-in copies,
but those copies are independent of the kit tag and require separate migration
or replacement.

## Historical and non-active matches

- `diagram-generator/docs/spec-archive/068-internal-dual-path-deletion/search-evidence.md`
  has one historical match at line 121.
- `ontologies/gg/HISTORY.md` has one historical match at line 203 and
  `ontologies/gg/docs/analyses/2026-04-29-horticultural-rigour-audit.md` has one
  at line 126.
- `portfolio/HISTORY.md` has two matches at lines 149 and 164;
  `portfolio/MIGRATION-PLAN.md` has three at 47,58,176; `portfolio/STATUS.md`
  has one status assertion at 42.
- `repo-workflow-boilerplate/HISTORY.md` has three matches at 15,35,41 and
  `ROADMAP.md` has three at 54,98,103. Its operational README, STATUS, prompt,
  instruction and launcher matches remain in the active table.
- `agent-workflow-kit` itself has the expected retirement targets across CI,
  instructions, docs, prompts, tests and PowerShell sources. It is the producer
  being migrated, not a downstream consumer.
- One additional unique Git repository exists only under the survivor/archive
  path
  `diagram-generator-survivors-20260906/tmp/baseline-foundry-source-0.1.7`.
  It contains local legacy launchers and prompts, but is classified as an
  archived snapshot rather than an active pin target.
- The other 40 unique primary repositories had no current tracked matches for
  the requested terms.

## Read-only integrity evidence

SHA-256 was captured immediately before and after a repeated read-only search
for 38 operational matched/dependency files. All 38 before/after hashes were
identical (`changed=0`). Representative hashes:

| File | SHA-256 before and after |
|---|---|
| `a4-generator/package.json` | `76244f36df85070142899015746671a295c231439b43c1dfd2d69a31faa2cc9b` |
| `baseline-foundry/agent-loop.ps1` | `609cd66a3cd92d1da71a8555d0de2beb6e2b0f6e7bb9484fa31b84d6540ae51a` |
| `design-documentation-planning/.github/copilot-instructions.md` | `e991c6e24a94f676e211a7d10e8f7f81b3e3720c9a68e219a10a34999462a352` |
| `design-foundry/.github/copilot-instructions.md` | `4f5ca811d1878a57c576037f834469b737a86a523e2d64da07ce794f57d2a742` |
| `diagram-generator/.github/prompts/overnight.prompt.md` | `0b6bf61528d6eb3e3f942fe1674917c2c0e60bbd1fd271042054b46e245d13ad` |
| `diagram-registry/.workflow-kit.json` | `2287714a772d70bea81033313505e1657fc0c713f1b21cc2856bcf28906ddfb9` |
| `lightning-talks/README.md` | `adbcbf1a34d04bcab4289fba8f6ca2107b5e62f65fae2c3dfde7e960b8c51955` |
| `ontologies/gg/bin/agent-loop.cmd` | `703b6ebcc29760b6cd73033f86f80df30571e9626fbf6b6dc191de1177f138c5` |
| `portfolio/.github/copilot-instructions.md` | `f5dc53ca369ff14340e6d4f5abcb2e8d2839ec7631bef80e2ee4c25a02396f5d` |
| `repo-workflow-boilerplate/agent-loop.ps1` | `609cd66a3cd92d1da71a8555d0de2beb6e2b0f6e7bb9484fa31b84d6540ae51a` |

No consumer file, Git configuration, ref, index or hook was intentionally
modified; no fetch, install, worker, push, merge, clean, stage or commit was
performed.
