#!/usr/bin/env python3
"""Shared library for the LLM Knowledge Base skills (kb-capture, kb-compile, kb-lint).

Holds the load-bearing authorship-boundary primitives from SPEC §1 in ONE place so the
three skills cannot drift on the non-destruction invariant (INV-1). Zone classification,
the Shared append-fence, and provenance helpers live here.

Scaffold status: constants and the pure fence string-helpers are implemented (SPEC §1 is
locked). Behavioral functions that require design choices deferred to the per-skill tasks
(zone classification from frontmatter, fenced append into an existing note, idempotency
keys) are declared with their contracts and raise NotImplementedError until those tasks
implement them test-first.

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


# --- Compile-task contracts (implemented test-first by the kb-compile task) ---


def classify_zone(frontmatter: dict, path: str) -> Zone:
    """Classify a note into its edit-rule Zone (INV-2: marker-authoritative, subtree as
    the organizational default). Implemented by the compile/lint tasks (SPEC §1)."""
    raise NotImplementedError("classify_zone is implemented in the kb-compile task (SPEC §1)")


def append_in_fence(existing_text: str, body: str) -> str:
    """Return ``existing_text`` with ``body`` appended inside the kb:generated fence,
    leaving all text outside the fence byte-for-byte unchanged (INV-1, AC-2.3/AC-2.6).
    Implemented by the kb-compile task."""
    raise NotImplementedError("append_in_fence is implemented in the kb-compile task (SPEC §2.2)")
