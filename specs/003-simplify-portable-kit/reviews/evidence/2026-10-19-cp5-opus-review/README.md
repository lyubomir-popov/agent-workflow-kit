# Copilot Opus review qualification

Authority: [CP4 clearance, T030](../../2026-10-19-cp4-owner-clearance.md).
Source: `51ba13c44f01a280945c150729c88e80a66dfa13`.
This is one review of a disposable arithmetic fixture, not a review or clearance
of this project's CP5. No real implementing worker or project worker ran.

The shipped `copilot-opus` reviewer and profile tier map selected
`claude-opus-4.8`. Installed `models.list` confirmed that version and excluded
4.7; [discovery](model-discovery.json) records the available IDs. The real
[model events](model-evidence.json) confirm 4.8 actually served the review.
Copilot CLI reported 1.0.88; no CLI installation or update was run by this task.

The only command override adds JSON stdout and diagnostic logging to the shipped
argument vector. Model selection/authentication/native Node resolution remain
the shipped defaults. The fake prerequisite task makes one checkbox commit.
The single real review completed in 64.797 seconds, saved [findings](findings.txt)
with verdict `accept`, and the scheduler committed that sole new record.
The 120-second per-worker cap and one-task limit were explicit; no second review
or remediation was started. The fixture CP2 remained pending.

[Summary](summary.json) records the exact commits, changed paths, byte checks,
clean worktree and unchanged clean primary HEAD/no remotes assertions.
[Report](report.md), [result](result.json), auth/task/review logs and diagnostic
log are preserved. `commits.patch` strips display-only trailing whitespace;
original report/log paths and log hashes remain in the summary. Credential
pattern scanning found no tokens; zero redactions were needed. No credential
file or raw auth RPC payload was copied. Existing MCP startup warnings did not
prevent completion; the reviewer used only local fixture tools.

The standalone `claude` adapter remains unqualified with no auth probe. It was
not installed or invoked. This qualification is specific to the installed
Copilot release, available model and authorized disposable scope.
