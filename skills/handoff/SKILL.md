---
name: handoff
description: Write and rehydrate a durable session-handoff document so a fresh, zero-context session resumes work without inheriting bloated history. Use when approaching the context limit, before /clear, at end of session, or when handing work to another session or agent. Two operations — write (capture current state to a handoff doc) and rehydrate (re-ground a fresh session from it, reconciling against live state). Host-agnostic; discovers the handoff file per project. Invoke via /handoff (write) or /handoff rehydrate.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
version: 1.0.0
---

# /handoff — session-handoff document

Writes a durable, inspectable Markdown state file to disk so a fresh, zero-context session can pick up exactly where the last one left off — instead of inheriting a bloated conversation or hoping lossy compaction kept the right things. The handoff doc is the explicit, reviewable alternative to `/compact`: you read it, verify it, then `/clear`.

This is the **interactive-operator-layer** primitive. It is human-readable and operator-facing — distinct from machine durability mechanisms (e.g. an AC serialized image). Use it for sessions that stay interactive across a `/clear`, a compaction, an end-of-day stop, or a handoff to another operator/agent.

## Surface

```
/handoff [focus hint]        # write/refresh the handoff doc
/handoff rehydrate           # re-ground a fresh session from the doc
```

- A trailing `focus hint` (e.g. `/handoff focus on the auth refactor`) biases what `write` emphasizes; it does not change the schema.
- The handoff **file location is discovered**, not configured per-call — see `references/protocol.md`.

## Operations (load on demand)

| Operation | When | File |
|-----------|------|------|
| Write the handoff doc | `/handoff` (no `rehydrate`) | `operations/write.md` |
| Rehydrate a fresh session | `/handoff rehydrate` | `operations/rehydrate.md` |

Read only the operation that applies to the current invocation.

## Doctrine source-of-truth

- The document **schema** is read from `references/schema.md`. It is the durable contract — never inline it into an operation, and never silently drop a section.
- The **discovery rule**, hand-off timing, and staleness-reconciliation procedure live in `references/protocol.md`.

Both files are read at operation time. If either is missing, fail loud rather than improvising a schema — recover from git history.

## Hard rules

1. **Always Write to disk — never just display the doc.** A handoff that only appears in chat dies with the context it was meant to outlive.
2. **Review before reset.** `write` reports the path and reminds the operator to read it before `/clear`; it does not itself clear or compact.
3. **Reconcile, don't assert.** `rehydrate` cross-checks the doc against live state (git, and `GOAL.md`/`coord` if present) and flags divergence rather than trusting a possibly-stale doc.
4. **No auto-act on rehydrate.** Emit a re-grounding summary and hand control back to the operator/role.

## See also

- `references/schema.md` — the handoff document schema (frontmatter + sections)
- `references/protocol.md` — discovery rule, when to hand off, staleness reconciliation
- `task-workflow` `/finish`, `chief-of-staff` End-of-Session Capture — knowledge capture (Obsidian session-journal, metrics). Complementary, not the same surface: those are durable knowledge; a handoff is ephemeral session state.
- `goal-tree` `/resume-project` — tree-status rehydration from `CLAUDE.md` + `GOAL.md` + `coord`. `/handoff rehydrate` layers a narrative re-grounding on top.
