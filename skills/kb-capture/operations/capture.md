# Capture Operation

Stage eligible Readwise Reader documents into the vault's `raw/` queue (SPEC §2.1).

The deterministic core — the eligibility gate (`is_eligible`) and the idempotency key
(`source_key`) — lives in `kb_core` and is unit-tested (AC-1.2/1.3/1.4/1.6/1.7). The
Readwise read and the vault write are agent-orchestrated here (Readwise MCP +
`obsidian-notes` CLI), the same I/O-via-CLI shape as the `compound` skill.

## Inputs

- Optional: a specific Reader doc id/url. Blank → **sweep highlighted sources** (step 1).

## Steps

1. **Enumerate candidate sources.** The operator's keepers are **highlighted, then
   archived** — so the primary signal is *highlighted sources*, not the inbox. A freshly
   saved, unhighlighted, untagged doc is exactly what the highlight gate is meant to exclude,
   so **do not default to `location="new"`.** Enumerate, in priority order:
   - **(primary) Highlighted sources** — `readwise_list_highlights` (the Readwise highlights
     library), grouped by `book_id`. Every highlighted source is a candidate. Gather
     `book_id`, `book_title`, `book_author`, `book_source_url`, `book_category`, `book_tags`,
     and each highlight's `text`/`note`/`highlighted_at`. Page from most-recent and **bound the
     window** (e.g. last N pages, or `highlighted_at_gt` a date) unless asked to go deeper —
     the library can hold tens of thousands of highlights. Key: `source_key = readwise-<book_id>`.
   - **(override) `kb`-tagged Reader docs** — `reader_list_documents(tag=["kb"])`, any
     location; captured unconditionally (Path B). Key: `source_key = readwise-<reader_id>`.
   - **(named input)** — if an id/url was passed, resolve just that source
     (`reader_get_document_details` + `reader_get_document_highlights`, or `readwise_list_highlights(book_id=…)`).

   Large highlight pages can exceed the response limit and be saved to a file — page through
   with `jq`/a script rather than loading the whole payload into context.
2. **Evaluate eligibility** per source (SPEC §2.1) using
   `${CLAUDE_PLUGIN_ROOT}/skills/kb-core/scripts/kb_core.py`:
   - `has_capture_tag` = the `kb` tag (`kb_core.CAPTURE_TAG`) is present on the doc.
   - `highlight_count` / `notes_count` from the doc's highlights and notes.
   - `work_relevant` = **your** judgment of work-relevance scored against `WORK-DOMAINS.md`
     (AI/LLM content relevant only when tied to engineering/agent automation). This is the
     one non-deterministic input; everything else is mechanical.
   - Capture iff `kb_core.is_eligible(highlight_count, notes_count, has_capture_tag, work_relevant)`.
   - Record the deciding gate for skipped docs (for the report).
3. **Idempotency guard** — compute `key = kb_core.source_key(source)` (pass the Readwise
   `book_id` for highlighted sources, or the Reader `id` for tagged/named docs). The raw
   artifact path is `raw/<key>.md`. If it already exists (probe with `obsidian-notes` `read`),
   skip — re-capture is a no-op (AC-1.6). **Dedup:** a source reachable both as a highlighted
   book and a Reader doc must be captured once — prefer the `book_id` key when it has highlights,
   so the two paths don't produce two `raw/` notes for the same source.
4. **Write the raw artifact** via the `obsidian-notes` skill (`create`), preserving origin
   metadata and highlights/notes unmodified (AC-1.1). Schema below.
   - **Compose the frontmatter with `fm-emit.py` when it's installed, not by hand.** `title` and
     `author` routinely contain a bare `: ` (e.g. "Claude Sonnet 5 vs Opus 4.8: Which Model…"),
     plus `#`, `[`, or a leading `@` — unquoted, any of these breaks the `---`...`---` block, and
     the Obsidian CLI writes `create`'s `content=` unvalidated, so the corruption is silent. Check
     for the helper first:

     ```bash
     FM_EMIT="$HOME/.claude/skills/obsidian-notes/scripts/fm-emit.py"
     [[ -x "$FM_EMIT" ]] || FM_EMIT=""
     ```

     - **If present**: build the frontmatter via `fm-emit.py key=value [...]` and splice its
       output into `content=` rather than hand-rolling the YAML. `key=value` can't express
       list-valued keys (`reader_tags`, `tags`) — every arg becomes a string scalar — so use
       `fm-emit.py --json` for any source carrying those fields.
     - **If absent** (the companion `fm-emit.py` install hasn't landed on this host yet):
       hand-compose the frontmatter, but YAML-quote every string scalar per the rule below
       (double-quote `title`, `author`, `url`, `category`, `captured`, `source_key`, and each
       `reader_tags` element — anything with a bare `: `, `#`, `[`, or leading `@`), and write
       list-valued keys as a quoted YAML flow list (e.g. `reader_tags: ["ai", "agents"]`) rather
       than a bare comma string. Skip the validate sub-step below and emit the non-blocking note
       `[obsidian-notes] fm-emit.py not installed — composed frontmatter manually, quoted scalars`.
   - **Validate after writing** (only when `fm-emit.py` was used to compose). Run
     `fm-emit.py --validate <path>` against the note just created. On failure, surface it as
     `[obsidian-notes] <message>` per the skill's non-blocking failure contract (report the source
     as unstaged) rather than leaving a silently-corrupt `raw/` note.
5. **Write boundary** — the only write target is `raw/<key>.md`; capture writes nowhere else
   (AC-1.5). `raw/` is a verbatim staging area, the only KB-specific folder. **A source's own
   Reader tags go in the `reader_tags` key, never in `tags`** — so captured content can never
   inject the `kb` capture tag or `project: knowledge-base` routing and be mistaken for
   KB-authored output (INV-2).

## raw/ artifact schema

`raw/` is a subtree of the **Obsidian vault** (resolved per-host by `obsidian-notes`; never
hardcoded). One note per source, filename `raw/<source_key>.md`:

```markdown
---
type: kb-raw
source_key: "readwise-<id>"
readwise_book_id: <book id>   # highlighted sources  (OR: reader_id: <id> for tagged/named docs)
url: "<source_url>"
title: "<title>"
author: "<author>"
category: "<category>"
captured: "<ISO-8601 date>"
reader_tags: ["<tag>", ...]
tags: [kb-raw]
---

# <title>

## Highlights

> <highlight text 1>
> <highlight text 2>

## Notes

<note text, verbatim>
```

- `type: kb-raw` marks this as the staging queue — deliberately not a compiled-note type
  (`reference`/`zettel`) and carrying no `project: knowledge-base` routing, so it is never
  mistaken for compiled KB output.
- Every string scalar (`title`, `author`, and any other free text) MUST be YAML-quoted, as
  shown above — compose the block with `fm-emit.py` when available (Step 4), or by hand with
  the same quoting rule when it isn't.
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
