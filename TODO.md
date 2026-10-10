# TODO

## Purpose

This is the active execution queue for the workflow boilerplate repo.

## Maintaining this file

Only open items belong here. Git history and `HISTORY.md` are the record of completed work.

Use priority tags inline:

- `P1` - next important work
- `P2` - useful soon
- `P3` - later or opportunistic
- Every open item should also carry a routing tag: `[H]`, `[S]`, `[L]`, or `[X]` (see `.github/copilot-instructions.md` → "Model tier routing and subagent orchestration").

## Short-term

- [ ] [H] P1 Receive the [Spec 001 Opus specification review](specs/001-spec-first-workflow/reviews/2026-10-10-opus-spec-review-request.md) before planning or implementing the workflow renewal.

- [ ] [X] P2 Observe the stale-TODO warning across a few more real loop runs and tighten or relax the token matching if it proves noisy.
- [ ] [S] P2 Add lint rule: every `prompts/*.prompt.md` must declare a `model:` frontmatter field. Implemented as a warning in `workflow-kit.ps1` on 2026-04-29 — promote to `error` after one cycle if no false positives surface in downstream repos.
- [ ] [S] P3 Add `-Branch <name>` flag to `agent-loop.ps1` for repos that prefer PR workflow over direct commit. Optional follow-up: `-OpenPR` switch that runs `gh pr create` after the worker commit lands. Default behaviour (direct commit to current branch) stays unchanged.
- [ ] [S] P3 Add `-OnFailure skip|retry|stop` flag to `agent-loop.ps1`. Default `stop` (current behaviour). `skip` for queues with many independent items; `retry` for transient-failure scenarios only.

## Medium-term

*(empty — the bookkeeping-scope decision was resolved 2026-04-29; see ROADMAP "Resolved decisions".)*

## Long-term

*(empty — the two scheduler-design decisions were resolved 2026-04-29 and converted into the `[S] P3` flag-implementation items above.)*

## Open questions

- Optimal `--max-autopilot-continues` for real tasks (5 may be low for complex work).
