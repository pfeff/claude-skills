# Capture Operation

Stage eligible Readwise sources into the vault's `raw/` queue (SPEC §2.1).

**Plugin-hybrid (2026-07-18):** per the operator-signed-off design
(`Notes/2026/07/2026-07-17-readwise-double-capture-audit-plugin-hybrid.md`), the Readwise
Official Obsidian plugin is now the *only* thing that talks to Readwise. It syncs into the
vault's local `Readwise/` folder; this operation reformats/filters from that folder into
`raw/` instead of polling `readwise_list_highlights`. `book_id` stays the identity key end to
end, so `source_key`/`highlights_fingerprint`/`new_highlights` and the `raw/` schema are
unchanged — only *where the highlights come from* (step 1) and *how they're parsed* (step 2)
changed. A narrow Reader MCP query is retained solely for the `kb`-tag override (Path B —
see § Second Readwise pipeline below), because Readwise never exports a zero-highlight
source into the plugin's folder at all.

The deterministic core — the eligibility gate (`is_eligible`), the idempotency key
(`source_key`), and content-aware re-sync (`highlights_fingerprint`, `new_highlights`) —
lives in `kb_core` and is unit-tested (AC-1.2/1.3/1.4/1.6/1.7). The plugin-folder parsing —
`book_id`/highlight/metadata extraction, dated-append-section aggregation, both backlink
forms, gen1/gen2 duplicate-file and duplicate-block merging — lives in `readwise_folder` and
is unit-tested (`skills/kb-capture/scripts/test_readwise_folder.py`). The vault reads/writes
are agent-orchestrated here (`obsidian-notes` CLI), the same I/O-via-CLI shape as the
`compound` skill.

## Inputs

- Optional: a specific Reader doc id/url (resolved via the narrow Path-B MCP query, same as
  before). Blank → **sweep the plugin's `Readwise/` folder** (step 1).

## Steps

1. **Enumerate candidate sources from the plugin's folder.** The operator's keepers are
   **highlighted, then archived** — so the primary signal is *highlighted sources*, not the
   inbox. Readwise's export only emits sources that *have* highlights, so the plugin's
   `Readwise/` folder is already pre-filtered to that population — there is no `location="new"`
   equivalent to worry about here. In priority order:
   - **(primary) The plugin's `Readwise/` folder.** Read every `Readwise/**/*.md` file
     (`obsidian-notes` `read`, or `Glob`+`Read` — bound the sweep to files modified since the
     last capture run if the folder is large; unless asked to go deeper, a full sweep is fine
     since parsing is cheap and local, no rate limits). Build `file_texts = {path: content}`
     and call `${CLAUDE_PLUGIN_ROOT}/skills/kb-capture/scripts/readwise_folder.py`'s
     `collect_sources(file_texts)`. This single call does all of the mechanical work:
     - Recovers `book_id` per source. **`book_id` stays the identity key** — a file/block with
       no `book_id` (gen1 exports, ~76% of the folder) cannot be captured this way and is
       skipped; this mirrors the design note's migration guidance to leave the id-less
       population alone, not force-migrate it.
     - Aggregates **every** dated `## New highlights added <date>` section a note has
       accumulated (the plugin appends, never rewrites — losing anything but the first
       section would silently truncate highlights added after the initial sync).
     - Handles both backlink forms transparently (`([View Highlight](...))` for
       articles/Reader docs, `([Location N](...))` for Kindle books — note the space before
       the Kindle location number is a non-breaking space, not ASCII, which is why this is a
       script and not an ad hoc grep).
     - Merges the plugin's gen1/gen2 intra-`Readwise/` duplication — both duplicate *files*
       (e.g. two "Perfect Health Diet" notes) and duplicate *blocks within one file* (the
       plugin has been observed to resolve some title collisions by concatenating a second
       source's complete export into the same file instead of writing a `-2.md` sibling) —
       deduped by highlight backlink URL, so the same highlight is never double-counted.
     - Each result is `{book_id: {"highlights": [...], "metadata": {...}, "paths": [...]}}`;
       each highlight is `{"text": str, "note": str, "backlink": str}` — directly compatible
       with `kb_core.highlights_fingerprint`/`new_highlights`, which only read `.text`/`.note`.
     Key: `source_key = kb_core.source_key({"id": book_id})` = `readwise-<book_id>`.
   - **(override) `kb`-tagged Reader docs** — `reader_list_documents(tag=["kb"])`, any
     location; captured unconditionally (Path B). This is the one path still using the
     Readwise MCP: Readwise never exports a zero-highlight source into the plugin's folder at
     all, so folder-parsing structurally cannot recover it (see § Second Readwise pipeline).
     Key: `source_key = readwise-<reader_id>`.
   - **(named input)** — if an id/url was passed, resolve just that source via the Path-B MCP
     query (`reader_get_document_details` + `reader_get_document_highlights`) if it's not
     found in the folder; prefer the folder's copy when both exist.
2. **Evaluate eligibility** per source (SPEC §2.1) using
   `${CLAUDE_PLUGIN_ROOT}/skills/kb-core/scripts/kb_core.py`:
   - `has_capture_tag` = the `kb` tag (`kb_core.CAPTURE_TAG`) is present (Path-B sources only —
     the plugin folder carries no reliable Reader-tag signal, see § Second Readwise pipeline).
   - `highlight_count` = `len(highlights)`; `notes_count` =
     `readwise_folder.notes_count(highlights)` — both from the `collect_sources` result.
   - `work_relevant` = **your** judgment of work-relevance scored against `WORK-DOMAINS.md`
     (AI/LLM content relevant only when tied to engineering/agent automation), reading the
     source's title/highlights. This is the one non-deterministic input; everything else is
     mechanical.
   - Capture iff `kb_core.is_eligible(highlight_count, notes_count, has_capture_tag, work_relevant)`.
   - Record the deciding gate for skipped sources (for the report).
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
   - **Dedup:** a source reachable both via the plugin folder (Path A) and the `kb`-tag
     override (Path B) must be captured once — prefer the `book_id` key when the folder has
     it, so the two paths don't produce two `raw/` notes for the same source. `collect_sources`
     already dedupes *within* the folder (duplicate files and duplicate blocks — see step 1);
     this bullet is about the folder-vs-Path-B boundary, which is the only remaining place two
     pipelines could still collide (see § Second Readwise pipeline below).

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
   - **Metadata source (Path A, folder-derived):** `title`/`author`/`url` come from
     `collect_sources(...)[book_id]["metadata"]` (`readwise_folder.extract_metadata` —
     best-effort across the plugin's coexisting note generations; empty string when
     unrecoverable, e.g. `url` is legitimately empty for a Kindle book with no source URL).
     `category` comes from the immediate subfolder the source's file(s) live under
     (`Readwise/Articles` → `articles`, `Readwise/Books` → `books`, `Readwise/Tweets` →
     `tweets`), not parsed from content. `reader_tags` is always `[]` — the plugin carries no
     reliable per-source Reader-tag signal (see § Second Readwise pipeline); this is
     unchanged from today's behavior (empirically dead code — all 51 pre-migration `raw/`
     notes already had `reader_tags: []`).
   - **Highlights body:** render each `collect_sources(...)[book_id]["highlights"]` entry as
     `> <highlight text>` (and its `note`, if non-empty, under `## Notes`), same convention as
     before — `kb-compile`'s read contract only looks at `source_key`/`type`/`sources:`, so
     the exact internal rendering doesn't need to match the plugin's own layout byte-for-byte,
     only preserve every highlight's text verbatim (AC-1.1).
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

## Second Readwise pipeline (Obsidian "Readwise Official" plugin) — now the only sync mechanism

**Adopted (2026-07-18).** The vault runs the community **Readwise Official** Obsidian plugin
(`.obsidian/plugins/readwise-official/`), which does its own content-level incremental sync
of the Readwise library into the `Readwise/` vault folder, keyed by `book_id` via its own
`booksIDsMap`. This *used to be* a second, disconnected pipeline racing this sweep's MCP polls
into `raw/` — the audit found 18 confirmed, then 51 (100% of `raw/`) after a plugin re-sync,
duplicate `book_id`s staged in both places. That risk is now structurally closed: this sweep
no longer polls Readwise at all for Path A. The plugin is the *only* thing that talks to
Readwise; this operation only reformats its local output. See
`Notes/2026/07/2026-07-17-readwise-double-capture-audit-plugin-hybrid.md` for the full audit
and rearchitecture rationale (Proposal / Verified findings / Migration path sections).

**Prerequisite this design inherits, not resolves:** the plugin must actually run
(`frequency` set to a real interval, not `0`) for Path A to ingest anything — a dormant
plugin under this design means no ingestion at all, since kb-capture no longer has an
independent MCP fallback for Path A. This is a config change on the plugin side, not
something this operation can enforce; flag it if a sweep finds nothing new for an
implausibly long stretch.

**What Path B (`kb`-tag override) still needs the MCP for, and why it can't move to the
folder:** Readwise's export only emits sources that *have* highlights, so a `kb`-tagged
source with **zero** highlights is never written into `Readwise/` at all — no amount of
folder-parsing can recover it. The plugin's `tags:` frontmatter also carries only the
Readwise *category* (`#articles`/`#tweets`/`#books`), never the operator's `kb` tag — 0/1196
plugin notes in the audited vault carried it. The narrow `reader_list_documents(tag=["kb"])`
query in step 1 exists solely to keep this path alive; it is cheap (one filtered query, not a
full sweep) and, per the audit, empirically dead code today (all pre-migration `raw/` notes
had `reader_tags: []` — Path B has never fired) — kept per the design note's explicit
"do not silently drop it" guidance rather than retired outright.

**Migration note (one-time, already applied 2026-07-18):** the 18/51 duplicates between
`raw/` and `Readwise/` that motivated this rearchitecture are inert going forward — `raw/`
notes already staged are untouched by this change (idempotency is content-fingerprint-keyed,
so re-running the sweep over a source whose folder-derived content is unchanged is a no-op,
not a rewrite), and no backfill/reconciliation pass was required as a precondition for this
PR. If a stronger cleanup (e.g. deduping the pre-existing 51 against `Readwise/`) is wanted,
track it as separate follow-up — out of scope here.

**Not carried forward from the design note (verify against a live vault, not assumed):** a
single `Readwise/` file can hold more than one independently-frontmattered source
concatenated together — observed on 5/1235 notes in the audited vault as the plugin's
resolution of a title collision (writing a second complete export into the same file instead
of a `-2.md` sibling), rather than the design note's assumed 1-file-to-≤1-`book_id` shape.
`readwise_folder.split_into_book_blocks` handles this; see its docstring and
`test_readwise_folder.py`'s `TestSplitIntoBookBlocks`/`TestCollectSources` for the concrete
case. Flagging this here since it's a correction to the design note's Identity section
("filename is not an identity key... -2/-3 suffixes on collision"), discovered during
implementation rather than during the original audit.

## Acceptance Criteria (SPEC §2.1)

AC-1.1 (staged with metadata/highlights), AC-1.2 (no-highlight/no-notes skipped),
AC-1.3 (notes count), AC-1.4 (irrelevant skipped unless tagged), AC-1.5 (zones untouched),
AC-1.6 (idempotent — content-stable re-capture is a no-op; changed sources are updated in
place, not skipped), AC-1.7 (tagged with zero highlights/notes captured).

## Integration Points

- `kb_core.is_eligible`, `kb_core.source_key`, `kb_core.CAPTURE_TAG`,
  `kb_core.highlights_fingerprint`, `kb_core.new_highlights` —
  `${CLAUDE_PLUGIN_ROOT}/skills/kb-core/scripts/kb_core.py`
- `readwise_folder.collect_sources` (and its primitives — `extract_book_id`,
  `split_into_book_blocks`, `split_sections`, `extract_highlights`, `merge_highlights`,
  `extract_metadata`, `notes_count`) —
  `${CLAUDE_PLUGIN_ROOT}/skills/kb-capture/scripts/readwise_folder.py` — Path A source
- The plugin's `Readwise/` vault folder — Path A source documents (read via `obsidian-notes`
  or `Glob`+`Read`, no MCP call)
- Readwise MCP `reader_*` tools — Path B (`kb`-tag override) only
- `obsidian-notes` skill — vault path resolution + `raw/` writes
- `WORK-DOMAINS.md` (workspace) — work-relevance reference for step 2
