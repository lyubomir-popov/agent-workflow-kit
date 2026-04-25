---
description: "Audit all workflow markdown files for consistency, staleness, and drift."
mode: agent
---

# Audit workflow files

Check these files for consistency and staleness:

1. **STATUS.md** - Does the current-state summary match reality? Are key file paths still accurate?
2. **TODO.md** - Are completed items still in the active section? Should any be moved to HISTORY?
3. **INBOX.md** - Is it empty? If not, triage items now.
4. **AGENT-INBOX.md** - Is it empty? If not, triage machine notes now.
5. **ROADMAP.md** - Does it still reflect the actual long-term direction?
6. **HISTORY.md** - Is it under ~200 lines? If over, move older entries to `docs/archive/YYYY.md`.
7. **docs/specs.md** - Are linked spec paths still valid?
8. **README.md** - Does the workflow map match the actual file set and command list?
9. **.github/copilot-instructions.md** - Is the documentation structure table accurate?
10. **prompts/** - Are all prompt files listed in README.md and installable?

If `workflow-kit.ps1` exists, run:

```powershell
pwsh -NoLogo -NoProfile -File ./workflow-kit.ps1 -Command lint -RepoRoot .
```

Report findings as a short checklist: ✅ for clean, ⚠️ for needs update, with a one-line explanation for each issue found. Fix any issues you find unless they require user input.
