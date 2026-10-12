# CP2 adversarial author dispositions: Spec 001 slice A

Date: 2026-10-12. Author: Codex, Spec 001 implementer.
**Scope**: `001/spec-r2`
Findings: [saved adversarial review](2026-10-12-cp2-adversarial-delta-review.md).
This is author evidence. CP2 remains pending; only the owner clears it.

## Bounded correction choices

The owner confirmed the correction choices on 2026-10-12:

- ADV-1/2: "Fix now in slice A."
- ADV-3: "Wait for slice A delivery; fix restoration now."
- ADV-4: "Error with remote-ref evidence."

The committed fixes follow those decisions. New packages, including Spec 002,
remain unavailable until main has slice A's config, owners and overrides; no early
merge is authorized. Creation restores the original checkout on failure. Orphan
rows in available local/cached refs are errors. Configured remotes without cached
inventory are explicitly unknown, without a network query. These decisions
authorize corrections; acceptance of the completed corrections and CP2 clearance
remain owner actions. No gate clearance or slice B/C authorization is inferred.

## Findings

- **ADV-1**: fixed at `e6193c4` and `b2124c1` / Worker.Tests: remove superseded verdict, delete an existing verdict-less record, inject Accepted scope into dispositions, add each of six gate labels in new records, revert an earlier record edit, and add UTF-16 LE/BE or UTF-32 gate metadata. All reject before cherry-pick and retain scratch. New unlabelled notes plus focused completion still integrate.
- **ADV-2**: fixed at `e6193c4` and `b2124c1` / Workflow.Tests: plain/single-emphasis/bold list-style wrong checkpoint; obsolete scope with backticks/context; matching and mismatching list-style Accepted scope; missing Reviewer/Reviewed revision; encoded local-versus-declared-branch identities. All fields use one label reader and consistent byte decoding.
- **ADV-3**: fixed at `bad7ba9` / SpecKit.Tests: target missing slice A/config, missing override with detached original head, rejected commit with staged registration retained, simultaneous creation/restore failure, and post-registration feature checkout failure. Both failures retain their exceptions; committed registration is not rewound. README/plan record the main prerequisite and no early merge.
- **ADV-4**: fixed at `d77c9c0` / SpecKit.Tests: cached-inventory orphan, local-only orphan, explicitly unknown uncached remote inventory, staged orphan without command context, persisted hint, matching hint for an existing orphan, new registration alongside another orphan, and first-row registration through the real hook. Fresh-clone fetch info still passes. The transient Git command hint needs a new HEAD-absent ID and matching staged catalog-only row; it creates no persistent policy.
- **ADV-5**: author validation procedure corrected / AGENTS and quickstart: worktree, staged diff and `53fc575..HEAD` committed range checked. The new round is clean. Ranged CI checking and older `864cad5..HEAD` vendor/integration whitespace are deferred kit maintenance, owner: Codex (Spec 001 implementer). No vendor edits or broad whitespace cleanup occurred.

Rejected findings: none. Existing CPA-M5/CPA-m2/CPA-m5 and CPA-r4 deferrals retain
their named owner and future slice B planning disposition. No slice B/C work,
prompt installation, push, remote change or live worker run occurred. No further
independent/delta review was started; only the supplied review was saved.

Validation: [per-commit results and test map](../evidence/slice-a-validation.md#cp2-adversarial-correction-validation).
The latest code run passed 148/148; strict lint, dry run and all whitespace checks
passed. Main/master remain at 864cad5; main remains an ancestor of the feature.
