# Owner lean direction and implementer handover

Date: 2026-10-14. Recorded by Cline at the repository owner's instruction:
"we do not want ceremony for the sake of ceremony – we need a foundation that
ensures lean, fast working practices." Recipient: GPT, Spec 001 implementer.
This record is direction, not a checkpoint verdict. It clears no gate.

## Why

The core already pays off: always-loaded instructions fell from about 19.8 KB
(`copilot-instructions.md` + `agents/agent.md` on main) to 4.3 KB (`AGENTS.md`),
and STATUS/TODO/HISTORY no longer compete for state. The cost moved elsewhere:

- Full-suite time grew from 136 s (86 tests) to 1,748 s (271 tests), and it ran
  before every commit, including metadata-only handoffs.
- The package holds about 230 KB of prose. The prohibition list was repeated in
  22 lines across 16 files; completed task rows restated "CP2 stays pending".
- Closeout is 816 production and 1,617 test lines. Remote reconciliation rests
  on an unverified provider property (BQA-06).

## What changed in this record-only change

- [spec.md](../spec.md): FR-038 proportional validation; FR-039 no duplicated
  state; FR-037/FR-014 reviewer identity is the owner's choice and is recorded
  truthfully; FR-019/FR-024 freeze remote closeout and closeout scope; FR-030
  uses Git commits/revert for migration rollback; SC-010. Checkpoint gate labels
  no longer say "Opus". States and verdict links are unchanged.
- [tasks.md](../tasks.md): removed gate-state restatements from completed rows;
  T045 reworded as an owner decision; T050 records this change; T051 added;
  T017 narrowed.
- [plan.md](../plan.md): constitution IV row, narrow slice C bounds, row 8.
- AGENTS.md, [quickstart](../quickstart.md), README: tiered validation; remote
  closeout marked experimental.

Validation followed FR-038: strict lint (0 errors/0 warnings/1 info), dry run
(stops at manual T045, 0 workers) and whitespace checks. No full suite ran; no
code changed. Committed locally on the package branch; nothing was pushed.

## Working rules for you

1. Read only: AGENTS.md, docs/specs.md, the spec header block, the tasks header,
   and this file. Open other records only when a task needs them.
2. Validate by tier (AGENTS, quickstart). Record-only commit: quick checks.
   Code commit: the covering test files. Full suite: once, on final code, before a
   checkpoint handoff. Never rerun a passing suite to refresh evidence.
3. One review round = one request (≤30 lines), one disposition file. Do not open
   delta, adversarial or self-review rounds unless the owner asks.
4. Evidence: one summary per checkpoint – revision, commands, pass counts,
   runtime, known gaps. No intermediate failure diaries.
5. Do not restate checkpoint states or prohibitions in tasks, plans or inbox
   lines; link the checkpoint table or AGENTS instead.
6. Closeout is frozen: fix only fixture-reproduced defects. No remote features.
7. Report runtime: if a focused test file passes 5 minutes, or the full suite
   grows by more than a third, report it before adding more cases.

## Ordered work

1. **T045 – owner decision; you wait.** The owner accepts slice B at `8569b12`
   or names blockers. The saved acceptance names checkpoint CP3, scope
   001/spec-r2, the reviewed revision, the actual reviewer and an "accept"
   verdict (the labels the gate parser reads); only the owner sets the state.
2. **T051 – test-only fix, allowed now (gate CP2).** In this session 7 cases in
   `tests/Hook.Tests.ps1` and `tests/HookScope.Tests.ps1` failed because the
   child `pwsh` error text wrapped mid-phrase (e.g. "affected package\n
   owner/review artifacts are not staged"). The author's 271/271 run passed, so
   this depends on the environment. Make the assertions independent of wrapping,
   e.g. collapse whitespace and `|` gutters before `Should Match`, or set a fixed
   `$ErrorView`/width in the child. Do not change `workflow-hook.ps1` messages.
   Run only those two files. One commit, `tests:` prefix.
3. **After CP3 owner-cleared: plan slice C (T017), then stop for approval.**
   Keep it within [plan.md](../plan.md) slice C bounds: read-only `migrate
   -Preview`; apply as ordinary commits on a migration branch; Git rollback;
   prompt dual mode on `workflowModelVersion`; one migrated, one unmigrated and
   one external-kit fixture; under 400 production lines. Add detailed tasks for C
   only, then hand back with one short request.
4. **Recommend to the owner, don't perform:** land slice A+B on main (this
   unblocks new packages and Spec 002), and push the branch so CI runs on
   Windows and Linux. Both are owner actions.

## Out of scope without new owner instruction

Consumer repositories, prompt installation, live or remote cleanup, pushes,
merges, unattended workers, vendor skill edits, rewriting historical review or
evidence files, and new closeout guard classes.

## Definition of done for Spec 001

Slice C passes its focused tests and one full suite; CP4 is accepted; the delivery
commit sets `delivered` and archives the catalog row. Consumer adoption is then a
separate, owner-authorized activity.
