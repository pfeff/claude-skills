#!/usr/bin/env python3
"""Deterministic helpers for kb-lint's proposal inbox.

kb-lint surfaces two kinds of report-only "proposal" findings that it may never auto-apply:
within-KB link suggestions it declines to write itself, and KB<->non-KB cross-links it
structurally can't write (the target note is outside KB ownership). Historically these
proposals were only ever emitted into the session transcript and evaporated at session end.

This module holds the pure, unit-testable primitives for giving them a durable landing
place: a stable idempotency key per proposal, a rendered checklist line carrying that key,
and a dedup filter so re-running kb-lint against an unchanged vault does not re-append
proposals already recorded. No vault I/O happens here — reading/writing the inbox note is
agent-orchestrated in operations/lint.md, same division of labor as kb-core.
"""

import re

KEY_COMMENT_RE = re.compile(r"<!--\s*kb-lint-key:\s*(\S+)\s*-->")


def _normalize_target(target: str) -> str:
    """Reduce a note reference (path, wikilink, or bare title) to a stable comparison form:
    strip a ``[[...]]`` wikilink wrapper and any path/extension, lowercase, collapse
    non-alphanumerics to single hyphens."""
    stripped = target.strip()
    if stripped.startswith("[[") and stripped.endswith("]]"):
        stripped = stripped[2:-2]
    basename = stripped.rsplit("/", 1)[-1]
    if basename.lower().endswith(".md"):
        basename = basename[:-3]
    return re.sub(r"[^a-z0-9]+", "-", basename.strip().lower()).strip("-")


def proposal_key(kind: str, targets) -> str:
    """Stable, order-independent idempotency key for a proposal, so recording it twice (same
    kind, same note pair, either order) collapses to the same key. ``targets`` is any
    iterable of note references (paths, wikilinks, or bare titles)."""
    normalized = sorted(_normalize_target(t) for t in targets)
    return f"{kind}:" + "|".join(normalized)


def _sanitize_description(description: str) -> str:
    """Neutralize sequences in a free-text description that could otherwise forge or hide an
    idempotency key: collapse embedded newlines (which could fabricate extra checklist
    lines) and break up any ``<!--``/``-->`` the description happens to contain (which could
    forge a fake ``kb-lint-key`` comment that ``extract_existing_keys`` would then trust on
    the next run, silently suppressing a real future proposal with the same key)."""
    single_line = re.sub(r"\s*\n\s*", " ", description.strip())
    return single_line.replace("<!--", "< !--").replace("-->", "-- >")


def format_proposal_line(kind: str, targets, description: str) -> str:
    """Render one proposal as an Obsidian checklist line with its idempotency key embedded
    as a trailing HTML comment (invisible when rendered, greppable for dedup). The
    description is sanitized so it cannot forge or hide the trailing key comment."""
    key = proposal_key(kind, targets)
    safe_description = _sanitize_description(description)
    return f"- [ ] {safe_description} <!-- kb-lint-key: {key} -->"


def extract_existing_keys(markdown_text: str) -> set:
    """Scan a proposals-note body for already-recorded idempotency keys."""
    return set(KEY_COMMENT_RE.findall(markdown_text))


def dedupe_new_proposals(existing_keys, proposals):
    """Filter a batch of freshly-detected proposals down to the ones not already recorded in
    ``existing_keys``, and drop duplicates within the batch itself (the same connection
    candidate can surface more than once in a single lint pass).

    ``proposals`` is an iterable of ``(kind, targets, description)`` tuples. Returns a list
    of the same tuples, in input order, first-occurrence-wins."""
    seen = set(existing_keys)
    kept = []
    for kind, targets, description in proposals:
        key = proposal_key(kind, targets)
        if key in seen:
            continue
        seen.add(key)
        kept.append((kind, targets, description))
    return kept
