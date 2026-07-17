# Capture Operation

Stage eligible Readwise Reader documents into the vault's `raw/` queue (SPEC §2.1).

The deterministic core — the eligibility gate (`is_eligible`), the idempotency key
(`source_key`), and content-aware re-sync (`highlights_fingerprint`, `new_highlights`) —
lives in `kb_core` and is unit-tested (AC-1.2/1.3/1.4/1.6/1.7). The Readwise read and the
vault write are agent-orchestrated here (Readwise MCP + `obsidian-notes` CLI), the same
I/O-via-CLI shape as the `compound` skill.

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
3. **Idempotency guard — content-aware, not existence-only.** Compute
   `key = kb_core.source_key(source)` (pass the Readwise `book_id` for highlighted sources, or
   the Reader `id` for tagged/named docs). The raw artifact path is `raw/<key>.md`. Probe with
   `obsidian-notes` `read`.
   - **Missing** → go to step 4 (full capture).
   - **Present** → a bare existence check would treat this source as "done" forever, even
     when the operator later highlights more of it (the historical bug: source `62041720`
     gained highlights after its first capture and the sweep silently skipped it on every
     subsequent run, because existence alone can't distinguish "captured" from "captured, now
     stale"). Instead:
     1. Compute `current_hash = kb_core.highlights_fingerprint(current_highlights)` over the
        highlights/notes just fetched for this source.
     2. Read the existing note's `highlights_hash` frontmatter value (absent on notes written
        before this fix — treat as unknown and fall through to 3.4).
     3. `current_hash` matches the stored value → **skip**, true no-op (AC-1.6 preserved for
        the common case — nothing changed).
     4. Otherwise → parse the existing note's `## Highlights` section into `existing_texts`
        (one highlight per `> ` blockquote line, stripped of the prefix), then compute
        `kb_core.new_highlights(existing_texts, current_highlights)`.
        - **Empty** → nothing actually changed (e.g. an old note has no `highlights_hash` to
          compare against yet); skip, but still do the frontmatter-only rewrite in step 3a to
          backfill `highlights_hash` so the next sweep takes the fast path in 3.3.
        - **Non-empty** → go to step 3a: fold the new highlight(s) into the existing note.
   - **Dedup:** a source reachable both as a highlighted book and a Reader doc must be
     captured once — prefer the `book_id` key when it has highlights, so the two paths don't
     produce two `raw/` notes for the same source. (See also § Second Readwise pipeline below
     for the Obsidian-plugin case.)

3a. **Fold-in update** (reached from 3.4 when there's new content, or as a hash-only backfill
    when there isn't). Read the full existing note (`obsidian-notes` `read`):
    - Append the new highlight blockquote line(s) — `> <highlight text>` per line, verbatim,
      same convention as a fresh capture — to the end of the `## Highlights` section. Never
      reorder, delete, or edit an existing highlight; never touch `## Notes` or any other
      section.
    - Replace `highlights_hash` with `current_hash` (add the key if the note predates this
      fix).
    - Rewrite the note in full via `create ... overwrite` (the two-call
      `template:read`-free "read, modify, overwrite" shape — `property:set` cannot target
      `highlights_hash` because it isn't in the vault's property registry, the same reason
      `source_key`/`readwise_book_id` are hand-composed rather than `property:set`). Compose
      the frontmatter with `fm-emit.py` exactly as in step 4, and validate after writing.
    - Report this source as **updated** (not skipped, not freshly captured) in the sweep
      summary.

4. **Write the raw artifact** via the `obsidian-notes` skill (`create`), preserving origin
   metadata and highlights/notes unmodified (AC-1.1). Include `highlights_hash:
   "<current_hash>"` (from step 3's `kb_core.highlights_fingerprint`) in the frontmatter so a
   later sweep can take the fast no-op path in step 3.3. Schema below.
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
highlights_hash: "<sha256 of current highlights, kb_core.highlights_fingerprint>"
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
- `highlights_hash` is a backward-compatible addition: existing `raw/` notes written before
  this field existed simply lack it, and step 3.2 treats that as "unknown" rather than an
  error. `kb-compile`'s read contract only looks at `source_key`/`type`/`sources:`, so it is
  unaffected by this field either way (see kb-compile's `operations/compile.md`).

## Re-sync vs. skip

Re-running the sweep over an already-captured source now has three possible outcomes, not
two — worth calling out explicitly since it changes what "idempotent" means here:

| Outcome | When | Report as |
|---|---|---|
| Skip (no-op) | `highlights_hash` matches what was just fetched | "skipped — unchanged" |
| Fold-in update | fetched highlights include text not yet in the note | "updated — N new highlight(s)" |
| Fresh capture | `raw/<key>.md` doesn't exist yet | "captured" |

AC-1.6 ("re-capture is a no-op") now means *content-stable* re-capture is a no-op — a source
whose highlights haven't changed is still skipped exactly as before. A source whose highlights
*have* changed is no longer silently and permanently skipped (the bug this fixes).

## Second Readwise pipeline (Obsidian "Readwise Official" plugin) — reconciliation, not full integration

The vault also runs the community **Readwise Official** Obsidian plugin
(`.obsidian/plugins/readwise-official/`), which does its own content-level incremental sync
of the same Readwise library into a `Readwise/` vault folder, keyed by `book_id` via its own
`booksIDsMap`. This is a second, currently disconnected pipeline from this MCP-based sweep
into `raw/`. Fully hybridizing kb-capture to read the plugin's synced folder instead of
polling `readwise_list_highlights` (letting the plugin, which is free and already running,
own sync mechanics; kb-capture would then only filter + reformat into `raw/`) is a larger
rearchitecture deferred as follow-up — it needs the plugin's actual synced-note schema
inspected against a live vault to key off correctly, which is out of scope for this change
(see kb-capture `SKILL.md` § Follow-up).

**What's true today (2026-07-17 audit):** both pipelines key off the same Readwise `book_id` —
this sweep's `source_key` is `readwise-<book_id>`, and the plugin's `booksIDsMap` is also
`book_id`-keyed. But a shared key only makes duplicates **detectable**, not **prevented**: the
two pipelines write to different paths (`Readwise/` for the plugin, `raw/` for this sweep) and
this sweep never reads `Readwise/`, so nothing dedupes between them. The audit confirmed 18
duplicate `book_id`s already staged in both `raw/` (51 notes) and `Readwise/` (1196 notes). The
plugin only syncs on Obsidian load (auto-sync off, `frequency: 0`); its last sync predates this
sweep's first capture by two days, so today's 18 are a one-time backlog overlap rather than two
pipelines actively racing — but the other 33 `raw/` book_ids the plugin hasn't seen yet will
duplicate on its next sync, i.e. 100% of `raw/` will eventually have a plugin-side twin. No
code changes are needed *yet* because this sweep does not read the plugin's folder at all — but
the manual check below exists to catch duplicates that already occurred, not just to guard
against future id drift. The manual check for now: before compiling, cross-check the
`readwise_book_id` values already staged under `raw/*.md` against the plugin's `booksIDsMap`
(`.obsidian/plugins/readwise-official/data.json`); treat any match as a confirmed duplicate to
reconcile (drop or merge), not merely evidence of a hypothetical id-drift bug.

## Acceptance Criteria (SPEC §2.1)

AC-1.1 (staged with metadata/highlights), AC-1.2 (no-highlight/no-notes skipped),
AC-1.3 (notes count), AC-1.4 (irrelevant skipped unless tagged), AC-1.5 (zones untouched),
AC-1.6 (idempotent — content-stable re-capture is a no-op; changed sources are updated in
place, not skipped), AC-1.7 (tagged with zero highlights/notes captured).

## Integration Points

- `kb_core.is_eligible`, `kb_core.source_key`, `kb_core.CAPTURE_TAG`,
  `kb_core.highlights_fingerprint`, `kb_core.new_highlights` —
  `${CLAUDE_PLUGIN_ROOT}/skills/kb-core/scripts/kb_core.py`
- Readwise MCP `reader_*` tools — source documents
- `obsidian-notes` skill — vault path resolution + `raw/` writes
- `WORK-DOMAINS.md` (workspace) — work-relevance reference for step 2
