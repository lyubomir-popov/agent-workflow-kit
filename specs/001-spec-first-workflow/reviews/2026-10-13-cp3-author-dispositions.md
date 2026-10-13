# Slice B CP3 author dispositions

**Checkpoint**: CP3
**Scope**: `001/spec-r2`
**Reviewed revision**: `af8ed58ba17a0dff944c9f87e7774ac670234984`
**Reviewer**: Codex, Spec 001 implementer; author disposition, not Opus
**Verdict**: author corrections complete; CP3 remains pending owner-run review

Date: 2026-10-13. Authority: [plan approval](2026-10-12-slice-b-plan-approval.md).
The owner authorized code and isolated fixtures only. No live cleanup, unattended
worker, merge, push, prompt installation, vendor edit, consumer change or slice C.

## CP2 carryovers

- CPA-M5 — fixed at `2a4a6ef` / `Preservation.Tests.ps1`: directory summaries, bounded subtree scans, nested evidence/link/hold and zero-commit scratch fixtures.
- CPA-m2 — fixed at `af8ed58ba17a0dff944c9f87e7774ac670234984` / `HookScope.Tests.ps1` (13 cases), baseline `Hook.Tests.ps1`, and real-hook registration in `SpecKit.Tests.ps1`: affected index contracts with source state preserved.
- CPA-m5 — fixed at `17b3535` and `af8ed58ba17a0dff944c9f87e7774ac670234984` / `Carryover.Tests.ps1`: missing/drifted canonical hook/library inventory and external/legacy compatibility; no installation.
- CPA-r4 — fixed at `af8ed58ba17a0dff944c9f87e7774ac670234984` / `Carryover.Tests.ps1`: narrow final delivery transition, archived edits on exact configured target only, deleted source branch and quoted Unicode path; existing squash target tests retained.
- ADV-5 — fixed at `af8ed58ba17a0dff944c9f87e7774ac670234984` / `CI.Tests.ps1`: committed PR/push/first-push/root ranges, diverged targets and missing evidence. Older `864cad5..75ddc89` whitespace is deferred to separately scoped maintenance, owner: Spec 001 implementer; no vendor cleanup or path exclusions.

## Author/delegated QA

Full issue, provenance, correction and test details: [author findings](2026-10-13-slice-b-author-review.md).

- BQA-01 — fixed at `af8ed58ba17a0dff944c9f87e7774ac670234984` / Carryover.Tests.ps1: quoted Unicode archive path.
- BQA-02 — fixed at `17b3535`; regression at `af8ed58` / Carryover.Tests.ps1: CLI JSON/human preview and unauthorized apply.
- BQA-03 — fixed at `af8ed58ba17a0dff944c9f87e7774ac670234984` / CI.Tests.ps1: divergent PR, unavailable/unrelated histories, nested root.
- BQA-04 — fixed at `17b3535` / Closeout.Tests.ps1: ancestor tip race, unpublished tip race, newly checked-out branch.
- BQA-05 — fixed at `17b3535` / Closeout.Tests.ps1: captured immutable annotation race.
- BQA-06 — bounded correction at `17b3535` / Closeout.Tests.ps1: atomic proof-ref races and server no-op omission; remaining owner: repository owner/provider. Cross-ref server isolation remains unverified. Repository owner/provider must resolve live-operation policy; this session authorizes no remote mutation.
- BQA-07 — fixed at `17b3535` / Closeout.Tests.ps1: squash deletion with configured upstream, unpublished race and caller hook.
- BQA-08 — fixed at `17b3535` / Closeout.Tests.ps1: stable archive/landed proof locks and unsupported locks.
- BQA-09 — fixed at `17b3535` / Closeout.Tests.ps1: exact Unicode wildcard-like paths and decoder failure.
- BQA-10 — fixed at `17b3535` / Closeout.Tests.ps1: suffix-lookalike remote ref.
- BQA-11 — fixed at `17b3535` / Closeout.Tests.ps1: retained detached/scratch/unknown association Describe (3 cases).
- BQA-12 — fixed at `17b3535` / Closeout.Tests.ps1: remote held source and deleted working hold.
- BQA-13 — fixed at `17b3535` / Closeout.Tests.ps1: deterministic day13/en-GB and February30 rejection.
- BQA-14 — fixed at `af8ed58ba17a0dff944c9f87e7774ac670234984` / Carryover.Tests.ps1: differently cased target.
- BQA-15 — fixed at `2a4a6ef` / Preservation.Tests.ps1: encoded/scoped/base holds, directory summaries, nested evidence and links.
- BQA-16 — fixed at `af8ed58ba17a0dff944c9f87e7774ac670234984` / HookScope.Tests.ps1 (13 cases), Hook.Tests.ps1 and SpecKit.Tests.ps1 real-hook registration.
- BQA-17 — fixed at `af8ed58ba17a0dff944c9f87e7774ac670234984` / Closeout.Tests.ps1: 'Closeout literal ref ownership and prepared deletion guards' (13 cases) and 'Closeout registered checkout ref ownership' (8 cases), including inverse primary/linked aliases, late checkout guards, unknown inventory and quoted Unicode paths.

No finding is rejected. BQA-06 remains bounded for owner/provider review; no live
operation is authorized by these dispositions. CP3/CP4 remain pending.
