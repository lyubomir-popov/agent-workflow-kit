# CP3 Opus dispositions

Checkpoint: CP3
Scope: `003/spec-r1`
Findings: [Opus round 2](2026-10-18-cp3-opus-findings.md), reviewed at `e28391d`.
Remediation base: `bb3ac5c`. Final source revision and checks are recorded in
[validation](2026-10-18-cp3-validation.md#cp3-opus-remediation).

Only the owner decides CP3. Both independent rounds are exhausted; no third
review or slice C work was started. This is an author disposition, not a new
independent verdict.

1. **Major — fixed.** Init now reads the shipped `templates/init/config.json`:
   AGENTS.md 100 lines/12,288 bytes; CLAUDE.md and Copilot instructions each
   15 lines/2,048 bytes; each configured host 150 lines/16,384 bytes. Missing
   thin adapters are added so their declarations lint clean. Existing config,
   instructions and adapters are preserved byte-for-byte; missing or empty
   `autoLoadedFiles`/`hostBudgets` fields are named in the manual checklist.
   The regression first reproduced lint accepting a preserved 200-line AGENTS.md;
   it now rejects that file. Two additional fixtures verify exact defaults,
   a lint-clean fresh adoption, and budget-specific preview/apply checklists.
   Existing preservation coverage now includes both adapter files.
2. **Minor — deferred for the owner's decision.** Severity checks still scan all
   numbered lists in a findings file. Use bulleted validation lists until the
   parser is scoped to the Findings section. Recorded in tasks' Known limits.
3. **Minor — deferred for the owner's decision.** Header labels still scan the
   entire document. Keep example labels inline rather than at the start of a
   body line, including fenced-code lines. Recorded in tasks' Known limits.
4. **Minor — deferred for the owner's decision.** Default prompt installation
   still creates both Code and Insiders profile paths even when an editor is
   absent. Preview before applying; for only one existing editor, manually copy
   the desired prompt sources to its profile. Recorded in tasks' Known limits.

The three minor behaviors were left unchanged to keep this correction focused
on the required adoption budgets. They are not described as fixed or accepted.
The reviewer-owned CP2 link correction is preserved unchanged. No spec acceptance
criteria, repository config, real installation, cleanup or consumer files changed.
