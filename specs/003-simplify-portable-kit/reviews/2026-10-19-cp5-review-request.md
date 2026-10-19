# CP5 review request: portable kit retirement

Scope: `003/spec-r1`, slice D; branch `feat/003-simplify-portable-kit`.
Reviewed revision: `7d1b0a7acbbe2ecf90ade4609fb52ce5d7895d76`.
Review base: `2a38c29`; later changes are review records only.

Linux collision fixes, Copilot Opus reviewer qualification, consumer inventory,
PowerShell retirement/config v2, portable prompts, human docs and three-OS CI
configuration are committed locally. Fallback tag `v1-powershell` points to
`aa09890148e456f49d2fae5d2ad66df69d1de33c`; vendor assets are unchanged.

Evidence: [validation](2026-10-19-cp5-validation.md),
[independent findings](2026-10-19-cp5-independent-findings.md),
[dispositions](2026-10-19-cp5-independent-dispositions.md),
[author integration review](2026-10-19-cp5-integration-review.md).
Full suites: Windows 227 tests, OK, six skips; WSL 227, OK, three skips.
Lint has zero errors/17 documented warnings; preview stops at manual T029.

The one authorized scratch review passed with actual `claude-opus-4.8` events.
Standalone Claude remains unqualified. No real-project worker or cleanup ran.
Ten consumer repositories still need a separately scoped pin or migration;
the expanded read-only inventory covers all 88 discovered checkout trees.

Required macOS/remote CI execution is outstanding; T029 remains unchecked.
Please perform the final Opus review and decide the scope for publishing/running
CI before CP5 acceptance. One independent round is saved; no review starts here.
No push, merge or consumer migration is authorized by this request.
