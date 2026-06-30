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


class TestClassifyZone(unittest.TestCase):
    """SPEC §1 zone classification: marker-authoritative, subtree as the default.
    Edit-rule (zone) is a separate axis from provenance (AC-2.5)."""

    def test_generated_tag_is_derived(self):
        from kb_core import classify_zone, Zone

        self.assertEqual(classify_zone({"tags": ["generated_note"]}, "anywhere/note.md"), Zone.DERIVED)

    def test_generated_subtree_default_is_derived(self):
        from kb_core import classify_zone, Zone

        self.assertEqual(classify_zone({}, "Generated/summary.md"), Zone.DERIVED)

    def test_keyword_tag_is_shared(self):
        from kb_core import classify_zone, Zone

        self.assertEqual(classify_zone({"tags": ["keyword"]}, "anywhere/dns.md"), Zone.SHARED)

    def test_keywords_subtree_default_is_shared(self):
        from kb_core import classify_zone, Zone

        self.assertEqual(classify_zone({}, "Keywords/dns.md"), Zone.SHARED)

    def test_llm_created_keyword_note_is_shared_not_derived(self):
        # Carries generated_note for provenance yet lives in Keywords/ → Shared edit rule.
        from kb_core import classify_zone, Zone

        fm = {"tags": ["keyword", "generated_note"]}
        self.assertEqual(classify_zone(fm, "Keywords/agents.md"), Zone.SHARED)

    def test_plain_human_note_is_human(self):
        from kb_core import classify_zone, Zone

        self.assertEqual(classify_zone({"tags": ["meeting"]}, "Journal/2026-06-30.md"), Zone.HUMAN)

    def test_tags_as_scalar_string(self):
        from kb_core import classify_zone, Zone

        self.assertEqual(classify_zone({"tags": "generated_note"}, "x.md"), Zone.DERIVED)


class TestAppendInFence(unittest.TestCase):
    """SPEC §2.2 fenced append: add inside the fence, leave outside byte-for-byte unchanged
    (AC-2.3, AC-2.6)."""

    def test_creates_fence_when_absent(self):
        from kb_core import append_in_fence, has_fence, FENCE_START

        existing = "# DNS\n\nHuman prose about DNS.\n"
        result = append_in_fence(existing, "generated detail")
        self.assertTrue(has_fence(result))
        self.assertTrue(result.startswith(existing))  # existing bytes preserved as a prefix
        start = result.index(FENCE_START)
        self.assertIn("generated detail", result[start:])  # body lives in the fenced region
        self.assertNotIn("generated detail", result[:start])  # nothing leaked above the fence

    def test_appends_into_existing_fence_preserving_outside(self):
        from kb_core import append_in_fence, fence_wrap, FENCE_START, FENCE_END

        existing = "# Agents\n\nHuman prose.\n\n" + fence_wrap("first gen") + "\n\nTail human prose.\n"
        result = append_in_fence(existing, "second gen")

        s = result.index(FENCE_START)
        e = result.rindex(FENCE_END)
        inner = result[s:e]
        self.assertIn("first gen", inner)
        self.assertIn("second gen", inner)
        # text before the fence is byte-for-byte unchanged
        self.assertEqual(result[:s], existing[: existing.index(FENCE_START)])
        # text from FENCE_END onward (the human tail) is byte-for-byte unchanged
        self.assertEqual(result[e:], existing[existing.rindex(FENCE_END):])

    def test_human_prose_unchanged_no_duplicate_fence(self):
        from kb_core import append_in_fence

        existing = "Concept prose.\n\n<!-- kb:generated start -->\nold\n<!-- kb:generated end -->\n"
        result = append_in_fence(existing, "new")
        # exactly one fence (no duplicate region created)
        self.assertEqual(result.count("<!-- kb:generated start -->"), 1)
        self.assertEqual(result.count("<!-- kb:generated end -->"), 1)
        self.assertIn("Concept prose.", result)


class TestLintGuards(unittest.TestCase):
    """SPEC §2.6 lint write-boundary (AC-6.2): auto-fix allowed only in Derived; everything
    else is a proposal. Plus orphan detection (AC-6.3 input)."""

    def test_autofix_allowed_only_in_derived(self):
        from kb_core import is_autofix_allowed

        self.assertTrue(is_autofix_allowed({"tags": ["generated_note"]}, "Generated/x.md"))
        self.assertFalse(is_autofix_allowed({"tags": ["keyword"]}, "Keywords/x.md"))  # Shared
        self.assertFalse(is_autofix_allowed({}, "Journal/x.md"))  # Human

    def test_find_orphans_returns_notes_with_no_backlinks(self):
        from kb_core import find_orphans

        # A links to B; A has no inbound link → orphan. B is linked → not.
        self.assertEqual(find_orphans({"A": ["B"], "B": []}), ["A"])

    def test_find_orphans_none_when_all_linked(self):
        from kb_core import find_orphans

        self.assertEqual(find_orphans({"A": ["B"], "B": ["A"]}), [])

    def test_find_orphans_lone_note(self):
        from kb_core import find_orphans

        self.assertEqual(find_orphans({"A": []}), ["A"])


if __name__ == "__main__":
    unittest.main()
