#!/usr/bin/env python3
"""Shared library for the LLM Knowledge Base skills (kb-capture, kb-compile, kb-lint).

Holds the deterministic, unit-testable primitives the three skills share (SPEC v2 §1):
the capture eligibility predicate, the source idempotency key, content-aware re-sync
(fingerprint + delta), the off-limits write-guard, the KB-ownership check (for lint
auto-fix), a concept-slug normalizer, and orphan detection.

v2 model: there are no folder-zones and no append-fence. Content is KB-owned (free-edit) or
off-limits; edit safety is git + review (INV-5). Readwise reads and vault writes are
agent-orchestrated in the operation docs — no vault I/O happens in this module.
"""

import hashlib
import re


# --- Constants (SPEC v2 §1/§5) -----------------------------------------------

CAPTURE_TAG = "kb"  # operator's unconditional "ingest this" override (§2.1 path B)
KB_PROJECT = "knowledge-base"  # project: routing for compiled KB notes (INV-2)

# type: values (§5 decision #3 — kb-raw is KB-specific; the rest reuse the vault vocabulary)
TYPE_RAW = "kb-raw"  # staged verbatim source in raw/
TYPE_SUMMARY = "reference"  # per-source summary note in Notes/
TYPE_CONCEPT = "zettel"  # fuller concept note in Notes/
TYPE_MOC = "moc"  # KB index note

# Off-limits subtrees — the KB never writes under these (INV-1, SPEC v2 §1).
OFF_LIMITS = ("DevOps Documentation", "Confluence")


# --- small pure helpers ------------------------------------------------------


def _tag_list(frontmatter: dict) -> list:
    """Normalize frontmatter tags to a list of strings. Tags may be a scalar string, or an
    empty `tags:` key that parses to None (common in Obsidian) — both handled so callers
    never crash on real frontmatter."""
    tags = frontmatter.get("tags") or []
    if isinstance(tags, str):
        return [tags]
    return list(tags)


def _under(path: str, subtree: str) -> bool:
    """True iff ``path`` is inside ``subtree`` at any depth."""
    norm = path.replace("\\", "/")
    return norm.startswith(f"{subtree}/") or f"/{subtree}/" in norm


# --- Capture predicate (SPEC §2.1) -------------------------------------------


def is_eligible(
    highlight_count: int,
    notes_count: int,
    has_capture_tag: bool,
    work_relevant: bool,
) -> bool:
    """Capture-eligibility predicate (SPEC §2.1).

    Captured iff **either**:
      - Path B (tag override): ``has_capture_tag`` — unconditional (AC-1.4, AC-1.7).
      - Path A (default): ≥1 highlight *or note* (notes count) **AND** work-relevant
        (AC-1.1, AC-1.2, AC-1.3).

    ``work_relevant`` is the caller-supplied result of the LLM relevance judgment scored
    against WORK-DOMAINS.md; this function owns only the deterministic gate logic.
    """
    if has_capture_tag:
        return True
    return (highlight_count + notes_count) >= 1 and work_relevant


def source_key(source: dict) -> str:
    """Stable, filesystem-safe idempotency key for a captured Reader source, so re-capture
    and re-compile are no-ops (INV-4, AC-1.6). Derived from the Reader document id. Raises
    KeyError if the source has no id."""
    raw_id = source["id"]
    safe = "".join(c if (c.isalnum() or c in "-_") else "-" for c in str(raw_id))
    return f"readwise-{safe}"


# --- Content-aware re-sync (fixes existence-only idempotency) ---------------
#
# `source_key`'s presence check (raw/<key>.md exists ⇒ skip) is a *no-recapture* guard, not a
# *no-recapture-when-unchanged* guard: a source that gains highlights after its first capture
# (the operator returns to a book and highlights more of it) is silently skipped forever,
# because existence alone can't distinguish "already captured" from "already captured, but
# stale." The two primitives below let kb-capture detect and fold in the delta instead.


def highlights_fingerprint(highlights) -> str:
    """Stable content fingerprint over a source's highlights/notes, so a re-sweep can tell
    whether a previously captured source has changed without diffing text by hand. Order of
    ``highlights`` doesn't affect the result (re-fetching the same set in a different page
    order must not look like a change). ``highlights`` is an iterable of dicts with a ``text``
    key and an optional ``note`` key; both are stripped before hashing so incidental
    whitespace differences don't either."""
    parts = []
    for h in highlights:
        text = (h.get("text") or "").strip()
        note = (h.get("note") or "").strip()
        parts.append(f"{text}\x1f{note}")
    canonical = "\n".join(sorted(parts))
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def new_highlights(existing_texts, current_highlights) -> list:
    """Given the highlight texts already captured in a `raw/` note (``existing_texts`` —
    e.g. parsed from its rendered `## Highlights` blockquote lines) and the highlights just
    fetched for that source (``current_highlights``, dicts with a ``text`` key), return the
    subset of ``current_highlights`` not already present — the highlights a re-sweep should
    fold into the existing note. Preserves the order of ``current_highlights``; comparison is
    on stripped text."""
    seen = {t.strip() for t in existing_texts}
    return [h for h in current_highlights if (h.get("text") or "").strip() not in seen]


# --- Write boundary + KB ownership (SPEC v2 §1/§2.6) -------------------------


def is_writable(path: str) -> bool:
    """True iff the KB may write to ``path`` (INV-1). False for the read-only off-limits
    subtrees (DevOps Documentation/, Confluence/). Task-scope discipline — don't touch notes
    outside the current task — is an agent-level concern layered on top of this path floor,
    not encoded here."""
    return not any(_under(path, sub) for sub in OFF_LIMITS)


def is_kb_owned(frontmatter: dict, path: str) -> bool:
    """True iff a note is KB-authored, so lint auto-fix may write it (AC-6.2). KB-authored =
    a staged source under raw/, or a compiled note routed to the KB (``project:
    knowledge-base`` or the ``kb`` tag). Everything else — including ordinary human/agent
    notes in Notes/ — is proposal-only for lint."""
    if _under(path, "raw"):
        return True
    if frontmatter.get("project") == KB_PROJECT:
        return True
    return CAPTURE_TAG in _tag_list(frontmatter)


# --- Concept identity (SPEC §2.2, AC-2.3 dedup) ------------------------------


def concept_slug(title: str) -> str:
    """Normalize a concept title to a stable slug so re-compile updates the existing concept
    note in place instead of duplicating it (AC-2.3). Lowercase; runs of non-alphanumerics
    collapse to a single hyphen; leading/trailing hyphens stripped."""
    return re.sub(r"[^a-z0-9]+", "-", title.strip().lower()).strip("-")


# --- Lint orphan detection (SPEC §2.6) ---------------------------------------


def find_orphans(adjacency: dict) -> list:
    """Return the notes that have no inbound backlinks (AC-6.3 input), sorted. ``adjacency``
    maps each note name to the list of notes it links TO; an orphan is a note that never
    appears as a link target."""
    linked_to = set()
    for targets in adjacency.values():
        linked_to.update(targets)
    return sorted(note for note in adjacency if note not in linked_to)
