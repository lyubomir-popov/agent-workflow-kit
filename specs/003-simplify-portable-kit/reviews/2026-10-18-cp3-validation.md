# CP3 validation

Latest: [CP3 Opus remediation](#cp3-opus-remediation), source `c37172a`.
The earlier slice B handoff results below are retained as evidence.

## Slice B handoff

Review base: `c0380c6` (CP2 owner clearance). Scope: T007–T010 only.
Implementation: `70a440594e306d4e13251da2a90d40cb6c0a39b0`.
Final code/test revision: `e28391dbb736a80aade3659942ffefa3e6d808d5`.
T007–T010 are complete. The final code/test revision passed the complete legacy
suite; subsequent changes contain handoff records only. CP3 remains pending for
external Opus round 2 and the owner's decision. No slice C task was started.

| Check | Result |
|---|---|
| `python -m unittest discover -s tests_python -v` | 109 tests in 170.330 s; OK, 4 skips |
| `python -m compileall -q wfk` | pass |
| `python -m wfk lint --json` | 0 errors, 18 diagnostic/compatibility warnings on final records |
| Legacy strict lint | 0 errors, 0 warnings |
| Legacy scheduler dry run | 0 worker invocations; stops before T011 at CP3 |
| `git diff --check c0380c6..HEAD`, worktree/index whitespace | pass on implementation; rechecked for handoff |
| Focused `./tests/run-tests.ps1 -Path ./tests/Migration.Tests.ps1` | 12 passed, 0 failed, 17.22 s |
| Complete `./tests/run-tests.ps1` | 284 passed, 0 failed/skipped; 1500.41 s on e28391d (wall 1501.17 s) |

The first full run exposed one stale test: it assumed thirteen prompts and
required every source to be a mode router. Slice B adds the generic saved-review
procedure as a fourteenth source. `e28391d` corrects the legacy assertion and
checks for v2 routes while preserving the v1 contract; production code is
unchanged. The affected file and complete repeat both pass, giving the checkpoint
a full result on the final code/test tree.
The initial full result was 283 passed, 1 failed in 1527.07 seconds; that single
failure was the corrected prompt-source assertion, with no additional failures.

The four Python skips are the POSIX launcher on Windows, one adoption directory
symlink case and two prompt link cases requiring unavailable Windows privilege.
macOS/Linux destination paths were simulated. The GitHub matrix covers three OSes
and Python 3.10/current, now including Python lint with full local branch inventory;
it was not run because this session is local-only.

The 18 Python lint warnings comprise ignored v1 fields, preserved historical
review formats/link counts, the historical CP2 delta-check filename and same-date
review ambiguity. Standard findings are strict in both config generations;
version 2 also enforces complete per-record owner decisions and latest dated
findings links. These warnings do not reopen the owner's CP2 clearance. Existing
accepted evidence remains unchanged; limits belong in tasks.

Test-first evidence: workflow module import failure; orphan flag rejection failed
against the old no-op; adoption/prompt module import failures; missing v2 prompt
routes; malformed budget schema traceback; broken checkpoint anchors, link count
and finding severity failures. Independent round 1 reproduced seven majors;
their failing regressions and corrections are recorded in
[dispositions](2026-10-18-cp3-gpt-dispositions.md).

Initial integration run: 88 Python tests, OK (4 capability/platform skips), before
the final review repairs. The final 109-test run includes all seven corrections
and the orphan flag rejection. Adoption's final focused run was 24 tests, OK
(one skip); prompts 12, OK (two skips); workflow 26, all pass.

The orchestrator inspected the actual diffs and the workers' fixture evidence,
then integrated the independent review repairs. GPT-6.1 Sol handled bounded
adoption/prompts implementation; GPT-5.6 Sol performed independent round 1.
Configured GPT-5.4 tiers were unavailable; substitutions were disclosed. The
orchestrator self-review is an integration pass, not independent round 2.

No `.specify`, `.agents` or `.claude` vendor asset changed against the review base.
Root STATUS/TODO/HISTORY placeholders were deleted as authorized. No consumer
files, real inventory sweep, cleanup, hooks, user prompt installation, scheduler worker,
push or merge has been performed. Git mutations occurred only in temporary test
repositories and the authorized local implementation/record commits.

## CP3 Opus remediation

Base: `bb3ac5c` (saved round 2 findings). Scope: T023–T024, finding 1 and
dispositions for findings 2–4. T023–T024 are complete. All checks ran on the final
source; later changes contain handoff records only. CP3 remains pending for the
owner's decision, and slice C is untouched.
Source: `c37172a47ca9ca3b649d7f21062dce481b4628e3`.

Test-first: the three new adoption fixtures failed before implementation. Lint
accepted the preserved 200-line AGENTS.md, the generated config lacked
`autoLoadedFiles`, and preview/apply checklists did not name missing budget fields.
The focused adoption suite now runs 27 tests, OK (one symlink capability skip),
in 32.267 seconds. Existing config and both adapter preservation are covered.

The complete Python suite passed: 112 tests in 183.395 seconds, OK (4 existing
platform/capability skips). Python compilation and whitespace checks passed.
Python lint reports 0 errors and 17 existing diagnostic/compatibility warnings.
The required complete legacy suite passed: 284 passed, 0 failed/skipped, in
1516.24 seconds (wall 1517.35 seconds). Strict legacy lint reports 0 errors and
0 warnings; scheduler dry run invokes 0 workers and stops at CP3. Review-range
whitespace uses `git diff --check bb3ac5c..HEAD`, plus worktree/index checks.
The author inspected the actual diff and fixture results; no new review round
was started. No real init, installation, cleanup, consumer edit or push occurred.
No third review was started. See [dispositions](2026-10-18-cp3-opus-dispositions.md)
for the required fix, deferred minors and workarounds.
