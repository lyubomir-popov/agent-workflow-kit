# CP4 author dispositions

Scope: `003/spec-r1`, T011–T014. Findings:
[independent GPT round 1](2026-10-19-cp4-gpt-findings.md).
The original verdict remains `changes`; these are author repairs, not an
independent passing review. External Opus round 2 and the owner decide CP4.
Final source and results belong in [validation](2026-10-19-cp4-validation.md).

1. **Major — fixed.** Scheduling parses committed spec/task records and reads
   linked decisions/latest findings from that same branch revision. Worker
   checkouts with assume-unchanged or skip-worktree index flags are refused,
   even when porcelain reports clean. The hidden-gate regression first ran both
   T001 and unauthorized T002; it now reports uncommitted work after T001 and
   dispatches no T002. Ignored checkout evidence cannot grant clearance.
2. **Major — fixed.** Each dispatch snapshots Git refs and detects changes
   outside its package branch. A violating tip is quarantined and existing
   foreign refs are restored with expected-observed-value CAS, without touching
   unrelated files/index. The fake primary-ref rewrite now reports a violation,
   restores primary HEAD and leaves its checkout clean. Newly created foreign
   refs are retained and named for inspection rather than silently deleted.
3. **Major — fixed.** Quarantine accepts the captured explicit package ref and
   rewinds it even after a worker branch switch or detached HEAD. It first saves
   a unique recovery ref, rejects symbolic target refs and uses no-dereference
   CAS. Tests preserve the alternate checkout HEAD, index and all local bytes;
   stale CAS preserves recovery. The implicit API still refuses detached HEAD.
4. **Major — fixed.** The durable canonical result owns a task row before the
   worker starts. Every attempt is appended there before fallback preflight.
   Quota followed by auth failure retains its attempt, log, commits and duration
   in the final report. Crashes/interruption retain an initialized task/report;
   a probe that fails before any task produces an auth report without a task.
5. **Major — fixed.** New findings must name the requested reviewer profile
   exactly and cannot claim self/integration review. Generated records consume
   rounds independently of their authored classification, including across run
   IDs and exclusion-like profile/run names. Existing legitimate integration
   evidence is excluded only by explicit header identity. Spoofing and four-run
   cap regressions failed before the repair and pass now.
6. **Major — fixed.** Review dispatch audits every commit's paths against its
   exact named new findings record before permitting a review result. Reviewer
   code changes, including code reverted in a later commit, use the same
   quarantine/rewind path. End-to-end fake CLIs confirm the package ref returns
   to its pre-review task commit and rejected history remains recoverable.
7. **Minor — fixed.** Fallback position persists across tasks and packages in
   the run. An exhausted agent is not restarted; final quota exhaustion stops
   the run before the next selected package. Tests cover two eligible tasks and
   a second authorized package.

Additional integration corrections: a present lock flag with an empty reason
still means locked; cleanup retains catalog protection and activity grace; review
receives the freshly completed task; a sole named new dispositions record may
remain dirty until its exact-file evidence commit; output classification scans
bounded chunks rather than allocating a complete log or unbounded line.

No accepted requirement was edited. No third review, live CLI qualification,
consumer mutation, real cleanup/install, push, merge or slice D occurred.
