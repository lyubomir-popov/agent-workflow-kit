# CP3 bounded correction review request

Checkpoint: CP3
Scope: `001/spec-r2`
CP3 remains pending; only the owner may clear it.
Repository: `H:/WSL_dev_projects/agent-workflow-kit`; branch: `feat/001-spec-first-workflow`.
Review code revision: `8569b125980cf2f630829ec71565df9909c7896a`; compare `9e1819c..8569b125980cf2f630829ec71565df9909c7896a`. Full slice B base: `dce8394`; subsequent handoff is metadata only.
Read AGENTS.md, docs/specs.md, package spec/plan/tasks, [received Cline review](2026-10-13-opus-slice-b-review.md), [correction dispositions](2026-10-14-cp3-author-correction-dispositions.md), and [validation](../evidence/slice-b-validation.md).
The received reviewer is Cline with model identity unattested; no verified Opus claim or new external review occurred. The owner decides acceptance and any reviewer-identity requirement.
CP3-R1: original landing is an ancestor of current target; immutable archive tuple is reused. Local locks and remote leases capture current snapshots separately.
CP3-R2: original squash/tree comparison survives later catalog registration without owner confirmation.
CP3-R3: README preserves/retrieves the original tuple; CLI JSON/human output separates landing and current tip, with no tag deletion/retarget workaround.
Independent author QA CP3-Q1: separately authorized remote actions proceed while unauthorized local selections remain retained, with incomplete overall status.
Challenge interrupted ancestry/squash retries, unchanged tag OID, advanced local/remote tips, lock/lease races, rewind/unrelated/missing objects, changed tuple and OwnerConfirmed conflicts.
Challenge unknown remote objects without fetch, conservative partial/promisor bounds, server no-op omission and descendant snapshot changes. Existing literal/case/symbolic ownership, checkout, holds and preservation guards must remain intact.
Challenge mixed local/remote grants with mocked network; no live network or cleanup is authorized.
Run `pwsh -NoLogo -NoProfile -File ./tests/run-tests.ps1`; corrected-code author result: Passed: 271 Failed: 0 Skipped: 0 Pending: 0 Inconclusive: 0 (1748.51 seconds).
Run strict lint and `agent-loop.ps1 -DryRun`; author result: 0 errors/0 warnings/1 info, target=main, manual T045, zero workers.
Run worktree/index and `9e1819c..HEAD`, `dce8394..HEAD`, `53fc575..HEAD` whitespace checks; author results clean. The staged hook passes.
Windows/PowerShell 7.6.6/Git 2.52/Pester 3.4 verified; Linux and remote CI unverified.
BQA-06 remains owner/provider judgment: unchanged-ref server isolation is unverified; deletion with changed captured proof is incomplete, local archive retained.
Main/master remain 864cad5. New packages wait for slice A on main; delivery/push, remote default switch and master retirement remain owner steps.
Older vendor whitespace and self-hosted code-integrity gaps remain explicit. No vendor edit, consumer change, prompt installation, live cleanup, worker, target mutation or push occurred.
Save any owner acceptance/review with checkpoint, scope, exact accepted revision, reviewer and verdict under reviews/. Do not auto-clear CP3 or start slice C.
