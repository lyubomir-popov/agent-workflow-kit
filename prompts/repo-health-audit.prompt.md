---
description: "Dual-perspective repo health audit (domain expert + software architect), persisted as a dated report with findings routed into TODO/ROADMAP."
mode: agent
model: claude-opus-4.7
---

# Repo health audit

## Workflow mode

Read `.workflow-kit.json` as JSON and inspect `workflowModelVersion`. If `.workflow-kit.json` is missing or `workflowModelVersion` is absent,
including when only `canonicalMirrorMode: external` is set, select legacy mode. Select spec-first mode only when `workflowModelVersion` is the JSON integer `1` or `2`;
do not coerce strings or other values. Stop if the JSON is
malformed, is not an object, or contains a present invalid or unsupported
version. Do not infer the mode from root files or placeholders. Execute only the
matching route below; versions 1 and 2 must not execute Legacy procedure.

## Version 1 route

Use `AGENTS.md`, `docs/specs.md`, the relevant package records, `README.md`, and actual source as audit inputs. Assess domain usefulness, architecture, and drift; report strengths and ranked next moves. Keep findings in the owning package and create a report only when requested and within its write scope.

## Version 2 route

Read `AGENTS.md`, `docs/specs.md`, the relevant package owners, README and
actual source. Assess domain usefulness, architecture and drift against the
accepted scope; report strengths and ranked next moves. Keep the audit read-only
unless persistence is requested within the owning package. Do not create a new
execution queue. For checkpoint findings, follow `prompts/review.prompt.md`,
including saved dispositions, the round limit and owner-only gate clearance.

## Legacy procedure

Produce a strategic, high-level health audit of the current repo as if you were seeing it for the first time, wearing **two hats simultaneously**:

1. **The domain expert** — the practitioner this tool exists to serve (e.g. horticulture professor, frontend architect, ML researcher, accountant, game designer). Infer the right domain from `README.md`, `STATUS.md`, `docs/specs.md`, and `docs/vision/` if present.
2. **The software architect** — looking at code structure, separation of concerns, test discipline, and architectural drift.

Focus on **high-level usefulness, vision alignment, and architectural drift**, not glitches or line-level bugs.


### Model ownership

Use the heavy tier for synthesis and the standard/light tier for mechanical
follow-up. Concrete preferences live in agent-loop.ps1's TierDispatchMap.
Read that owner when selecting models; do not copy a preference table here.

### Pre-flight

1. Read `STATUS.md`, `README.md`, `ROADMAP.md`, `TODO.md`, `HISTORY.md`, `docs/specs.md`, and any `docs/vision/*.md`.
2. Sample the actual code surface: list top-level source folders, count rule/module files, peek at the largest one.
3. Note the current test count if the repo declares tests (`npm test`, `pytest`, etc.). Do not run them — just count.
4. Check if there are sibling files under `docs/analyses/` (or equivalent). That folder is the right home for the report; create it if it doesn't exist.


### Audit

Produce a single comprehensive report with these sections:

1. **TL;DR** — three to five sentences. What state is the repo in? What is the single biggest drift?
2. **Domain-expert view** — what's genuinely useful (4–6 points), what's weaker than the implementation implies (3–5 points). Be specific. Name actual files, features, numbers.
3. **Software-architect view** — strengths (5–7 points), weaknesses / drift (4–6 points), healthy signals (bullet list).
4. **Drift table** — area | drift | severity (low / moderate / high). Include both vision-vs-implementation drift and within-codebase drift.
5. **Vision verdict** — is the vision good? What's strong about it? What would you push back on? One concrete suggested addition or principle.
6. **Recommended next moves, ranked** — 4–6 items, each one sentence of "what" and one sentence of "why this is the highest leverage". Tag each with the model tier (`[H]`, `[S]`, `[L]`) it should be done on.

Be willing to call out that the engine has outrun the data, that the vision overpromises in one specific place, that one folder needs splitting, that a recurring uncommitted file should be decided on. **Honest critique is the point.** Do not hedge.


### Persist the report

Write the full audit to `docs/analyses/YYYY-MM-DD-repo-health.md` (use the actual current date). If a report from today already exists, append `-v2` rather than overwrite.


### Route findings into the workflow

For each item in **Recommended next moves** and any concrete drift in the table:

- Add a corresponding entry to `TODO.md` with the right tier tag and priority. Cross-reference the report path so future sessions can trace rationale.
- If a recommended move is strategic enough to reshape the **Now / Next / Later** structure, also update `ROADMAP.md`. Add a short note at the top of `ROADMAP.md` pointing to the report.
- If the audit reveals stale items in `TODO.md` (already shipped, no longer relevant), remove them and note in `HISTORY.md` if they represent finished work.

Do not duplicate the report's content into `TODO.md`. The TODO entries should be **terse, actionable bullets** that link back to the report for context.


### Commit

Single commit at the end:

```
docs: add YYYY-MM-DD health report; route findings into TODO/ROADMAP
```

Use explicit `git add` paths (the report file, `TODO.md`, `ROADMAP.md`, and `HISTORY.md` if touched). Never `git add -A`. Push to `origin/main` (or the repo's default branch).


### Report back

Three-bullet summary in chat:
- where the report landed
- what changed in TODO/ROADMAP
- the single most important next move from the audit
