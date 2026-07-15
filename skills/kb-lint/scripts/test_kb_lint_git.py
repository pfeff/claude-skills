"""Tests for kb_lint_git.py — kb-lint's git-backed / auto-apply-eligibility detection.

Guards against the failure mode this module exists to fix: the git-backed determination
drifting between runs (one session reporting the vault as not git-backed, a later session
applying fixes as "git-revertible" without re-checking). Exercises the real git binary
against real fixture directories — no mocks.

Run: python3 -m unittest test_kb_lint_git   (from this scripts/ directory)
"""

import shutil
import subprocess
import tempfile
import unittest


class TestIsGitBacked(unittest.TestCase):
    def setUp(self):
        self.git_dir = tempfile.mkdtemp(prefix="kb-lint-test-git-")
        subprocess.run(["git", "init", "-q"], cwd=self.git_dir, check=True)
        self.non_git_dir = tempfile.mkdtemp(prefix="kb-lint-test-nogit-")

    def tearDown(self):
        shutil.rmtree(self.git_dir, ignore_errors=True)
        shutil.rmtree(self.non_git_dir, ignore_errors=True)

    def test_git_backed_dir_is_true(self):
        from kb_lint_git import is_git_backed

        self.assertTrue(is_git_backed(self.git_dir))

    def test_non_git_dir_is_false(self):
        from kb_lint_git import is_git_backed

        self.assertFalse(is_git_backed(self.non_git_dir))

    def test_deterministic_across_repeated_calls(self):
        # Same fixture, called twice — must agree with itself both times. This is the
        # regression case: a cached/assumed result diverging from a fresh check against
        # identical git state.
        from kb_lint_git import is_git_backed

        self.assertEqual(is_git_backed(self.git_dir), is_git_backed(self.git_dir))
        self.assertEqual(is_git_backed(self.non_git_dir), is_git_backed(self.non_git_dir))

    def test_reflects_state_change_between_runs(self):
        # A dir that becomes git-backed after the first check must report True on the next
        # check — proof the function re-checks live state each run rather than caching.
        from kb_lint_git import is_git_backed

        self.assertFalse(is_git_backed(self.non_git_dir))
        subprocess.run(["git", "init", "-q"], cwd=self.non_git_dir, check=True)
        self.assertTrue(is_git_backed(self.non_git_dir))

    def test_nonexistent_path_is_false(self):
        from kb_lint_git import is_git_backed

        self.assertFalse(is_git_backed("/no/such/path/kb-lint-test"))


if __name__ == "__main__":
    unittest.main()
