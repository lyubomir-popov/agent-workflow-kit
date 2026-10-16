# CP4 adversarial review: Spec 001 slice C adoption

**Checkpoint**: CP4
**Scope**: `001/spec-r2`
**Reviewed revision**: `c13d402456a63217d8848d5bb2bb6155e2553890` (records through `098835a`)
**Reviewer**: Cline agent in VS Code, run at the owner's request; model identity is not independently attested
**Verdict**: accept with bounded corrections

Compared range: `917e12b..098835a`, against the approved plan at `48ba3a5`.
This review does not clear CP4; only the owner can.

## Summary

The read-only preview contract holds: no probe changed branch, HEAD, index or
content. `-Preview` is required and `-Apply` is rejected. The slice C plan
section is unchanged since approval except for its authority link, and the line
budget (205 lines) is honest. Two problems sit on the compatibility side (FR-030.4/7,
FR-031). The legacy `/overnight` route now changes behavior for unmigrated
consumers. The prompt layout also leaves the version 1 scope ambiguous, and in
`sync-all-repos` that includes `git add -A` and push. Fix both before
installation or consumer rollout.

## Reproduced

- Strict lint: 0 errors, 0 warnings, 1 info. Dry run: target=main, manual T057,
  zero workers. `git diff --check` / `--cached --check`: clean. `main` is still
  `864cad5`, an ancestor of HEAD.
- Kit self-preview: spec-first / ready / 34 dispositions; Git status unchanged.
- `tests/run-tests.ps1 -Path ./tests/Migration.Tests.ps1`: **6 passed, 2 failed**
  in this host's console (IBM437 output encoding, 53-column buffer). See CP4-m3/m4.
  The recorded result was 8/8. The full suite was not rerun.
- Every probe ran in a disposable temp repository, which was then removed.

## Findings

### CP4-M1 (major). Legacy `/overnight` no longer preserves the legacy route

Refs: FR-030.7 ("do not impose new behavior on unmigrated repos"), FR-031,
US5 scenario 4; plan "Prompt compatibility" ("the existing TODO scheduler for
legacy repositories"); `prompts/overnight.prompt.md:45-54`.

Before this change (`917e12b`), an unversioned repository's `/overnight` launched
`-Workflow SpecKit`. It also said explicitly not to fall back to the TODO
scheduler unless the user asked for it. The new legacy route runs only
`-Workflow Todo`, then a live `-MaxTasks 3`. The plan text contains the same error,
so the implementation follows an incorrect approved plan.

Probe: an unmigrated repository with `specs/001-x/tasks.md` and no `TODO.md`.
- New legacy route `-Workflow Todo -DryRun`: crashes at `agent-loop.ps1:1820`
  (`Cannot find path ...\TODO.md`), exit 1.
- Previous route `-Workflow SpecKit -DryRun`: runs, exit 0.

An unmigrated spec-kit consumer that does have `TODO.md` would now execute TODO
items instead of its spec packages. The rewrite also removed the legacy pre-flight
steps, the authentication/terminal safeguards (`docs/operations.md` is no
longer referenced by any prompt), and the overrides table. The summary's claim
that "legacy procedures remain available" is therefore false for `/overnight` and
`/proceed-autonomously`.

Correction: restore the `917e12b` body as the legacy procedure, keeping its
explicit `-Workflow Todo` opt-in. Amend the plan's prompt-compatibility sentence.
Add a static contract that the legacy section keeps the SpecKit default and the
operations safeguards.

### CP4-M2 (major). Version 1 prompt scope is structurally ambiguous

Refs: FR-031 ("Migrated repos MUST NOT execute legacy TODO-driven work"),
AGENTS staging/push rules; `tests/Migration.Tests.ps1:302`.

Seven prompts put operational content under `##` headings that are siblings
after `## Legacy procedure`, not children of it: `orchestrate` (dispatch
contract, validation), `competing-audit` (its entire procedure),
`repo-health-audit`, `audit-diagram-generator`, `simo-plan-sweep`, and
`sync-all-repos`. Either reading is wrong for some prompt:

- If the headings are treated as legacy only, version 1 loses orchestrate's dispatch contract and
  `TierDispatchMap` ownership note, the competing-audit procedure, and
  sync-all-repos' "do not force-push" rules.
- If the headings are treated as shared, version 1 runs `sync-all-repos` `## Procedure`
  (`git add -A`, push every repo), which contradicts its own version 1 route. It
  also runs `repo-health-audit` `## Route findings into the workflow` (write
  `TODO.md`, note in `HISTORY.md`), which recreates retired owners.

The static test only inspects the text between the version 1 heading and the
legacy heading, so it cannot catch this.

Correction: demote legacy subsections to `###` under `## Legacy procedure`. Move
mode-independent rules into a shared section before `## Workflow mode` or into
the version 1 route. Assert that no `## ` heading follows `## Legacy procedure`.

### CP4-M3 (medium). Legacy-mode preview hides blockers and its status is legacy lint

Refs: FR-030.1, US5 scenario 1 ("conflicts ... visible before activation");
`workflow-migration.ps1:64-86,146,168-174`.

The resume-agent, feature-cursor, live-route, retired-owner and missing-destination
findings only fire when `mode -eq 'spec-first'`, which is after activation. In
legacy mode, `status` comes from legacy `Test-WorkflowRepo`. That lint requires the
very files migration retires. Probe: a legacy repository without `STATUS.md`/`TODO.md`
shows `incomplete` for 8 `required-file` errors, while the legacy fixture with a
live `.github/agents/agent.md` shows `ready` with zero errors. `ready`/`incomplete`
therefore does not mean migration readiness before activation.

Correction: in legacy mode, emit the same blockers as preview-level findings,
or label the status as legacy-lint. Exclude retire-target `required-file` errors
from migration status.

### CP4-m1. Planned blocker and disposition classes are untested

The plan requires "all disposition classes" and the router conflicts. The
migration tests have no case for `migration-resume-agent`, `migration-feature-cursor`,
`migration-live-route` (prompt or script), or `migration-git`. They also never
assert the actions `replace-incompatible-route`, `add-mode-selection`,
`untrack-and-ignore`, `reduce-to-adapter`, `convert-to-catalog`,
`add-workflow-model-version` or `repair`. The evidence's FR-030 coverage claim
overstates the tests.

### CP4-m2. Route and dual-mode detection are text sentinels

A prompt counts as dual-mode if it contains the word `workflowModelVersion`
anywhere. A local validator or scheduler counts as compatible if two function
names appear in its text. Route checks are skipped entirely for external mode.
Record these as mechanical limits rather than proof of compatibility.

### CP4-m3. Unicode tracked-path decoding depends on the console encoding

`Get-WorkflowPreservationGitRecords` decodes `git ls-files -z` through the
host's `[Console]::OutputEncoding`. Under IBM437, `tmp/notes δ.txt` is reported
as `tmp/notes ╬┤.txt`. Non-ASCII tracked paths are therefore also misclassified as
`untracked` (the hash keys are the mangled names). The "exact Unicode tracked
scratch" claim holds only for UTF-8 consoles. The helper is shared with
slice B. Its impact there and on Windows CI is unverified.

### CP4-m4. CLI diagnostic assertion regresses the T051 wrap fix

`Invoke-MigrationCli` normalizes wrapped `|` output differently from the
hardened hook helpers. At 53 columns, the guard message is split mid-sentence,
and the test fails even though the exit code and message are correct. Reuse the
T051 normalization or assert on the exit code plus an unwrapped substring.

### CP4-m5. Records rewritten to match drift; open obligations lack task owners

- T056 was approved as "...one final full suite ... and CI after an authorized
  push". It was reworded at check-off to "record CI as an owner-push follow-up".
  CI now has no task ID; only the evidence prose mentions it. AGENTS forbids
  rewriting an owner to match drift. Keep T056 partial or add a CI task.
- T053–T055 were also reworded at check-off: the budget and overrun clauses
  were removed. The approved text survives only in `48ba3a5`.
- FR-037 makes slice C responsible for removing the STATUS/TODO/HISTORY placeholders
  after owner prompt installation. README:28-29 and the placeholders still say
  "until slice C", and no task owns the removal.
- The kit's own tracked `tmp/hello.txt` and `tmp/world.txt` are reported, but no
  preserve/retire decision is recorded.

## Recommended correction scope

Bounded to `prompts/*.prompt.md`, the plan's prompt-compatibility paragraph,
`tests/Migration.Tests.ps1`, small `workflow-migration.ps1` status/blocker changes,
and task rows. No new commands, apply path or remote work. After corrections,
run Migration plus the directly affected files, then one final full suite per FR-038.
