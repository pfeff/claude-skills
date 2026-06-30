# Compile Operation

Incrementally compile un-compiled `raw/` sources into Derived summaries + Shared concept
notes (SPEC §1 + §2.2).

**Scaffold:** this operation defines the contract; the steps below are implemented in the
kb-compile task, TDD against AC-2.1…AC-2.6 and AC-3.1. Until then it is a specification,
not a runnable procedure.

## Billing guard

Interactive `/compile` only — never invoke from cron / `claude -p` / Agent SDK (SPEC §6).

## Steps (to implement)

1. **Find un-compiled sources** in the vault `raw/` queue; skip already-compiled, unchanged
   ones via `kb_core.source_key` (incrementality, AC-2.2).
2. For each source:
   1. **Write a source-summary note → Derived** (`Generated/`), with `generated_note` tag
      and `sources:` provenance (INV-2/INV-3).
   2. **Extract concepts → Shared** (`Keywords/`): for each concept, either create a new
      concept note (carrying `keyword` + `generated_note` + `sources:`), or
      `kb_core.append_in_fence(existing_text, body)` into an existing note — leaving all
      text outside the fence byte-for-byte unchanged (AC-2.3/AC-2.6).
   3. **Add backlinks** between the summary and its concepts; backlinks into a Shared note
      go inside the fence.
3. **Maintain index/MOC notes** in Derived so the set stays navigable (AC-2.1).
4. **Zone guard** via `kb_core.classify_zone`: never write to a Human-zone note (AC-2.4);
   Shared writes limited to new notes + fenced appends (INV-1).
5. **Validate output**: no broken `[[links]]`, valid frontmatter (AC-3.1).
6. **Mark sources compiled.**

## Acceptance Criteria (SPEC §2.2, §2.3)

AC-2.1 (each source summarized + linked from ≥1 concept), AC-2.2 (idempotent re-run),
AC-2.3 (fenced append, no duplicate, human prose unchanged), AC-2.4 (Human zone untouched —
adversarial), AC-2.5 (INV-2/INV-3 on every write), AC-2.6 (fence-only append), AC-3.1
(valid links + frontmatter).

## Integration Points

- `kb_core` — `${CLAUDE_PLUGIN_ROOT}/skills/kb-core/scripts/kb_core.py`
- `obsidian-notes` skill — vault path resolution + writes
