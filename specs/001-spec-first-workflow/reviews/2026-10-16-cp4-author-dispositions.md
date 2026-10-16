# CP4 author dispositions

Scope: `001/spec-r2`. Findings: [received Cline review](2026-10-16-cp4-adversarial-review.md), actual model unattested.
Correction revision: `27f452cadba3b93c689714164d16136f8b934588`; [final validation](../evidence/slice-c-validation.md).
These are implementer dispositions, not checkpoint acceptance or a new review round.

| Finding | Disposition and evidence |
|---|---|
| CP4-M1 | Fixed: restore the pre-adoption legacy overnight SpecKit body, operations safeguards and overrides; Todo stays explicit opt-in, including the alias. Correct the plan. Migration: “keeps the compatibility commands explicit and leaves installation separate”. |
| CP4-M2 | Fixed: nest every legacy subsection; explicit shared orchestration/audit procedures and sync safety precede mode selection. Migration: prompt source contracts and shared orchestration/audit cases inspect all 13 sources. |
| CP4-M3 | Fixed: the same migration blockers run before activation; legacy lint's retired-file requirements no longer determine readiness. Migration: pre-activation blockers in both modes and retired-files-absent cases. |
| CP4-m1 | Fixed: cover every disposition action, resume agent, tracked cursor, prompt/script routes, missing destination and Git failure. Migration: inventory and blocker/CLI cases. |
| CP4-m2 | Accepted limitation, documented: word/function-name sentinels are mechanical hints, not semantic compatibility proof; external-kit routes are not inspected. Preview emits migration-mechanical-limit; README and final evidence explain the boundary. |
| CP4-m3 | Fixed in the shared preservation reader: explicitly decode Git NUL records as UTF-8 without changing console encoding. Migration inventory and Preservation's non-UTF8 case verify exact Unicode tracked/untracked paths, preservation and encoding restoration under IBM437. The final suite also covers Closeout/Scheduler callers. |
| CP4-m4 | Fixed: strip ANSI before unwrapping diagnostics, retain Raw JSON and exit-code checks, and assert stable guard fragments. Migration: CLI guards and coloured narrow-console continuation regression. |
| CP4-m5 | Fixed record ownership: restore T053's explicit 400-line budget, T054's obligations and T055's measurement/overrun clauses; retain local T056 evidence and assign CI to open T059, post-install placeholder removal to open T060. |

Tracked scratch decision: preserve `tmp/hello.txt` and `tmp/world.txt` unchanged as
tracked historical sample artifacts. They are not an execution queue or disposable
cleanup target. Any later retirement is separately scoped; this correction neither
deletes nor silently ignores them.

No findings are rejected. T059/T060 retain their conditional delivery obligations;
the existing BQA-06 owner/provider decision and Linux/remote CI gap remain.
