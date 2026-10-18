# CP3 author dispositions

Scope: `003/spec-r1`, slice B. Findings: [GPT round 1](2026-10-18-cp3-gpt-findings.md).
The independent verdict remains `changes` as historical evidence. These fixes
receive the orchestrator's integration checks; no second GPT round was started.
The external Opus review is the next independent round, and only the owner clears
CP3. Final revisions and complete results belong in [validation](2026-10-18-cp3-validation.md).

1. **Major — fixed.** Version 2 requires one accepting decision with its own
   Reviewer, Reviewed revision and matching Accepted scope. A historical blocker
   findings record no longer vetoes a complete later owner acceptance. The
   split-record false clearance and historical-blocker reproductions failed
   before the fix and pass in `test_workflow.py`. Version 1 composition remains
   explicit compatibility for accepted legacy evidence.
2. **Major — fixed.** Cleanup protection unions the caller catalog and target
   revision catalog. Target catalog read/parse failures preserve work by failing
   the command. The stale-caller protection regression failed before the fix and
   passes. The same guard is used in cleanup's mutation rechecks.
3. **Major — fixed.** Gate extraction is case-insensitive, normalizes checkpoint
   names and rejects malformed gate-like annotations. Mixed case, spacing and
   missing-colon cases can no longer fall back to an earlier gate. The fixture
   reproduced three unsafe fallbacks before the fix.
4. **Major — fixed.** Lint names the v1 fields it ignores, without claiming the
   budgets it consumes are ignored. Workflow lint/package parsing requires an
   explicit supported version and gives legacy repositories adoption instructions.
   Standalone worktree commands remain usable before adoption. Fixtures cover
   absent versions and lint-specific v1 diagnostics.
5. **Major — fixed.** Init preserves malformed/unsupported local configuration,
   warns and supplies manual repair steps, and adds unrelated missing owners.
   Both failing cases now pass byte-preservation, preview, ref and owner-file
   checks. Invalid user-level configuration is still an operator error.
6. **Major — fixed.** Registration searches only inside Current packages and
   requires that section's exact header/separator. Catalog parsing also rejects
   malformed recognized tables. Failing preview/apply regressions now pass with
   no files or refs changed.
7. **Major — fixed with an explicit date-granularity limit.** Version 2 gate
   selection and lint reject missing or older standard findings links. Same-date
   findings produce an ambiguity warning; the checkpoint explicitly selects the
   latest record for owner review. Fixtures cover an unlinked newer blocker and
   same-date ambiguity. File dates cannot establish within-day chronology; this
   remains in tasks' Known limits rather than a false ordering guarantee.

All repairs stayed within T007–T010. No accepted requirement was rewritten, no
vendor asset changed, and no real repository cleanup or installation occurred.
