# Compile Operation

Incrementally compile un-compiled `raw/` sources into Derived summaries + Shared concept
notes (SPEC §1 + §2.2).

The load-bearing zone/fence primitives are implemented and unit-tested in `kb_core`
(`classify_zone`, `append_in_fence`, `fence_wrap` — AC-2.3/2.5/2.6). Source enumeration,
concept extraction, and the writes are agent-orchestrated here (`obsidian-notes` CLI),
guarded by those primitives. A live end-to-end run is exercised by the demo task.

## Billing guard

Interactive `/kb-compile` only — never invoke from cron / `claude -p` / Agent SDK (SPEC §6).

## Incrementality / idempotency (AC-2.2)

A raw source `raw/<key>.md` is **compiled** iff its Derived summary `Generated/<key>.md`
exists (`<key>` = the `source_key` from the raw note's frontmatter). Skip sources whose
summary already exists and whose raw note is unchanged. Re-running with no new sources
writes nothing.

## Steps

1. **Find un-compiled sources** — list `raw/*.md` (via `obsidian-notes` `read`/listing); for
   each, read `source_key` from frontmatter; skip if `Generated/<key>.md` already exists.
   raw notes are identified by `type: kb-raw` and are **not** run through `classify_zone`
   (they are the input queue, a staging area — see DESIGN DD-D).
2. For each un-compiled source:
   1. **Write a source-summary note → Derived** at `Generated/<key>.md` (schema below): an
      LLM summary of the source. `generated_note` tag + `sources:` provenance (INV-2/INV-3).
   2. **Extract concepts → Shared** (`Keywords/`): for each concept, resolve a target
      `Keywords/<concept>.md`:
      - **Absent** → create a new concept note (schema below) carrying `keyword` +
        `generated_note` + `sources:`.
      - **Exists** → read it, compute `append_in_fence(existing_text, body)`, write the
        result back. This appends inside `<!-- kb:generated start/end -->` only; human prose
        outside the fence is byte-for-byte unchanged (AC-2.3/AC-2.6).
      - **Guard:** call `classify_zone(frontmatter, path)` first. Only write when the target
        is SHARED (new/append) or DERIVED (free). **Never** write a note that classifies as
        HUMAN (AC-2.4).
   3. **Add backlinks**: link the summary ↔ each concept. Backlinks added into an existing
      Shared note go inside the fence.
3. **Maintain index/MOC notes** in Derived (`Generated/`) so the set stays navigable (AC-2.1).
4. **Validate output**: no broken `[[links]]`, valid frontmatter (AC-3.1).

## Derived summary schema (`Generated/<key>.md`)

```markdown
---
type: kb-summary
tags: [generated_note]
sources: ["readwise-<id>"]
source_url: <url>
compiled: <ISO-8601 date>
---

# <source title> — summary

<LLM summary>

## Concepts

- [[<concept A>]]
- [[<concept B>]]
```

## Shared concept note schema (`Keywords/<concept>.md`, when newly created)

```markdown
---
tags: [keyword, generated_note]
sources: ["readwise-<id>"]
---

# <concept>

<!-- kb:generated start -->
<LLM concept prose + [[backlinks]] to source summaries>
<!-- kb:generated end -->
```

When the concept note already exists, do **not** rewrite it — append via `append_in_fence`.

## Acceptance Criteria (SPEC §2.2, §2.3)

AC-2.1 (each source summarized + linked from ≥1 concept), AC-2.2 (idempotent re-run),
AC-2.3 (fenced append, no duplicate, human prose unchanged), AC-2.4 (Human zone untouched —
adversarial), AC-2.5 (INV-2/INV-3 on every write), AC-2.6 (fence-only append), AC-3.1
(valid links + frontmatter).

## Integration Points

- `kb_core.classify_zone`, `kb_core.append_in_fence`, `kb_core.fence_wrap` —
  `${CLAUDE_PLUGIN_ROOT}/skills/kb-core/scripts/kb_core.py`
- `obsidian-notes` skill — vault path resolution + writes
