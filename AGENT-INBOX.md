# Agent Inbox

Machine-generated handoffs, long diagnostics, and cross-repo follow-up notes go here.

Do not use this file for user notes. User-authored async notes belong in `INBOX.md`.

The agent should triage anything durable from this file into `TODO.md`, `ROADMAP.md`, `STATUS.md`, `HISTORY.md`, or `docs/specs.md`, then empty this file back to this header template.

---

## 2026-05-21 – Anti-patch protocol proposed for boilerplate (from diagram-generator)

The `diagram-generator` repo now has an "Anti-Patch Protocol" section in its `.github/copilot-instructions.md` that prevents agents from stacking local fixes without classifying requests or checking layer ownership. The pattern is general enough to upstream into the boilerplate template:

1. **Classify before coding** — taxonomy: contract change, configuration, bug, feature, one-off
2. **Patch smell test** — 5 yes/no questions; any "yes" means stop and redesign
3. **Layer ownership map** — which file owns which concept (per-repo)
4. **Flag mechanism** — structured report when patching is detected
5. **After implementing** — run all existing artifacts through the engine, not just the triggering one

Consider adding a "Change Discipline" section to the boilerplate `copilot-instructions.md` template with the classify + smell-test + flag pattern. Repos with layered engines (like `a4-generator`, `baseline-foundry`) would also benefit from declaring a layer-ownership map.

2026-05-07 - Cross-repo follow-up from `lightning-talks`

User preference / possible workflow convention to evaluate upstream:

- keep `agent-workflow-kit`-derived canonical workflow files visually distinct from local repo-specific markdown files
- possible direction: uppercase plus ordered naming for kit-owned workflow files, and lowercase plus ordered naming for local non-kit docs
- main user need is read order clarity for cold starts; alphabetical ordering is causing confusion

No change requested in this session. This is a durable follow-up idea for the workflow-kit repo, not an active lightning-talk content task.