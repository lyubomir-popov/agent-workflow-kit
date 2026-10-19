# CP4 Opus findings: slice C scheduler

**Checkpoint**: CP4
**Scope**: `003/spec-r1`
**Reviewer**: Opus (GitHub Copilot, Claude Opus 5.5)
**Reviewed revision**: `3a1943a7d6a76928c3f9192be9871a18f777b443` (records at `8bd7e6a`)
**Verdict**: changes

Date: 2026-10-19. Round 2 of 2 for CP4 under FR-022.

## Summary

The safety machinery is good: explicit `--package` authority, gate checks read
from committed records, per-package locks, Windows Job Object and POSIX
process-group termination, ref quarantine and restore, outcome classification
by exit code before log patterns, and a report written on every exit path. I
reran the slice C modules (85 tests, 2 skips, OK). A preview for this package
correctly reports "CP4 is not owner-cleared". The gap is the other half of user
story 2: with the shipped defaults, the scheduler cannot run a worker
unattended, and on the owner's Windows machine it cannot launch one at all.

## Findings

1. **Major – shipped defaults cannot complete an unattended task.**
   [scheduler-defaults.json](../../../templates/scheduler-defaults.json):
   - Every `authCommand` is `null`, and `runtime.argv(auth=True)` then refuses.
     So every `--apply` run stops with outcome `auth` before its first task.
   - The worker commands lack the non-interactive permission flags the previous
     scheduler relied on: `copilot … --allow-all --no-ask-user --autopilot
     --max-autopilot-continues N -s` and `codex exec
     --dangerously-bypass-approvals-and-sandbox`. Claude needs its equivalent.
     Without them, a worker that runs cannot edit or commit, and each task ends
     in `no-progress`.
   - `tierModels` is all `null`. The `TierDispatchMap` models and efforts
     (`gpt-5.4` xhigh/high, `gpt-5.4-mini`) were dropped rather than moved, but
     FR-031 says config replaces that map.
   *Fix*: port the proven flags and tier map into the defaults, with
   `modelArgs`. Choose per-agent auth probes, then confirm flags and probes in
   an owner-authorized live qualification: one trivial task per agent in a
   scratch repo, saved as evidence. Without that run, user story 2 is not met.

2. **Major – Windows cannot launch npm-installed workers.** On the owner's
   machine `copilot` resolves only to `.bat`, `.cmd` and `.ps1` shims (npm and
   the VS Code Copilot CLI), and `processes.execute` rejects batch launchers.
   The previous scheduler resolved the Node entry point instead.
   *Fix*: resolve npm shims to `node <entry script>` (or the vendor's native
   binary) and keep rejecting raw `.cmd`. Do not route the prompt through
   `cmd.exe` arguments: task text can contain `&`, `|` or `^`. Add a fixture
   with a fake npm-style shim.

3. **Major – the Linux suite is not green.** Validation records 2 errors on WSL
   (init and prompt installation, parent-file collision). SC-001 requires all
   three operating systems, and the owner works on Linux and macOS. This may be
   fixed in slice D, but must be green before CP5.

4. **Minor – the primary-checkout refusal gives no recovery command.** The
   owner usually keeps the package branch checked out in the primary checkout,
   as now. Print the exact fix, for example `git -C <primary> switch <target>`,
   then rerun.

## Remediation scope

Findings 1 and 2 are required before CP4; finding 1's live qualification needs
owner scope. Finding 3 may move to slice D with a task, and must be closed
before CP5. Finding 4 may be fixed or recorded. No third review round starts
automatically.
