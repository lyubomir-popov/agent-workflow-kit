# Agent workflow kit constitution

## Core principles

### I. Owner scope and review

The owner's current instructions govern scope and authorization. A draft spec
defines proposed behavior; it does not silently replace the operating contract.
When the owner requests review before implementation, finish the specification
and review handoff, then wait for that review.

### II. One owner per fact

Keep each rule, state fact, task, and source reference in its declared owner.
Other files link to that owner. Workflow changes reconcile instructions,
prompts, automation, and documentation together.

### III. Preserve work

Preserve unrelated changes and user evidence. Repository-specific permissions
and deletion restrictions apply to automation too. Uncertain merge or cleanup
evidence requires preservation and a clear report.

### IV. Proportional verification

Validate the behavior a change affects. Test automation failure paths when they
can lose work or falsely declare completion. Keep ordinary documentation
checks small; do not introduce evidence machinery without a named need.

### V. Canonical tooling

This repository owns the reusable workflow scripts and prompts. Consumer
product rules remain in their repositories. Respect explicit external-kit
usage and avoid machine-specific paths in reusable artifacts.

## Governance

These principles capture the existing owner instructions and kit invariants.
Spec 001 proposes the next workflow contract and needs independent review.
The current operating instructions remain in `.github/copilot-instructions.md`
until an accepted implementation replaces them coherently.

**Version**: 1.0.0 | **Ratified**: 2026-10-10 | **Last amended**: 2026-10-10
