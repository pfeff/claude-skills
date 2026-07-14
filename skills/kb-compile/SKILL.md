---
name: kb-compile
description: "Compile staged knowledge-base sources into the vault's native notes: one per-source summary (type: reference) plus fuller concept notes (type: zettel) in Notes/, cross-linked to Keywords/ term pages and surfaced through a KB MOC + Dataview. Incremental and idempotent; concept notes update in place. Bounded writes (never DevOps Documentation//Confluence/ or unrelated notes); edit safety is git + review. Operator-invoked via /kb-compile. Use when turning raw/ sources into linked, queryable knowledge."
argument-hint: "[blank to compile all uncompiled raw/ sources]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - AskUserQuestion
version: 0.2.0
---

# KB Compile

The core behavior of the LLM Knowledge Base workflow (SPEC v2 §2.2). Incrementally compiles
un-compiled sources from the vault's `raw/` queue into the vault's **existing note idioms** —
`type:`-routed notes in `Notes/`, cross-linked into `Keywords/` and the MOC/Dataview machinery.

> **Status:** the deterministic primitives are implemented and unit-tested in `kb-core`
> (`source_key`, `is_writable`, `concept_slug`, `TYPE_*`). Summarization, concept extraction,
> and the writes are agent-orchestrated per `operations/compile.md`.

## Billing posture

`/kb-compile` is **operator-invoked and interactive** → subscription billing pool. It must
**never** be wired to cron, `claude -p`, or the Agent SDK (that moves the workflow to the
metered pool; requires operator sign-off). See SPEC v2 §6 and the CLAUDE.md billing guard.

## What it writes (SPEC v2 §2.2)

1. **Source summary → `Notes/YYYY/MM/`** (`type: reference`, `project: knowledge-base`,
   `sources: [<key>]`): one summary note per source.
2. **Concept notes → `Notes/YYYY/MM/`** (`type: zettel`): fuller-than-keyword treatments;
   created new or **updated in place** (dedup by `concept_slug`) on re-compile.
3. **Keywords/ cross-link**: concept notes `[[link]]` to term pages; compile may create a new
   `Keywords/` stub or elaborate an existing one (free-edit, git-reviewable).
4. **KB MOC** (`type: moc`) with a Dataview block over the KB notes; backlinks summary ↔
   concept ↔ keyword.

Bounded writes: never `DevOps Documentation/`/`Confluence/` or notes outside the compile's
scope (`kb_core.is_writable` floor + task-scope). Incremental/idempotent (AC-2.2). Every note
carries `type:` + `sources:` (INV-2/INV-3). No fence — edit safety is git + review (INV-5).

## Invocation

```
/kb-compile               # compile all uncompiled raw/ sources
```

## Execution

1. Load the operation: `Read(${CLAUDE_PLUGIN_ROOT}/skills/kb-compile/operations/compile.md)`
2. Execute it.
3. Report summaries written, concept notes created/updated, `Keywords/` pages touched, and sources compiled.

## Integration Points

- **kb-core** — `${CLAUDE_PLUGIN_ROOT}/skills/kb-core/scripts/kb_core.py` (`source_key`, `is_writable`, `concept_slug`, `KB_PROJECT`, `TYPE_*`).
- **obsidian-notes skill / host config** — vault path resolution + writes.
- **kb-capture** — fills the `raw/` queue this skill drains.
- **kb-lint** — health-checks the KB notes this skill produces.

## See Also

- `SPEC.md` v2 §1 (ownership model) and §2.2 (compile contract) — workspace.
- `skills/kb-capture`, `skills/kb-lint`.
