# Slice C independent GPT findings — round 1

Reviewer: GPT independent review (actual gpt-6.1-sol)
Reviewed revision: 9a3e38aca7f28855ebf02cf0d0699811faedf9ef plus working tree slice C
Verdict: changes

Scope: T011–T014 / FR-030–039 on `feat/003-simplify-portable-kit`.
This reviewer did not implement the slice. The reviewed scheduler, process,
protection, runtime, review and CLI modules, defaults and fixtures were initially
uncommitted. The implementer was concurrently adding tests and integrating fixes;
locations below identify the original reviewed functions/lines, not an assertion
that subsequent working-tree edits retain each defect. The code commit will be
identified by the implementer's dispositions/request. This is independent round
1 of at most 2; it does not request an automatic delta review.

## Findings

1. **Major — uncommitted protected gate state hidden from Git status authorizes a later task.**
   Locations: `wfk/scheduler.py:_dirty` (original lines 18–29), `_fresh` (37–40),
   `_dispatch` completion/gate refresh (110–114, 151–163), and the run-loop
   `workflow.next_task(_fresh(package))` call (314–315); `wfk/protection.py:audit`
   audits committed trees only. The gate parser reads checkout bytes, while the
   cleanliness guard trusts porcelain status. A fake worker can hide protected
   owner changes with Git's ordinary index/ignore mechanisms, so neither guard
   detects the authorization change.
   Reproducer: use `SchedulerTests`' disposable fixture, with T001 at cleared CP1
   and T002 at pending CP2. A Python fake worker completes/commits only its
   dispatched checkbox. After T001's commit it runs
   `git update-index --skip-worktree specs/001-test/spec.md`, edits the working
   spec's CP2 row to
   `| CP2 | Next | [decision](reviews/injected.md) | owner-cleared |`, appends
   `/specs/001-test/reviews/injected.md` to common-directory `info/exclude`, and
   writes that ignored file with `Reviewer: Owner`, `Reviewed revision: fake`,
   `Verdict: accept`, `Checkpoint: CP2`, and
   `Accepted scope: ` plus the fixture scope `001/spec-r1`.
   Run `scheduler.run(..., packages=[PACKAGE], agents=['hidden'], apply=True,
   max_tasks=2, task_timeout=5)` with this fake profile and a successful auth
   probe. Expected: stop/reject the protected uncommitted change before T002;
   committed CP2 is still pending. Actual: `[('T001', 'done'), ('T002', 'done')]`,
   `errors=[]`, stop reason `Task limit reached`.
   Authorization must be tied to committed protected owner/evidence state, with
   protected checkout bytes checked independently of status/index suppression.

2. **Major — a worker can rewrite the primary checkout's branch and still receive `done`.**
   Location: `wfk/scheduler.py:_dispatch`, original lines 129–138. Only the
   package ref and worker HEAD are compared; foreign refs are not observed.
   Reproducer: in the same disposable fixture, a Python fake worker checks off
   T001, commits the allowed task file on `feat/001-test`, then executes
   `git update-ref refs/heads/main HEAD` and exits zero. Expected: a protected
   ref violation, preserved recovery evidence and restoration without changing
   unrelated work. Actual: task outcome `done`; primary checkout `HEAD` advances
   from the fixture base and its files/index become dirty relative to that HEAD.
   This breaks FR-032's primary-checkout guarantee despite all worker filesystem
   writes being inside the linked checkout. Snapshot/recheck existing foreign
   refs and preserve/restore unauthorized changes with expected-old-value guards.

3. **Major — switching branches after a protected commit avoids the required package-ref rewind.**
   Location: `wfk/scheduler.py:_dispatch`, original lines 139–149;
   `wfk/protection.py:quarantine` requires the currently symbolic HEAD branch.
   Reproducer: a fake worker changes `.workflow-kit.json` to `{}`, commits it on
   `feat/001-test`, then runs `git switch -c escaped` and exits zero. Expected:
   `gate-violation`, a recovery ref and removal of the bad commit from the known
   package ref while retaining checkout/index/untracked bytes. Actual:
   `gate-violation` and a recovery ref, but `feat/001-test` still points to the
   protected commit (`package_rewound=False`). The alternate path saves recovery
   without rewinding the expected ref. Quarantine should operate on the captured
   explicit package ref using CAS, even if worker HEAD changes; also preserve the
   observed worker HEAD when it differs from the expected package tip.

4. **Major — fallback preflight failure deletes already-recorded task attempts from the final report.**
   Location: `wfk/scheduler.py:run`, original lines 322–351 and final `_save`.
   Reproducer: use the shipped fake fixture profiles with
   `agents=['quota', 'auth']`, one explicit package and `apply=True`. The quota
   profile authenticates, runs a task and returns exit 7; fallback auth then
   returns exit 3. Expected: final status `auth` and a task row retaining the
   quota attempt, duration, agent and log, plus the fallback auth stop. Actual:
   `status='auth'`, `items=[]`; final report contains no quota task attempt.
   `_save(dict(result, items=result['items'] + [row]))` temporarily writes the
   attempt, but `stop_run` breaks before appending the row to canonical result;
   final `_save(result)` removes it. Persist the row before any dispatch and
   retain its attempts through fallback errors, exceptions and interruptions.

5. **Major — reviewer-controlled identity bypasses the persistent two-round cap.**
   Locations: `wfk/reviews.py:_count`, original lines 57–66, and `_findings`,
   original lines 91–104. Saved `Reviewer: self review` or `integration review`
   records are excluded when counting, but accepted for a configured independent
   reviewer. Filename exclusions also depend on configurable profile names.
   Reproducer: use `ReviewTests`' fixture and normal callback, changing only its
   generated `Reviewer: reviewer` header to `Reviewer: self review`; call
   `run_reviews(callback, run_id='run '+str(n))` four times. Expected: no third
   automatic reviewer dispatch after two saved rounds. Actual: four `accept`
   outcomes, four callback invocations and four saved findings files. Bind new
   findings to the requested identity and count scheduler-generated dispatches
   independently of reviewer-authored classification, including across runs.

6. **Major — the review phase detects out-of-scope committed code but leaves it on the package branch.**
   Locations: `wfk/reviews.py:run` changed-path validation, original lines
   195–197; `wfk/scheduler.py:_dispatch` original commit audit/outcome handling.
   Reproducer: a review callback creates valid named findings with the exact
   pre-dispatch revision, also changes tracked `code.txt`, commits both, and
   returns `done`. Expected: `gate-violation` plus quarantine/rewind preserving
   evidence and worker bytes. Actual: `reviews.run` returns `gate-violation`,
   while branch HEAD remains advanced and `code.txt` retains committed reviewer
   code. The scheduler commit audit permits ordinary code, so it does not close
   this gap before review-layer rejection. Enforce the named findings-only
   committed scope inside the dispatch protection boundary, before the existing
   quarantine path; preserve any rejected review evidence in recovery history.

7. **Minor — ordered quota fallback restarts the exhausted agent for each subsequent task.**
   Location: `wfk/scheduler.py:run`, original `for index, agent in enumerate(names)`
   at line 323 inside the task loop. Reproducer: change the fixture T002 gate to
   CP1 and run two tasks with `agents=['quota','done']`. Actual attempt order is
   `[['quota','done'], ['quota','done']]`. The first known-exhausted profile is
   retried despite FR-035's switch-to-next/no-automatic-retry policy. Retain the
   selected fallback position for the run, and stop the run when no quota
   fallback remains; do not restart exhausted profiles on later packages.

## Validation and limits

- All repros used temporary Git repositories, isolated config, fake identities,
  Python fake workers or direct review callbacks. No real Codex, Copilot or
  Claude command was invoked, including help/auth discovery. No real hooks,
  cleanup application, installation, push, merge or slice D action occurred.
- Full scheduler probes confirmed findings 1–4 and 7. Review fixture callbacks
  confirmed findings 5–6; code inspection verified that scheduler's ordinary
  commit audit permits the out-of-scope code in finding 6.
- The sole allowed new disposition file was accepted by the concurrent updated
  address dispatch when an implementation commit existed; the initially
  suspected dirty-dispositions integration issue is not a finding.
- Focused command: `python -m unittest tests_python.test_processes
  tests_python.test_protection tests_python.test_reviews
  tests_python.test_scheduler -q`: 62 tests, 2 skipped, 2 failures, 78.889 seconds.
  Tests were still being added concurrently. Failures were newly added fixture
  setup issues: `test_existing_clean_checkout_is_reused_but_dirty_or_locked_is_refused`
  reused a completed task before its locked-check assertion, and
  `test_missing_executable_and_inactive_package_never_invoke_worker` switched
  the primary onto a branch still registered in a worker worktree. Reported to
  the implementer; these do not substantiate additional product findings.
- Required quick lint, legacy dry run, `git diff --check` and
  `git diff --cached --check` passed. Dry run dispatched zero workers and stopped
  slice D at pending CP4. The full legacy suite was intentionally left to the
  implementer's final-code checkpoint validation.
- Process fixtures exercised native Windows process-tree cleanup and logs;
  actual POSIX signal-session coverage was skipped on Windows. No local
  macOS/Linux execution or hostile POSIX `setsid` containment is claimed.
- Default auth commands remain unset and fail closed as authorized by CP3.
  Configured Windows batch CLI wrappers still require a native launcher;
  live adapter interoperability remains outside this fake-worker review.
- Findings were communicated immediately while fixes were integrated. This
  artifact records the original independent review evidence, not a passing
  verdict on those concurrent repairs. The implementer owns dispositions,
  integration self-review and the external CP4 Opus request.
