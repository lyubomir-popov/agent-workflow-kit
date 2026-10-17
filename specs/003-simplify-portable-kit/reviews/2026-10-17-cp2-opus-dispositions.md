# CP2 Opus finding dispositions

**Author**: GPT implementer/orchestrator
**Checkpoint**: CP2
**Scope**: `003/spec-r1`, slice A remediation only
**Review base**: `b6a375e0341bda8ca1d82f8ecdbf106fd70c016b`
**Integrated revision**: `6ed3022211a7e8697331b36fc6c6619075b75e58`

Response to [round 2 Opus findings](2026-10-17-cp2-opus-findings.md). This is
implementation and self-verification, not a third review or CP2 clearance.

1. **Fixed**: standalone branches remain listed but kept unless `--branches`
   and `--apply` are explicit. The target and default patterns `main`, `master`,
   `develop`, `trunk`, `release/*` are always protected; `protectedBranches`
   adds user/repo patterns without removing defaults. Protected worktrees are
   kept too. Fresh checks protect associated branch deletion after a worktree
   is removed. Hooks omit `--branches`, covered by a fixture. Catalog-declared
   branches join protection in slice B; their standalone branches are already
   kept by default in this slice.
2. **Fixed**: a HEAD reflog must show actual nonzero old-to-new OID movement.
   Git's repeated initialization/reset entries at one OID do not qualify.
   Missing/unreadable/malformed movement evidence keeps the checkout. Standalone
   branch candidates use their branch reflog. Worktrees also need activity older
   than `cleanupGraceHours` (24 by default); the newest HEAD log timestamp and
   admin-directory mtime both participate. Recheck movement, activity, status,
   landing and protection immediately before removal. Fixtures preserve fresh
   attached/detached checkouts, recent HEAD/admin activity and missing reflogs,
   and still remove old landed work across all four landing styles.
3. **Fixed**: both preview and apply refuse any effective hook directory inside
   any registered checkout's ordinary files, including `.husky` and absolute
   paths into another checkout. Preflight the entire installation before any
   wrapper or backup write. Real Git admin hooks and external shared storage
   remain supported; core.hooksPath is unchanged. Refusal includes a portable,
   target-guarded manual composition line. Fixtures preserve existing bytes and
   prove refusal also leaves otherwise safe admin hooks untouched.
4. **Deferred minor**: hook failures remain silent. No persistent hook.log or
   listing warning has been added. The known limit is explicit in tasks/docs;
   a moved Python or kit path still requires manual intervention.
5. **Deferred minor**: unavailable registrations block pruning for their repo.
   No parent-exists inference or `--prune` override is implemented; this retains
   stale records safely rather than guessing whether a drive is mounted.
6. **Fixed documentation/output**: docs and cleanup removal reasons now state
   that ALL ignored files are deleted, including `.env`, secrets, local notes,
   tmp evidence and build output. No allowlist or secret-preservation claim.

## Orphan recommendation

The implementer agrees with listing orphans (with requested disk size) and
manual removal. They have no Git owner through which safe Git removal can run.
The owner said they will record the FR-014 amendment; this remediation does not
silently mark that proposal accepted or rewrite its current orphan clause.
Orphans remain preserved, and the existing size limitation awaits that record.

## Evidence and stopping point

[Validation](2026-10-17-cp2-validation.md) owns the remediation commands/results
and test-first evidence. Both required branch/freshness fixtures first failed;
the `.husky` preview and apply subtests also failed before repair. The grace
fixture's initial setup bug was corrected before its behavioral red was saved.
The hook worker implemented the bounded hook fix; the orchestrator integrated
and checked the actual diff. No new independent/adversarial review was run.
CP2 remains pending. The owner decides from this evidence or explicitly requests
a targeted check; slice B, pushes and real-repository mutation remain unauthorized.
