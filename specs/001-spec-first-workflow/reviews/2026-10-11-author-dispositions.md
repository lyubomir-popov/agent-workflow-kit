# Author dispositions: Spec 001 Opus findings

Date: 2026-10-11. Branch: `feat/001-spec-first-workflow`.
Review: [original findings and binding owner decisions](2026-10-10-opus-spec-review.md).
Revision: [Spec 001, scope `001/spec-r2`](../spec.md).
The original author amendments below are retained as history. The owner's
acceptance and amendments appended below supersede their prior clearance and
closeout interpretation; this is not an independent review verdict.

| Finding | Disposition |
|---|---|
| B1 | Fixed in FR-002/FR-033 and the header: one lifelong lifecycle owner, eight values, checkpoint table, supersession IDs; CP1 is `findings-received`. |
| B2 | Fixed in FR-004/FR-005/FR-007 and SC-001: catalog alone resumes work; static AGENTS routing; four named entry files. |
| B3 | Fixed in FR-034 and FR-009/FR-015: markers fail, cursor ignored, declared package resolution, reserved paths/numbers, upgrade preservation, vendor budgets, principles-only constitution. |
| B4 | Fixed in FR-030/FR-031: dual mode from versioned repo config; separate prompt-install authorization; legacy retirement after portfolio migration. |
| B5 | Fixed in FR-015/FR-033 and story 3: per-finding dispositions, owner-only gate clearance, delta reviews only on owner request. |
| B6 | Fixed in FR-019/FR-020/FR-024 and story 4: final delivery commit, exact changed-path squash proof or owner confirmation, authorized network, no closeout target writes. |
| M1 | Fixed in FR-007/FR-009/FR-036: aggregate host budget, one-line CLAUDE adapter, Copilot pointer, retired resume agent, destinations for all contract sections. |
| M2 | Fixed in FR-002/FR-009 and SC-001: bounded 25-line/4,096-byte task header; task state only, lifecycle/gates linked. |
| M3 | Fixed in FR-004/FR-010/FR-016/FR-024: branch plus relative path, local worktree resolution, declared-branch precedence and edit restriction. |
| M4 | Fixed in FR-022/FR-023 and SC-005: marker plus managed-root scratch class, checked Git force only there, no recursive fallback. |
| M5 | Fixed in FR-021/FR-035: one config, default disposable list, protected tracked/evidence content, package-owned holds. |
| M6 | Deferred to Spec 002 by owner decision 8; FR-028 stub and assumptions retain brief-revision returns and consumer task-writer ownership for that candidate. |
| M7 | Fixed in FR-017/FR-035 and edge cases: declared target branch even when both `main` and `master` exist. |
| M8 | Fixed in FR-037 and catalog: slices A/B/C with owner checkpoints; story 6, FR-025–FR-029, SC-007 moved to Spec 002; no new package created. |
| m1 | Fixed in FR-008.4: kit CI backstop or explicit gap; no claim of universal enforcement. |
| m2 | Fixed in FR-009: complete findings exempt from review-request budget, read on demand. |
| m3 | Fixed in FR-008.6: per-host enforcement matrix as a deliverable, actual triggers and gaps named. |
| m4 | Fixed in FR-005 and this package: received review transferred here, original preserved; its consumed inbox links removed, not moved into TODO. |
| m5 | Fixed in FR-030.2 and SC-008: tracked scratch such as `tmp/` appears in migration preview. |
| m6 | Fixed in numbered clauses FR-008.1–6, FR-021.1–6, FR-030.1–7. |

No finding is rejected. M6 is deferred to the owner-designated Spec 002.
All other findings are addressed in the specification, not implemented.

## Historical closeout interpretation (superseded)

FR-024 keeps `delivered` as the landed snapshot after physical cleanup; a later,
separately authorized documentation change may set `closed` and update the
catalog's declared branch. This reconciles the closed lifecycle with the binding
rule that closeout never writes to the target branch or moves the package.
The owner can amend this interpretation when accepting dispositions; it does
not require an automatic delta review or another implementation state home.

CP1 remains `findings-received`. No plan, implementation, or migration is authorized
by this document. The next action is owner acceptance of these dispositions.

## Owner acceptance and amendments, 2026-10-11

Source: the owner's instruction for `feat/001-spec-first-workflow`, dated
2026-10-11. The owner accepts all author dispositions above with these amendments
and explicitly clears CP1. The historical pending-clearance and later-`closed`
interpretation above are superseded. This records owner instruction, not agent
self-clearance or a new independent verdict.

1. **CP1 and planning**: CP1 is `owner-cleared`; lifecycle is `ready` for
   planning. CP2 (after A), CP3 (after B), and CP4 (after C) are `pending`.
   No delta review is requested and CP2 must not be cleared by the implementer.
2. **Terminal delivery and preserved proof**: `delivered` is terminal for landed
   work; `closed` means withdrawn or abandoned without delivery. No post-merge
   documentation change is needed. Before deleting the delivery branch, closeout
   creates an annotated `archive/<package-id>` tag on the accepted head. Its
   message records target, landed commit, proof method (ancestry, changed-path
   equality, or owner confirmation), and date. This is preserved proof without
   a target-branch write or new state file. Pushing tags requires authorization.
   Cleanup status (retained worktrees, unknown proof, dirty state) is computed
   from Git/config in preview and is not persisted; package-owned holds are
   declared before delivery. FR-019/FR-020/FR-021.4/FR-024/FR-033, SC-005/SC-006,
   and edge cases now reflect this decision.
3. **Self-hosting compatibility**: Slice A retires root STATUS/TODO/HISTORY as
   active owners but leaves each as a 2–3 line placeholder pointing to
   `docs/specs.md`, protecting against installed legacy prompts. Slice C removes
   them after the owner installs dual-mode prompts. Open TODO items move into
   catalog candidates (maximum ten) or `ROADMAP.md`; HISTORY remains recoverable
   in Git or moves to an on-demand archive. Nothing useful is lost. FR-006 and
   FR-037 record this transition.
4. **Planning/task scope**: `plan.md` covers all three slices briefly;
   `tasks.md` details slice A only, with B and C one-line placeholders. The owner
   authorizes lifecycle `active` after tasks exist, for slice A implementation
   only. Work stops at CP2 with a saved review request; no slice B/C implementation,
   shared prompt installation, push, or downstream repository changes are authorized.
