"""Doc<->script drift guard for run_bounded_external.

The hard-cap + kill-on-stall recipe is documented as a fenced code block in
../references/bounded-external-waits.md (the teaching copy) and duplicated
as an executable, sourceable script in run-bounded-external.sh (the
executable copy that call sites actually `source`). Nothing enforces that
the two stay in sync except a human remembering to edit both.

This test is a narrow, deterministic diff between exactly these two known
files — not a repo-wide linter. It compares CODE only (comment-only and
blank lines stripped from both sides) because the two copies legitimately
reword comments: a cross-reference that reads naturally inline in the doc
("see platform note below") reads differently from a standalone script
file ("see the doctrine doc's platform note"), and the script also carries
its own shebang/usage-header block the doc's fence doesn't need. Stripping
comments avoids the test being brittle to those sensible rewordings while
still catching any executable-statement drift, which is the actual hazard
this test exists to catch.

Run: python3 -m unittest test_bounded_external_equivalence  (from this
scripts/ directory)
"""

import re
import unittest
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
DOC_PATH = SCRIPTS_DIR.parent / "references" / "bounded-external-waits.md"
SCRIPT_PATH = SCRIPTS_DIR / "run-bounded-external.sh"

_COMMENT_OR_BLANK = re.compile(r"^\s*#|^\s*$")


def _extract_bash_fence(markdown_text):
    """Return the contents of the first ```bash ... ``` fence."""
    match = re.search(r"```bash\n(.*?)```", markdown_text, re.DOTALL)
    assert match, "no ```bash fence found in bounded-external-waits.md"
    return match.group(1)


def _code_lines(text):
    """Lines with comment-only and blank lines stripped, for a code-only diff."""
    return [line for line in text.splitlines() if not _COMMENT_OR_BLANK.match(line)]


class TestBoundedExternalEquivalence(unittest.TestCase):
    def test_doc_fence_and_script_are_code_equivalent(self):
        doc_fence = _extract_bash_fence(DOC_PATH.read_text())
        script_text = SCRIPT_PATH.read_text()

        doc_code = _code_lines(doc_fence)
        script_code = _code_lines(script_text)

        self.assertEqual(
            doc_code,
            script_code,
            "bounded-external-waits.md's fenced recipe and "
            "run-bounded-external.sh have drifted (comments excluded from "
            "this comparison — only executable statements are compared). "
            "Edit both files together; see the note under 'Recipe: "
            "flat-CPU kill-on-stall' in bounded-external-waits.md.",
        )


if __name__ == "__main__":
    unittest.main()
