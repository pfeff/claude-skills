"""Tests for drift_check.py — mechanical skills-estate drift detection.

Exercises the real git binary against real fixture repos (no mocks — same convention as
kb-lint's test_kb_lint_git.py). Fixtures are modeled on the three real drift instances found
in pfeff/claude-skills on 2026-07-21:

  1. unreleased plugin content — a PR-style commit ("...(#191)") touching skills/** merged
     after the last version-bump commit to .claude-plugin/plugin.json.
  2. a dangling file reference — a SKILL.md referencing a WORK-DOMAINS.md-style path that
     does not exist.
  3. a registry/dir mismatch — a skills/ directory absent from marketplace.json.

Run: python3 -m unittest test_drift_check   (from this scripts/ directory)
"""

import json
import os
import shutil
import subprocess
import tempfile
import unittest

import drift_check


def _git(args, cwd):
    subprocess.run(["git"] + args, cwd=cwd, check=True, capture_output=True, text=True)


def _write(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)


def _init_repo(root):
    _git(["init", "-q"], root)
    _git(["config", "user.email", "test@example.com"], root)
    _git(["config", "user.name", "Test"], root)


def _commit(root, message):
    _git(["add", "-A"], root)
    _git(["commit", "-q", "-m", message], root)


def _plugin_json(version):
    return json.dumps({"name": "mbp", "version": version, "description": "test"}, indent=2) + "\n"


def _marketplace_json(skill_names):
    return (
        json.dumps(
            {
                "name": "pfeff",
                "plugins": [
                    {
                        "name": "mbp",
                        "source": "./",
                        "skills": [f"./skills/{name}" for name in skill_names],
                    }
                ],
            },
            indent=2,
        )
        + "\n"
    )


class DriftCheckTestCase(unittest.TestCase):
    def setUp(self):
        self.repo = tempfile.mkdtemp(prefix="drift-check-test-")
        _init_repo(self.repo)

    def tearDown(self):
        shutil.rmtree(self.repo, ignore_errors=True)

    def _path(self, *parts):
        return os.path.join(self.repo, *parts)


# --- find_repo_root -------------------------------------------------------------


class TestFindRepoRoot(DriftCheckTestCase):
    def test_finds_root_from_nested_dir(self):
        _write(self._path(".claude-plugin", "plugin.json"), _plugin_json("1.0.0"))
        nested = self._path("skills", "foo")
        os.makedirs(nested, exist_ok=True)
        self.assertEqual(
            os.path.realpath(drift_check.find_repo_root(nested)),
            os.path.realpath(self.repo),
        )

    def test_returns_none_when_not_found(self):
        outside = tempfile.mkdtemp(prefix="drift-check-test-outside-")
        try:
            self.assertIsNone(drift_check.find_repo_root(outside))
        finally:
            shutil.rmtree(outside, ignore_errors=True)


# --- Check 1: unreleased plugin content ------------------------------------------


class TestUnreleasedDrift(DriftCheckTestCase):
    def _seed_base(self):
        _write(self._path(".claude-plugin", "plugin.json"), _plugin_json("1.0.0"))
        _write(self._path(".claude-plugin", "marketplace.json"), _marketplace_json(["foo"]))
        _write(self._path("skills", "foo", "SKILL.md"), "# foo\n")
        _commit(self.repo, "chore: scaffold repo")

    def test_detects_unreleased_pr_after_version_bump(self):
        # Modeled on real drift instance 1: PR #191 merged after the last version bump.
        self._seed_base()
        _write(self._path(".claude-plugin", "plugin.json"), _plugin_json("1.1.0"))
        _commit(self.repo, "chore: bump plugin version to 1.1.0")

        _write(self._path("skills", "foo", "scripts", "new.py"), "# new capability\n")
        _commit(self.repo, "feat(foo): add new capability (#191)")

        result = drift_check.check_unreleased_drift(self.repo)
        self.assertTrue(result["drifted"])
        self.assertEqual(result["count"], 1)
        self.assertEqual(result["pr_numbers"], ["191"])
        self.assertIn("feat(foo): add new capability (#191)", result["commits"][0][1])

    def test_clean_when_version_bump_is_last_commit(self):
        self._seed_base()
        _write(self._path(".claude-plugin", "plugin.json"), _plugin_json("1.1.0"))
        _commit(self.repo, "chore: bump plugin version to 1.1.0")

        result = drift_check.check_unreleased_drift(self.repo)
        self.assertFalse(result["drifted"])
        self.assertEqual(result["count"], 0)
        self.assertEqual(result["pr_numbers"], [])

    def test_clean_when_unrelated_paths_change_after_bump(self):
        self._seed_base()
        _write(self._path(".claude-plugin", "plugin.json"), _plugin_json("1.1.0"))
        _commit(self.repo, "chore: bump plugin version to 1.1.0")

        _write(self._path("README.md"), "unrelated docs change\n")
        _commit(self.repo, "docs: update README")

        result = drift_check.check_unreleased_drift(self.repo)
        self.assertFalse(result["drifted"])

    def test_no_version_history_yields_no_drift(self):
        # No .claude-plugin/plugin.json history at all -> since_commit is None.
        _write(self._path("README.md"), "hello\n")
        _commit(self.repo, "chore: init")

        result = drift_check.check_unreleased_drift(self.repo)
        self.assertFalse(result["drifted"])
        self.assertEqual(result["commits"], [])

    def test_multiple_prs_all_counted(self):
        self._seed_base()
        _write(self._path(".claude-plugin", "plugin.json"), _plugin_json("1.1.0"))
        _commit(self.repo, "chore: bump plugin version to 1.1.0")

        _write(self._path("skills", "foo", "a.md"), "a\n")
        _commit(self.repo, "feat(foo): a (#201)")
        _write(self._path("skills", "foo", "b.md"), "b\n")
        _commit(self.repo, "feat(foo): b (#202)")

        result = drift_check.check_unreleased_drift(self.repo)
        self.assertEqual(result["count"], 2)
        self.assertEqual(sorted(result["pr_numbers"]), ["201", "202"])


# --- Check 2: dangling file references -------------------------------------------


class TestDanglingReferences(DriftCheckTestCase):
    def test_detects_dangling_plugin_root_reference(self):
        # Modeled on real drift instance 2: kb-capture's dangling WORK-DOMAINS.md reference.
        _write(
            self._path("skills", "kb-capture", "SKILL.md"),
            "# kb-capture\n\nSee `${CLAUDE_PLUGIN_ROOT}/skills/kb-capture/WORK-DOMAINS.md` "
            "for the work-relevance criterion.\n",
        )
        result = drift_check.check_dangling_references(self.repo)
        self.assertTrue(result["drifted"])
        self.assertEqual(result["count"], 1)
        doc_path, raw_ref, resolved = result["findings"][0]
        self.assertEqual(doc_path, os.path.join("skills", "kb-capture", "SKILL.md"))
        self.assertEqual(raw_ref, "skills/kb-capture/WORK-DOMAINS.md")
        self.assertEqual(resolved, os.path.join("skills", "kb-capture", "WORK-DOMAINS.md"))

    def test_clean_when_referenced_file_exists(self):
        skill_dir = self._path("skills", "foo")
        _write(os.path.join(skill_dir, "operations", "real.md"), "# real op\n")
        _write(
            os.path.join(skill_dir, "SKILL.md"),
            "# foo\n\nSee `${CLAUDE_PLUGIN_ROOT}/skills/foo/operations/real.md`.\n",
        )
        result = drift_check.check_dangling_references(self.repo)
        self.assertFalse(result["drifted"])
        self.assertEqual(result["count"], 0)

    def test_bare_skills_relative_reference_resolved_from_repo_root(self):
        _write(self._path("skills", "bar", "references", "spec.md"), "# spec\n")
        _write(
            self._path("skills", "foo", "SKILL.md"),
            "# foo\n\nSee also `skills/bar/references/spec.md`.\n",
        )
        result = drift_check.check_dangling_references(self.repo)
        self.assertFalse(result["drifted"])

    def test_bare_scripts_relative_reference_resolved_from_skill_dir(self):
        skill_dir = self._path("skills", "foo")
        _write(os.path.join(skill_dir, "scripts", "foo_core.py"), "# core\n")
        _write(
            os.path.join(skill_dir, "SKILL.md"),
            "# foo\n\n`scripts/foo_core.py` — pure primitives.\n",
        )
        result = drift_check.check_dangling_references(self.repo)
        self.assertFalse(result["drifted"])

    def test_dangling_scripts_relative_reference_detected(self):
        _write(
            self._path("skills", "foo", "SKILL.md"),
            "# foo\n\n`scripts/missing_module.py` — does not exist.\n",
        )
        result = drift_check.check_dangling_references(self.repo)
        self.assertTrue(result["drifted"])
        self.assertEqual(result["count"], 1)

    def test_scripts_relative_reference_falls_back_to_repo_root_scripts(self):
        # Some skills (cadence-goals, skillify) reference the repo's top-level
        # scripts/ maintainer tooling with the same bare `scripts/...` convention
        # kb-core uses for its own scripts/ dir. Both candidates must be tried
        # before flagging dangling.
        _write(self._path("scripts", "maintainer-tool.sh"), "#!/bin/sh\n")
        _write(
            self._path("skills", "foo", "SKILL.md"),
            "# foo\n\nRun `scripts/maintainer-tool.sh` after a release.\n",
        )
        result = drift_check.check_dangling_references(self.repo)
        self.assertFalse(result["drifted"])

    def test_scans_operations_directory(self):
        skill_dir = self._path("skills", "foo")
        _write(
            os.path.join(skill_dir, "operations", "run.md"),
            "Load `${CLAUDE_PLUGIN_ROOT}/skills/foo/scripts/absent.py`.\n",
        )
        _write(os.path.join(skill_dir, "SKILL.md"), "# foo\n")
        result = drift_check.check_dangling_references(self.repo)
        self.assertTrue(result["drifted"])
        self.assertIn(
            os.path.join("skills", "foo", "operations", "run.md"),
            [doc for doc, _, _ in result["findings"]],
        )

    def test_no_skills_dir_yields_no_findings(self):
        result = drift_check.check_dangling_references(self.repo)
        self.assertFalse(result["drifted"])
        self.assertEqual(result["findings"], [])

    def test_prose_without_backticks_not_flagged(self):
        # High-precision, not high-recall (documented limitation): unquoted mentions of a
        # path are not scanned, to avoid false positives.
        _write(
            self._path("skills", "foo", "SKILL.md"),
            "# foo\n\nSee skills/foo/NOPE.md for details (no backticks, not matched).\n",
        )
        result = drift_check.check_dangling_references(self.repo)
        self.assertFalse(result["drifted"])


# --- Check 3: registry mismatches ------------------------------------------------


class TestRegistryMismatches(DriftCheckTestCase):
    def test_detects_unregistered_dir(self):
        # Modeled on real drift instance 3: a skills/ dir missing from marketplace.json.
        os.makedirs(self._path("skills", "foo"))
        os.makedirs(self._path("skills", "bar"))
        _write(self._path(".claude-plugin", "marketplace.json"), _marketplace_json(["foo"]))

        result = drift_check.check_registry_mismatches(self.repo)
        self.assertTrue(result["drifted"])
        self.assertEqual(result["unregistered"], ["bar"])
        self.assertEqual(result["missing_dirs"], [])

    def test_detects_missing_dir(self):
        os.makedirs(self._path("skills", "foo"))
        _write(
            self._path(".claude-plugin", "marketplace.json"),
            _marketplace_json(["foo", "ghost"]),
        )

        result = drift_check.check_registry_mismatches(self.repo)
        self.assertTrue(result["drifted"])
        self.assertEqual(result["unregistered"], [])
        self.assertEqual(result["missing_dirs"], ["ghost"])

    def test_clean_when_sets_match(self):
        os.makedirs(self._path("skills", "foo"))
        os.makedirs(self._path("skills", "bar"))
        _write(
            self._path(".claude-plugin", "marketplace.json"),
            _marketplace_json(["foo", "bar"]),
        )

        result = drift_check.check_registry_mismatches(self.repo)
        self.assertFalse(result["drifted"])

    def test_no_marketplace_json_treats_all_dirs_as_unregistered(self):
        os.makedirs(self._path("skills", "foo"))
        result = drift_check.check_registry_mismatches(self.repo)
        self.assertTrue(result["drifted"])
        self.assertEqual(result["unregistered"], ["foo"])

    def test_malformed_marketplace_json_reported_not_raised(self):
        # A malformed marketplace.json must degrade to a reported finding, not an
        # uncaught traceback that kills the run before any report is printed.
        os.makedirs(self._path("skills", "foo"))
        _write(self._path(".claude-plugin", "marketplace.json"), "{not valid json")

        result = drift_check.check_registry_mismatches(self.repo)
        self.assertTrue(result["drifted"])
        self.assertIsNotNone(result["error"])
        self.assertIn("marketplace.json", result["error"])
        self.assertEqual(result["unregistered"], [])
        self.assertEqual(result["missing_dirs"], [])

        # The full report still renders deterministically end-to-end (main() completes
        # rather than raising).
        report = drift_check.format_report(drift_check.run_all_checks(self.repo))
        self.assertIn("DRIFT:", report)
        self.assertIn("marketplace.json", report)
        self.assertEqual(drift_check.main([self.repo]), 0)


# --- extract_path_references / resolve_reference ---------------------------------


class TestExtractAndResolve(unittest.TestCase):
    def test_extracts_plugin_root_reference(self):
        text = "Read(`${CLAUDE_PLUGIN_ROOT}/skills/foo/operations/run.md`)"
        refs = drift_check.extract_path_references(text)
        self.assertIn(("skills/foo/operations/run.md", "plugin-root"), refs)

    def test_extracts_bare_skills_reference(self):
        text = "See `skills/foo/references/spec.md` for details."
        refs = drift_check.extract_path_references(text)
        self.assertIn(("skills/foo/references/spec.md", "skills-relative"), refs)

    def test_extracts_bare_scripts_reference(self):
        text = "`scripts/foo_core.py` — pure primitives."
        refs = drift_check.extract_path_references(text)
        self.assertIn(("scripts/foo_core.py", "skill-relative"), refs)

    def test_resolve_plugin_root_is_repo_relative(self):
        candidates = drift_check.resolve_candidates(
            "skills/foo/x.md", "plugin-root", "/repo", "/repo/skills/foo"
        )
        self.assertEqual(candidates, ["/repo/skills/foo/x.md"])

    def test_resolve_skill_relative_tries_skill_dir_then_repo_root(self):
        candidates = drift_check.resolve_candidates(
            "scripts/x.py", "skill-relative", "/repo", "/repo/skills/foo"
        )
        self.assertEqual(
            candidates, ["/repo/skills/foo/scripts/x.py", "/repo/scripts/x.py"]
        )


# --- run_all_checks / main / format_report ----------------------------------------


class TestOrchestration(DriftCheckTestCase):
    def test_run_all_checks_returns_all_three_keys(self):
        results = drift_check.run_all_checks(self.repo)
        self.assertEqual(
            set(results.keys()),
            {"unreleased_drift", "dangling_references", "registry_mismatches"},
        )

    def test_format_report_reports_ok_on_clean_repo(self):
        results = drift_check.run_all_checks(self.repo)
        report = drift_check.format_report(results)
        self.assertIn("OK: no unreleased plugin content.", report)
        self.assertIn("OK: no dangling references found.", report)
        self.assertIn("OK: registry matches skills/ dirs.", report)

    def test_main_returns_zero_on_valid_repo(self):
        self.assertEqual(drift_check.main([self.repo]), 0)

    def test_main_returns_nonzero_on_missing_repo(self):
        self.assertEqual(drift_check.main(["/no/such/path/drift-check-test"]), 1)


if __name__ == "__main__":
    unittest.main()
