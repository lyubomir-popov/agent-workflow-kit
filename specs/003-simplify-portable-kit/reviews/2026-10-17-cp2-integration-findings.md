# CP2 orchestrator integration findings

**Reviewer**: GPT orchestrator (self-review, not Opus)
**Reviewed revision**: `716823f475b8f8b0a537f93372f353b150c41295`
**Verdict**: accept
**Scope**: `003/spec-r1`, slice A only; CP2 remains owner-pending.

This is the integration pass within the first GPT review round, not an extra
review request. The separate independent worker review supplies its own verdict.

1. **major, resolved**: Git's `--separate-git-dir` inventory reports the metadata
   directory as the primary checkout. Correct it from the invoking primary root;
   the metadata-location acceptance fixture now passes.
2. **major, resolved**: Skipping linked-checkout descendants hid independently
   cloned nested repos. Traverse those contents while skipping Git internals and
   dependency caches; the added nested-repo regression passes.
3. **minor, documented**: Relative hook directories can be untracked and thus
   preserve a checkout; new host-created checkouts need installation. Do not
   silently add ignores to hide owner hook files.
4. **minor, documented**: Unknown orphan ownership and unavailable mounts require
   preservation. [Known limits](../tasks.md#known-limits) describes the remaining
   FR-014 orphan removal gap; it still needs the owner's decision.

Independent major fixes and their validation are recorded in the matching
GPT dispositions. No remaining blocker or major was found in this integration
pass. Cross-platform CI and inaccessible repositories remain unverified limits;
this verdict does not clear CP2 or authorize slice B.
