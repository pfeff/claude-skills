# /kb-capture — Stage Reader sources into the KB raw/ queue

Capture work-relevant Readwise Reader documents into the vault's `raw/` staging queue for
later `/kb-compile` (SPEC §2.1).

## Procedure

1. Load the skill operation:
   `Read(${CLAUDE_PLUGIN_ROOT}/skills/kb-capture/operations/capture.md)`
2. Execute it with `$ARGUMENTS` (blank → inbox sweep; otherwise a Reader doc id/url).
3. Report staged vs skipped sources (with the gate that skipped each).
