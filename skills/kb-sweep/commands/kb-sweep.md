# /kb-sweep — Run the full capture -> compile -> lint KB pipeline

Run the LLM Knowledge Base pipeline end to end in one pass: capture, then compile, then lint.
Operator-invoked and interactive (subscription billing pool) — never wire to cron / `claude -p`
/ Agent SDK.

## Procedure

1. Load the skill operation:
   `Read(${CLAUDE_PLUGIN_ROOT}/skills/kb-sweep/operations/sweep.md)`
2. Execute it (runs capture, then compile, then lint, per each stage's own operation doc).
3. Emit the consolidated report: sources captured/updated/skipped, sources compiled
   (summaries/concepts/keywords), and lint findings + proposals appended.
