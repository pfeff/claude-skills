"""Tests for check-bounded-external-waits.py — the bounded-external-wait
lint validator.

Run: python3 -m unittest test_check_bounded_external_waits   (from this scripts/ directory)
"""

import importlib.util
import sys
import unittest
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
FIXTURES = SCRIPTS_DIR / "fixtures" / "bounded-external-waits-lint"

spec = importlib.util.spec_from_file_location(
    "check_bounded_external_waits", SCRIPTS_DIR / "check-bounded-external-waits.py"
)
assert spec and spec.loader, "could not load check-bounded-external-waits.py"
check_bounded_external_waits = importlib.util.module_from_spec(spec)
sys.modules["check_bounded_external_waits"] = check_bounded_external_waits
spec.loader.exec_module(check_bounded_external_waits)


def check_fixture(name):
    return check_bounded_external_waits.check_file(FIXTURES / name)


class TestUnwrappedExternalCallFails(unittest.TestCase):
    """(a) An unwrapped external call in a fenced bash block -> FLAGGED."""

    def test_flags_curl(self):
        violations = check_fixture("violation.md")
        self.assertTrue(violations, "expected at least one violation")
        self.assertEqual(violations[0]["call"], "curl")

    def test_flags_wget_ssh_osascript(self):
        violations = check_fixture("other-vocab.md")
        calls = {v["call"] for v in violations}
        self.assertEqual(calls, {"wget", "ssh", "osascript"})

    def test_main_exits_nonzero(self):
        rc = check_bounded_external_waits.main(
            ["check-bounded-external-waits.py", str(FIXTURES / "violation.md")]
        )
        self.assertNotEqual(rc, 0)


class TestWrappedCallPasses(unittest.TestCase):
    """(b) The same call, routed through run_bounded_external -> NOT flagged."""

    def test_no_violations(self):
        self.assertEqual(check_fixture("wrapped.md"), [])


class TestLoopbackExcluded(unittest.TestCase):
    """(c) A call targeting a loopback host -> NOT flagged."""

    def test_no_violations(self):
        self.assertEqual(check_fixture("loopback.md"), [])


class TestInternalServiceExcluded(unittest.TestCase):
    """(d) A call targeting this repo's own COORDINATOR_URL -> NOT flagged."""

    def test_no_violations(self):
        self.assertEqual(check_fixture("internal-service.md"), [])


class TestNonBashFenceExcluded(unittest.TestCase):
    """(e) The vocabulary word inside a non-shell fenced block (e.g.
    ```markdown``` illustrating doc syntax) -> NOT flagged."""

    def test_no_violations(self):
        self.assertEqual(check_fixture("non-bash-fence.md"), [])


class TestInlineCodeSpanExcluded(unittest.TestCase):
    """(f) The vocabulary word only in an inline code span / prose, no
    fenced block at all -> NOT flagged."""

    def test_no_violations(self):
        self.assertEqual(check_fixture("inline-code-span.md"), [])


class TestFullCorpusIsClean(unittest.TestCase):
    """(g) The current repo's skills/ and docs/ trees produce zero
    violations — this is the claim the review required proof of before this
    lint could ship."""

    def test_repo_root_clean(self):
        repo_root = SCRIPTS_DIR.parent
        violations = []
        for sub in ("skills", "docs"):
            d = repo_root / sub
            if d.is_dir():
                for md in d.rglob("*.md"):
                    violations.extend(check_bounded_external_waits.check_file(md))
        self.assertEqual(
            violations, [],
            f"expected zero violations against the live corpus, got: {violations}",
        )


if __name__ == "__main__":
    unittest.main()
