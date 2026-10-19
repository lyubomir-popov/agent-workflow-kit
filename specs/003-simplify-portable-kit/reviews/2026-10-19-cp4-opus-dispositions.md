# CP4 Opus author dispositions

Findings: [Opus round 2](2026-10-19-cp4-opus-findings.md).
Authority: [owner decision](2026-10-19-cp4-owner-decision.md).
Base: `298b3d3`. CP4 remains pending. No third review was started.
Source/checks: [remediation validation](2026-10-19-cp4-remediation-validation.md).

1. **Major — code corrected; live qualification has explicit limits.** Defaults
   restore the unattended flags, shared H/S/L model/effort table and provider
   argument syntax. Codex's installed `login status` and Copilot's bundled
   `auth.getStatus` RPC both authenticated in scratch. The RPC helper makes no
   model session/login request, requires a boolean true result, bounds input and
   prints no credential/account payload. CLI help is not used as authentication.
   The restored tier map is H `gpt-5.4`/xhigh, S `gpt-5.4`/high and L
   `gpt-5.4-mini` without explicit effort. Provider overrides remain supported.
   The first port missed the old `Test-CodexCompatibleModel` guard; the one Codex
   attempt rejected that Copilot alias. The final code restores the guard while
   retaining tier effort, with red/green fixtures. It was not live-rerun because
   the owner authorized one attempt only. Copilot completed its one task and
   committed. Claude is unavailable, so its probe remains unset and no installation,
   login or unverified probe is claimed. These limits remain for the owner to
   decide, rather than declaring three passing qualifications.
2. **Major — fixed and live-qualified with installed Copilot.** Known npm wrappers
   use validated package metadata and an allowed installed entrypoint to select
   native Node. The wrapper script is never evaluated or executed. Native
   executables stay supported; unknown/malformed wrappers fail closed. Tests
   cover `.cmd`, `.bat`, `.ps1`, local/PATH Node, Unicode/spaces, missing/tampered
   metadata, and real Node execution with command metacharacters preserved in
   one argument. The installed npm Copilot completed its scratch task without
   routing a prompt through cmd.exe.
3. **Major — deferred exactly as authorized.** New slice D task T029 explicitly
   owns both Linux parent-file collision fixes and their tests, required green
   before CP5. T016 owns the final three-OS suite/CI. Those Python functions were
   not changed here and no slice D work was started. The earlier CP3-baseline
   reproduction remains in CP4 validation.
4. **Minor — fixed.** A primary-branch refusal prints an executable, shell-quoted
   `git -C <primary> switch -- <configured-local-target>` command, or a detach
   command when no different local target is available. It never switches the
   owner's checkout. The existing refusal fixture first failed its new command
   assertion and now passes.

Live reports, logs, the committed patch and boundary checks are preserved in
[scratch evidence](evidence/2026-10-19-cp4-live/README.md). All worker execution was
confined to that new temporary repository. No push/merge, hook install, real
cleanup, consumer edit or real-project worker occurred.
