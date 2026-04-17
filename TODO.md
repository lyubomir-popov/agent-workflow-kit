# TODO

## Purpose

This is the active execution queue for the workflow boilerplate repo.

## Active TODO

- [ ] Mirror Stage 2 refinements to active repos (baseline-foundry, brand-layout-ops, canonical-spacing-spec). Each repo's `.github/copilot-instructions.md` should be updated to match the boilerplate.
- [ ] Design a cleaner agent-to-agent communication channel — current INBOX.md mixing user notes with long agent exchanges buries user content. Consider a separate `AGENT-INBOX.md` or a `tmp/agent-exchanges/` folder.

## Open questions

- Optimal `--max-autopilot-continues` for real tasks (5 may be low for complex work).
- Should the loop run on a branch and PR, or commit directly to master?
- How to handle loop failures: retry once, skip, or stop?