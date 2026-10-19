# CP5 consumer inventory and linked-checkout correction

Date: 2026-10-19
Scope: read-only inventory under `H:\WSL_dev_projects` before T015, then a
linked-checkout coverage correction after retirement commit `9e5e4f4`.
Search terms: `agent-loop.ps1`, `workflow-kit.ps1`, legacy `bin/agent-loop`,
`bin/workflow-kit`, `bin/install-vscode-prompts` launchers, and
`canonicalMirrorMode`

## Method and limits

- Enumerated repository roots with a bounded directory walk that skipped Git
  metadata, dependencies, caches, generated output and large-data conventions.
- The walk found 88 checkouts, 52 unique Git common directories and 36 linked
  worktree duplicates. No traversed directory was unavailable. Every one of the
  88 checkout trees was searched before results were grouped by the absolute
  `git rev-parse --git-common-dir`; linked branches were not discarded before
  search.
- Used ripgrep first, then `git grep` to restrict the reported matches to files
  tracked in each checkout's current worktree. No referenced script was
  executed. The first pass covered only the 52 primary representatives; the
  corrective pass covered all 88 checkout trees and is the basis of the final
  result below.
- This proves only the scanned current tracked files under
  `H:\WSL_dev_projects`; it does not cover untracked files, other roots, user
  prompt installations or branches with no discovered checkout.

## Operational consumers

These ten active repositories need a v2 migration or an explicit PowerShell
compatibility arrangement to continue using the retired implementation.

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

## Linked-checkout coverage

The expanded pass found no additional Git common directory and therefore no
additional repository-level consumer beyond the ten active names above. It did
find branch-specific copies of already reported dependencies in 23 additional
linked checkouts:

- `baseline-foundry`: 11 matching checkouts total (the `main` primary plus
  `docs/demo-provenance-rules`, `docs/relocate-spec-024`,
  `docs/repository-map`, `feat/020b-page-grid-token-adoption`,
  `feat/024-semantic-spacing-token-schema`,
  `feat/025-compact-alignment-grid`, `feat/026-body-line-text-phase`,
  `feat/028-shared-spacing-decisions`, `wip/bf-typography-cap-metric`, and the
  detached `temp/bf-028-opus-corrections-20261006/pinned-4954c6e` checkout).
  Each has the same matched paths/counts/line locations shown for the primary,
  although file content can differ by branch.
- `diagram-generator`: 9 matching checkouts total (the primary plus
  `feat/108-registry-agent-prompting`, `feat/120-grid-track-alignment`,
  `docs/121-onboarding-cold-start`, `chore/eol-lf-normalization`,
  `diagram/generator-how-it-works-c4-continuation`, `main` in
  `onboarding-quickstart`, and detached `generator-how-it-works-c4` and
  `prodstack-cloud-images-flow-merge`). Each has the same three operational
  `.github/prompts/overnight.prompt.md` matches at lines 9,20,30 and the same
  historical archive match at line 121.
- `diagram-registry`: 6 matching checkouts total (the `main` primary plus
  `fix/analytics-pilot-observability`,
  `feat/selfhosted-analytics-continuity`, `docs/record-analytics-activation`,
  `work/mermaid-edge-label-review`, and `feat/share-succeeded-analytics`). All
  have `.workflow-kit.json` at line 2; the two analytics feature checkouts have
  the README match at line 52 and the other four at line 51.

Across all Git identities, 35 checkout trees matched: 33 active-consumer
checkouts, the kit producer, and the archived snapshot. The remaining 53
checkout trees had no tracked matches. After common-directory grouping, 12 of
52 Git identities matched (the ten active consumers, kit producer and archived
snapshot); all checkout trees belonging to the other 40 identities were clean
for the requested terms.

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
- The other 40 unique Git common directories had no current tracked matches in
  any of their discovered checkout trees for the requested terms.

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

The corrective linked-checkout pass separately captured SHA-256 before and
after a repeated read-only search for eight representative tracked files across
linked and detached checkouts. All eight hashes were identical (`changed=0`):

| Linked-checkout file | SHA-256 before and after |
|---|---|
| `baseline-foundry-worktrees/docs-demo-provenance-rules/bin/agent-loop` | `095349bf295e07590392fea59847567ec2ac59e78111459e7fef013eaca93f3a` |
| `baseline-foundry-worktrees/feat-028-shared-spacing-decisions/prompts/overnight.prompt.md` | `fa6984f476c6c78e9c053cc385b6d7c2b569b84d6526ed1bb0f488ff632467df` |
| `diagram-generator-worktrees/108-registry-agent-prompting/.github/prompts/overnight.prompt.md` | `dcf6bcb6526a4dfbcef7f4f005a19a8aed742111cc22b410f7a55209ae47bafc` |
| `diagram-generator-worktrees/generator-how-it-works-c4/.github/prompts/overnight.prompt.md` | `0b6bf61528d6eb3e3f942fe1674917c2c0e60bbd1fd271042054b46e245d13ad` |
| `diagram-registry-analytics-observability/.workflow-kit.json` | `905d23b78acb2220794abdd5a8e02dcbf725ebc23fd37d7391f0598a4ad20fae` |
| `diagram-registry-analytics-observability/README.md` | `1272ceb3fa981e47321e39978cc4b8d333c77c2a6089cc7cd4f8a59f93255271` |
| `diagram-registry-worktrees/share-succeeded-analytics/README.md` | `c3259b086c9a2dae16b40a324ede57e55a60cf589b41be335f6979e2c07465b8` |
| `temp/bf-028-opus-corrections-20261006/pinned-4954c6e/bin/agent-loop.cmd` | `2afec00e31ebc1a4862dcbb4bd4a86459431c59cbe8456599010e38c7cd88a75` |
