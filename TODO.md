# TODO

## Purpose

This is the active execution queue for the workflow boilerplate repo.

## Active TODO

- [ ] Mirror Stage 2 refinements to active repos (baseline-foundry, brand-layout-ops, canonical-spacing-spec). The boilerplate now contains: history rotation, validation gate, session-start resilience, autonomous-continuation tips, cross-repo coordination, and updated specs.md/README templates. Each active repo's `.github/copilot-instructions.md` should be updated to match.

## Completed (move to HISTORY.md)

- [x] Implement HISTORY.md rotation rule (~200 line ceiling → `docs/archive/YYYY.md`).
- [x] Update `docs/specs.md` template with optional-spec wording.
- [x] Add `## Validation` section to `copilot-instructions.md`.
- [x] Make session-start audit stale STATUS from prior sessions.
- [x] Restructure README to put `.github` convention in quick-start.
- [x] Add `## Cross-repo coordination` section.
- [x] Add `### Maximising autonomous run length` guidance.

## Open questions

- Research: is there a reliable way to chain autonomous agent sessions overnight? Current best approach is checkpoint-and-resume via shell loop or CI. No established best practice yet — see ROADMAP.