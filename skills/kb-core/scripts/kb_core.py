#!/usr/bin/env python3
"""Shared library for the LLM Knowledge Base skills (kb-capture, kb-compile, kb-lint).

Holds the load-bearing authorship-boundary primitives from SPEC §1 in ONE place so the
three skills cannot drift on the non-destruction invariant (INV-1). Zone classification,
the Shared append-fence, and provenance helpers live here.

All primitives are implemented and unit-tested (see `test_kb_core.py`): the SPEC §1
constants and fence helpers, the capture predicate and idempotency key (SPEC §2.1), zone
classification and fenced append (SPEC §1/§2.2), and the lint write-guard and orphan
detector (SPEC §2.6).

No vault I/O happens in this module — callers pass note text / frontmatter in and get
values out, which keeps the primitives unit-testable without touching a real vault.
"""

from enum import Enum


# --- SPEC §1 locked constants -------------------------------------------------

# Shared-zone append fence. LLM-appended content in a human-authored Keywords/ note lives
# strictly between these HTML-comment markers; human prose lives outside them. Chosen
# because the markers are unambiguously machine-detectable and render invisibly in
# Obsidian. (SPEC §1, OQ #9.)
FENCE_START = "<!-- kb:generated start -->"
FENCE_END = "<!-- kb:generated end -->"

# Frontmatter markers that make a note's zone derivable without reading its prose (INV-2).
GENERATED_TAG = "generated_note"  # Derived-zone authority (and provenance on LLM-made Shared notes)
KEYWORD_TAG = "keyword"  # Shared-zone marker, alongside residence in Keywords/

# Capture tag — the operator's unconditional "ingest this" override (SPEC §2.1 path B).
CAPTURE_TAG = "kb"


class Zone(Enum):
    """Edit-rule zones from SPEC §1. Zone governs what the LLM may DO to a note; it is a
    separate axis from provenance (who originated it)."""

    DERIVED = "derived"  # Generated/ subtree — LLM may create/edit/delete freely
    SHARED = "shared"  # Keywords/ concept notes — create new; append only within the fence
    HUMAN = "human"  # everything else — read only; never edit or delete


# --- Pure fence helpers (SPEC §1 locked; no vault I/O) ------------------------


def fence_wrap(body: str) -> str:
    """Wrap LLM-generated ``body`` in the kb:generated fence as a standalone block.

    The returned string is the complete fenced region (markers + body) that gets appended
    to a Shared note. Content outside this region is never produced by the LLM.
    """
    return f"{FENCE_START}\n{body}\n{FENCE_END}"


def has_fence(text: str) -> bool:
    """True iff ``text`` already contains a kb:generated fence (both markers present)."""
    return FENCE_START in text and FENCE_END in text


# --- Capture predicate (SPEC §2.1, kb-capture task) --------------------------


def is_eligible(
    highlight_count: int,
    notes_count: int,
    has_capture_tag: bool,
    work_relevant: bool,
) -> bool:
    """Capture-eligibility predicate (SPEC §2.1).

    A Reader doc is captured iff **either**:
      - Path B (tag override): ``has_capture_tag`` — captured unconditionally, no highlight
        required, topic irrelevant (AC-1.4, AC-1.7). The operator's explicit "ingest this".
      - Path A (default): it has ≥1 highlight *or note* (notes count as highlights)
        **AND** is judged work-relevant (AC-1.1, AC-1.2, AC-1.3).

    ``work_relevant`` is the caller-supplied result of the LLM relevance judgment scored
    against WORK-DOMAINS.md; this function owns only the deterministic gate logic.
    """
    if has_capture_tag:
        return True
    return (highlight_count + notes_count) >= 1 and work_relevant


def source_key(source: dict) -> str:
    """Stable, filesystem-safe idempotency key for a captured Reader source, so re-capture
    and re-compile are no-ops (INV-4, AC-1.6). Derived from the Reader document id, which is
    the stable unique identity of the source. Raises KeyError if the source has no id."""
    raw_id = source["id"]
    safe = "".join(c if (c.isalnum() or c in "-_") else "-" for c in str(raw_id))
    return f"readwise-{safe}"


# --- Zone classification + fenced append (SPEC §1/§2.2, kb-compile task) ------


def _tag_list(frontmatter: dict) -> list:
    """Normalize a note's frontmatter tags to a list of strings. Tags may be a scalar
    string, or an empty `tags:` key that parses to None (common in Obsidian) — both are
    handled so the INV-1 write-guard never crashes on real frontmatter."""
    tags = frontmatter.get("tags") or []
    if isinstance(tags, str):
        return [tags]
    return list(tags)


def _under(path: str, subtree: str) -> bool:
    """True iff ``path`` is inside ``subtree`` (e.g. "Keywords") at any depth."""
    norm = path.replace("\\", "/")
    return norm.startswith(f"{subtree}/") or f"/{subtree}/" in norm


def classify_zone(frontmatter: dict, path: str) -> Zone:
    """Classify a note into its edit-rule Zone (INV-2: marker-authoritative, subtree as the
    organizational default). Edit-rule is a separate axis from provenance: a Keywords/ note
    that also carries ``generated_note`` (provenance) is still Shared (append-only) — so the
    Shared check precedes the Derived check (SPEC §1)."""
    tags = _tag_list(frontmatter)
    if KEYWORD_TAG in tags or _under(path, "Keywords"):
        return Zone.SHARED
    if GENERATED_TAG in tags or _under(path, "Generated"):
        return Zone.DERIVED
    return Zone.HUMAN


def append_in_fence(existing_text: str, body: str) -> str:
    """Return ``existing_text`` with ``body`` appended inside the kb:generated fence,
    leaving all text *outside* the fence byte-for-byte unchanged (INV-1, AC-2.3/AC-2.6).

    If the note already has a fence, ``body`` is inserted just before the closing marker
    (existing fenced content kept); otherwise a single new fence is appended after the
    existing prose. Never rewrites or duplicates human prose.

    Raises ValueError on a malformed half-fence (exactly one marker present) rather than
    appending a second fence and compounding the corruption — compile fails loudly."""
    has_start, has_end = FENCE_START in existing_text, FENCE_END in existing_text
    if has_start != has_end:
        raise ValueError("malformed kb:generated fence: exactly one marker present")
    if has_fence(existing_text):
        idx = existing_text.rindex(FENCE_END)
        before, after = existing_text[:idx], existing_text[idx:]
        sep = "" if before.endswith("\n") else "\n"
        return f"{before}{sep}{body}\n{after}"
    sep = "\n" if existing_text.endswith("\n") else "\n\n"
    return f"{existing_text}{sep}{fence_wrap(body)}"


# --- Lint guards (SPEC §2.6, kb-lint task) -----------------------------------


def is_autofix_allowed(frontmatter: dict, path: str) -> bool:
    """True iff a lint auto-fix may write to this note (AC-6.2). Auto-fix is confined to the
    Derived zone; Shared and Human findings are surfaced as proposals only (INV-1)."""
    return classify_zone(frontmatter, path) == Zone.DERIVED


def find_orphans(adjacency: dict) -> list:
    """Return the notes that have no inbound backlinks (AC-6.3 input), sorted. ``adjacency``
    maps each note name to the list of notes it links TO; an orphan is a note that never
    appears as a link target."""
    linked_to = set()
    for targets in adjacency.values():
        linked_to.update(targets)
    return sorted(note for note in adjacency if note not in linked_to)
