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
