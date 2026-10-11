# Decisions

- Use one shared PowerShell parser: avoids divergent launcher/lint ownership rules.
  Keep Markdown plus JSON; a database or activation sidecar would duplicate owners.
- Task entry checkpoint plus per-task gate override distinguishes slice boundaries
  from future pending reviews. Never infer gates from task completion or inbox text.
- Installed Pester 3.4 permits compatible fixture tests without dependency install.
- No external research is needed: owner decisions and inspected local Git/scripts
  resolve the choices. No extension hooks are installed. Marker/context updates
  from vendor skills are skipped under FR-034.1 and explicit owner instruction.
