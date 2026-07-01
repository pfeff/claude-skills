# Compile Operation

Incrementally compile un-compiled `raw/` sources into the vault's native knowledge notes
(SPEC v2 §2.2): per-source summaries + fuller concept notes in `Notes/`, cross-linked to
`Keywords/` and surfaced through a KB MOC.

The deterministic primitives are implemented and unit-tested in `kb_core` (`source_key`,
`is_writable`, `concept_slug`). Source enumeration, summarization, concept extraction, and
the writes are agent-orchestrated here (`obsidian-notes` CLI). Edit safety is git + review
(INV-5) — there is no fence.

## Billing guard

Interactive `/kb-compile` only — never invoke from cron / `claude -p` / Agent SDK (SPEC v2 §6).

## Write boundary (INV-1)

Before **any** write, require `kb_core.is_writable(path)` — never write under
`DevOps Documentation/` or `Confluence/`. Also respect task-scope: do not edit notes
unrelated to the current compile (no incidental reorganization). All KB writes are
git-reviewable diffs.

## Incrementality / idempotency (AC-2.2)

A raw source `raw/<key>.md` is **compiled** once its summary note exists (a `type: reference`
note in `Notes/` whose `sources:` contains `<key>`). Skip sources already summarized whose
raw note is unchanged. Re-running with no new sources writes nothing.

## Steps

1. **Find un-compiled sources** — list `raw/*.md`; for each read `source_key`; skip if a
   summary note already carries that key in `sources:`.
2. For each un-compiled source:
   1. **Summary → `Notes/YYYY/MM/`** (`type: reference`, schema below): an LLM summary of the
      source, `sources: [<key>]`, `project: knowledge-base`, `tags: [kb]`, `keywords:` links.
   2. **Concepts → `Notes/YYYY/MM/`** (`type: zettel`): for each concept the source covers,
      compute `kb_core.concept_slug(title)` and look for an existing KB concept note with
      that slug (a `project: knowledge-base` zettel):
      - **Found** → **update it in place**: incorporate the new source's contribution and add
        a backlink to the summary. Free-edit (git-reviewable); no duplicate note (AC-2.3).
      - **Absent** → create a new concept note (schema below).
   3. **Keywords/ cross-link** — each concept note `[[links]]` to the vault's `Keywords/`
      term page(s). If a genuinely new domain term has no page, create a short `Keywords/`
      stub; an existing page may be elaborated. These are free-edit, git-reviewable writes.
   4. **Backlinks** between summary ↔ concept ↔ keyword.
3. **Maintain the KB MOC** (`type: moc`, schema below) — an index note with a Dataview block
   over `project: knowledge-base` (or the `kb` tag), so the compiled set is navigable (AC-2.1).
4. **Validate**: no broken `[[links]]`, valid frontmatter; new notes appear in the MOC
   rollup (AC-3.1).

## Schemas

**Summary** (`Notes/YYYY/MM/<date>-<slug>.md`):
```markdown
---
type: reference
project: knowledge-base
tags: [kb]
sources: ["readwise-<id>"]
source_url: <url>
date: <YYYY-MM-DD>
keywords: ["[[<Keyword>]]", ...]
---
# <source title> — summary
<LLM summary>
## Concepts
- [[<concept note>]]
```

**Concept** (`Notes/YYYY/MM/<date>-<concept-slug>.md`, `type: zettel`) — fuller than a
keyword page; `project: knowledge-base`, `sources:` accumulates every contributing source,
body cross-links to `Keywords/` pages and back to the summaries. Updated in place on re-compile.

**KB MOC** (`type: moc`, `project: knowledge-base`) — an index with a `dataview` block listing
KB sources/summaries/concepts.

## Acceptance Criteria (SPEC v2 §2.2)

AC-2.1 (summaries linked from ≥1 concept), AC-2.2 (idempotent re-run), AC-2.3 (concept
updated in place, no duplicate), AC-2.4 (bounded writes — off-limits/unrelated untouched),
AC-2.5 (type: + sources: + MOC routing), AC-2.6 (Keywords/ cross-link, reversible), AC-3.1
(valid links/frontmatter, appears in MOC rollup).

## Integration Points

- `kb_core.source_key`, `kb_core.is_writable`, `kb_core.concept_slug`, `kb_core.KB_PROJECT`,
  `kb_core.TYPE_*` — `${CLAUDE_PLUGIN_ROOT}/skills/kb-core/scripts/kb_core.py`
- `obsidian-notes` skill — vault path resolution + writes
