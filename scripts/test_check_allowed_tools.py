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

    def test_block_list_with_interleaved_comment(self):
        # Regression: a YAML comment line between block-list items must not
        # cause the parser to drop the items that follow it — dropping a
        # legitimately-declared tool would flag a tool that IS declared (R4).
        fm = ["allowed-tools:", "  - Bash", "  # scoped below", "  - Agent",
              "version: 1.0.0"]
        tools, wildcard = check_allowed_tools.parse_allowed_tools(fm)
        self.assertEqual(tools, {"Bash", "Agent"})
        self.assertFalse(wildcard)

    def test_missing_key_is_wildcard(self):
        fm = ["name: foo", "description: bar"]
        _, wildcard = check_allowed_tools.parse_allowed_tools(fm)
        self.assertTrue(wildcard)

    def test_no_frontmatter_is_wildcard(self):
        _, wildcard = check_allowed_tools.parse_allowed_tools(None)
        self.assertTrue(wildcard)


class TestExemplifiedCallFormNotFlagged(unittest.TestCase):
    """Regression: a call-form token that an exemplification cue ("e.g.", "eg",
    "for example", "such as") *immediately introduces* — only whitespace, an
    opening backtick, an opening paren, and/or a comma between the cue and
    the "Tool(" token — illustrates a pattern rather than mandating a step,
    and must not be flagged. Canonical repro: dispatch-gate/SKILL.md's
    "(e.g. `Agent(isolation: \"worktree\")`)"."""

    def test_dispatch_gate_line_shape_not_flagged(self):
        refs = check_allowed_tools.find_mandatory_refs(
            '- **Tool-level worktree isolation** (e.g. '
            '`Agent(isolation: "worktree")`):\n'
        )
        self.assertEqual(refs, [])

    def test_comma_separated_cue_not_flagged(self):
        # A comma between the cue and the call-form -- "For example, `Agent(...)`"
        # -- is a common illustrative phrasing and must be exempted.
        refs = check_allowed_tools.find_mandatory_refs(
            'For example, `Agent(isolation: "worktree")` sets up a sandbox.\n'
        )
        self.assertEqual(refs, [])

    def test_other_exemplification_cues_not_flagged(self):
        # Each cue immediately introduces the call-form (only whitespace /
        # backtick / paren intervening).
        for line in (
            "Use a dispatch tool such as Agent(isolation: \"worktree\") "
            "when appropriate.\n",
            "Provision it e.g. `Agent(isolation: \"worktree\")` in the "
            "sandbox.\n",
            "eg Agent(isolation: \"worktree\") for illustration.\n",
            "Isolation such as (Agent(isolation: \"worktree\")) applies.\n",
        ):
            self.assertEqual(check_allowed_tools.find_mandatory_refs(line), [])

    def test_genuine_call_form_mandate_still_flagged(self):
        # Paired positive: a genuine call-form mandate with NO exemplification
        # cue must still be flagged -- proving the exemption is narrow and
        # did not blanket-disable call-form detection.
        refs = check_allowed_tools.find_mandatory_refs(
            'Run `Agent(isolation: "worktree")` to provision the sandbox.\n'
        )
        tools = {r[1] for r in refs}
        self.assertIn("Agent", tools)

    def test_imperative_mandate_after_exemplified_example_still_flagged(self):
        # A cue exempts only the call-form it immediately introduces -- a
        # later, non-exemplified imperative mandate for a different tool on
        # the same line must still be flagged.
        refs = check_allowed_tools.find_mandatory_refs(
            "Provision via e.g. `Agent(isolation: \"worktree\")`; then "
            "invoke the Bash tool to run it.\n"
        )
        tools = {r[1] for r in refs}
        self.assertNotIn("Agent", tools)
        self.assertIn("Bash", tools)

    def test_ambiguous_like_is_a_genuine_mandate(self):
        # "like" is ordinary English, NOT an exemplification marker. This is
        # a genuine call-form mandate (TOOL_IMPERATIVE_RE misses it because no
        # literal "tool" word follows, so CALL_FORM is the only detector) and
        # must be flagged -- the exemption must not swallow it.
        refs = check_allowed_tools.find_mandatory_refs(
            'I would like you to invoke Agent(isolation: "worktree") '
            "to complete the task.\n"
        )
        self.assertIn("Agent", {r[1] for r in refs})

    def test_cue_earlier_but_mandate_later_still_flagged(self):
        # A cue appears earlier on the line but does NOT immediately introduce
        # this call-form; the call-form is a genuine mandate and must flag.
        refs = check_allowed_tools.find_mandatory_refs(
            "Follow e.g. the setup guide, then you MUST invoke "
            '`Agent(isolation: "worktree")` to proceed.\n'
        )
        self.assertIn("Agent", {r[1] for r in refs})


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

    def test_bare_tool_phrase_without_imperative_not_flagged(self):
        # R4: a bare "the X tool" mention with no imperative verb and no
        # parentheses is prose, not a mandate — the real false-positive class
        # from task-workflow's operations/ docs.
        for line in (
            "| task_subject | Yes | Short label for the Task tool field |\n",
            "This reuses the parallel Task tool invocation pattern.\n",
            "The Skill tool returns control to the caller afterward.\n",
        ):
            self.assertEqual(check_allowed_tools.find_mandatory_refs(line), [])

    def test_imperative_use_is_flagged(self):
        refs = check_allowed_tools.find_mandatory_refs(
            "Use the Edit tool for surgical updates.\n"
        )
        self.assertIn("Edit", {r[1] for r in refs})

    def test_must_not_negation_not_flagged(self):
        # R4: a prohibition ("MUST NOT use the X tool") is not a mandate.
        for line in (
            "The reviewer MUST NOT use the Bash tool during grading.\n",
            "You must not invoke the Agent tool here.\n",
            "Never invoke the Task tool from this step.\n",
        ):
            self.assertEqual(check_allowed_tools.find_mandatory_refs(line), [])

    def test_negation_does_not_swallow_other_tool_mandate_same_line(self):
        # Regression: a negation for one tool must exempt only that tool —
        # not the whole line. A genuine mandate for a DIFFERENT tool later
        # on the same line must still be flagged (the exact defect class
        # this validator exists to catch).
        refs = check_allowed_tools.find_mandatory_refs(
            "MUST NOT use the Bash tool here; use the Edit tool instead.\n"
        )
        tools = {r[1] for r in refs}
        self.assertIn("Edit", tools)
        self.assertNotIn("Bash", tools)

    def test_reuse_misuse_prose_not_flagged(self):
        # Regression: TOOL_IMPERATIVE_RE must not substring-match "use"
        # inside larger words like "reuses"/"misuse" — it needs a word
        # boundary before the imperative verb.
        for line in (
            "This helper reuses the Bash tool internally.\n",
            "This misuse the Bash tool example is illustrative.\n",
        ):
            self.assertEqual(check_allowed_tools.find_mandatory_refs(line), [])


if __name__ == "__main__":
    unittest.main()
