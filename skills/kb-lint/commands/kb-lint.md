# /kb-lint — Health-check the knowledge base

Report-only health check over the KB notes (SPEC v2 §2.6). Operator-invoked and
interactive (subscription billing pool) — no scheduled pass.

## Procedure

1. Load the skill operation:
   `Read(${CLAUDE_PLUGIN_ROOT}/skills/kb-lint/operations/lint.md)`
2. Execute it (lints the KB notes).
3. Emit the findings report; apply only reversible fixes to KB-owned notes, surface the rest as proposals.
