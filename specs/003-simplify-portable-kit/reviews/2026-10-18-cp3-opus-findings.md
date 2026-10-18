# CP3 Opus findings: slice B workflow core

**Checkpoint**: CP3
**Scope**: `003/spec-r1`
**Reviewer**: Opus (GitHub Copilot, Claude Opus 5.5)
**Reviewed revision**: `e28391dbb736a80aade3659942ffefa3e6d808d5` (records at `55065ed`)
**Verdict**: changes

Date: 2026-10-18. Round 2 of 2 for CP3 under FR-022.

## Summary

Slice B works end to end without PowerShell. I reran the suite (109 tests,
4 skips, OK) and ran `wfk lint` here (0 errors, 18 v1 compatibility warnings).
In a scratch repo, `wfk init --apply` kept the existing AGENTS.md and created
the rest. `wfk new "Add login" --apply` then made one registration commit that
lints clean, the package branch points at it, and `wt clean` protects that
branch. The circular hook dependency that blocked Spec 003's own creation is
gone. One gap defeats a core purpose of the kit in adopted repositories.

## Findings

1. **Major – adopted repositories get no entry-file budgets.** `wfk init` writes
   `.workflow-kit.json` with only `workflowModelVersion` and `targetBranch`
   ([adoption.py](../../../wfk/adoption.py) `initialize`). `_budgets` checks only
   declared `autoLoadedFiles` and `hostBudgets`, so in every repository adopted
   with `init`, AGENTS.md can grow without limit and lint stays green. Keeping
   frequently loaded files small was the owner's explicit requirement.
   *Fix*: `init` writes default declarations for `AGENTS.md`, `CLAUDE.md` and
   `.github/copilot-instructions.md`, plus host budgets, using this kit's values
   (100 lines/12 KB, 15/2 KB, 15/2 KB; hosts 150/16 KB). When a config already
   exists, the checklist names the missing budget fields. Add a fixture: after
   `init`, a 200-line AGENTS.md fails lint.

2. **Minor – the severity check reads every numbered list in a findings file.**
   `lint` applies `^\d+\.\s+` to the whole text, so a numbered "Validation"
   list, which the review prompt invites, becomes an error under v2. Restrict
   the check to the `## Findings` section.

3. **Minor – review header labels are parsed from the whole document.**
   `labels()` raises "Duplicate review header" when the body quotes a header
   line, for example a `Verdict:` example. Parse only the block before the
   first `##` heading.

4. **Minor – `prompts install` creates folders for editors that aren't installed.**
   The default destinations always include both `Code` and `Code - Insiders`,
   and `_write` creates the missing parents. The old installer only detected
   existing Insiders profiles. Default to destinations whose `<editor>/User`
   folder already exists; explicit destinations stay as given.

## Record fix made by this review

Under v2 rules the CP2 row in `spec.md` would fail "latest findings must be
linked", because it linked my delta check rather than a `-findings` file. I
relinked CP2 to the [round-2 findings](2026-10-17-cp2-opus-findings.md) and the
[owner clearance](2026-10-18-cp2-owner-clearance.md); the clearance still
reaches the delta check through the owner decision.

## Remediation scope

Finding 1 is required before CP3. Findings 2–4 may be fixed or recorded as known
limits. No third review round starts automatically; the owner decides CP3 on
the dispositions and validation, or asks for a targeted check.
