---
description: "Run a deep post-change sweep from fresh angles, dispatching multiple parallel reviewers and reporting findings."
mode: agent
model: claude-opus-4.7
---

# sweep

## Retired root-state guard

Before this legacy procedure, read the repository's AGENTS.md. If STATUS.md,
TODO.md, or HISTORY.md is a 2–3 line retirement placeholder pointing to
`docs/specs.md`, stop the legacy procedure and follow AGENTS/catalog/package
owners instead. Never recreate or expand retired files, drain unread handoffs,
write feature handovers into instructions, or bypass an owner checkpoint.
Full shared dual-mode conversion and installation remain a later authorized step.

Perform a broader and deeper post-change sweep over the latest task done in the current workspace.
Not linting and testing (these are still called for if you find issues and make changes), but real deep analysis of logic, edge cases, etc.
Take your time, deep think and analyze.

What to do: call five sub-agents in parallel — all running the same llm model and thinking effort as the main running agent — to critically review the work done with fresh eyes and from new angles so issues are called out and handled, specifically looking for: high-level logic and intended behavior that seem off or can be improved, inadequate error handling or propagation, race conditions, edge cases not being handled, breakage of unrelated code paths, failing to update code paths unrelated to the feature being implemented but dependent on changes being made. Focus areas of the sub-agents:
- one sub-agent with a focus on low level details, edge cases and race conditions;
- another - focus on higher level logic, workflow and use cases;
- the third - focus on end-to-end coherence;
- the fourth - focus on making sure all possible errors are handled gracefully and propagate properly rather than being swallowed;
- finally, the fifth - carefully analyze whether the changes made don't break unrelated code paths or whether they necessitate changes to unrelated code paths to make everything sound and coherent.

Do not blindly trust their findings - verify the claims with fresh eyes; make sure you don't reject valid concerns: analyze their reviews and use your best judgement to implement any needed changes. Finally, if you've made any changes, commit them.

General guidance for the sub-agents follows.
For all sub-agents, use the same llm model and thinking effort as the main running agent.
Use the current chat context, changed files, recent commits, and relevant tests, linters, type checks, builds, or repo-specific validation commands to look for:
- gaps, omissions, and edge cases in the implemented behavior
- regressions in nearby or seemingly unrelated code paths
- mismatches across UI, backend, stored data, routing, integration boundaries, and validation layers
- places where the change only appears correct from one narrow angle
- missing validation, missing tests, fragile assumptions, or unsafe commit boundaries

Approach:
- Start from the concrete changed files, failing behavior, or recent commit diff, then inspect the controlling code paths most likely to hide remaining defects.
- Re-check the work from fresh angles such as data-shape integrity, control flow, tenant or org awareness, storage splits, caching, key stability, validation coverage, error handling, and user-visible behavior.
- Prefer executable validation over inspection alone. Run the narrowest relevant checks first, then broaden to nearby or repo-level checks when that increases confidence.
- Do not change unrelated code. Do not revert user changes. Do not commit. Do not push.
- If you find issues, fix them, validate them, and report findings first with concrete file references and any residual risks.
- If no issues remain, return findings-only output summarizing that no blocking issues were found, what you validated, and any unrelated warnings or pre-existing issues.

Output requirements:
- Findings first, ordered by severity, with concrete file references when applicable.
- If no findings remain, state that explicitly, list the validations run, note any unrelated warnings or pre-existing issues, and state that no commit was created.

If the user supplied extra text with the slash command, treat it as additional scope and focus guidance or instructions. If not, choose the best fresh angles yourself.
