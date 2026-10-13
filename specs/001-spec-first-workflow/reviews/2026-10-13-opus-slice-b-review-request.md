# Opus slice B review request

Checkpoint: CP3
Scope: `001/spec-r2`
CP3 remains pending.
Owner-run review only. Do not clear gates, commit, merge, push, clean live worktrees or implement slice C.
Repository: `H:/WSL_dev_projects/agent-workflow-kit`; branch: `feat/001-spec-first-workflow`.
Review code revision: `af8ed58ba17a0dff944c9f87e7774ac670234984`; compare `dce8394..af8ed58ba17a0dff944c9f87e7774ac670234984`. Subsequent handoff commit changes metadata only; checkout is clean after it.
Authority: [owner plan approval](2026-10-12-slice-b-plan-approval.md); [accepted plan](../plan.md#slice-b-plan-for-owner-approval).
Read AGENTS.md, docs/specs.md, package spec/plan/tasks, [validation](../evidence/slice-b-validation.md), [full author findings](2026-10-13-slice-b-author-review.md), and [dispositions](2026-10-13-cp3-author-dispositions.md).
Review FR-019–024 and CPA-M5/m2/m5/r4/ADV-5; slice A corrections remain accepted separately at 75ddc89.
Changes: offline preview, exact source/base/landing proof, annotated archive, guarded authorized apply, shared bounded preservation inventory, staged-index hook scope, archive edit rule, mirror inventory and committed CI event ranges.
Challenge ancestry/squash modes/add/delete/rename, unknown/stale evidence, native ref-lock races, literal/case/symbolic ownership, holds, primary/locked/scratch/detached trees and interrupted retries.
Challenge index/worktree differences, affected-package scope, durable review deletion/rename, Unicode paths, command-only creation hints and cached ref evidence.
Network commands are mocked. Check explicit local/remote authorization and actual incomplete outcomes when a server omits unchanged proof refs.
Run `pwsh -NoLogo -NoProfile -File ./tests/run-tests.ps1`; final author result: Passed: 258 Failed: 0 Skipped: 0 Pending: 0 Inconclusive: 0 (1282.45 seconds).
Run strict lint and `agent-loop.ps1 -DryRun`; author result: 0 errors/0 warnings/1 info, target=main, manual T045, zero workers.
Run `git diff --check`, `git diff --cached --check`, `git diff --check dce8394..HEAD`, and `git diff --check 53fc575..HEAD`; author results clean.
Windows/PowerShell 7.6.6/Git 2.52/Pester 3.4 verified; Linux and remote CI unverified.
BQA-06 bounded residual: server cross-ref isolation is unverified; owner/provider must resolve live policy. Actual deletion with changed proof is reported incomplete; local archive retained.
BQA-17 fixed via literal direct refs and prepared revalidation; non-ASCII ref cleanup conservatively retained. Unicode filenames remain supported.
No live cleanup, unattended worker, target write, network push, consumer change, prompt installation or vendor edit occurred. Spec 001 remains active.
Main/master remain 864cad5. New packages wait for slice A on main; owner must land/push main, switch remote default and retire master. Older vendor whitespace and self-hosted code-integrity gaps remain explicit.
Save an independent review with checkpoint, scope, exact reviewed revision, reviewer, verdict and numbered findings under reviews/. Return accept, bounded corrections or reject; only the owner may clear CP3.
