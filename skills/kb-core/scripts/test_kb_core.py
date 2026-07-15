"""Tests for kb_core.py — the shared KB primitives (SPEC v2).

v2 model: no folder-zones, no fence. The deterministic primitives are the capture predicate,
the idempotency key, the off-limits write-guard, the KB-ownership check (for lint auto-fix),
concept-slug dedup, and orphan detection.

Run: python3 -m unittest test_kb_core   (from this scripts/ directory)
"""

import unittest


class TestCaptureEligibility(unittest.TestCase):
    """SPEC §2.1 capture-eligibility predicate (AC-1.1…AC-1.7)."""

    def test_highlighted_relevant_is_captured(self):  # AC-1.1
        from kb_core import is_eligible

        self.assertTrue(is_eligible(3, 0, False, True))

    def test_no_highlights_no_notes_skipped(self):  # AC-1.2
        from kb_core import is_eligible

        self.assertFalse(is_eligible(0, 0, False, True))

    def test_notes_count_as_highlights(self):  # AC-1.3
        from kb_core import is_eligible

        self.assertTrue(is_eligible(0, 2, False, True))

    def test_irrelevant_skipped_unless_tagged(self):  # AC-1.4
        from kb_core import is_eligible

        self.assertFalse(is_eligible(5, 0, False, False))
        self.assertTrue(is_eligible(5, 0, True, False))

    def test_tagged_with_zero_highlights_and_notes_captured(self):  # AC-1.7
        from kb_core import is_eligible

        self.assertTrue(is_eligible(0, 0, True, False))


class TestSourceKey(unittest.TestCase):
    """Stable idempotency key so re-capture is a no-op (AC-1.6)."""

    def test_stable_for_same_id(self):
        from kb_core import source_key

        self.assertEqual(source_key({"id": "abc123"}), source_key({"id": "abc123"}))

    def test_distinct_for_different_ids(self):
        from kb_core import source_key

        self.assertNotEqual(source_key({"id": "abc123"}), source_key({"id": "xyz789"}))

    def test_namespaced_and_filesystem_safe(self):
        from kb_core import source_key

        key = source_key({"id": "abc/123 weird:id"})
        self.assertTrue(key.startswith("readwise-"))
        for ch in "/\\: ":
            self.assertNotIn(ch, key)

    def test_missing_id_raises(self):
        from kb_core import source_key

        with self.assertRaises(KeyError):
            source_key({})


class TestHighlightsFingerprint(unittest.TestCase):
    """Content fingerprint that lets a re-sweep detect new highlights on an already-captured
    source, fixing the existence-only idempotency bug (source `62041720` silently skipped
    forever after gaining new highlights)."""

    def test_stable_for_same_set(self):
        from kb_core import highlights_fingerprint

        highlights = [{"text": "a"}, {"text": "b"}]
        self.assertEqual(
            highlights_fingerprint(highlights), highlights_fingerprint(highlights)
        )

    def test_order_independent(self):
        from kb_core import highlights_fingerprint

        forward = [{"text": "a"}, {"text": "b"}]
        backward = [{"text": "b"}, {"text": "a"}]
        self.assertEqual(highlights_fingerprint(forward), highlights_fingerprint(backward))

    def test_changes_when_highlight_added(self):
        from kb_core import highlights_fingerprint

        before = [{"text": "a"}]
        after = [{"text": "a"}, {"text": "b"}]
        self.assertNotEqual(highlights_fingerprint(before), highlights_fingerprint(after))

    def test_note_text_affects_fingerprint(self):
        from kb_core import highlights_fingerprint

        plain = [{"text": "a"}]
        annotated = [{"text": "a", "note": "why this matters"}]
        self.assertNotEqual(highlights_fingerprint(plain), highlights_fingerprint(annotated))

    def test_empty_is_stable(self):
        from kb_core import highlights_fingerprint

        self.assertEqual(highlights_fingerprint([]), highlights_fingerprint([]))


class TestNewHighlights(unittest.TestCase):
    """AC (kb-capture re-sync): the subset of freshly fetched highlights not yet folded into
    an existing `raw/<key>.md`, so a re-sweep can append only the delta."""

    def test_returns_only_unseen_highlights(self):
        from kb_core import new_highlights

        existing_texts = ["a", "b"]
        current = [{"text": "a"}, {"text": "b"}, {"text": "c"}]
        self.assertEqual(new_highlights(existing_texts, current), [{"text": "c"}])

    def test_empty_when_nothing_new(self):
        from kb_core import new_highlights

        existing_texts = ["a", "b"]
        current = [{"text": "a"}, {"text": "b"}]
        self.assertEqual(new_highlights(existing_texts, current), [])

    def test_all_new_when_no_existing(self):
        from kb_core import new_highlights

        current = [{"text": "a"}, {"text": "b"}]
        self.assertEqual(new_highlights([], current), current)

    def test_whitespace_normalized(self):
        from kb_core import new_highlights

        existing_texts = ["  a  "]
        current = [{"text": "a"}]
        self.assertEqual(new_highlights(existing_texts, current), [])


class TestWriteBoundary(unittest.TestCase):
    """SPEC v2 §1 INV-1: the KB never writes the off-limits subtrees (AC-1.5/2.4/6.1)."""

    def test_off_limits_are_not_writable(self):
        from kb_core import is_writable

        self.assertFalse(is_writable("DevOps Documentation/22_CICD/x.md"))
        self.assertFalse(is_writable("Confluence/imported/y.md"))

    def test_kb_locations_are_writable(self):
        from kb_core import is_writable

        for p in ("raw/readwise-abc.md", "Notes/2026/07/z.md", "Keywords/AWS.md", "index.md"):
            self.assertTrue(is_writable(p), p)


class TestKbOwnership(unittest.TestCase):
    """SPEC §2.6 AC-6.2: lint auto-fix is confined to KB-authored notes."""

    def test_raw_is_kb_owned(self):
        from kb_core import is_kb_owned

        self.assertTrue(is_kb_owned({}, "raw/readwise-abc.md"))

    def test_kb_project_is_owned(self):
        from kb_core import is_kb_owned

        self.assertTrue(is_kb_owned({"project": "knowledge-base"}, "Notes/2026/07/s.md"))

    def test_kb_tag_is_owned(self):
        from kb_core import is_kb_owned

        self.assertTrue(is_kb_owned({"tags": ["kb", "aws"]}, "Notes/2026/07/s.md"))

    def test_ordinary_note_is_not_owned(self):
        from kb_core import is_kb_owned

        self.assertFalse(is_kb_owned({"type": "session-journal"}, "Notes/2026/07/j.md"))

    def test_tags_none_does_not_crash(self):
        # An empty `tags:` key parses to None in Obsidian frontmatter.
        from kb_core import is_kb_owned

        self.assertFalse(is_kb_owned({"tags": None}, "Notes/2026/07/j.md"))


class TestConceptSlug(unittest.TestCase):
    """SPEC §2.2 AC-2.3: stable slug so re-compile updates the concept in place, not duplicates."""

    def test_normalizes_title(self):
        from kb_core import concept_slug

        self.assertEqual(concept_slug("LLM Knowledge Base"), "llm-knowledge-base")

    def test_stable_across_whitespace_and_punctuation(self):
        from kb_core import concept_slug

        self.assertEqual(concept_slug("  Knowledge Base: Linting!  "), "knowledge-base-linting")

    def test_same_title_same_slug(self):
        from kb_core import concept_slug

        self.assertEqual(concept_slug("Dev-Stacks"), concept_slug("dev  stacks"))


class TestFindOrphans(unittest.TestCase):
    """SPEC §2.6 AC-6.3 input: notes with no inbound backlinks."""

    def test_returns_notes_with_no_backlinks(self):
        from kb_core import find_orphans

        self.assertEqual(find_orphans({"A": ["B"], "B": []}), ["A"])

    def test_none_when_all_linked(self):
        from kb_core import find_orphans

        self.assertEqual(find_orphans({"A": ["B"], "B": ["A"]}), [])

    def test_lone_note(self):
        from kb_core import find_orphans

        self.assertEqual(find_orphans({"A": []}), ["A"])


if __name__ == "__main__":
    unittest.main()
