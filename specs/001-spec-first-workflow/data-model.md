# Data model

- Config: `workflowModelVersion: 1`, `targetBranch`, `disposablePatterns`,
  `managedScratchRoot`, `autoLoadedFiles` (path, hosts, lines, bytes, loading),
  `hostBudgets` and bounded `budgetExceptions` (path/host, limits, authorization,
  reason, expiry). Existing `canonicalMirrorMode` is independent of activation.
- Catalog table: `Spec | Package | Branch` in ordered Current packages and Archive
  sections. Package links target `../specs/<id>-<slug>/spec.md`; branch is explicit.
  Optional Lifecycle column is checked against the declared-branch spec.
- Spec top block: unique Feature branch, Lifecycle, Scope, Superseded tasks, and
  Checkpoints table (`ID | Gate | Verdict link | State`). Owner-only clearances.
- Tasks top section: `# Current work`, next IDs, blockers and checkpoint links;
  ends at first `##` heading. `**Entry checkpoint**: CP1` declares the default.
  Stable checkbox IDs `Tnnn`; `(gate: CPn)` overrides the default when needed.
- Saved review: checkpoint, scope/revision, actual known reviewer, verdict and
  findings; request and findings remain separate. Inbox handoff gives recipient,
  scope, artifact and action; receipt/transfer precedes removal.
- Scratch marker in the worktree's Git admin directory records repo, starting
  revision and integration branch; detached writes require that checked marker.
  It is operational scratch metadata, not a new lifecycle or activation owner.

Lifecycle vocabulary and transition authorization belong to [spec.md](spec.md).
Closeout proof tags and migration tooling are deferred to slices B/C.
