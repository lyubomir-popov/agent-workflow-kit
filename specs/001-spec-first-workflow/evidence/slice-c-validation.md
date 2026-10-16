# Adoption validation summary

Final correction code: `27f452cadba3b93c689714164d16136f8b934588`; compared range: `098835a..27f452cadba3b93c689714164d16136f8b934588`.
Authority: [approved adoption plan](../reviews/2026-10-16-slice-c-plan-approval.md).
Received findings and per-ID outcomes: [review](../reviews/2026-10-16-cp4-adversarial-review.md),
[dispositions](../reviews/2026-10-16-cp4-author-dispositions.md).
Runtime: Windows, PowerShell 7.6.6, Git 2.52, Pester 3.4.
Author assessment: bounded corrections ready for the owner's final acceptance;
no independent checkpoint review or acceptance is claimed.

| Check | Final corrected-code result |
|---|---|
| Migration focused file | 12 passed, 0 failed; 12.73s |
| Preservation covering file | 14 passed, 0 failed; 18.85s |
| One final full suite after corrections | Passed: 284 Failed: 0 Skipped: 0 Pending: 0 Inconclusive: 0; 1100.34 seconds |
| Strict lint | 0 errors, 0 warnings, 1 semantic-limit info |
| Scheduler dry run | target=main; manual T057; zero workers |
| Kit self-preview | spec-first / ready; 34 dispositions; no errors |
| Worktree/index and `098835a..HEAD` whitespace | clean |

## Coverage and budgets

- FR-030: read-only snapshots retain branch, HEAD, index and content. Both legacy
  and versioned preview expose resume-agent, tracked-cursor, prompt/script routes,
  competing task owners and missing destinations before activation. Git/config
  failures are incomplete; Preview required, Apply rejected. Every disposition
  action is asserted. Legacy lint's obsolete required-file checks are excluded.
- FR-031: legacy overnight retains the SpecKit scheduler, preflight, operations
  safeguards and overrides; Todo is explicit opt-in. All 13 prompt sources have
  explicit boundaries. Both modes retain shared orchestration/audit contracts;
  version 1 cannot fall into legacy root-owner or stage/push-everything procedures.
- FR-032: migrated, unmigrated and external-kit fixtures preserve unknown product
  prose/config and external ownership. IBM437 tests verify exact Unicode Git
  inventory and preservation; diagnostic tests cover coloured wrapped output.
- FR-038/039, SC-010: migration production additions are 208 lines across the
  179-line library and 29 added CLI lines, below 400. The shared UTF-8 defect fix
  adds 15 lines elsewhere (223 added production lines overall). The focused
  437-line migration file takes 12.73s, below five minutes. One full suite on final
  correction code; passing suites were not rerun just to refresh evidence.

The original c13d402 run passed 279 tests locally, but the received review
reproduced two host-dependent focused failures. That earlier result did not
establish console independence; the new regressions and results above replace
its unqualified coverage claim. Against the retained CP3 baseline of 271 tests /
2396.89s, final count growth is 4.80% and observed runtime change is -54.09%.
Timings vary; no causal performance improvement is claimed.

## Mechanical limits and delivery ownership

Prompt words and function names are sentinels, not proof of behavioral compatibility
or LLM compliance. External-kit routes are not inspected; ready means no detected
mechanical migration blockers, not completed adoption. Prose placement remains
owner/agent judgment.

Linux/remote CI awaits owner-authorized push (T059). BQA-06 remains owner/provider
policy; experimental remote closeout stays excluded from rollout. New packages
await delivery of A+B to main. T060 owns placeholder removal after separately
authorized owner prompt installation. Tracked scratch is explicitly preserved in
the dispositions. Main/master remain unchanged; no installation, consumer edits,
live workers, cleanup, merge or push occurred. Prior vendor whitespace and
self-hosted code-integrity limits remain as previously recorded.
Lifecycle/checkpoint state is owned by [spec.md](../spec.md#checkpoints).
