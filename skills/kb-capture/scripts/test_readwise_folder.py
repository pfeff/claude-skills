"""Tests for readwise_folder.py — the plugin-folder parser for the kb-capture plugin-hybrid.

Fixtures below are trimmed, literal excerpts from live vault notes (captured during the
2026-07-18 premise-verification pass), not invented shapes — in particular the NBSP before
Kindle location numbers and the no-newline-before-heading append quirk are reproduced exactly
as observed, because a "clean" synthetic fixture would not have caught either bug.

Run: python3 -m unittest test_readwise_folder   (from this scripts/ directory)
"""

import unittest

from readwise_folder import (
    collect_sources,
    extract_book_id,
    extract_highlights,
    extract_metadata,
    group_by_book_id,
    merge_highlights,
    notes_count,
    split_into_book_blocks,
    split_sections,
)


# Live excerpt: Readwise/Books/🔖Perfect Health Diet.md (verbatim, incl. the U+00A0 NBSP
# before each Location number).
PERFECT_HEALTH_DIET = (
    "## New highlights added July 27, 2023 at 7:45 PM\n"
    "- Be wary of gut problems. If you experience symptoms of digestive tract dysfunction, "
    "such as acid reflux, consider avoiding alcohol until your gut is healthy. "
    "([Location 3132](https://readwise.io/to_kindle?action=open&asin=B007USA6MM&location=3132))\n"
    "- Reduced neurological and cognitive function. "
    "([Location 4784](https://readwise.io/to_kindle?action=open&asin=B007USA6MM&location=4784))\n"
    "## New highlights added November 26, 2024 at 12:20 PM\n"
    "- nutrients are no substitute for food—edible "
    "([Location 1180](https://readwise.io/to_kindle?action=open&asin=B007USA6MM&location=1180))\n"
)

# Live excerpt: Readwise/Articles/🔖How to Do Great Work.md, reproducing the observed quirk
# where the plugin's appended heading shares a physical line with the prior highlight's
# closing backlink (no newline inserted between them).
GLUED_HEADING = (
    "---\n"
    "category: #articles\n"
    "book_id: 30226157\n"
    "state: done\n"
    "---\n"
    "## Metadata\n"
    "* Author: [[Paul Graham]]\n"
    "* Full Title: How to Do Great Work\n"
    "* URL: http://paulgraham.com/greatwork.html\n\n"
    "## Highlights\n"
    "- Try lots of things, meet lots of people, read lots of books, ask lots of questions.\n"
    "        - ([View Highlight](https://read.readwise.io/read/01h5q0bknhpj3q7jkcrp272ka0))"
    "## New highlights added August 3, 2023 at 7:17 AM\n"
    "- I think for most people who want to do great work, the right strategy is not to plan "
    "too much. "
    "([View Highlight](https://read.readwise.io/read/01h6wgjc3jcmz3fehezcceg013))\n"
)

# Live-shaped excerpt: nested doc-outline rendering (article/Reader highlight style) — a
# structural heading bullet followed by two highlight bullets, each broken across an
# indentation level, each terminated by its own backlink line.
NESTED_OUTLINE = (
    "## Highlights\n"
    "- ## Deciding What to Work On\n"
    "    - The first step is to decide what to work on.\n"
    "        - The work you choose needs to have three qualities.\n"
    "            - ([View Highlight](https://read.readwise.io/read/aaa111))\n"
    "    - The way to figure out what to work on is by working.\n"
    "        - If you're not sure what to work on, guess.\n"
    "            - ([View Highlight](https://read.readwise.io/read/bbb222))\n"
)

# Live-shaped excerpt: an annotation ("Note:") attached to a highlight.
# Live excerpt: Readwise/Articles/🔖THREAD The top 6 ways to make sure your book....md —
# a highlighted line whose OWN content starts with a bare "#" (numbered-list style, no space
# after the hash). Must not be mistaken for a structural "## Heading" bullet and dropped.
HASH_PREFIXED_HIGHLIGHT = (
    "## Highlights\n"
    "- #1: Know Your Objective "
    "([View Highlight](https://read.readwise.io/read/01gmdp93twwhfvmqnpwdab9jd2))\n"
)

WITH_NOTE = (
    "## Highlights\n"
    "- Some interesting passage. "
    "([View Highlight](https://read.readwise.io/read/ccc333))\n"
    "    - Note: #Question worth revisiting\n"
)

# Live excerpt: Readwise/Articles/🔖Well Being Cardiovascular Damage & Health.md — a
# highlight whose entire visible text lives inside a "- Note: ... (backlink)" line, with
# nothing else on it (no separate highlight-text line precedes it). Must still be extracted
# as a highlight, not dropped as if it were purely a trailing annotation.
NOTE_LINE_IS_THE_HIGHLIGHT = (
    "## Highlights\n"
    "#### Magnesium:\n"
    "- Note: Taking vitamin D in high levels can lower magnesium stores. "
    "([View Highlight](https://read.readwise.io/read/dddeee))\n"
    "#### Taurine:\n"
    "- Taurine improves vascular health. "
    "([View Highlight](https://read.readwise.io/read/fffggg))\n"
)

GEN3_FRONTMATTER = (
    "---\n"
    "author: [[amazon.com]]\n"
    "tags: #articles\n"
    "url: https://docs.aws.amazon.com/example.html\n"
    "book_id: 50386490\n"
    "state: toImport\n"
    "---\n"
    "# The management account\n\n"
    "## Highlights\n"
    "- The management account is unique. "
    "([View Highlight](https://read.readwise.io/read/01jrd699qn5m7m3jsnfv374kt7))\n"
)

# Live excerpt: Readwise/Books/🔖Zero to One.md — an empty "* URL: " bullet immediately
# followed by another bullet on the next line. A `\s*` (rather than `[ \t]*`) after the colon
# would cross the newline and swallow "* Synced On: ..." whole as the URL value (a real bug
# this fixture caught).
EMPTY_URL_BULLET = (
    "---\n"
    "category: #books\n"
    "book_id: 5707597\n"
    "state: toImport\n"
    "---\n"
    "## Metadata\n"
    "* Author: [[Peter Thiel, Blake Masters]]\n"
    "* Full Title: Zero to One\n"
    "* URL: \n"
    "* Synced On: 2023-10-02 10:27 AM\n"
    "* Last Highlight: 2023-09-22 04:56:00+00:00\n\n"
    "## Highlights\n"
    "- Doing what we already know how to do takes the world from 1 to n. "
    "([Location 48](https://readwise.io/to_kindle?action=open&asin=B00J6YBOFQ&location=48))\n"
)

# Live-shaped excerpt: Readwise/Articles/🔖Google - Site Reliability Engineering.md — a title
# collision the plugin resolved by concatenating a SECOND complete source export (own
# frontmatter, own book_id, own "## Metadata"/"## Highlights") into the same file instead of
# writing a "-2.md" sibling. Verified live on 5/1235 Readwise/ notes; naive single-block
# parsing found only the LAST "## Highlights" and silently dropped the first source's
# highlights entirely (the bug `split_into_book_blocks` exists to fix).
TWO_SOURCES_ONE_FILE = (
    "---\n"
    "url: https://sre.google/sre-book/introduction/\n"
    "book_id: 30162771\n"
    "---\n"
    "## Metadata\n"
    "* Full Title: Google - Site Reliability Engineering (Introduction)\n\n"
    "## Highlights\n"
    "- Direct costs. ([View Highlight](https://read.readwise.io/read/first0001))\n"
    "- Indirect costs. ([View Highlight](https://read.readwise.io/read/first0002))\n"
    "---\n"
    "url: https://sre.google/sre-book/production-environment/\n"
    "book_id: 31889046\n"
    "---\n"
    "## Metadata\n"
    "* Full Title: Google - Site Reliability Engineering (Production Environment)\n\n"
    "## Highlights\n"
    "- A machine is a piece of hardware. ([View Highlight](https://read.readwise.io/read/second0001))\n"
)

# Live shape: no frontmatter at all, no book_id (Readwise/Books/🔖Clean Code.md style).
NO_ID_NOTE = (
    "## New highlights added July 27, 2023 at 7:29 AM\n"
    "- Error handling is important. "
    "([Location 120](https://readwise.io/to_kindle?action=open&asin=X&location=120))\n"
)


class TestExtractBookId(unittest.TestCase):
    def test_present(self):
        self.assertEqual(extract_book_id(GEN3_FRONTMATTER), "50386490")

    def test_absent(self):
        self.assertIsNone(extract_book_id(NO_ID_NOTE))

    def test_absent_on_dated_only_note(self):
        # Live case: 🔖Perfect Health Diet.md has book_id in neither of its two live
        # generations — verified against the vault, not assumed.
        self.assertIsNone(extract_book_id(PERFECT_HEALTH_DIET))


class TestSplitSections(unittest.TestCase):
    def test_single_section_when_no_marker(self):
        self.assertEqual(split_sections(GEN3_FRONTMATTER), [GEN3_FRONTMATTER])

    def test_two_dated_sections(self):
        # PERFECT_HEALTH_DIET has no preamble before its first marker, so split_sections
        # returns an empty initial section plus one section per dated marker (3 total).
        sections = split_sections(PERFECT_HEALTH_DIET)
        self.assertEqual(len(sections), 3)
        self.assertEqual(sections[0], "")
        self.assertIn("3132", sections[1])
        self.assertIn("4784", sections[1])
        self.assertNotIn("1180", sections[1])
        self.assertIn("1180", sections[2])

    def test_no_content_lost_across_split(self):
        # Every character is accounted for exactly once.
        self.assertEqual("".join(split_sections(PERFECT_HEALTH_DIET)), PERFECT_HEALTH_DIET)

    def test_glued_heading_still_splits(self):
        sections = split_sections(GLUED_HEADING)
        self.assertEqual(len(sections), 2)
        self.assertIn("01h5q0bknhpj3q7jkcrp272ka0", sections[0])
        self.assertNotIn("01h6wgjc3jcmz3fehezcceg013", sections[0])
        self.assertIn("01h6wgjc3jcmz3fehezcceg013", sections[1])


class TestExtractHighlights(unittest.TestCase):
    def test_aggregates_all_dated_sections(self):
        # The regression this whole reformat exists to avoid: dropping everything but the
        # first dated section.
        highlights = extract_highlights(PERFECT_HEALTH_DIET)
        self.assertEqual(len(highlights), 3)
        backlinks = {h["backlink"] for h in highlights}
        self.assertEqual(len(backlinks), 3)

    def test_kindle_location_form_with_nbsp(self):
        highlights = extract_highlights(PERFECT_HEALTH_DIET)
        self.assertTrue(highlights[0]["text"].startswith("Be wary of gut problems"))
        self.assertIn("readwise.io/to_kindle", highlights[0]["backlink"])

    def test_view_highlight_form(self):
        highlights = extract_highlights(GEN3_FRONTMATTER)
        self.assertEqual(len(highlights), 1)
        self.assertEqual(highlights[0]["text"], "The management account is unique.")
        self.assertIn("read.readwise.io/read", highlights[0]["backlink"])

    def test_glued_heading_does_not_lose_or_merge_highlights(self):
        highlights = extract_highlights(GLUED_HEADING)
        self.assertEqual(len(highlights), 2)
        self.assertTrue(highlights[0]["text"].startswith("Try lots of things"))
        self.assertTrue(highlights[1]["text"].startswith("I think for most people"))

    def test_nested_outline_extracts_both_highlights_without_structural_heading(self):
        highlights = extract_highlights(NESTED_OUTLINE)
        self.assertEqual(len(highlights), 2)
        for h in highlights:
            self.assertNotIn("Deciding What to Work On", h["text"])
        self.assertIn("three qualities", highlights[0]["text"])
        self.assertIn("guess", highlights[1]["text"])

    def test_note_attached_to_highlight(self):
        highlights = extract_highlights(WITH_NOTE)
        self.assertEqual(len(highlights), 1)
        self.assertEqual(highlights[0]["note"], "#Question worth revisiting")
        self.assertNotIn("Note:", highlights[0]["text"])

    def test_note_line_carrying_its_own_backlink_is_not_dropped(self):
        highlights = extract_highlights(NOTE_LINE_IS_THE_HIGHLIGHT)
        self.assertEqual(len(highlights), 2)
        self.assertIn("Taking vitamin D", highlights[0]["text"])
        self.assertIn("Taurine improves", highlights[1]["text"])

    def test_no_backlink_no_highlight(self):
        self.assertEqual(extract_highlights("## Highlights\n- just some prose\n"), [])

    def test_hash_prefixed_highlight_not_mistaken_for_heading(self):
        highlights = extract_highlights(HASH_PREFIXED_HIGHLIGHT)
        self.assertEqual(len(highlights), 1)
        self.assertEqual(highlights[0]["text"], "#1: Know Your Objective")


class TestMergeHighlights(unittest.TestCase):
    def test_dedupes_by_backlink_across_duplicate_files(self):
        a = extract_highlights(GEN3_FRONTMATTER)
        b = extract_highlights(GEN3_FRONTMATTER)  # simulates a gen1/gen2 duplicate file
        merged = merge_highlights([a, b])
        self.assertEqual(len(merged), 1)

    def test_unions_distinct_highlights(self):
        a = extract_highlights(GEN3_FRONTMATTER)
        b = extract_highlights(NESTED_OUTLINE)
        merged = merge_highlights([a, b])
        self.assertEqual(len(merged), 3)

    def test_preserves_first_seen_order(self):
        a = extract_highlights(PERFECT_HEALTH_DIET)
        merged = merge_highlights([a, []])
        self.assertEqual([h["backlink"] for h in merged], [h["backlink"] for h in a])


class TestGroupByBookId(unittest.TestCase):
    def test_groups_matching_ids(self):
        groups = group_by_book_id(
            {
                "Readwise/Books/A.md": GEN3_FRONTMATTER,
                "Readwise/Books/A-dup.md": GEN3_FRONTMATTER,
                "Readwise/Books/NoId.md": NO_ID_NOTE,
            }
        )
        self.assertEqual(set(groups.keys()), {"50386490"})
        self.assertEqual(
            set(groups["50386490"]), {"Readwise/Books/A.md", "Readwise/Books/A-dup.md"}
        )

    def test_id_less_notes_omitted(self):
        groups = group_by_book_id({"x.md": NO_ID_NOTE, "y.md": PERFECT_HEALTH_DIET})
        self.assertEqual(groups, {})


class TestExtractMetadata(unittest.TestCase):
    def test_frontmatter_url_and_author(self):
        meta = extract_metadata(GEN3_FRONTMATTER)
        self.assertEqual(meta["url"], "https://docs.aws.amazon.com/example.html")
        self.assertEqual(meta["author"], "amazon.com")
        self.assertEqual(meta["title"], "The management account")

    def test_metadata_bullets_fallback(self):
        meta = extract_metadata(GLUED_HEADING)
        self.assertEqual(meta["author"], "Paul Graham")
        self.assertEqual(meta["title"], "How to Do Great Work")
        self.assertEqual(meta["url"], "http://paulgraham.com/greatwork.html")

    def test_missing_fields_are_empty_not_raising(self):
        meta = extract_metadata(NO_ID_NOTE)
        self.assertEqual(meta, {"title": "", "author": "", "url": ""})

    def test_empty_bullet_value_does_not_swallow_next_line(self):
        meta = extract_metadata(EMPTY_URL_BULLET)
        self.assertEqual(meta["url"], "")
        self.assertEqual(meta["author"], "Peter Thiel, Blake Masters")
        self.assertEqual(meta["title"], "Zero to One")


class TestNotesCount(unittest.TestCase):
    def test_counts_only_highlights_with_notes(self):
        highlights = extract_highlights(WITH_NOTE) + extract_highlights(GEN3_FRONTMATTER)
        self.assertEqual(notes_count(highlights), 1)


class TestSplitIntoBookBlocks(unittest.TestCase):
    def test_single_block_for_ordinary_file(self):
        self.assertEqual(split_into_book_blocks(GEN3_FRONTMATTER), [GEN3_FRONTMATTER])

    def test_dated_only_file_is_one_block(self):
        self.assertEqual(split_into_book_blocks(PERFECT_HEALTH_DIET), [PERFECT_HEALTH_DIET])

    def test_two_concatenated_sources_split_into_two_blocks(self):
        blocks = split_into_book_blocks(TWO_SOURCES_ONE_FILE)
        self.assertEqual(len(blocks), 2)
        self.assertEqual(extract_book_id(blocks[0]), "30162771")
        self.assertEqual(extract_book_id(blocks[1]), "31889046")

    def test_no_content_lost_across_split(self):
        self.assertEqual("".join(split_into_book_blocks(TWO_SOURCES_ONE_FILE)), TWO_SOURCES_ONE_FILE)

    def test_each_block_keeps_only_its_own_highlights(self):
        blocks = split_into_book_blocks(TWO_SOURCES_ONE_FILE)
        first_highlights = extract_highlights(blocks[0])
        second_highlights = extract_highlights(blocks[1])
        self.assertEqual(len(first_highlights), 2)
        self.assertEqual(len(second_highlights), 1)


class TestCollectSources(unittest.TestCase):
    def test_recovers_both_sources_from_one_concatenated_file(self):
        sources = collect_sources({"Readwise/Articles/dup.md": TWO_SOURCES_ONE_FILE})
        self.assertEqual(set(sources.keys()), {"30162771", "31889046"})
        self.assertEqual(len(sources["30162771"]["highlights"]), 2)
        self.assertEqual(len(sources["31889046"]["highlights"]), 1)

    def test_merges_gen1_gen2_duplicate_files_by_book_id(self):
        sources = collect_sources(
            {
                "Readwise/Books/A.md": GEN3_FRONTMATTER,
                "Readwise/Books/A-dup.md": GEN3_FRONTMATTER,
            }
        )
        self.assertEqual(len(sources), 1)
        entry = sources["50386490"]
        self.assertEqual(len(entry["highlights"]), 1)  # deduped, not doubled
        self.assertEqual(
            set(entry["paths"]), {"Readwise/Books/A.md", "Readwise/Books/A-dup.md"}
        )

    def test_id_less_files_omitted(self):
        sources = collect_sources({"x.md": NO_ID_NOTE, "y.md": PERFECT_HEALTH_DIET})
        self.assertEqual(sources, {})

    def test_metadata_captured(self):
        sources = collect_sources({"a.md": GLUED_HEADING})
        self.assertEqual(sources["30226157"]["metadata"]["title"], "How to Do Great Work")


if __name__ == "__main__":
    unittest.main()
