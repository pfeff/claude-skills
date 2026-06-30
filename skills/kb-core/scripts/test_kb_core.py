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


class TestBehavioralContractsDeferred(unittest.TestCase):
    """These remain NotImplementedError until the per-skill tasks implement them test-first."""

    def test_classify_zone_deferred(self):
        from kb_core import classify_zone

        with self.assertRaises(NotImplementedError):
            classify_zone({}, "some/path.md")

    def test_append_in_fence_deferred(self):
        from kb_core import append_in_fence

        with self.assertRaises(NotImplementedError):
            append_in_fence("text", "body")

    def test_source_key_deferred(self):
        from kb_core import source_key

        with self.assertRaises(NotImplementedError):
            source_key({})


if __name__ == "__main__":
    unittest.main()
