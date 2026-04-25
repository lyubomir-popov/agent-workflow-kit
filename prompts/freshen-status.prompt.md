---
description: "Refresh STATUS.md by checking the actual repo state and current workflow files."
mode: agent
---

# Freshen status

Refresh `STATUS.md` from actual repo state.

1. Read `.github/copilot-instructions.md`, `STATUS.md`, `TODO.md`, `HISTORY.md`, and `docs/specs.md`.
2. Check the current git status, key file list, active TODO queue, and declared validation commands.
3. If the repo has a build, test, metrics, or validation command under `## Validation`, run the targeted command unless it is clearly expensive or destructive.
4. Update `STATUS.md` so it accurately reflects:
   - what the repo is
   - current state
   - current execution plan
   - key files
   - critical invariants
   - what the next session should do

Keep `STATUS.md` concise. Do not move active tasks into status; put those in `TODO.md`.
