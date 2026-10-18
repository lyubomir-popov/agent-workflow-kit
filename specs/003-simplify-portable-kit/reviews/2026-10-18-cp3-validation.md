# CP3 validation

Review base: `c0380c6` (CP2 owner clearance). Scope: T007–T010 only.
The final code is frozen while the legacy checkpoint suite runs. The final Python
suite passed: 109 tests in 170.330 seconds, OK (4 platform/capability skips).
T010 remains open and CP3 remains pending. This is an in-progress validation
record, not a review request or checkpoint clearance.

Test-first evidence: workflow module import failure; orphan flag rejection failed
against the old no-op; adoption/prompt module import failures; missing v2 prompt
routes; malformed budget schema traceback; broken checkpoint anchors, link count
and finding severity failures. Independent round 1 reproduced seven majors;
their failing regressions and corrections are recorded in
[dispositions](2026-10-18-cp3-gpt-dispositions.md).

Initial integration run: 88 Python tests, OK (4 capability/platform skips), before
the final review repairs. Final results will replace this progress record before
the CP3 handoff. No consumer files, real cleanup, hooks, user prompt installation,
worker dispatch, push or merge has been performed.
