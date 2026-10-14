# CP3 correction author dispositions

**Checkpoint**: CP3
**Scope**: `001/spec-r2`
**Reviewed revision**: `8569b125980cf2f630829ec71565df9909c7896a`
**Reviewer**: Codex, Spec 001 implementer; author disposition, not external acceptance
**Verdict**: author corrections complete; CP3 remains pending owner decision

Date: 2026-10-14. The received [Cline review](2026-10-13-opus-slice-b-review.md)
records model identity as unattested. Its filename is historical, not evidence
of Opus identity. No external review or gate clearance occurred in this round.
The implementer chose the recommended R1/R2/R3 corrections within already
approved slice B code/fixture scope, under CP2. No slice C or live action follows.

## Finding dispositions

| Finding | Disposition and evidence at `8569b125980cf2f630829ec71565df9909c7896a` |
|---|---|
| CP3-R1 (major) | Fixed. Original landed revision must be an ancestor of the current configured target; archive metadata remains bound to the original tuple. Local locks and remote leases capture separate current tips. `Closeout.Tests.ps1`, 'Closeout immutable landing and advancing targets': interruption/retry for ancestry and squash with unchanged tag object, refreshed/stale local proof locks, advanced remote leases and snapshot changes. |
| CP3-R2 (major) | Fixed. Source/landing comparison uses the original landing tree after later catalog registration. Same Describe: 'proves squash landing before later catalog registration and reuses that landing on retry'; `Carryover.Tests.ps1` CLI case also registers another package after landing. No owner confirmation is needed for a proved squash. |
| CP3-R3 (minor) | Fixed. README documents original base/accepted/landed IDs on retry, recovering the annotation with `git cat-file tag`, inspecting conflicting tuples and keeping the immutable tag. CLI JSON/human output separates original landing from current target tip; `Carryover.Tests.ps1` checks both and unauthorized apply. |
| CP3-Q1 (minor, independent author QA) | Fixed. A denied local selection no longer suppresses separately authorized remote reconciliation; both local actions are retained and the overall outcome is incomplete. `Closeout.Tests.ps1`, 'Closeout separate local and remote authorization': 'performs authorized mocked remote reconciliation while retaining both unauthorized local actions'. Local branch, worktree bytes and status stay unchanged, with no local cleanup commands. |

No finding is rejected or moved into slice C. R1/R2 coverage is 14 focused cases;
Q1 adds one focused case; the CLI file passes seven existing cases with expanded
advance/retry assertions. Full validation and historical B findings remain in
[validation evidence](../evidence/slice-b-validation.md) and the
[prior dispositions](2026-10-13-cp3-author-dispositions.md).

## Independent author QA and bounds

staged_hook (gpt-5.6-sol) independently read the closeout implementer's diff and
found no concrete R1/R2 defect. It identified Q1; closeout (gpt-6.1-sol) corrected
it, and the primary implementer integrated the CLI/docs/evidence and full checks.
These are author-team checks, not a verified Opus review or owner acceptance.

Offline proof retains declared partial-clone/promisor/filter repositories before
object reads and forbids lazy fetching in Git child processes. Missing, unrelated
or rewound target ancestry retains cleanup. Changing the original tuple still
conflicts with an existing archive, including with `-OwnerConfirmed`; archives
are neither deleted nor retargeted to make a retry succeed.

BQA-06 remains open for the repository owner/Git provider: server isolation of
unchanged proof refs is unverified. A successful deletion followed by a changed
captured proof snapshot reports incomplete even if the new target is a descendant;
the local archive survives. All network behavior here is mocked.

Linux and remote CI remain unverified. New packages, including Spec 002, wait for
slice A delivery to main. The owner still owns delivery/push of main, remote default
branch selection and eventual master retirement. Older vendor whitespace remains
separately scoped maintenance, owned by the Spec 001 implementer; no vendor edit
or whitespace exclusion occurred. No live cleanup, unattended worker, target
mutation, push, consumer change or prompt installation was authorized or run.
CP3/CP4 stay pending; lifecycle remains active.
