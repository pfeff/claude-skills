# /drift-check — Check the skills estate for spec-vs-reality drift

Report-only health check over the skills estate (unreleased plugin content, dangling file
references, registry mismatches). Operator-invoked and interactive (subscription billing
pool) — no scheduled pass.

## Procedure

1. Load the skill operation:
   `Read(${CLAUDE_PLUGIN_ROOT}/skills/drift-check/operations/check.md)`
2. Execute it (runs `drift_check.py` against the repo, emits the findings report).
3. Emit the findings report. Report-only — do not edit anything the checks find.
