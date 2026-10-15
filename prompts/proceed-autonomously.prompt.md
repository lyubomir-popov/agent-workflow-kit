---
description: "Alias for /overnight; scheduler mode follows workflowModelVersion."
mode: agent
model: gpt-5.4-mini
---

# Proceed autonomously

## Workflow mode

Read `.workflow-kit.json` as JSON and inspect `workflowModelVersion`. If `.workflow-kit.json` is missing or `workflowModelVersion` is absent,
including when only `canonicalMirrorMode: external` is set, select legacy mode. Select spec-first mode only when `workflowModelVersion` is the JSON integer `1`;
do not coerce strings or other values. Stop if the JSON is
malformed, is not an object, or contains a present invalid or unsupported
version. Do not infer the mode from root files or placeholders. Execute only the
matching route below; version 1 must not execute Legacy procedure.

## Version 1 route

For version `1`, this command remains an alias for `/overnight`. Follow `prompts/overnight.prompt.md`, which selects the SpecKit scheduler; do not start a second workflow here.

## Legacy procedure

Legacy alias for `/overnight`. Follow `prompts/overnight.prompt.md`; its absent-version route selects the legacy TODO scheduler.
