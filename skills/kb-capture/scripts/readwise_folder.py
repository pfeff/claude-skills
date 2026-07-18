#!/usr/bin/env python3
"""Deterministic parser for the Readwise Official Obsidian plugin's `Readwise/` folder.

kb-capture's Path A source used to be a live MCP sweep (`readwise_list_highlights`). Per the
2026-07-18 operator-signed-off plugin-hybrid design
(vault `Notes/2026/07/2026-07-17-readwise-double-capture-audit-plugin-hybrid.md`), the plugin
now owns sync mechanics and kb-capture only reformats its local `Readwise/` output. This
module holds the mechanical parsing that reformat needs: recovering `book_id`, aggregating
every dated "## New highlights added <date>" append-section a note has accumulated, and
extracting highlight text from both Readwise backlink forms. No vault I/O happens here — the
operation doc drives file reads/writes; this module is pure text-in, data-out (mirrors
kb_core.py's split between deterministic core and agent-orchestrated I/O).
"""

import re


# --- Backlink forms (verified 2026-07-18 against a live vault) --------------
#
# - Reader/web sources:  ([View Highlight](https://read.readwise.io/read/<id>))
# - Kindle books:        ([Location 3132](https://readwise.io/to_kindle?...))
#
# The space between "Location" and the number is U+00A0 (NBSP) in live plugin notes, not
# ASCII 0x20 — a literal " " in the pattern silently matches nothing. `\s` matches NBSP under
# Python's default (Unicode) `re` semantics, so it is used here instead of a literal space.
_BACKLINK_RE = re.compile(r"\(\[(?:View\s+Highlight|Location\s+\d+)\]\(([^)]+)\)\)")

# The plugin appends a new dated section on every sync rather than rewriting the note
# (verified on a live multi-sync note). It does not reliably insert a newline before the
# appended heading — on one live note the previous highlight's closing backlink and the new
# heading share one physical line — so section splitting is marker-anchored, not
# line-anchored.
_SECTION_MARKER_RE = re.compile(r"##\s*New highlights added [^\n]*")

_BOOK_ID_RE = re.compile(r"^book_id:\s*(\d+)\s*$", re.MULTILINE)

_NOTE_LINE_RE = re.compile(r"^\s*[-*]\s*Note:\s*(.*)$")

# A genuine CommonMark ATX heading requires whitespace after the "#" run — "#1: Know Your
# Objective" (a live highlighted line, no space after the hash) is NOT a heading and must not
# be filtered as one; "## Deciding What to Work On" / "#### Manganese" (both live,
# space-separated) are.
_ATX_HEADING_RE = re.compile(r"^#+\s")

# Zero or more "- Note: ..." lines (optionally preceded by blank lines) immediately
# following a highlight's backlink — the annotation(s) that belong to THAT highlight.
_TRAILING_NOTES_RE = re.compile(r"\A(?:[ \t]*\n)*((?:[ \t]*[-*]\s*Note:.*\n?)+)")

_FRONTMATTER_RE = re.compile(r"\A---\n(.*?)\n---", re.DOTALL)
_FRONTMATTER_STRIP_RE = re.compile(r"\A---\n.*?\n---\n?", re.DOTALL)

_METADATA_BULLET_RE = re.compile(
    # `[ \t]*` (not `\s*`) after the colon — `\s` matches newlines too, which would let a
    # blank value (e.g. "* URL: \n") swallow the following bullet line whole (caught against
    # a live "Zero to One.md" note whose URL bullet is empty).
    r"^\s*[-*]\s*(Author|Full Title|URL):[ \t]*(.*)$", re.MULTILINE
)

# Content before the LAST "## Highlights" heading in a section is preamble (YAML
# frontmatter's own "---" delimiters, or the "## Metadata" author/title/URL bullet block) —
# never highlight text. Only the initial section can carry this preamble; dated append-
# sections start directly with highlight bullets in every live sample seen, so trimming is a
# no-op for those.
_HIGHLIGHTS_HEADING_RE = re.compile(r"##\s*Highlights\b[^\n]*\n?")


def _trim_to_highlights_body(section: str) -> str:
    body_start = 0
    for m in _HIGHLIGHTS_HEADING_RE.finditer(section):
        body_start = m.end()
    return section[body_start:]


# Matches a whole "---\n...\n---\n" frontmatter block wherever it occurs in a file, not just
# at position 0 — needed because the plugin has been observed to resolve some title
# collisions by concatenating a second source's complete export (own frontmatter, own
# "## Metadata", own "## Highlights") into the SAME file instead of writing a "-2.md"
# sibling, verified live on 5/1235 `Readwise/` notes (e.g. two distinct `book_id`s sharing
# one "Google - Site Reliability Engineering.md"). `re.MULTILINE` so `^` anchors at each
# embedded block's own start, not just the file start.
_FRONTMATTER_BLOCK_RE = re.compile(r"^---\n.*?\n---\n?", re.DOTALL | re.MULTILINE)


def split_into_book_blocks(text: str) -> list:
    """Split a plugin note into independent book-blocks.

    Ordinarily a file holds exactly one source and this returns a single-element list. But
    see `_FRONTMATTER_BLOCK_RE` above — some files hold two (never more, in the live vault)
    complete, independently-frontmattered source exports concatenated together. Splitting on
    frontmatter-block boundaries, rather than assuming one file is one source, is required so
    a second embedded source's highlights are not silently discarded (the bug this fixes:
    naive "trim to the file's `## Highlights` heading" logic found the *last* one and threw
    away an entire first source's worth of highlights).

    A file with no frontmatter at all (e.g. a dated-append-only gen1 note) is a single block
    covering the whole file, same as before this function existed.
    """
    marks = list(_FRONTMATTER_BLOCK_RE.finditer(text))
    if not marks:
        return [text]
    boundaries = [m.start() for m in marks] + [len(text)]
    blocks = []
    if boundaries[0] > 0:
        blocks.append(text[: boundaries[0]])  # rare: stray prose before the first frontmatter
    for i in range(len(marks)):
        blocks.append(text[boundaries[i] : boundaries[i + 1]])
    return blocks


def extract_book_id(text: str) -> str | None:
    """Return the `book_id` frontmatter value as a string, or None if the note has none.

    Only a minority of plugin notes carry `book_id` (gen1 exports predate it) — callers must
    treat a miss as "this source can't be identity-keyed," not as an error. `book_id` stays
    the sole identity key for capture (design note, Identity section); id-less notes are out
    of scope here, same as the design note's migration guidance.
    """
    m = _BOOK_ID_RE.search(text)
    return m.group(1) if m else None


def split_sections(text: str) -> list:
    """Split a plugin note into its append-history.

    Returns the initial section (everything before the first dated marker — the plugin's
    original sync; may itself be empty for notes that only ever had append-sections) followed
    by one section per "## New highlights added <date>" marker found, in document order.
    Every character of `text` is accounted for exactly once, so aggregating highlights across
    the returned sections cannot lose or double-count content relative to the source file.
    """
    marks = list(_SECTION_MARKER_RE.finditer(text))
    if not marks:
        return [text]
    sections = [text[: marks[0].start()]]
    for i, m in enumerate(marks):
        end = marks[i + 1].start() if i + 1 < len(marks) else len(text)
        sections.append(text[m.start() : end])
    return sections


def extract_highlights(text: str) -> list:
    """Extract every highlight in one plugin note, aggregated across all of its dated
    append-sections (via `split_sections`). Each result is
    ``{"text": str, "note": str, "backlink": str}``. Handles both backlink forms (View
    Highlight / Location N) transparently — the caller never needs to know which one a given
    highlight used. Order-preserving; not deduped across files — see `merge_highlights` for
    the gen1/gen2 duplicate-file case.
    """
    text = _FRONTMATTER_STRIP_RE.sub("", text, count=1)
    highlights = []
    for section in split_sections(text):
        highlights.extend(_extract_section_highlights(_trim_to_highlights_body(section)))
    return highlights


def _extract_section_highlights(section: str) -> list:
    """One section's highlights. A highlight's span is everything since the previous
    backlink in this section (or the section start, for the first one) through and including
    its own backlink — the plugin closes each highlight's block with exactly one backlink.
    Lines that are pure document-outline structure (the plugin nests a highlight under its
    containing headings, rendered as "- ## Heading" bullets, or as a bare "#### Heading" line
    with its own Location backlink — verified live in a Kindle book export) are dropped
    rather than folded into the highlight text. Identified by the CommonMark ATX-heading
    shape — one or more "#" followed by whitespace — not merely "starts with #": a highlight
    can legitimately start with a bare "#" as its own content (verified live, e.g. a
    highlighted "#1: Know Your Objective" list heading from an article), and `#1` has no
    space after the hash so it does not match a real heading.

    A Readwise annotation renders as a "- Note: ..." line *after* the highlight's own
    backlink, before the next highlight begins (verified live, e.g. "How might one use this
    client? (…)" followed on the next line by "- Note: #Question") — so notes are
    attached by scanning forward from each backlink, not backward with the highlight text.
    """
    matches = list(_BACKLINK_RE.finditer(section))
    results = []
    cursor = 0
    for m in matches:
        span = section[cursor : m.end()]
        cursor = m.end()

        text_parts = []
        for line in span.splitlines():
            # Skip a leading "- Note: ..." line UNLESS it carries this highlight's own
            # backlink — Readwise can render a highlight whose entire visible text is inside
            # a "- Note: <text> (backlink)" line with nothing else (verified live: a
            # "#### Magnesium:" sub-heading followed directly by
            # "- Note: Taking vitamin D... ([View Highlight](url))" and nothing between). A
            # true trailing annotation line (handled below) never carries a backlink itself.
            if _NOTE_LINE_RE.match(line) and not _BACKLINK_RE.search(line):
                continue  # trails the PREVIOUS highlight's backlink; handled below
            cleaned = _BACKLINK_RE.sub("", line)
            cleaned = re.sub(r"^\s*[-*]\s*", "", cleaned).strip()
            if not cleaned or _ATX_HEADING_RE.match(cleaned):
                continue
            text_parts.append(cleaned)
        highlight_text = " ".join(text_parts).strip()

        note_parts = []
        trailing_m = _TRAILING_NOTES_RE.match(section[m.end() :])
        if trailing_m:
            for line in trailing_m.group(1).splitlines():
                note_m = _NOTE_LINE_RE.match(line)
                if note_m:
                    note_parts.append(note_m.group(1).strip())

        if not highlight_text:
            continue
        results.append(
            {
                "text": highlight_text,
                "note": " ".join(note_parts).strip(),
                "backlink": m.group(1),
            }
        )
    return results


def merge_highlights(highlight_lists) -> list:
    """Merge highlights recovered from multiple files that resolve to the same `book_id` —
    the plugin's gen1/gen2 intra-`Readwise/` duplication (e.g. two "Perfect Health Diet"
    notes coexisting in `Readwise/Books/`). Dedupes by backlink URL, the stable per-highlight
    identity Readwise assigns, falling back to normalized text for the (unexpected, given
    `extract_highlights` always requires a backlink) case of a keyless entry. Preserves
    first-seen order across the input lists.
    """
    seen = set()
    merged = []
    for highlights in highlight_lists:
        for h in highlights:
            key = h.get("backlink") or h["text"].strip().lower()
            if key in seen:
                continue
            seen.add(key)
            merged.append(h)
    return merged


def group_by_book_id(file_texts: dict) -> dict:
    """Group plugin note file contents by `book_id`, so callers can detect and merge
    gen1/gen2 duplicate files before capture. ``file_texts`` maps vault-relative path to file
    content. Files with no recoverable `book_id` are omitted from the result — identity is
    book_id-keyed, so id-less notes are out of scope for capture (same as the design note's
    migration guidance: the id-less population is left alone, not force-migrated).
    """
    groups: dict = {}
    for path, text in file_texts.items():
        book_id = extract_book_id(text)
        if book_id is None:
            continue
        groups.setdefault(book_id, []).append(path)
    return groups


def extract_metadata(text: str) -> dict:
    """Best-effort title/author/url extraction across the plugin's coexisting note
    generations (frontmatter `url:`/`author:`, a "## Metadata" bullet block, an H1 title
    line, or none of the above). Missing fields come back as "" rather than raising — callers
    fall back to other signals (e.g. the filename for title, the containing folder for
    category) when a field is empty.
    """
    meta = {"title": "", "author": "", "url": ""}

    fm_match = _FRONTMATTER_RE.match(text)
    fm = fm_match.group(1) if fm_match else ""

    # `[ \t]*` (not `\s*`) after the colon, same reasoning as `_METADATA_BULLET_RE` — an
    # empty `url:`/`author:` value followed by a blank line must not let `\s*` cross the
    # newline and swallow the next frontmatter key as the "value".
    url_m = re.search(r"^url:[ \t]*(.+)$", fm, re.MULTILINE)
    if url_m:
        meta["url"] = url_m.group(1).strip()

    author_m = re.search(r"^author:[ \t]*\[\[(.*?)\]\]", fm, re.MULTILINE)
    if author_m:
        meta["author"] = author_m.group(1).strip()
    else:
        plain_author_m = re.search(r"^author:[ \t]*(.+)$", fm, re.MULTILINE)
        if plain_author_m:
            meta["author"] = plain_author_m.group(1).strip()

    title_m = re.search(r"^#\s+(.+?)\s*(?:\(highlights\))?\s*$", text, re.MULTILINE)
    if title_m:
        meta["title"] = title_m.group(1).strip()

    for bullet_m in _METADATA_BULLET_RE.finditer(text):
        key, val = bullet_m.group(1), bullet_m.group(2).strip()
        val = re.sub(r"^\[\[|\]\]$", "", val)
        if key == "Full Title" and not meta["title"]:
            meta["title"] = val
        elif key == "Author" and not meta["author"]:
            meta["author"] = val
        elif key == "URL" and not meta["url"]:
            meta["url"] = val

    return meta


def notes_count(highlights) -> int:
    """Count of highlights carrying a non-empty Readwise annotation note — the `notes_count`
    input `kb_core.is_eligible` expects, computed the plugin-folder way."""
    return sum(1 for h in highlights if h.get("note"))


# --- Pipeline entry point ----------------------------------------------------


def collect_sources(file_texts: dict) -> dict:
    """Full plugin-folder ingestion pipeline: parse every file (each possibly containing
    more than one concatenated book-block — `split_into_book_blocks`), group by `book_id`
    across both duplicate FILES (the plugin's gen1/gen2 intra-`Readwise/` duplication) and
    duplicate BLOCKS within a single file, merge/dedupe highlights per `book_id`
    (`merge_highlights`), and pick the first non-empty metadata seen for each.

    ``file_texts`` maps vault-relative path to file content — the caller (the capture
    operation) has already read every file under `Readwise/`; no I/O happens here.

    Returns ``{book_id: {"highlights": [...], "metadata": {...}, "paths": [str, ...]}}``.
    Blocks with no recoverable `book_id` are omitted (identity is book_id-keyed; id-less
    notes are out of scope for capture — design note, Identity/Migration sections).
    """
    by_id: dict = {}
    for path, text in file_texts.items():
        for block in split_into_book_blocks(text):
            book_id = extract_book_id(block)
            if book_id is None:
                continue
            entry = by_id.setdefault(
                book_id, {"highlight_lists": [], "metadata": {}, "paths": []}
            )
            entry["highlight_lists"].append(extract_highlights(block))
            if path not in entry["paths"]:
                entry["paths"].append(path)
            if not any(entry["metadata"].values()):
                meta = extract_metadata(block)
                if any(meta.values()):
                    entry["metadata"] = meta

    return {
        book_id: {
            "highlights": merge_highlights(entry["highlight_lists"]),
            "metadata": entry["metadata"] or {"title": "", "author": "", "url": ""},
            "paths": entry["paths"],
        }
        for book_id, entry in by_id.items()
    }
