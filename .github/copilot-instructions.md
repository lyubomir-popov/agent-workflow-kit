# Workspace Instructions

## What this repo is

`agent-workflow-kit` is the central workflow blueprint for human plus agent coding sessions. It owns the canonical workflow file templates, reusable VS Code prompt files, and the `agent-loop.ps1` / `workflow-kit.ps1` automation scripts.

Key surfaces:

- Workflow files: `STATUS.md`, `TODO.md`, `ROADMAP.md`, `HISTORY.md`, `INBOX.md`, `AGENT-INBOX.md`, `docs/specs.md`
- Automation: `agent-loop.ps1`, `workflow-kit.ps1`, `install-vscode-prompts.ps1`, `bin/`
- Prompt source: `prompts/*.prompt.md`

## Documentation structure

| File | Role | Who writes |
|------|------|-----------|
| `.github/copilot-instructions.md` | Rules. Workflow rules, source precedence, planning rules. | Agent maintains |
| `.github/agents/agent.md` | Optional resume-agent prompt for repo-specific continuation. | Agent maintains |
| `README.md` | Overview. Repo summary and workflow map. | User + agent maintain |
| `ROADMAP.md` | Long-term. Product direction, stages, future ideas. | Agent updates rarely |
| `TODO.md` | Active plan. Current execution queue, principles, architecture notes. | Agent updates every session |
| `INBOX.md` | User inbox. Async user notes that should stay easy to scan. | User writes, agent drains |
| `AGENT-INBOX.md` | Agent inbox. Long machine-generated handoffs, cross-repo notes, and diagnostics awaiting triage. | Agents / automation write, agent drains |
| `STATUS.md` | Cold start. Repo orientation, current state, key files, invariants. | Agent updates when state changes |
| `HISTORY.md` | Archive. Completed work log. | Agent appends when tasks complete |
| `docs/specs.md` | Specs. Linked source docs, upstream references, and path summary. | Agent updates when source paths change |

No other files should carry duplicate TODO lists, handoff notes, or parallel status tracking. `AGENT-INBOX.md` is the only allowed repo-level overflow channel for machine-to-machine notes, and it must not become a second `TODO.md` or `STATUS.md`. Session scratch in Copilot memory is fine, but the repo itself should keep status in one place only.

## Instruction file scope

Use the two `.github` files for different layers of guidance:

- `.github/copilot-instructions.md` is the stable repo-wide contract. Put workflow rules, planning thresholds, validation expectations, precedence rules, repo boundaries, and instructions that should apply to every future session here.
- `.github/agents/agent.md` is optional and should stay short. Put only repo-specific resume guidance here: what to read first, which code or docs matter most, and any narrow continuation hints that help a fresh agent start quickly.
- If a detail stops being a short resume hint and becomes durable project state, move it into the canonical workflow files instead of expanding `.github/agents/agent.md`.

When deciding where extra detail belongs, use this map:

- Current state or cold-start notes: `STATUS.md`
- Active tasks or architecture notes: `TODO.md`
- Long-term direction: `ROADMAP.md`
- Completed work: `HISTORY.md`
- Source-of-truth references: `docs/specs.md`
- Human-readable overview: `README.md`
- Async user notes: `INBOX.md`
- Agent-to-agent handoffs or long diagnostics: `AGENT-INBOX.md`

## Source-of-truth precedence

When sources disagree, adapt precedence to the repo type. The rule is repo-type-aware: durable canonical artifacts beat interpretive planning docs.

Default docs/spec repo order:

1. Linked specs, upstream docs, or explicitly referenced source material
2. `ROADMAP.md`
3. `.github/copilot-instructions.md`
4. `STATUS.md` and `HISTORY.md`
5. `README.md` and `docs/specs.md`
6. `INBOX.md`
7. `AGENT-INBOX.md`
8. Local implementation details that are not clearly intentional or documented

Code/data repo order:

1. Canonical repo data, schemas, source code, committed assets, and tests that define current behavior
2. Linked specs, upstream docs, or explicitly referenced source material
3. `ROADMAP.md`
4. `.github/copilot-instructions.md`
5. `STATUS.md` and `HISTORY.md`
6. `README.md` and `docs/specs.md`
7. `INBOX.md`
8. `AGENT-INBOX.md`

Do not rewrite higher-priority docs to match lower-priority implementation drift.

## Token discipline

- Use `rg` and targeted file reads before opening large files.
- Avoid broad reads of generated output, build artifacts, dependency folders, caches, and large data directories unless the task specifically requires them.
- In downstream repos, replace this placeholder with exact heavy paths such as `dist/`, `build/`, `coverage/`, `.next/`, `outputs/`, `tmp/`, or large fixture/data folders.
- Keep permanent instructions short. Put one-off task detail in the current prompt, `TODO.md`, or `STATUS.md`.

## Planning threshold

- Small task: act directly.
- Medium task: write a short plan in `STATUS.md` before execution.
- Large, architectural, or cross-repo task: create or update a dedicated plan section before broad changes.

## History rules

- Record completed short-term items under a short-term section.
- Record completed long-term items under a long-term section.
- Move items to history only when actually complete.
- Do not use history as a backlog or scratchpad.
- When `HISTORY.md` exceeds ~200 lines, move older entries to `docs/archive/YYYY.md` and keep only recent entries in the root file.

### The inbox pattern

`INBOX.md` is the user write-only channel. `AGENT-INBOX.md` is the machine-generated handoff channel for long agent notes, automation diagnostics that need triage, and cross-repo follow-ups. At session start, the agent must:

1. Read `INBOX.md` and triage each item into `TODO.md` (near-term) or `ROADMAP.md` (longer-term).
2. Read `AGENT-INBOX.md` and triage durable facts into `TODO.md`, `ROADMAP.md`, `STATUS.md`, `HISTORY.md`, or `docs/specs.md`.
3. Empty both files back to their header templates.

### What goes where

| Information | Goes in |
|-------------|---------|
| What should the next chat do? | `TODO.md` |
| Why was an architectural decision made? | `TODO.md` |
| What does the product become long-term? | `ROADMAP.md` |
| What source documents govern this repo? | `docs/specs.md` |
| What has been completed? | `HISTORY.md` |
| Cold-start orientation and resume notes | `STATUS.md` |
| Async user notes | `INBOX.md` |
| Agent-generated handoffs or long machine notes | `AGENT-INBOX.md` |

## Agent workflow

### Session start

1. Read `STATUS.md` for orientation. If it looks stale or references work that is clearly finished, update it before proceeding — do not assume the previous session cleaned up.
2. Check `INBOX.md`, triage user items into plan or roadmap, then empty it.
3. Check `AGENT-INBOX.md`, triage machine notes into canonical files, then empty it.
4. Read `TODO.md` for current tasks.
5. Read `docs/specs.md` before changing spec-governed behavior.

### During work

- Mark tasks done in `TODO.md` as you complete them.
- Move completed items to `HISTORY.md`.

### Session end

1. Update `STATUS.md` if the current-state section is stale.
2. Update `TODO.md` with any new tasks that emerged.
3. Ensure `INBOX.md` is empty.
4. Ensure `AGENT-INBOX.md` is empty.
5. Do not create new markdown files to document status unless explicitly requested.

## Validation

Before committing, run validation to confirm nothing is broken.

### Full validation

Use before merging substantial changes or after broad workflow edits:

```bash
pwsh -NoLogo -NoProfile -File ./workflow-kit.ps1 -Command lint -RepoRoot . -Strict
pwsh -NoLogo -NoProfile -File ./agent-loop.ps1 -DryRun -RepoRoot .
```

### Targeted validation

Use during incremental work:

```bash
pwsh -NoLogo -NoProfile -File ./workflow-kit.ps1 -Command lint -RepoRoot .
```

If there are no automated checks, at minimum verify that the files you changed are syntactically valid and consistent with the rest of the repo.

## Agent environment rules

- Use VS Code integrated terminals the user can monitor — not background processes or external terminal windows.
- Prefer reusing a small number of foreground integrated terminals the user can actually inspect. Do not spawn dozens of throwaway shells for small checks.
- Keep track of the terminals you start. If one hangs, times out, or is no longer needed, close it before finishing the task.
- When using Playwright or browser automation, use Chrome, not Edge.

## Repo boundary

- Work in this repo only unless the user explicitly redirects elsewhere.
- If sibling repos are used as references, list them in `docs/specs.md` or `STATUS.md`.

## Commit message discipline

Use a short area prefix such as `docs:`, `workflow:`, `build:`, `types:`, `test:`, or a repo-specific equivalent. Keep the first line under 72 characters.

## Autonomous continuation rule

If the user explicitly says to proceed autonomously, treat that as standing approval to keep executing the best available plan without pausing for small confirmations.

In that mode:

1. Work through the current plan until you hit a real blocker, not a minor ambiguity.
2. Make small validated checkpoint commits after substantive chunks if commits are allowed.
3. Re-read `TODO.md` after major chunks and periodically re-audit alignment.
4. Update the canonical docs as work lands so the next chat can continue cold.
5. Do not stop just to ask whether to continue unless the next best move is genuinely unclear or risky.

### Maximising autonomous run length

Current LLM agents lose coherence after extended autonomous runs because context fills up. To get the longest useful runs:

- **Narrow the scope per burst.** "Complete all items in TODO.md section X" works better than open-ended "work through the roadmap."
- **Checkpoint and resume.** After each substantive chunk, commit + update STATUS + update TODO so a fresh session can continue cold. A shell loop or CI job can restart the agent automatically.
- **Keep TODO items small.** Each item should be completable in one focused burst. If an item needs decomposition, break it down before starting the autonomous run.
- **Prefer sequential single-repo sessions** over multi-repo autonomous runs. Cross-repo context bloats fast and causes mistakes.

User-level VS Code prompt files provide shortcuts for common workflows: `/whats-next` (session start + triage), `/overnight` (preferred shortcut for launching the autonomous `agent-loop.ps1` scheduler), `/audit-workflow` (check all workflow files for drift), `/run-validation` (run declared validation commands), and `/freshen-status` (refresh `STATUS.md` from actual repo state). `/proceed-autonomously` may remain installed as a legacy alias. Canonical prompt definitions should live in this repo under `prompts/` and be installed into the VS Code user prompt directory via `install-vscode-prompts.ps1`.

## Model tier routing and subagent orchestration

Different parts of a session need different model classes. Don't burn premium reasoning on text shuffling, and don't hand architectural decisions to a small model. Tag every open `TODO.md` item with one of these tiers so any agent picking up the queue routes the work to the right place.

| Tag | Tier | Models | Use for |
|---|---|---|---|
| `[H]` | Heavy | Claude Opus 4.7, GPT-5 | Cross-file refactors, invariant-bearing changes, naming translations from external sources, architectural decisions, picking the next batch of work. |
| `[S]` | Standard | Claude Sonnet 4.5, GPT-5 mini | Single-component additions following an established pattern, demo-page authoring, contained code swaps. |
| `[L]` | Light | Haiku, Gemini Flash, GPT-5 nano | ROADMAP/STATUS/HISTORY housekeeping, INBOX triage, commit-message edits, dependency bumps, lint-rule tweaks. |
| `[X]` | Subagent / no model | `Explore` subagent, validation commands, Playwright runs | Read-only research, validation, visual regression. Just runs and reports pass/fail. |

Routing rule of thumb:

- "Matches an existing pattern + passes the build invariants" → `[S]`.
- "Reads N files and decides what shape the new thing should be" → `[H]`.
- "Moves text from file A to file B" → `[L]`.
- "Just runs and reports pass/fail" → `[X]`.

### Orchestrator vs subagent execution

A Heavy session should act as an orchestrator: plan, sequence, dispatch, and validate. Bounded mechanical work belongs in a subagent so the orchestrator's context stays focused on decisions.

When a Heavy session is running, it can dispatch:

- The `Explore` subagent for read-only research that would otherwise burn many tool calls (find all call sites, summarize a sibling repo's structure, locate an exact pattern).
- A per-repo `agent` subagent for any `[L]` task and any small `[S]` task whose recipe is fully written down (in `TODO.md`, `AGENT-INBOX.md`, or a referenced doc).

Rules for the orchestrator:

1. Don't have a Heavy session do `[L]` work directly. Dispatch instead.
2. Each subagent invocation is stateless. Its prompt must contain everything it needs: the goal, the recipe, validation steps, and exactly what to report back.
3. Subagents return one report. Plan dependent subagent calls sequentially; run independent ones in parallel.
4. After a subagent returns, the orchestrator validates the result against the original intent before accepting it. Don't blindly trust unfamiliar diffs.
5. `[H]` work stays on the orchestrator thread. Do not delegate architectural decisions to a subagent.

When a session starts on a Standard or Light model, it executes its assigned tier directly and escalates back to the user if a task it picks up is actually `[H]`. It does not dispatch its own subagents.

### Concrete model preferences

These are the user's standing model preferences. Apply them when picking a model in any session, when configuring `agent-loop.ps1 -UseTierDispatch`, and when reading the dispatch label in dry-run output. They override generic "use the heavy model" defaults.

| Tier | Preferred model | Fallback if preferred not available | Cost class |
|------|-----------------|-------------------------------------|------------|
| `[H]` | `claude-opus-4.7` or `gpt-5.5` | `gpt-5.4` with `--effort xhigh` | 7.5x (preferred) → 1x+ (fallback) |
| `[S]` | `gpt-5.4` (with `--effort high` for nontrivial work) | `gpt-5.2` | 1x |
| `[L]` | `gpt-5.4-mini` or `claude-haiku-4.5` | either is fine | 0.33x |
| `[X]` | n/a — runs as a subagent or validation command, not a Copilot CLI invocation | n/a | 0x |

Hard rules:

- **Do not use older-generation 1x-multiplier models** (`claude-opus-4.5`, `claude-sonnet-4.5`, `claude-sonnet-4.6`, `gpt-4.1`, `gpt-4o`). They cost the same as `gpt-5.4` but are measurably weaker. The only acceptable Claude models in the standing preference are `claude-opus-4.7` (heavy) and `claude-haiku-4.5` (light).
- **Reserve the 7.5x premium tier (`claude-opus-4.7` / `gpt-5.5`) for genuinely heavy work**: cross-file refactors, invariant-bearing changes, architectural decisions, planning the next batch, code review.
- **Use `gpt-5.4` for almost everything else** that the orchestrator does not handle directly: standard component swaps, demo-page authoring, contained code changes, recipe-following work.
- **Use the 0.33x tier (`gpt-5.4-mini` / `claude-haiku-4.5`) for truly trivial work**: ROADMAP/STATUS/HISTORY housekeeping, INBOX triage, commit-message edits, dependency bumps, lint-rule tweaks.
- The Copilot CLI's available model IDs lag the VS Code Copilot Chat dropdown. As of 2026-04-28 the CLI does not yet expose `claude-opus-4.7` or `gpt-5.5`; until it does, `agent-loop.ps1` falls back to `gpt-5.4 --effort xhigh` for `[H]`. When the preferred IDs appear (probe with `copilot --model <id> -p x --no-ask-user`), update `TierDispatchMap` in `agent-loop.ps1` to use them.
- Reasoning effort: GPT-5 family supports `--effort low|medium|high|xhigh`; Claude family rejects `--effort` and the loop must omit it for those models.

## Cross-repo coordination

When work in one repo creates a dependency or follow-up in another:

1. Drop a machine-generated note in the **target repo's** `AGENT-INBOX.md` describing what changed and what the target repo needs to do. Reserve `INBOX.md` for user-authored notes.
2. Do not attempt the cross-repo change in the same session unless the user explicitly redirects there.
3. Use one agent per repo for feature work. Use one agent across repos only for mirroring convention changes or small coordinated edits.
4. For larger features, prefer sequential single-repo sessions with INBOX handoffs over one agent trying to hold multi-repo context.

## How to use this boilerplate in a new repo

1. Copy these files into the new repo root.
2. Keep the file names unchanged.
3. Replace repo-specific text such as `agent-workflow-kit` and any remaining placeholders such as `<upstream-spec>`.
4. Delete any old handoff, todo, or inbox files that would duplicate this structure.
5. Update `README.md`, `STATUS.md`, and `docs/specs.md` first so the repo can be resumed cleanly.
6. Run `workflow-kit lint` or `pwsh -NoLogo -NoProfile -File <path-to-agent-workflow-kit>/workflow-kit.ps1 -Command lint -RepoRoot .` and fix any findings.

## Agent file roles

- `.github/copilot-instructions.md` is the single repo-wide instruction file.
- `.github/agents/agent.md` is optional and should contain only repo-specific resume or subagent guidance.
- `.github/agents/agent.md` should not become a second `STATUS.md`, `TODO.md`, or `README.md`; when details grow beyond a short resume prompt, move them into the canonical file for that kind of information.
- Do not duplicate the full workflow rules in both places.

The key rule: every piece of status information should live in exactly one place.
