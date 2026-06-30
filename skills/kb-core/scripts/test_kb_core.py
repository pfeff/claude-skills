"""Tests for kb_core.py — the shared authorship-boundary primitives (SPEC §1).

Scaffold-level coverage: the locked SPEC §1 constants and the pure fence string-helpers.
Behavioral functions (classify_zone, append_in_fence, source_key) are covered test-first
by the kb-capture / kb-compile tasks; here we only assert they exist and signal their
not-yet-implemented contract, so the harness is green without pre-empting that work.

Run: python3 -m unittest test_kb_core   (from this scripts/ directory)
"""

import unittest


class TestFenceConstants(unittest.TestCase):
    def test_fence_markers_are_html_comments(self):
        from kb_core import FENCE_START, FENCE_END

        # HTML comments render invisibly in Obsidian and are machine-detectable (SPEC §1).
        self.assertTrue(FENCE_START.startswith("<!--") and FENCE_START.endswith("-->"))
        self.assertTrue(FENCE_END.startswith("<!--") and FENCE_END.endswith("-->"))
        self.assertIn("kb:generated", FENCE_START)
        self.assertIn("kb:generated", FENCE_END)

    def test_zone_values(self):
        from kb_core import Zone

        self.assertEqual({z.value for z in Zone}, {"derived", "shared", "human"})


class TestFenceHelpers(unittest.TestCase):
    def test_fence_wrap_encloses_body(self):
        from kb_core import fence_wrap, FENCE_START, FENCE_END

        wrapped = fence_wrap("hello")
        self.assertTrue(wrapped.startswith(FENCE_START))
        self.assertTrue(wrapped.endswith(FENCE_END))
        self.assertIn("hello", wrapped)

    def test_has_fence_detects_both_markers(self):
        from kb_core import fence_wrap, has_fence

        self.assertTrue(has_fence("prose\n" + fence_wrap("x") + "\nmore"))
        self.assertFalse(has_fence("just human prose, no markers"))


class TestCaptureEligibility(unittest.TestCase):
    """SPEC §2.1 capture-eligibility predicate (AC-1.1…AC-1.7).

    is_eligible(highlight_count, notes_count, has_capture_tag, work_relevant) -> bool
    - Path A: (highlights + notes >= 1) AND work_relevant
    - Path B: has_capture_tag -> True unconditionally (overrides path A)
    """

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

        self.assertFalse(is_eligible(5, 0, False, False))  # relevant gate fails
        self.assertTrue(is_eligible(5, 0, True, False))  # tag override wins

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
        # safe for use in a filename: no path separators or shell-hostile chars
        for ch in "/\\: ":
            self.assertNotIn(ch, key)

    def test_missing_id_raises(self):
        from kb_core import source_key

        with self.assertRaises(KeyError):
            source_key({})


class TestBehavioralContractsDeferred(unittest.TestCase):
    """Compile-task functions remain NotImplementedError until implemented test-first."""

    def test_classify_zone_deferred(self):
        from kb_core import classify_zone

        with self.assertRaises(NotImplementedError):
            classify_zone({}, "some/path.md")

    def test_append_in_fence_deferred(self):
        from kb_core import append_in_fence

        with self.assertRaises(NotImplementedError):
            append_in_fence("text", "body")


if __name__ == "__main__":
    unittest.main()
