# CP5 owner decision: remediate, push branch for CI, supersede 001

**Checkpoint**: CP5
**Scope**: `003/spec-r1`
**Reviewer**: Repository owner
**Reviewed revision**: `b0fa3e5`
**Verdict**: changes

Date: 2026-10-20. CP5 stays pending on the [Opus findings](2026-10-20-cp5-opus-findings.md).

## Owner choices

- "Authorize pushing the package branch": push `feat/003-simplify-portable-kit`
  to `origin` so CI runs on all three operating systems. Use no force push,
  and do not push `main`, push tags or merge.
- "Supersede 001 by 003": record Spec 001 as superseded by Spec 003 and move
  its catalog row to Archive, following the kit's own lint rules.

## Requested work (GPT)

1. Fix finding 1: restore the five Spec Kit PowerShell scripts from `059405a`
   and add a regression test against references to removed kit files. Document
   the vendor limit for macOS and Linux.
2. Fix or record finding 4, the feature cursor.
3. Supersede Spec 001 as above, then run `wfk lint`.
4. Push the package branch. Record the CI run links and per-OS results in the
   CP5 validation. If any OS fails, fix it on the branch and push again.
5. Save the updated CP5 request and stop. The owner clears CP5 and then
   handles the merge and consumer pinning separately.
