---
name: kb-core
description: "Shared library for the LLM Knowledge Base skills (kb-capture, kb-compile, kb-lint). Holds the SPEC v2 §1 primitives — capture predicate, idempotency key, off-limits write-guard, KB-ownership check, concept-slug dedup, orphan detection — in one place so the three skills share one implementation. Reference/infrastructure content, not user-invocable; the three KB skills load its scripts."
version: 0.2.0
---

# KB Core (shared library)

Shared infrastructure for the three LLM-Knowledge-Base skills. **Not user-invocable** —
there is no operation to run here (precedent: `lN-lifecycle-doctrine`). It exists so the
deterministic logic from SPEC v2 §1 lives in exactly one place.

## What it provides

`scripts/kb_core.py` — pure, vault-I/O-free primitives consumed by kb-capture, kb-compile,
and kb-lint:

- **Capture predicate** (`is_eligible`, `CAPTURE_TAG`) — the SPEC §2.1 eligibility gate
  (highlight/notes + work-relevance, with the `kb` tag override).
- **Idempotency** (`source_key`) — stable, filesystem-safe key from the Reader id, so
  re-capture / re-compile are no-ops (INV-4).
- **Write boundary** (`is_writable`, `OFF_LIMITS`) — the INV-1 floor: never write under
  `DevOps Documentation/` or `Confluence/`.
- **KB ownership** (`is_kb_owned`, `KB_PROJECT`) — is a note KB-authored? Confines lint
  auto-fix to KB notes (AC-6.2); everything else is proposal-only.
- **Concept dedup** (`concept_slug`) — stable slug so re-compile updates a concept note in
  place instead of duplicating it (AC-2.3).
- **Orphan detection** (`find_orphans`) — notes with no inbound backlinks (AC-6.3 input).
- **type: constants** (`TYPE_RAW`, `TYPE_SUMMARY`, `TYPE_CONCEPT`, `TYPE_MOC`) — the note
  kinds compile emits (`kb-raw` / `reference` / `zettel` / `moc`).

No zones, no fence: edit safety is git + review (SPEC v2 §1, INV-5).

## Status

All primitives implemented and unit-tested (`test_kb_core.py`).

## Tests

```
cd skills/kb-core/scripts && python3 -m unittest test_kb_core
```

Stdlib `unittest` (zero-dependency, matches `task-workflow/scripts/test_render_deps.py`).

## See Also

- `SPEC.md` §1 (workspace) — the authorship-boundary contract these primitives enforce.
- `skills/kb-capture`, `skills/kb-compile`, `skills/kb-lint` — the three consumers.
