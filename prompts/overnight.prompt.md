---
description: "Select the repository scheduler by workflow version; versioned runs stop at manual review and owner gates."
mode: agent
model: gpt-5.4-mini
---

# Overnight run (spec-kit)

## Workflow mode

Read `.workflow-kit.json` as JSON and inspect `workflowModelVersion`. If `.workflow-kit.json` is missing or `workflowModelVersion` is absent,
including when only `canonicalMirrorMode: external` is set, select legacy mode. Select spec-first mode only when `workflowModelVersion` is the JSON integer `1`;
do not coerce strings or other values. Stop if the JSON is
malformed, is not an object, or contains a present invalid or unsupported
version. Do not infer the mode from root files or placeholders. Execute only the
matching route below; version 1 must not execute Legacy procedure.


## Version 1 route

Read `AGENTS.md` and `docs/specs.md`, then inspect one active package's
`spec.md` and `tasks.md`. Confirm there is an authorized unchecked implementation task. Only active
packages with cleared entry gates are unattended implementation candidates. Review its declared branch and task gate.

Run a read-only preview first:

```powershell
pwsh -NoLogo -NoProfile -File "<path-to-agent-workflow-kit>/agent-loop.ps1" -Workflow SpecKit -RepoRoot . -MaxSpecs 1 -MaxTasks 1 -OnFailure stop -DryRun
```

When the user has authorized a live run, use their bounded SpecKit scope.
This example allows one worker invocation for that package:

```powershell
pwsh -NoLogo -NoProfile -File "<path-to-agent-workflow-kit>/agent-loop.ps1" -Workflow SpecKit -RepoRoot . -MaxSpecs 1 -MaxTasks 1 -OnFailure stop
```

The example defaults to one invocation. Honor explicitly authorized user bounds
for `-MaxTasks` and `-MaxSpecs`, keeping execution within the approved phase.
Stop at the authorized bound. Required reviews and owner
dispositions are handled manually; do not launch automatic adversarial review,
address rounds, or advance to another package. Authorization to continue never
clears a checkpoint or task gate.

## Legacy procedure

For an absent `workflowModelVersion`, use the legacy TODO scheduler only. Resolve `agent-loop.ps1` and run its legacy dry run before launch:

```powershell
pwsh -NoLogo -NoProfile -File "<path-to-agent-workflow-kit>/agent-loop.ps1" -Workflow Todo -RepoRoot . -DryRun
pwsh -NoLogo -NoProfile -File "<path-to-agent-workflow-kit>/agent-loop.ps1" -Workflow Todo -RepoRoot . -MaxTasks 3
```

Honor the repository's existing TODO queue and stop on its legacy blockers. Never select this route when version `1` is configured.
