# CP3 GPT findings: slice B workflow core

Reviewer: GPT-5.6 Codex (`gpt-5.6-sol`, high reasoning)
Reviewed revision: `c0380c6` plus the uncommitted Slice B working diff observed on 2026-10-18
Verdict: changes

Scope: `003/spec-r1`, T007-T010 / FR-020-FR-028 and FR-041, including the
Slice A catalog-branch-protection join. This is CP3 round 1. It does not clear
CP3 or authorize slice C. Several bounded corrections landed in the shared
working tree after these reproductions; the findings preserve the defects that
the round found and the evidence needed for dispositions.

1. **major — Version 2 gate clearance can be assembled without an owner
   verdict, while a remediated blocker findings record can permanently veto a
   real owner decision.** In a temporary version 2 package, I linked (a) GPT
   findings containing `Reviewer: GPT`, `Reviewed revision: abc` and
   `Verdict: accept`, and (b) a purported decision containing only
   `Accepted scope: 001/spec-r1`. With the row text set to `owner-cleared`,
   `gate_problem` returned `None`, `lint_errors=[]`, and `next_task=T001`.
   The parser combined authorization fields across two records even though no
   complete owner decision existed. The inverse also failed: a valid linked
   blocker findings file followed by a complete owner `Verdict: accept` for the
   matching accepted scope returned `CP1 saved verdict is blocking or
   superseded`. That makes the immutable findings record veto its later owner
   disposition forever, contrary to FR-021-FR-023 and the rule that the owner
   clears after accepting findings and dispositions. Require one authoritative
   version 2 decision record to carry its own reviewer, reviewed revision,
   exact `accept` verdict and matching accepted scope (and matching checkpoint
   when present). Treat other linked findings as evidence rather than as the
   final decision. Retain legacy composition only as an explicit version 1
   compatibility path.

2. **major — cleanup protection reads the caller checkout's catalog, so a
   target-declared package branch can be deleted from a stale checkout.** In a
   temporary repo, `main:docs/specs.md` declared `feat/002-new`; I switched the
   caller to an older `feat/001-test` checkout whose catalog lacked that row.
   The reproduction printed `target_catalog_has_branch=True`,
   `caller_catalog_has_branch=False`, and
   `_protected(repo, 'feat/002-new', 'main') == False`. A landed standalone
   package branch is therefore eligible when the operator explicitly uses
   `clean --branches --apply`, violating the FR-014 Slice B protection join.
   Build protection from the configured target revision's catalog and fail
   closed when it cannot be read; unioning the caller catalog is a conservative
   addition. Cover a stale non-target caller checkout.

3. **major — a malformed task gate silently falls back to the cleared entry
   gate and advances work past a pending checkpoint.** In a temporary version
   2 package I changed T002 from `(gate: CP2)` to `(Gate: CP2)` and completed
   T001. CP2 remained pending, but parsing produced `T002_parsed_gate=CP1`, lint
   returned no errors, and `next_task` selected T002. The extraction and the
   malformed-marker test are case-sensitive, so a gate-like annotation that
   differs in case is treated as no annotation. Parse case-insensitively and
   reject any gate-like parenthetical that is not exactly one valid checkpoint
   reference; test mixed case, spacing and extra text.

4. **major — `wfk lint` silently ignores version 1 fields, and absent-version
   configs were interpreted differently from every installed prompt.** On the
   real repository's version 1 config, `python -m wfk lint --repo . --json`
   named only Spec 001 compatibility warnings and did not name the ignored
   `managedScratchRoot`, `disposablePatterns`, or `budgetExceptions` fields.
   `workflow.lint` read `_read` directly without carrying configuration
   diagnostics, contrary to FR-041. Separately, all routed prompts say an absent
   `workflowModelVersion` is legacy, while Python used
   `.get('workflowModelVersion', 2)`, silently applying version 2 semantics to
   the same file. Emit lint-specific warnings for the version 1 fields lint
   truly ignores. Require an explicit workflow version for workflow-core
   commands, or give absent versions the same legacy meaning as prompt routing;
   standalone Slice A worktree commands can remain usable before adoption.

5. **major — an existing malformed or unsupported config prevents `wfk init`
   from adopting every other missing owner.** In a temporary Git repo with
   `.workflow-kit.json` containing `{ malformed`, `wfk init --apply` exited 1
   with `Cannot read config ... Expecting property name...`. The existing bytes
   were preserved, but `agents_created=False`: no unrelated missing kit files
   were added and no manual-merge checklist was returned. FR-027 requires init
   to preserve every collision while adding missing config, templates, catalog,
   inboxes and AGENTS guidance. Treat a bad existing local config as an owned
   collision: report it in warnings/checklist, leave it byte-identical, use an
   unknown/fallback target for the preview, and continue exclusive creation of
   safe missing destinations. Cover malformed JSON and unsupported versions.

6. **major — package registration can search into the next section and silently
   add a new draft to Archive instead of Current packages.** Starting from an
   initialized temporary repo, I removed only the `Current packages` table
   separator while leaving the default `Archive` table intact, committed that
   malformed catalog, and ran `adoption.new(..., apply=True)`. The result
   reported `docs/specs.md` as `registered`, the new row occurred after
   `## Archive`, and `workflow.lint(...).errors == []`. `_register` searches the
   entire remainder of the document for the first separator rather than bounding
   its search at the next level-two heading. Bound registration to the Current
   packages section and require its header and separator there before creating
   files or refs. Catalog lint should reject a malformed recognized package
   table instead of treating it as empty.

7. **major — a newer unlinked blocker review is invisible to lint and task
   selection.** In a temporary version 2 package whose CP1 row linked an older
   accepted owner decision, I added a valid
   `reviews/2026-10-19-cp1-gpt-findings.md` with `Verdict: blocker` and a
   severity-marked finding. The reproduction printed only the old decision in
   `linked`, then `lint_errors=[]` and `next_task=T001`. Header validation scans
   the file, but no code enforces FR-023's requirement that the checkpoint row
   link the latest findings. For standard version 2 filenames, group findings
   by checkpoint and require the row to link the latest dated/round record; at
   minimum reject a newer unlinked findings file and reject a row with no
   findings link when findings exist. Same-date records whose ordering cannot be
   inferred should produce an explicit ambiguity instead of silently choosing.
   Keep legacy version 1 records on the documented compatibility path.

## Validation and limits

All mutation reproductions used `TemporaryDirectory` Git fixtures; no real
cleanup, hook install, prompt install, push, merge or consumer edit occurred.
Focused workflow/adoption/prompt tests were run while integration was active;
the observed cases above were also exercised independently with direct fixture
calls. I confirmed the shipped version 2 prompt routes do not invoke PowerShell
or the unimplemented scheduler, the review prompt requires saved findings and
matching dispositions, the obsolete `--orphans` flag is rejected, and no
`.specify`, `.agents`, or `.claude` vendor asset was modified. Root integration
owns the final full-suite, three-platform CI and post-fix evidence; those results
were not available when this round was saved.
