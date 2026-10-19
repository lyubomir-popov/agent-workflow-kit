# CP5 Opus findings dispositions

Findings: [2026-10-20 Opus findings](2026-10-20-cp5-opus-findings.md).
Authority: [owner decision](2026-10-20-cp5-owner-decision.md).
Evidence: [remediation validation](2026-10-20-cp5-remediation-validation.md).
Two rounds are exhausted; this is remediation, not a third review.

1. **Major — fixed.** Restored all five vendor scripts from `059405a` exactly;
   the two unchanged scripts already matched. Red/green dependency and functional
   prerequisite regressions pass. Vendor PowerShell 7 requirements are documented.
2. **Major — pending CI.** Only the package branch is authorized for a normal
   push. Actual Windows/macOS/Linux matrix results must be saved before this
   finding or T029 can be recorded as resolved.
3. **Minor — fixed under explicit owner decision.** Spec 001 is superseded by
   003 and archived. Unfinished tasks and accepted evidence remain preserved;
   an explicit terminal-archive review format prevents retroactive v2 rewriting.
4. **Minor — fixed locally.** The intentionally Git-ignored vendor cursor selects
   Spec 003, confirmed by both read-only prerequisite modes. It remains local
   state and grants no checkpoint authority.

Consumer pinning/migration remains a pre-merge owner action. No consumer changes
or tag publication are included. CP5 clearance and merging remain with the owner.
