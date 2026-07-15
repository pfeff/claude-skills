"""Tests for kb_lint_proposals.py — the kb-lint proposal-inbox primitives.

Run: python3 -m unittest test_kb_lint_proposals   (from this scripts/ directory)
"""

import unittest


class TestProposalKey(unittest.TestCase):
    def test_stable_regardless_of_target_order(self):
        from kb_lint_proposals import proposal_key

        self.assertEqual(
            proposal_key("link", ["Note A", "Note B"]),
            proposal_key("link", ["Note B", "Note A"]),
        )

    def test_differs_by_kind(self):
        from kb_lint_proposals import proposal_key

        self.assertNotEqual(
            proposal_key("link", ["Note A", "Note B"]),
            proposal_key("cross-link", ["Note A", "Note B"]),
        )

    def test_differs_by_targets(self):
        from kb_lint_proposals import proposal_key

        self.assertNotEqual(
            proposal_key("link", ["Note A", "Note B"]),
            proposal_key("link", ["Note A", "Note C"]),
        )

    def test_normalizes_wikilinks_paths_and_extensions(self):
        from kb_lint_proposals import proposal_key

        self.assertEqual(
            proposal_key("link", ["[[Note A]]", "Notes/2026/07/note-b.md"]),
            proposal_key("link", ["note a", "Note B"]),
        )


class TestFormatProposalLine(unittest.TestCase):
    def test_embeds_description_and_key(self):
        from kb_lint_proposals import format_proposal_line, proposal_key

        line = format_proposal_line("link", ["Note A", "Note B"], "Link Note A <-> Note B")
        self.assertIn("Link Note A <-> Note B", line)
        self.assertIn(proposal_key("link", ["Note A", "Note B"]), line)
        self.assertTrue(line.startswith("- [ ] "))


class TestExtractExistingKeys(unittest.TestCase):
    def test_extracts_single_key(self):
        from kb_lint_proposals import extract_existing_keys

        text = "- [ ] Do the thing <!-- kb-lint-key: link:note-a|note-b -->\n"
        self.assertEqual(extract_existing_keys(text), {"link:note-a|note-b"})

    def test_extracts_multiple_keys(self):
        from kb_lint_proposals import extract_existing_keys

        text = (
            "- [ ] one <!-- kb-lint-key: link:a|b -->\n"
            "- [x] two <!-- kb-lint-key: cross-link:c|d -->\n"
        )
        self.assertEqual(extract_existing_keys(text), {"link:a|b", "cross-link:c|d"})

    def test_no_keys_in_plain_text(self):
        from kb_lint_proposals import extract_existing_keys

        self.assertEqual(extract_existing_keys("# Open Proposals\n\nnothing here yet\n"), set())


class TestDedupeNewProposals(unittest.TestCase):
    def test_drops_already_recorded_proposal(self):
        from kb_lint_proposals import dedupe_new_proposals, proposal_key

        existing = {proposal_key("link", ["Note A", "Note B"])}
        proposals = [("link", ["Note A", "Note B"], "already recorded")]
        self.assertEqual(dedupe_new_proposals(existing, proposals), [])

    def test_keeps_novel_proposal(self):
        from kb_lint_proposals import dedupe_new_proposals

        proposals = [("link", ["Note A", "Note B"], "new one")]
        self.assertEqual(dedupe_new_proposals(set(), proposals), proposals)

    def test_dedupes_within_the_same_batch(self):
        from kb_lint_proposals import dedupe_new_proposals

        proposals = [
            ("link", ["Note A", "Note B"], "first phrasing"),
            ("link", ["Note B", "Note A"], "duplicate, reordered targets"),
        ]
        kept = dedupe_new_proposals(set(), proposals)
        self.assertEqual(kept, [proposals[0]])

    def test_cross_link_kind_is_independent_of_link(self):
        from kb_lint_proposals import dedupe_new_proposals, proposal_key

        existing = {proposal_key("link", ["Note A", "Note B"])}
        proposals = [("cross-link", ["Note A", "Note B"], "different kind, not a dup")]
        self.assertEqual(dedupe_new_proposals(existing, proposals), proposals)


if __name__ == "__main__":
    unittest.main()
