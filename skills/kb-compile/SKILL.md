---
name: kb-compile
description: "Compile staged knowledge-base sources into the vault: one Derived summary note per source (Generated/, free edit) plus Shared concept notes (Keywords/, append-only inside the kb:generated fence), with backlinks and index/MOC notes. Incremental and idempotent; never rewrites human prose and never touches the Human zone. Operator-invoked via /compile. Use when turning raw/ sources into linked, queryable knowledge."
argument-hint: "[blank to compile all uncompiled raw/ sources]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - AskUserQuestion
version: 0.1.0
---

# KB Compile

The core new behavior of the LLM Knowledge Base workflow (SPEC §2.2). Incrementally
compiles un-compiled sources from the vault's `raw/` queue, **writing to two zones under
two different edit rules** (the load-bearing interaction with SPEC §1).

> **Status:** the load-bearing zone/fence primitives are implemented and unit-tested in
> `kb-core` (`classify_zone`, `append_in_fence`, `fence_wrap` — AC-2.3/2.5/2.6). The
> two-zone write, backlinks, MOC maintenance, and incrementality are agent-orchestrated per
> `operations/compile.md` (guarded by those primitives); the adversarial AC-2.4 (Human zone
> untouched) and a full end-to-end run are verified by the demo task.

## Billing posture

`/compile` is **operator-invoked and interactive** → subscription billing pool. It must
**never** be wired to cron, `claude -p`, or the Agent SDK (that moves the workflow to the
metered pool; requires operator sign-off). See SPEC §6 and the CLAUDE.md billing guard.

## What it writes (SPEC §2.2)

1. **Source summary → Derived** (`Generated/`): one summary note per source; free to create/edit/delete.
2. **Concept notes → Shared** (`Keywords/`): create a new concept note, or **append inside
   the `<!-- kb:generated start/end -->` fence** of an existing one — never rewrite human prose.
3. **Backlinks** between summaries (Derived) and concepts (Shared); fenced when added into Shared.
4. **Index/MOC → Derived**: keep the set navigable and self-describing.

Incremental: only new/changed sources are processed; re-running with no new sources is a
no-op (AC-2.2). Every written note carries its zone marker (INV-2) and `sources:` provenance (INV-3).

## Invocation

```
/compile               # compile all uncompiled raw/ sources
```

## Execution

1. Load the operation: `Read(${CLAUDE_PLUGIN_ROOT}/skills/kb-compile/operations/compile.md)`
2. Execute it.
3. Report Derived notes written, Shared notes created/appended, and sources marked compiled.

## Integration Points

- **kb-core** — `${CLAUDE_PLUGIN_ROOT}/skills/kb-core/scripts/kb_core.py` (`classify_zone`, `append_in_fence`, `fence_wrap`, provenance markers).
- **obsidian-notes skill / host config** — vault path resolution + writes.
- **kb-capture** — fills the `raw/` queue this skill drains.
- **kb-lint** — health-checks the Derived/Shared output this skill produces.

## See Also

- `SPEC.md` §1 (authorship boundary) and §2.2 (compile contract) — workspace.
- `skills/kb-capture`, `skills/kb-lint`.
