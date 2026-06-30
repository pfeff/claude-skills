# Capture Operation

Stage eligible Readwise Reader documents into the vault's `raw/` queue (SPEC §2.1).

The deterministic core — the eligibility gate (`is_eligible`) and the idempotency key
(`source_key`) — lives in `kb_core` and is unit-tested (AC-1.2/1.3/1.4/1.6/1.7). The
Readwise read and the vault write are agent-orchestrated here (Readwise MCP +
`obsidian-notes` CLI), the same I/O-via-CLI shape as the `compound` skill.

## Inputs

- Optional: a specific Reader doc id/url. Blank → sweep the Reader inbox (`location="new"`).

## Steps

1. **Enumerate candidate Reader docs** — the named doc, or the inbox sweep set, via the
   Readwise MCP `reader_*` tools (e.g. `reader_list_documents` / `reader_get_document_details`).
   For each, gather: `id`, `url` (`source_url`), `title`, `author`, `created_at`, the doc's
   tags, and its highlights + notes.
2. **Evaluate eligibility** per source (SPEC §2.1) using
   `${CLAUDE_PLUGIN_ROOT}/skills/kb-core/scripts/kb_core.py`:
   - `has_capture_tag` = the `kb` tag (`kb_core.CAPTURE_TAG`) is present on the doc.
   - `highlight_count` / `notes_count` from the doc's highlights and notes.
   - `work_relevant` = **your** judgment of work-relevance scored against `WORK-DOMAINS.md`
     (AI/LLM content relevant only when tied to engineering/agent automation). This is the
     one non-deterministic input; everything else is mechanical.
   - Capture iff `kb_core.is_eligible(highlight_count, notes_count, has_capture_tag, work_relevant)`.
   - Record the deciding gate for skipped docs (for the report).
3. **Idempotency guard** — compute `key = kb_core.source_key(source)`. The raw artifact path
   is `raw/<key>.md`. If it already exists (probe with `obsidian-notes` `read`), skip — re-capture
   is a no-op (AC-1.6).
4. **Write the raw artifact** via the `obsidian-notes` skill (`create`), preserving origin
   metadata and highlights/notes unmodified (AC-1.1). Schema below.
5. **Zone safety** — the only write target is `raw/<key>.md`. Never write to or under
   `Generated/`, `Keywords/`, or any Human note (AC-1.5). `raw/` is a staging area, not one
   of the three edit-rule zones.

## raw/ artifact schema

`raw/` is a subtree of the **Obsidian vault** (resolved per-host by `obsidian-notes`; never
hardcoded). One note per source, filename `raw/<source_key>.md`:

```markdown
---
type: kb-raw
source_key: readwise-<id>
reader_id: <id>
url: <source_url>
title: <title>
author: <author>
captured: <ISO-8601 date>
reader_tags: [<tag>, ...]
tags: [kb-raw]
---

# <title>

## Highlights

> <highlight text 1>
> <highlight text 2>

## Notes

<note text, verbatim>
```

- `type: kb-raw` / `tags: [kb-raw]` mark this as the staging queue — deliberately **not**
  `generated_note` or `keyword`, so it is never mistaken for a Derived or Shared note.
- Highlights and notes are copied **verbatim** (AC-1.1) — capture does not summarize.

## Acceptance Criteria (SPEC §2.1)

AC-1.1 (staged with metadata/highlights), AC-1.2 (no-highlight/no-notes skipped),
AC-1.3 (notes count), AC-1.4 (irrelevant skipped unless tagged), AC-1.5 (zones untouched),
AC-1.6 (idempotent), AC-1.7 (tagged with zero highlights/notes captured).

## Integration Points

- `kb_core.is_eligible`, `kb_core.source_key`, `kb_core.CAPTURE_TAG` —
  `${CLAUDE_PLUGIN_ROOT}/skills/kb-core/scripts/kb_core.py`
- Readwise MCP `reader_*` tools — source documents
- `obsidian-notes` skill — vault path resolution + `raw/` writes
- `WORK-DOMAINS.md` (workspace) — work-relevance reference for step 2
