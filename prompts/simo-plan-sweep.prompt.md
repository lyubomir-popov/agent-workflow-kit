---
description: "Refine an existing plan into safe implementation phases with validation, commit checkpoints, and review sweeps."
mode: agent
model: gpt-5.4
---

# plan-sweep

## Workflow mode

Read `.workflow-kit.json` as JSON and inspect `workflowModelVersion`. If `.workflow-kit.json` is missing or `workflowModelVersion` is absent,
including when only `canonicalMirrorMode: external` is set, select legacy mode. Select spec-first mode only when `workflowModelVersion` is the JSON integer `1`;
do not coerce strings or other values. Stop if the JSON is
malformed, is not an object, or contains a present invalid or unsupported
version. Do not infer the mode from root files or placeholders. Execute only the
matching route below; version 1 must not execute Legacy procedure.

## Version 1 route

Resolve the plan's `AGENTS.md`, catalog entry, and package owners first. Improve the plan's phases, edge-case handling, validation, review, and commit checkpoints while remaining in planning mode. Keep edits within authorized package scope and route durable findings to package records.

## Legacy procedure

Take the existing plan from the current chat context and turn it into a tighter execution plan document.

This prompt is for the period after planning has started but before implementation begins. Stay in planning mode. Do not implement, edit files other than the plan and checklist, commit, or push. Do not delete or modify the existing plan document.

Goal:
- Review the plan for gaps and common pitfalls such as inadequate error handling or propagation, race conditions, edge cases not being handled, breakage of unrelated code paths, failing to update code paths unrelated to the feature being implemented but dependent on changes being made. If any are found, fix the plan and review again, subject to the same requirements, repeating the cycle no more that 5 times.
- Break the work into a reasonable number of phases, usually no more than about 6 unless the scope clearly requires more.
- Make each phase able to stand on its own, be testable, and avoid leaving the system in a broken or half-integrated state.
- Build verification and review directly into the plan instead of treating them as optional cleanup.
- Two more documents should be produced (in addition to the revised plan document): a detailed implementation checklist and a detailed implementation sketch of the low-level changes to be made.
- Two more documents should be produced (in addition to the revised plan document): Each must include the Commit policy block and per-phase commit messages (checklist as checkboxes; sketch with a `## Commits` section mirroring phases).

For each phase, include:
- What changes belong in the phase and why this boundary is safe.
- The narrowest tests or validation steps that should run before considering the phase done.
- - A **required** local commit checkpoint (user has already authorized commits for this plan): after validation passes, `git add` only this phase’s changes and `git commit` with the message below. Do not push. If the user invoked "execute the plan", run this commit without asking again.
- A deeper sweep after the phase implementation and initial validation, specifically looking for gaps, edge cases, missed integration points, regressions, or mismatches across layers.
- Any open questions, assumptions, or prerequisites that could block safe execution.
- Explicit instruction to call a sub-agent — running the same llm model and thinking effort as the main running agent — to critically review the phase with fresh eyes and from new angles so issues are called out and handled, specifically looking for: high-level logic and intended behavior that seem off or can be improved, inadequate error handling or propagation, race conditions, edge cases not being handled, breakage of unrelated code paths, failing to update code paths unrelated to the feature being implemented but dependent on changes being made.

After the phases, include a final full-plan sweep that:
- reviews the complete implemented work from fresh angles
- again, instruction to call a sub-agent — running the same llm model and thinking effort as the main running agent — to critically review the phase with fresh eyes and from new angles, looking for inconsistencies, inadequate error handling or propagation, race conditions, edge cases not being handled, breakage of unrelated code paths, failing to update code paths unrelated to the feature being implemented but dependent on changes being made.
- checks for cross-phase gaps, regressions, inconsistencies, or missing cleanup
- calls out anything that still needs to be fixed before the work is truly done
- states that any issues found in that sweep should be addressed and revalidated before considering the plan complete

Finally, a **Finalizing** step that:
- creates `*-execution-summary.md`
- commits that file plus all `*-execution.md`, `*-checklist.md`, `*-sketch.md` (and any other planning artifacts for this feature) in one commit with a clear `docs(...)` message
- states again that this commit is part of the authorized plan (local only; no push)

Planning rules:
- Prefer the smallest sequence of independently safe phases over broad milestone labels.
- Do not force equal-sized phases; combine or split work based on risk, validation boundaries, and integration safety.
- If the current plan is too vague to phase responsibly, ask the user the minimum focused questions needed before finalizing the phased plan.
- If there are meaningful risks, dependencies, or unknowns, surface them explicitly rather than hiding them inside a phase.
- Keep the plan actionable and concrete, not aspirational.

### Commit policy (required in every execution plan)

The execution plan, checklist, and sketch must all state:

> **Commit authorization:** Implementing this execution plan (including when the user says "execute the plan", "implement", "ship it", or runs a phased implementation from this doc) **explicitly requests** creating the local git commits listed in each phase and in Finalizing. Do not treat phase commit checkpoints as optional. Do not push unless the user separately asks to push.

When producing `*-execution.md`, `*-checklist.md`, and `*-sketch.md`, include that block under a `## Commit policy` heading near the top.

Output format:
- Start with a short assessment of the current plan's main risk areas or unclear edges.
- Then provide a numbered phase list.
- For each phase, include: objective, scope, validation, **commit checkpoint (required; authorized)**, deeper sweep, and open questions or risks.
- End with a final full-plan sweep section and a short list of any questions that should be answered before implementation starts, as well as **Finalizing (required commits)** and the Commit policy reminder.

If the user supplied extra text with the slash command, treat it as additional shaping guidance for the phased plan.
