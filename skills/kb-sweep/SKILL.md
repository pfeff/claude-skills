---
name: kb-sweep
description: "Composed end-to-end sweep of the LLM Knowledge Base pipeline: runs kb-capture, then kb-compile, then kb-lint, in order, and reports one consolidated summary. Thin orchestration only — each stage's operation doc owns its own logic; this skill duplicates none of it. Lint always runs, even when capture and compile find nothing new, since it audits standing KB health rather than just new content. Operator-invoked via /kb-sweep. Use when running the full capture-compile-lint cycle in one pass instead of three separate invocations."
argument-hint: "[blank to run the full sweep]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - AskUserQuestion
  - WebSearch
version: 0.1.0
---

# KB Sweep

Composes the three LLM Knowledge Base pipeline stages — `kb-capture` → `kb-compile` →
`kb-lint` — into one operator-invoked pass, per the "codify anything that recurs" discipline.
This skill is pure orchestration: it loads and executes each stage's own operation doc in
sequence and never re-implements or duplicates their steps.

## Billing posture

`/kb-sweep` is **operator-invoked and interactive** → subscription billing pool, same as the
three stages it composes. It must **never** be wired to cron, `claude -p`, or the Agent SDK
(that moves the workflow to the metered pool; requires operator sign-off). See SPEC v2 §6 and
the CLAUDE.md billing guard.

## What it does

Runs the pipeline end to end in one pass:

1. **Capture** — sweep eligible Readwise sources into the vault's `raw/` queue
   (`kb-capture/operations/capture.md`).
2. **Compile** — compile all un-compiled `raw/` sources into summary + concept notes
   (`kb-compile/operations/compile.md`).
3. **Lint** — health-check the KB notes (`kb-lint/operations/lint.md`). **Always runs**, even
   when capture staged nothing new and compile found nothing un-compiled — lint audits the
   standing health of the whole KB, not just what this sweep just touched.

## Invocation

```
/kb-sweep                 # run the full capture -> compile -> lint sweep
```

## Execution

1. Load the operation: `Read(${CLAUDE_PLUGIN_ROOT}/skills/kb-sweep/operations/sweep.md)`
2. Execute it.
3. Emit the single consolidated report described there: sources captured/updated/skipped,
   sources compiled (summaries/concepts/keywords), and lint findings + proposals appended.

## Integration Points

- **kb-capture** — `${CLAUDE_PLUGIN_ROOT}/skills/kb-capture/operations/capture.md` (stage 1;
  invoked, not duplicated).
- **kb-compile** — `${CLAUDE_PLUGIN_ROOT}/skills/kb-compile/operations/compile.md` (stage 2;
  invoked, not duplicated).
- **kb-lint** — `${CLAUDE_PLUGIN_ROOT}/skills/kb-lint/operations/lint.md` (stage 3; invoked,
  not duplicated).

## See Also

- `skills/kb-core/references/spec-v2-contract.md` — the underlying capture/compile/lint
  contract each stage implements.
- `skills/kb-capture`, `skills/kb-compile`, `skills/kb-lint` — the three composed stages, each
  independently invocable via its own slash command.
