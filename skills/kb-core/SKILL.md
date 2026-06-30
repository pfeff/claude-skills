---
name: kb-core
description: "Shared library for the LLM Knowledge Base skills (kb-capture, kb-compile, kb-lint). Holds the SPEC §1 authorship-boundary primitives — zone classification, the Shared append-fence, provenance/idempotency helpers — in one place so the three skills cannot drift on the non-destruction invariant (INV-1). Reference/infrastructure content, not user-invocable; the three KB skills load its scripts."
version: 0.1.0
---

# KB Core (shared library)

Shared infrastructure for the three LLM-Knowledge-Base skills. **Not user-invocable** —
there is no operation to run here (precedent: `lN-lifecycle-doctrine`). It exists so the
load-bearing authorship-boundary logic from SPEC §1 lives in exactly one place.

## What it provides

`scripts/kb_core.py` — pure, vault-I/O-free primitives consumed by kb-capture, kb-compile,
and kb-lint:

- **Zone model** (`Zone`, `classify_zone`) — Derived / Shared / Human edit-rule zones,
  marker-authoritative with subtree as the organizational default (INV-2).
- **Append fence** (`FENCE_START`, `FENCE_END`, `fence_wrap`, `has_fence`,
  `append_in_fence`) — the `<!-- kb:generated start/end -->` mechanism that confines all
  LLM appends to existing Shared notes, leaving human prose byte-for-byte unchanged
  (INV-1, AC-2.3/AC-2.6).
- **Provenance / idempotency** (`GENERATED_TAG`, `KEYWORD_TAG`, `CAPTURE_TAG`,
  `source_key`) — frontmatter markers (INV-3) and the stable key that makes re-capture /
  re-compile no-ops (INV-4).

## Status

Scaffold: constants and the pure fence string-helpers are implemented; the behavioral
functions (`classify_zone`, `append_in_fence`, `source_key`) are declared with their
contracts and raise `NotImplementedError` until the per-skill tasks implement them
test-first.

## Tests

```
cd skills/kb-core/scripts && python3 -m unittest test_kb_core
```

Stdlib `unittest` (zero-dependency, matches `task-workflow/scripts/test_render_deps.py`).

## See Also

- `SPEC.md` §1 (workspace) — the authorship-boundary contract these primitives enforce.
- `skills/kb-capture`, `skills/kb-compile`, `skills/kb-lint` — the three consumers.
