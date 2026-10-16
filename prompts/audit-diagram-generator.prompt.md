---
description: "Read-only diagram-generator repo audit: health, staleness, architectural drift, Python legacy traces, and duplicate sources of truth."
mode: agent
model: claude-opus-4.7
---

# diagram-generator repo audit

## Workflow mode

Read `.workflow-kit.json` as JSON and inspect `workflowModelVersion`. If `.workflow-kit.json` is missing or `workflowModelVersion` is absent,
including when only `canonicalMirrorMode: external` is set, select legacy mode. Select spec-first mode only when `workflowModelVersion` is the JSON integer `1`;
do not coerce strings or other values. Stop if the JSON is
malformed, is not an object, or contains a present invalid or unsupported
version. Do not infer the mode from root files or placeholders. Execute only the
matching route below; version 1 must not execute Legacy procedure.

## Version 1 route

Read `AGENTS.md`, `docs/specs.md`, and the active package owners before auditing. Compare the frame-YAML to TypeScript to editable-SVG direction with the implementation, including Python legacy traces, force layout, and duplicate sources of truth. Use current product and architecture sources; keep the audit read-only unless asked to persist it, and route any report through the owning package.

## Legacy procedure

Perform a **read-only** audit of the **diagram-generator** repo (the workspace must be that repo, or a multi-root workspace that includes it). Another agent or human may be working in parallel — do **not** modify, commit, or fix anything unless the user explicitly asks you to persist the report.


### Intended architecture (benchmark)

The user's mental model for this repo:

1. Take a reference image or verbal description.
2. Convert content to **frame YAML** (`scripts/diagrams/frames/*.yaml`).
3. Use **TypeScript only** (`packages/layout-engine/`) to generate an **editable SVG** in the browser editor.
4. Python is narrowing to preview hosting, YAML save helpers, and transitional parity — **not** new layout or render features.

Audit against this benchmark and against `.github/copilot-instructions.md` (TS-first mandate).


### Model ownership

Use the heavy tier for synthesis and the standard/light tier for mechanical
follow-up. Concrete preferences live in agent-loop.ps1's TierDispatchMap.
Read that owner when selecting models; do not copy a preference table here.

### Pre-flight

1. Read `README.md`, `STATUS.md`, `TODO.md`, `HISTORY.md`, `docs/specs.md`, `DIAGRAM.md`, and any `docs/architecture*` material.
2. Map languages and packages: `packages/layout-engine/`, `scripts/preview/`, `scripts/*.py`, `specs/`.
3. Note git dirtiness and in-flight work from another session — flag it, don't fix it.
4. Check force-layout state: `scripts/preview/force.js`, `preview_server.py` force routes, `scripts/diagrams/force/`, `force_preview.py`, `force_layout.py`.


### Audit questions (answer all)

1. **Repo health** — maintainability, tests, build hygiene, doc freshness.
2. **Staleness** — abandoned scripts, docs contradicting code, orphaned routes.
3. **Architectural drift** — YAML→TS→SVG vision vs implementation; patch-on-patch areas.
4. **Python legacy traces** — where does Python still own layout, render, or APIs that TS should own?
5. **Double work** — Python + TS parity maintenance; intentional migration vs permanent burden.
6. **Duplicate sources of truth** — JSON sidecars, localStorage, prebuilt SVGs, draw.io exports vs YAML.
7. **Force layout** — Is the force editor lane working? What examples existed? What must be restored in **TypeScript** (not Python)?


### Report structure

1. **TL;DR** — three to five sentences; single biggest concern.
2. **Priority: restore force layout (TypeScript)** — dedicated section: current breakage, lost examples, required TS path, how to surface demos again.
3. **Intended vs actual architecture** — narrative + mermaid flow if helpful.
4. **Legacy & double-work inventory** — table: location | what it does | still needed? | severity.
5. **Sources of truth** — canonical vs derived; conflict risks.
6. **Staleness & doc drift** — specific files.
7. **Strengths**
8. **Recommended next moves** — ranked, tagged `[H]` / `[S]` / `[L]` / `[X]`.

Be specific: name files, folders, line counts where useful. Honest critique is the point.


### Persist (when user asks)

Write the full report to `docs/architecture/repo-health-audit-YYYY-MM-DD.md` (use the actual date). Do not route into `TODO.md` unless the user asks.


### Constraints

- **Read-only** by default. No commits unless explicitly requested.
- Do not run mutating validation unless the user asks.
