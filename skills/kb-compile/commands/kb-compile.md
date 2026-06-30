# /kb-compile — Compile KB sources into Derived + Shared notes

Compile un-compiled `raw/` sources into Derived summaries and Shared concept notes
(SPEC §1 + §2.2). Operator-invoked and interactive (subscription billing pool) — never
wire to cron / `claude -p` / Agent SDK.

## Procedure

1. Load the skill operation:
   `Read(${CLAUDE_PLUGIN_ROOT}/skills/kb-compile/operations/compile.md)`
2. Execute it (compiles all uncompiled `raw/` sources).
3. Report Derived notes written, Shared notes created/appended, and sources marked compiled.
