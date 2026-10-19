# Slice D validation

Authority: [CP4 clearance](2026-10-19-cp4-owner-clearance.md) and
[ordered handover](2026-10-19-slice-d-handover.md).
Review base: `2a38c29`.
Local commits only. CP5 remains pending; no consumer changes or publishing.

## T029: Linux collisions, test-first

- Before changes, the two existing collision tests both errored on WSL with
  `NotADirectoryError`: init at `docs/specs.md`, prompt install at `Code/prompts`.
- Strengthened regressions assert manual collision messages and exact binary
  preservation (`CRLF`, NUL and a non-UTF-8 byte). Red: Windows two tests/one
  message failure; WSL two tests/two errors.
- Minimal fix catches `NotADirectoryError` alongside missing paths during the
  ancestor scan, then lets the existing parent-file collision guard preserve it.
- Focused Windows: 39 tests, OK, three symlink-capability skips, 58.722 seconds.
- Focused WSL: 39 tests, OK, no skips, 4.209 seconds.
- Full WSL: 221 tests, OK, three platform skips, 50.361 seconds.
- Full Windows: 221 tests, OK, six platform/capability skips, 527.969 seconds.
- macOS is unavailable locally; the three-OS CI definition is not execution
  evidence. Its actual run remains a CP5 acceptance limitation until authorized
  publishing/CI or another macOS runner is available.

## Remaining slice checks

T030 live review, read-only consumer inventory, retirement, final source checks
and integration review are recorded here as their authorized steps complete.

## T030: reviewer profile, test-first

- The new default-reviewer regression failed while the default was `claude`.
  It verifies every task tier selects Opus through Copilot, uses the confirmed
  RPC auth probe and preserves the implementing H/S/L preferences and disabled
  standalone Claude probe.
- Installed CLI help confirms `--model`, JSON output and diagnostic logging.
  A bounded read-only `models.list` RPC confirms `claude-opus-4.8` is available;
  `claude-opus-4.7` is absent. The first short discovery timed out; subsequent
  discovery disproved that version assumption. No model task ran during discovery.
- Chose available `claude-opus-4.8` for the owner-requested Opus reviewer. The
  version-specific assertion failed against 4.7, then all nine runtime tests
  passed against 4.8. Focused runtime/review checks: Windows 31 tests OK, one
  symlink skip; WSL 31 tests OK, no skips (before that version-only adjustment).
- [Scratch qualification](evidence/2026-10-19-cp5-opus-review/README.md): one
  real review invocation, verdict `accept`, 64.797 seconds, one saved findings
  commit after a deterministic fake prerequisite task. JSON model events prove
  `claude-opus-4.8` actually served the review. Copilot reported 1.0.88; no update
  or installation was invoked by this task. Standalone Claude stays unqualified.
- Independently asserted exact answer bytes, only the fake task checkbox/new
  findings paths changed, clean worker/primary, unchanged primary HEAD, no
  remotes and fixture CP2 still pending. The logging-only command override,
  actual reports, findings, commit patch and scanned logs are preserved.

## Consumer check before retirement

[Read-only inventory](evidence/2026-10-19-cp5-consumers.md): 88 checkouts,
52 unique Git common directories, 36 linked duplicates, no unavailable roots.
Ten active consumers have operational references: eight shared-kit paths and two
local mirrors. An archived source snapshot is separate. All 38 sampled
operational dependency-file hashes matched before/after the scan. No consumer
file, index, ref, configuration or hook was changed.

The fallback tag alone cannot preserve execution at shared paths. Those eight
consumers need a separate `v1-powershell` checkout plus repointed paths, or v2
migration, under separate owner scope. Retirement here does not perform either.

## T015: retirement and commit transition

- Preserved annotated local tag `v1-powershell` at
  `aa09890148e456f49d2fae5d2ad66df69d1de33c`, before config migration/deletion.
  The tag contains the working v1 config, scripts, tests and legacy hook.
- Test-first source-version checks: three tests/four expected failures before
  compatibility and fail-closed source-config handling. Hook fixture: one
  expected failure against the old PowerShell hook when that checker was absent.
- Focused green: Windows 30 tests, OK, 27.169 seconds; WSL 30 tests, OK,
  1.526 seconds. A valid real fixture commit proceeds; lint-invalid commit
  refuses with unchanged HEAD and staged work preserved. Runtime scheduling
  remains v2 strict even when lint recognizes a v1 package source.
- Config v2 preserves target/file/host budgets and drops obsolete v1-only fields.
  Root lint reports zero errors/17 historical compatibility/date-order warnings.
- Invoked the tracked Python hook successfully in this checkout before deleting
  the PowerShell checker. Under the owner's installation permission and required
  hook transition, replaced only the byte-matching installed kit commit stub;
  its original bytes remain in `.git/hooks/pre-commit.v1-powershell`.
- Removed exactly 31 unchanged kit-owned legacy scripts/tests/launchers/CI files;
  [manifest](evidence/2026-10-19-cp5-retirement.json) records every path. All were
  compared with the fallback tag first. Vendor `.specify/` assets are unchanged.
  No cleanup hook, consumer migration, push, merge or real cleanup occurred.
- Commit lint now checks the working tree, not an isolated staged snapshot.
  The retired checker's partial-staging guarantees are not claimed. AGENTS quick
  checks now use Python lint, explicit-package preview and Git whitespace checks.
