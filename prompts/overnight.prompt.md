---
description: "Preview or execute a bounded Python scheduler run for explicit packages."
agent: agent
---

# Overnight run

## Workflow routing

Read `.workflow-kit.json` as JSON before using the procedure below.

- JSON integer `2`: use the Python workflow procedure.
- JSON integer `1`: use the same Python procedure and run
  `wfk lint --repo . --json`; report its named ignored-v1-field diagnostics
  and do not assume ignored scheduler or workflow fields are active.
- Missing file or missing `workflowModelVersion`: run only the adoption preview
  `wfk init --repo . --json`, report its manual checklist, and wait for
  authorized adoption.
- Malformed JSON, a non-object root, a non-integer version, or an unsupported
  version: fail closed and report the configuration error.

Do not reconstruct retired commands or TODO scheduling. If old behavior is
still required, use a separate kit checkout pinned to `v1-powershell`; the tag
alone does not repoint a shared consumer.

## Procedure

Read `AGENTS.md`, the catalog and each selected package's owners. Require the
user to name the package or derive it unambiguously from their authorized scope;
never sweep every active package implicitly.

Preview first without invoking a worker or authentication probe:

```console
wfk run --repo . --package <catalog-package> --agents <ordered-profiles> --json
```

Report packages, gates, tasks, limits, worker profiles and stops. Do not launch
when the user requested only a preview. For an authorized execution, use the same
explicit package selection and finite limits, then add `--apply`:

```console
wfk run --repo . --package <catalog-package> --agents <ordered-profiles> --max-tasks 1 --max-hours 8 --task-timeout 1800 --apply --json
```

Authentication probes fail closed. Stop on missing tools, malformed probe output,
timeouts or unauthenticated status; do not loop on login. Ordered fallback is
used only for a clean quota outcome. Other task failures stop that package, and
authentication or interruption stops the run.

Worker permission flags do not authorize new files, repositories, reviews,
publishing or checkpoint clearance. Add `--review --review-checkpoint <CP>`
only when the review phase is explicitly authorized. Reviews must be saved under
the package, and no checkpoint gets more than two rounds before an owner
decision.

Return the printed report path, each outcome, commits, retained worktrees and
recovery refs. Do not delete retained evidence or stale leases without inspection.
