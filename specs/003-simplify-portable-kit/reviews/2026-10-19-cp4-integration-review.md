# CP4 orchestrator integration review

Reviewer: GPT orchestrator (self-review, not independent or Opus)
Reviewed revision: 3a1943a7d6a76928c3f9192be9871a18f777b443 (integration self-review)
Verdict: changes

Scope: integration of T011–T014, not owner clearance. The mandatory external
CP4 review remains pending. Final checks are recorded once in
[validation](2026-10-19-cp4-validation.md).

## Findings

1. **Minor — live adapter qualification remains required.** The owner authorized
   fake workers only. Shipped command templates are declarative and auth probes
   are unset, so a live dispatch fails closed. No installed AI CLI was invoked,
   including help or login. CLI-default models are explicit null tier values;
   a chosen model requires a configured argument template. Qualifying real
   provider argv, auth and quota classification requires separate owner scope.
2. **Minor — containment has stated OS limits.** Windows uses a suspended child
   assigned to a kill-on-close Job Object before resume; CtrlBreak is best effort
   when no console is shared. POSIX descendants must remain in the owned session;
   deliberate setsid escape is unsupported. Windows batch files require a native
   executable launcher. macOS and Python 3.10 execution are not claimed locally.
3. **Minor — manual recovery boundaries are deliberate.** New foreign refs and
   dirty/rejected checkouts remain for inspection; a stale package lock is never
   stolen. Forced OS termination can leave the initialized report marked running.
   Optional reviews run after progress in that run; a standalone follow-up review
   without another eligible task uses the saved-review prompt and owner scope.
4. **Major — pre-existing Linux parent-path errors remain before final portability acceptance.**
   Full WSL discovery reproduces `NotADirectoryError` in
   `adoption._safe_destination` and `prompts._linked` when a destination's parent
   is a file. Both exact tests also fail in a temporary archive of CP3 commit
   `9a3e38a`; these source functions are unchanged by slice C. Slice C's complete
   fake-worker suite passes under WSL. Record the two earlier errors for T016's
   three-OS validation after CP4, without claiming overall Linux readiness or
   accepting the defects on the owner's behalf.

Disposition: record findings 1–3 as known limits for CP4 consideration, with operational
guidance in [scheduler reference](../../../docs/scheduler.md). They do not grant
live-worker authorization or waive an accepted requirement. The independent GPT
majors have author repairs and regressions in the linked dispositions; external
Opus must judge whether that evidence is sufficient. Finding 4 remains open for
the gated final portability work; the owner decides whether it blocks CP4.

## Integration checks

- Inspected process, protection and review worker source plus their failing and
  passing fixture evidence; integrated contracts before dispatch.
- Reproduced hidden gate escalation, foreign primary-ref mutation, switched-HEAD
  quarantine, erased fallback evidence, identity cap bypass and reviewer code
  scope. Each repaired boundary has a targeted fixture.
- Verified clean branch/worktree preflight, common-dir exclusive leases, explicit
  package scope, auth stop, quota ordering, gate stop, limits and durable report
  paths. Fake CLI coverage includes saved review/address/second-review flow.
- Preserved version 1 route/config, legacy tooling, existing Opus/owner evidence,
  accepted requirements, vendor assets and unrelated inbox entries. Slice D is
  behind pending CP4. No new independent review was launched after round 1.
