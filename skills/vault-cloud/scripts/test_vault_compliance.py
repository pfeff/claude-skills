#!/usr/bin/env python3
"""Unit tests for vault_compliance (zero-dependency stdlib unittest).

    cd skills/vault-cloud/scripts && python3 -m unittest test_vault_compliance
"""

import unittest

import vault_compliance as vc


# A trimmed but structurally faithful copy of the live _meta/vocabulary.md, including the
# "(optional, single-value)" heading suffixes and the |---| separator rows, so the parser is
# tested against the real file shape.
SAMPLE_VOCAB = """\
# Vault Vocabulary

## type (required, single-value)

| Value | Description |
|---|---|
| zettel | Atomic idea |
| reference | Factual lookup |
| moc | Map of content |

## area (optional, single-value)

| Value | Description |
|---|---|
| career | Professional development |
| health | Health |

## project (optional, single-value)

| Value | Description |
|---|---|
| job-search | Land a role |

## status (optional, single-value)

| Value | Description |
|---|---|
| active | In progress |
| archived | No longer relevant |

## tags (optional, multi-value)

Freeform.
"""


class TestParseVocabulary(unittest.TestCase):
    def setUp(self):
        self.vocab = vc.parse_vocabulary(SAMPLE_VOCAB)

    def test_extracts_type_values(self):
        self.assertEqual(self.vocab["type"], {"zettel", "reference", "moc"})

    def test_extracts_area_and_project_and_status(self):
        self.assertEqual(self.vocab["area"], {"career", "health"})
        self.assertEqual(self.vocab["project"], {"job-search"})
        self.assertEqual(self.vocab["status"], {"active", "archived"})

    def test_tags_not_a_constrained_field(self):
        self.assertNotIn("tags", self.vocab)

    def test_skips_header_and_separator_rows(self):
        for field in vc.CONSTRAINED_FIELDS:
            self.assertNotIn("Value", self.vocab[field])
            self.assertNotIn("---", self.vocab[field])

    def test_missing_section_is_empty_set_not_error(self):
        vocab = vc.parse_vocabulary("# nothing here\n")
        self.assertEqual(vocab["type"], set())
        self.assertEqual(vocab["project"], set())


class TestSlugify(unittest.TestCase):
    def test_lowercases_and_hyphenates(self):
        self.assertEqual(vc.slugify("Supabase IaC Role"), "supabase-iac-role")

    def test_collapses_punctuation_runs(self):
        self.assertEqual(vc.slugify("Claude Sonnet 5 vs Opus 4.8: Which?"),
                         "claude-sonnet-5-vs-opus-4-8-which")

    def test_trims_leading_trailing_separators(self):
        self.assertEqual(vc.slugify("  !!Hello!!  "), "hello")


class TestNotePath(unittest.TestCase):
    def test_builds_year_month_path(self):
        self.assertEqual(vc.note_path("2026-08-02", "cloud-access"),
                         "2026/08/2026-08-02-cloud-access.md")

    def test_rejects_non_iso_date(self):
        with self.assertRaises(ValueError):
            vc.note_path("Aug 2 2026", "x")
        with self.assertRaises(ValueError):
            vc.note_path("2026-8-2", "x")

    def test_rejects_empty_slug(self):
        # slugify("!!!") -> "" ; a note must not land at "…-.md"
        with self.assertRaises(ValueError):
            vc.note_path("2026-08-02", vc.slugify("!!!"))


class TestQuoting(unittest.TestCase):
    def test_plain_scalar_unquoted(self):
        self.assertEqual(vc.yaml_scalar("supabase-iac-role"), "supabase-iac-role")
        self.assertEqual(vc.yaml_scalar("reference"), "reference")

    def test_colon_space_forces_quote(self):
        self.assertEqual(vc.yaml_scalar("Opus 4.8: Which Model"),
                         '"Opus 4.8: Which Model"')

    def test_leading_indicator_and_hash_and_at(self):
        self.assertTrue(vc.needs_quoting("@fofr"))
        self.assertTrue(vc.needs_quoting("[draft]"))
        self.assertTrue(vc.needs_quoting("value # comment"))
        self.assertTrue(vc.needs_quoting("- leading dash"))

    def test_bool_null_number_lookalikes_quoted(self):
        for s in ("true", "False", "null", "no", "123", "1.5", "-3"):
            self.assertTrue(vc.needs_quoting(s), s)
        self.assertEqual(vc.yaml_scalar("123"), '"123"')

    def test_interior_quote_without_colon_is_plain(self):
        # A double quote in the middle of an otherwise-safe plain scalar is legal YAML.
        self.assertEqual(vc.yaml_scalar('a "b" c'), 'a "b" c')

    def test_escapes_embedded_quotes_and_backslashes(self):
        # A ": " forces quoting; embedded " and \ must then be escaped.
        self.assertEqual(vc.yaml_scalar('he said: "hi"'), '"he said: \\"hi\\""')
        self.assertEqual(vc.yaml_scalar("a\\b: c"), '"a\\\\b: c"')

    def test_whitespace_edges_quoted(self):
        self.assertTrue(vc.needs_quoting(" leading"))
        self.assertTrue(vc.needs_quoting("trailing "))


class TestEmitFrontmatter(unittest.TestCase):
    def test_field_order_and_block_tags(self):
        fm = vc.emit_frontmatter({
            "type": "reference",
            "area": "career",
            "project": "Job Search",
            "status": "active",
            "date": "2026-08-02",
            "tags": ["job-lead", "terraform"],
        })
        # "Job Search" has an interior space but no ": " / "#" / leading indicator, so it is a
        # legal YAML plain scalar and stays unquoted.
        self.assertEqual(fm, "\n".join([
            "---",
            "type: reference",
            "area: career",
            "project: Job Search",
            "status: active",
            "date: 2026-08-02",
            "tags:",
            "  - job-lead",
            "  - terraform",
            "---",
        ]))

    def test_omits_empty_optional_singles(self):
        fm = vc.emit_frontmatter({
            "type": "zettel", "area": "", "project": None,
            "status": "active", "date": "2026-08-02", "tags": [],
        })
        self.assertIn("type: zettel", fm)
        self.assertNotIn("area:", fm)
        self.assertNotIn("project:", fm)
        self.assertIn("tags: []", fm)

    def test_empty_extra_scalar_skipped(self):
        # An extra (non-known) key with an empty value is skipped, symmetric with the
        # known optional fields — no blank `key: ""` line.
        fm = vc.emit_frontmatter({
            "type": "reference", "date": "2026-08-02", "source_key": "",
        })
        self.assertNotIn("source_key", fm)

    def test_type_emitted_first(self):
        fm = vc.emit_frontmatter({"date": "2026-08-02", "type": "moc"})
        body = fm.splitlines()
        self.assertEqual(body[1], "type: moc")

    def test_extra_keys_ride_along_after_known(self):
        fm = vc.emit_frontmatter({
            "type": "reference", "date": "2026-08-02",
            "source_key": "readwise-42", "sources": ["[[a]]", "[[b]]"],
        })
        self.assertIn("source_key: readwise-42", fm)
        self.assertIn("sources:", fm)
        # Wikilinks start with "[" (a YAML indicator), so they are quoted — the same way
        # Obsidian serializes link-valued list properties.
        self.assertIn('  - "[[a]]"', fm)


class TestValidateFrontmatter(unittest.TestCase):
    def setUp(self):
        self.vocab = vc.parse_vocabulary(SAMPLE_VOCAB)

    def test_compliant_note_has_no_violations(self):
        v = vc.validate_frontmatter(
            {"type": "reference", "area": "career", "project": "job-search",
             "status": "active", "tags": ["anything", "freeform"]},
            self.vocab,
        )
        self.assertEqual(v, [])

    def test_missing_type_flagged(self):
        v = vc.validate_frontmatter({"status": "active"}, self.vocab)
        self.assertTrue(any("type" in m for m in v))

    def test_unknown_type_flagged(self):
        v = vc.validate_frontmatter({"type": "invented"}, self.vocab)
        self.assertTrue(any("invented" in m for m in v))

    def test_unknown_project_flagged(self):
        v = vc.validate_frontmatter({"type": "reference", "project": "mystery"}, self.vocab)
        self.assertTrue(any("project" in m and "mystery" in m for m in v))

    def test_absent_optional_fields_ok(self):
        v = vc.validate_frontmatter({"type": "zettel"}, self.vocab)
        self.assertEqual(v, [])

    def test_freeform_tags_never_flagged(self):
        v = vc.validate_frontmatter(
            {"type": "zettel", "tags": ["brand-new-tag", "another"]}, self.vocab)
        self.assertEqual(v, [])

    def test_unparsed_vocab_skips_constraint(self):
        empty = {f: set() for f in vc.CONSTRAINED_FIELDS}
        v = vc.validate_frontmatter({"type": "anything", "project": "whatever"}, empty)
        self.assertEqual(v, [])  # type present, no constraint sets to check against


if __name__ == "__main__":
    unittest.main()
