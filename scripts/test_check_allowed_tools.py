"""Tests for check-allowed-tools.py — the allowed-tools lint validator.

Run: python3 -m unittest test_check_allowed_tools   (from this scripts/ directory)
"""

import importlib.util
import sys
import unittest
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
FIXTURES = SCRIPTS_DIR / "fixtures" / "allowed-tools-lint"

spec = importlib.util.spec_from_file_location(
    "check_allowed_tools", SCRIPTS_DIR / "check-allowed-tools.py"
)
assert spec and spec.loader, "could not load check-allowed-tools.py"
check_allowed_tools = importlib.util.module_from_spec(spec)
sys.modules["check_allowed_tools"] = check_allowed_tools
spec.loader.exec_module(check_allowed_tools)


def run_on_fixture(name):
    skill_dir = FIXTURES / name
    return check_allowed_tools.check_skill(skill_dir)


class TestUndeclaredToolFails(unittest.TestCase):
    """(a) A mandatory step invokes an undeclared tool -> FAILS (violations returned)."""

    def test_flags_undeclared_agent_tool(self):
        violations = run_on_fixture("undeclared-tool")
        self.assertTrue(violations, "expected at least one violation")
        self.assertTrue(any(v["tool"] == "Agent" for v in violations))

    def test_main_exits_nonzero(self):
        rc = check_allowed_tools.main(
            ["check-allowed-tools.py", str(FIXTURES / "undeclared-tool")]
        )
        self.assertNotEqual(rc, 0)


class TestAllDeclaredPasses(unittest.TestCase):
    """(b) Every referenced mandatory tool is declared -> PASSES (no violations)."""

    def test_no_violations(self):
        violations = run_on_fixture("all-declared")
        self.assertEqual(violations, [])

    def test_main_exits_zero(self):
        rc = check_allowed_tools.main(
            ["check-allowed-tools.py", str(FIXTURES / "all-declared")]
        )
        self.assertEqual(rc, 0)


class TestNonMandatoryProseDoesNotFail(unittest.TestCase):
    """(c) A non-mandatory prose mention of an undeclared tool must not fail (R4)."""

    def test_no_violations(self):
        violations = run_on_fixture("prose-mention")
        self.assertEqual(violations, [])


class TestWildcardNeverFails(unittest.TestCase):
    """(d) allowed-tools containing/being `*` never flags, regardless of content."""

    def test_star_list_entry(self):
        violations = run_on_fixture("wildcard-star-entry")
        self.assertEqual(violations, [])

    def test_star_scalar(self):
        violations = run_on_fixture("wildcard-scalar")
        self.assertEqual(violations, [])


class TestHyphenatedMcpTool(unittest.TestCase):
    """Regression: hyphenated mcp__ tool names (e.g. mcp__agent-coordinator__ac_report)
    must not be truncated at the first hyphen — truncation would flag a fully-compliant
    skill as a violation, breaking R4 (no false positives)."""

    def test_declared_and_mandated_passes(self):
        violations = run_on_fixture("mcp-hyphen-declared")
        self.assertEqual(violations, [], f"unexpected FP: {violations}")

    def test_full_name_matched_in_must_line(self):
        refs = check_allowed_tools.find_mandatory_refs(
            "This step MUST invoke the mcp__agent-coordinator__ac_report tool.\n"
        )
        tools = {r[1] for r in refs}
        self.assertIn("mcp__agent-coordinator__ac_report", tools)
        self.assertNotIn("mcp__agent", tools)

    def test_full_name_matched_in_call_form(self):
        refs = check_allowed_tools.find_mandatory_refs(
            "mcp__agent-coordinator__ac_report(status=done)\n"
        )
        tools = {r[1] for r in refs}
        self.assertIn("mcp__agent-coordinator__ac_report", tools)

    def test_undeclared_hyphenated_mcp_flagged_with_full_name(self):
        fm = ["allowed-tools:", "  - Bash", "  - Read"]
        tools, wildcard = check_allowed_tools.parse_allowed_tools(fm)
        self.assertFalse(wildcard)
        refs = check_allowed_tools.find_mandatory_refs(
            "Step MUST call the mcp__agent-coordinator__ac_report tool.\n"
        )
        undeclared = [r[1] for r in refs if r[1] not in tools]
        self.assertIn("mcp__agent-coordinator__ac_report", undeclared)


class TestPluralToolsIsNotFlagged(unittest.TestCase):
    """R4 guard: "Task tools: `TaskList`, `TaskGet`, ..." uses "Task" as a
    category label for the task-list tool family, NOT the Task dispatch tool.
    A plural "<Word> tools" phrase must NOT match — matching it produced a real
    false positive against task-workflow's corpus, so the phrase form is
    deliberately singular-"tool"-only."""

    def test_plural_tools_category_label_not_matched(self):
        refs = check_allowed_tools.find_mandatory_refs(
            "- **Task tools**: `TaskList`, `TaskGet`, `TaskUpdate`\n"
        )
        self.assertEqual(refs, [])


class TestPR223Reproduction(unittest.TestCase):
    """End-to-end repro of pfeff/dotfiles PR #223: l1-review's operations/run.md
    mandated the Agent/Task tool via "Spawn a sub-agent (Task/Agent tool)"
    while allowed-tools only listed Bash, Read, Write, Grep."""

    def test_flags_task_agent(self):
        violations = run_on_fixture("pr223-repro")
        self.assertTrue(violations, "expected the PR #223 fixture to be flagged")
        flagged_tools = {v["tool"] for v in violations}
        self.assertTrue(
            {"Task", "Agent"} & flagged_tools,
            f"expected Task and/or Agent flagged, got {flagged_tools}",
        )
        for v in violations:
            self.assertNotIn(v["tool"], v["allowed"])

    def test_main_exits_nonzero(self):
        rc = check_allowed_tools.main(
            ["check-allowed-tools.py", str(FIXTURES / "pr223-repro")]
        )
        self.assertNotEqual(rc, 0)


class TestParseAllowedTools(unittest.TestCase):
    def test_block_list_form(self):
        fm = ["allowed-tools:", "  - Bash", "  - Read", "version: 1.0.0"]
        tools, wildcard = check_allowed_tools.parse_allowed_tools(fm)
        self.assertEqual(tools, {"Bash", "Read"})
        self.assertFalse(wildcard)

    def test_inline_bracket_form(self):
        fm = ["allowed-tools: [Bash, Read, mcp__agent-coordinator__ac_report]"]
        tools, wildcard = check_allowed_tools.parse_allowed_tools(fm)
        self.assertEqual(
            tools, {"Bash", "Read", "mcp__agent-coordinator__ac_report"}
        )
        self.assertFalse(wildcard)

    def test_inline_comma_form_with_scoped_bash(self):
        fm = ["allowed-tools: Bash(git status:*), Bash(git diff:*), Read"]
        tools, wildcard = check_allowed_tools.parse_allowed_tools(fm)
        self.assertEqual(tools, {"Bash", "Read"})
        self.assertFalse(wildcard)

    def test_missing_key_is_wildcard(self):
        fm = ["name: foo", "description: bar"]
        _, wildcard = check_allowed_tools.parse_allowed_tools(fm)
        self.assertTrue(wildcard)

    def test_no_frontmatter_is_wildcard(self):
        _, wildcard = check_allowed_tools.parse_allowed_tools(None)
        self.assertTrue(wildcard)


class TestFindMandatoryRefs(unittest.TestCase):
    def test_call_form(self):
        refs = check_allowed_tools.find_mandatory_refs("Read(some/path)\n")
        self.assertTrue(any(r[1] == "Read" for r in refs))

    def test_tool_phrase(self):
        refs = check_allowed_tools.find_mandatory_refs(
            "Spawn a sub-agent (Task/Agent tool) that receives only inputs.\n"
        )
        tools = {r[1] for r in refs}
        self.assertEqual(tools, {"Task", "Agent"})

    def test_must_line_with_tool(self):
        refs = check_allowed_tools.find_mandatory_refs(
            "This step MUST invoke the WebFetch tool to resolve the URL.\n"
        )
        tools = {r[1] for r in refs}
        self.assertIn("WebFetch", tools)

    def test_bare_heading_word_not_flagged(self):
        # Regression guard for the real false-positive class this repo's own
        # corpus surfaced: "### 1. Task Creation" is plain English, not a
        # tool mandate, and must not be flagged.
        refs = check_allowed_tools.find_mandatory_refs(
            "### 1. Task Creation\n\nCreate a new task on the list.\n"
        )
        self.assertEqual(refs, [])

    def test_plain_prose_not_flagged(self):
        refs = check_allowed_tools.find_mandatory_refs(
            "Some environments also expose an Agent capability for fan-out.\n"
        )
        self.assertEqual(refs, [])


if __name__ == "__main__":
    unittest.main()
