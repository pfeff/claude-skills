#!/usr/bin/env python3
"""Unit tests for the pure decision logic in check-version-bump.py.

The git plumbing in main() is intentionally thin; the whole rule set lives in
decide(), which is pure and covered here. Run with:

    python3 -m unittest discover -s scripts -p 'test_check_version_bump.py'
"""

import importlib.util
import os
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "check_version_bump", os.path.join(_HERE, "check-version-bump.py")
)
cvb = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cvb)


class ParseVersionTests(unittest.TestCase):
    def test_parses_semver(self):
        self.assertEqual(cvb.parse_version("2.11.0"), (2, 11, 0))
        self.assertEqual(cvb.parse_version(" 10.3.4 "), (10, 3, 4))

    def test_rejects_garbage(self):
        for bad in ("2.11", "v2.11.0", "2.11.0-rc1", "", "abc"):
            with self.assertRaises(ValueError):
                cvb.parse_version(bad)

    def test_orders_numerically_not_lexically(self):
        # 2.9.0 < 2.10.0 must hold — a string compare would get this wrong.
        self.assertLess(cvb.parse_version("2.9.0"), cvb.parse_version("2.10.0"))


class DecideTests(unittest.TestCase):
    def _ok(self, *args):
        ok, msg = cvb.decide(*args)
        self.assertTrue(ok, msg)
        return msg

    def _fail(self, *args):
        ok, msg = cvb.decide(*args)
        self.assertFalse(ok, msg)
        return msg

    # --- in-sync guard (applies regardless of shipped_changed) ---
    def test_out_of_sync_fails_even_without_shipped_change(self):
        msg = self._fail("2.11.0", "2.12.0", "2.11.0", False)
        self.assertIn("out of sync", msg)

    def test_out_of_sync_fails_with_shipped_change(self):
        self._fail("2.11.0", "2.12.0", "2.13.0", True)

    # --- shipped surface changed → strictly greater required ---
    def test_shipped_change_with_proper_bump_passes(self):
        self._ok("2.11.0", "2.12.0", "2.12.0", True)

    def test_shipped_change_without_bump_fails(self):
        # The owed-nothing case: skill changed but version left equal to base.
        msg = self._fail("2.11.0", "2.11.0", "2.11.0", True)
        self.assertIn("rebase", msg)

    def test_concurrent_collision_fails(self):
        # main already advanced to 2.12.0 (a sibling PR merged first); this PR
        # still carries 2.12.0 — the byte-identical collision. Must fail loudly.
        msg = self._fail("2.12.0", "2.12.0", "2.12.0", True)
        self.assertIn("leapfrog", msg)

    def test_shipped_change_bumping_below_base_fails(self):
        self._fail("2.12.0", "2.11.0", "2.11.0", True)

    def test_major_bump_passes(self):
        self._ok("2.11.0", "3.0.0", "3.0.0", True)

    # --- no shipped surface change → bump optional, no regression ---
    def test_no_shipped_change_same_version_passes(self):
        self._ok("2.11.0", "2.11.0", "2.11.0", False)

    def test_no_shipped_change_regression_fails(self):
        msg = self._fail("2.11.0", "2.10.0", "2.10.0", False)
        self.assertIn("regress", msg)

    def test_no_shipped_change_bump_still_allowed(self):
        self._ok("2.11.0", "2.12.0", "2.12.0", False)


if __name__ == "__main__":
    unittest.main()
