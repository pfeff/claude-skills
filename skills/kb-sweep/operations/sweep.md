# Sweep Operation

Run the LLM Knowledge Base pipeline's three stages in sequence — capture, compile, lint — and
emit one consolidated report. Thin orchestration: this operation loads and executes each
stage's own operation doc; it owns no capture/compile/lint logic itself.

## Billing guard

Interactive `/kb-sweep` only — never invoke from cron / `claude -p` / Agent SDK (SPEC v2 §6,
same guard as `/kb-compile` and `/kb-lint`).

## Steps

1. **Capture.** Load and execute
   `${CLAUDE_PLUGIN_ROOT}/skills/kb-capture/operations/capture.md` (blank invocation — sweep
   all eligible sources). Record its outcome per source: captured / updated / skipped (with
   the deciding gate).
2. **Compile.** Load and execute
   `${CLAUDE_PLUGIN_ROOT}/skills/kb-compile/operations/compile.md`. Record its outcome:
   summary notes written, concept notes created/updated, `Keywords/` pages touched, sources
   compiled.
3. **Lint.** Load and execute `${CLAUDE_PLUGIN_ROOT}/skills/kb-lint/operations/lint.md`.
   Record its findings and any proposals appended to `Notes/kb-lint-proposals.md`.

**No stage is skipped based on an earlier stage's outcome.** All three always run, in order,
regardless of whether capture staged anything new or compile had anything un-compiled to
work through — lint audits the KB's *standing* health (orphans, inconsistencies, connection
candidates across the whole vault), not just what capture/compile just touched. A quiet
capture+compile pass (nothing new) is a normal, reportable outcome, not a reason to stop
before lint.

## Consolidated report

Emit one report at the end covering all three stages, not three separate ones:

```markdown
## KB Sweep

### Capture
- Captured: <n> (<titles/keys>)
- Updated: <n> (<titles/keys>, new highlights folded in)
- Skipped: <n> (<titles/keys>, gate: <reason>)

### Compile
- Summaries written: <n>
- Concepts created/updated: <n>
- Keywords/ pages touched: <n>
- Sources compiled: <n>

### Lint
- Findings: <inconsistencies, orphans, missing-data, connection candidates>
- Proposals appended to Notes/kb-lint-proposals.md: <n>
```

Omit a stage's detail lines when it had nothing to report (e.g. "Capture: nothing new"),
but always include all three section headers so the report is legible as one sweep, not a
partial run.

## Integration Points

- `kb-capture` — `${CLAUDE_PLUGIN_ROOT}/skills/kb-capture/operations/capture.md` (stage 1).
- `kb-compile` — `${CLAUDE_PLUGIN_ROOT}/skills/kb-compile/operations/compile.md` (stage 2).
- `kb-lint` — `${CLAUDE_PLUGIN_ROOT}/skills/kb-lint/operations/lint.md` (stage 3).
