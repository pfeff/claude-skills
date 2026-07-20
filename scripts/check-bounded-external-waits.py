#!/usr/bin/env python3
"""check-bounded-external-waits.py — flag an unbounded, known-flaky external
call inside a fenced bash code block in skill/doc markdown.

Defect class this closes (lN-review-doctrine/references/verification-map.md
item 7; docs/skill-authoring.md rule 3): a verify/validation/acceptance-check
step shells out to a flaky or slow **external** resource — a third-party
API/service or an OS-integration shell-out — without the hard-cap +
kill-on-stall wrapper (`run_bounded_external`, see
skills/self-verify/references/bounded-external-waits.md). That doctrine is
authoring-time and review-time guidance; both rely on a human remembering to
apply it. This lint is the mechanical backstop that runs on every PR
regardless of which review tier the PR lands in (a self-constituent PR that
never reaches the doctrine-class review checklist still gets caught here).

Deliberately narrow. A general "is this shell command an external call"
classifier was assessed and rejected as infeasible (see
docs/skill-authoring.md rule 3 and PR #197's own investigation) —
distinguishing "external" from "the repo's own tooling," and "this bash
block is a verify step" from "this bash block is a doc example," both need
judgment a regex can't apply reliably at that generality. This script does
NOT attempt that. It checks a CLOSED, small vocabulary of command names that
are externally-flaky by their very nature, and only where they appear inside
a fenced bash-ish code block (never prose, an inline code span, or an
illustrative fenced block tagged with a non-shell language like
```markdown``` used for example output).

Runnable locally:  python3 scripts/check-bounded-external-waits.py skills docs
CI invokes it the same way (see .github/workflows/skill-lint.yml).

Vocabulary (closed — widening this requires re-verifying zero false
positives against the corpus, the same way this list was derived):
  curl, wget, ssh, osascript

Exclusions (both verified zero-false-positive against the current corpus by
scanning every fenced bash-ish block in skills/**/*.md and docs/**/*.md):
  1. Already wrapped — the enclosing fenced block also invokes/defines
     `run_bounded_external` (the recipe's function; see
     skills/self-verify/references/bounded-external-waits.md). A step that
     already runs the vocabulary call through the recipe is compliant, not a
     violation.
  2. Loopback / this repo's own coordinator — a call whose *same line*
     targets a loopback host (localhost, 127.0.0.1, 0.0.0.0, ::1) or this
     repo's own coordinator service (`COORDINATOR_URL`, which defaults to
     `http://localhost:4000` everywhere it's declared — see
     skills/goal-tree/scripts/coord) is internal tooling, not the
     third-party/flaky class this doctrine targets. This is a closed,
     named exception for one specific internal-service variable, not a
     general "any env var in the URL" carve-out — widening it needs the
     same zero-FP re-verification as the vocabulary itself.

Scope: fenced code blocks tagged (or untagged) as a shell language — "",
"bash", "sh", "shell", "zsh", "console" — across every *.md file under the
given paths. A fence tagged with any other language (e.g. ```markdown``` for
an illustrative example, ```yaml```, ```python```) is not scanned; those are
demonstrations, not the actual verify-step code surface.

**Markdown only.** This lint discovers and scans *.md files exclusively
(see `discover_markdown_files`) — it never reads a *.sh file. A real,
executable shell script committed anywhere in the repo (e.g. under a
skill's scripts/ dir) is entirely outside this lint's reach, even if it
shells out to the vocabulary unwrapped. Widening to *.sh was considered
and deliberately deferred: a spot check of this repo's committed *.sh
files turns up several unwrapped curl/ssh call sites (e.g.
skills/goal-tree/scripts/coord-helpers.sh,
skills/ralph-wiggum/scripts/run-container.sh), so "extend to *.sh" is not
the zero-false-positive, drop-in change the *.md scope was — it needs its
own corpus pass and exclusion review, not a one-line glob change. This
lint's actual, current guarantee is markdown-only coverage.

No third-party dependencies (stdlib only) so it runs identically in
pre-commit and CI without an extra install step.
"""

import re
import sys
from pathlib import Path

VOCAB = ["curl", "wget", "ssh", "osascript"]

# Match a vocabulary word only in COMMAND POSITION: the start of the line's
# code (after optional leading whitespace), or immediately after a
# statement/pipeline separator (`;`, `&`, `|` — this also covers `&&` and
# `||`, since the match anchors on the second character), a command
# substitution opener (`$(`), or a backtick. Still a regex, not a shell
# parser — it doesn't resolve quoting or subshells — but anchoring to
# command position (rather than a bare word-boundary search anywhere on the
# line) is what keeps a mention like "curl needs a timeout" in a comment,
# or a URL host like `curl.example.com` inside an `echo` string, from
# matching: neither is preceded by a command-starting delimiter.
COMMAND_POS_RE = re.compile(
    r"(?:^|[;&|`]|\$\()\s*(" + "|".join(VOCAB) + r")\b"
)

FENCE_RE = re.compile(r"^\s*```\s*([A-Za-z0-9_+-]*)\s*$")
BASHY_LANGS = {"", "bash", "sh", "shell", "zsh", "console"}

# Exclusion 1: already wrapped in the bounded-external-wait recipe anywhere
# in the enclosing fenced block (function definition or call site).
WRAPPED_RE = re.compile(r"run_bounded_external")

# Exclusion 2: loopback host or this repo's own coordinator variable, on the
# SAME line as the vocabulary hit (deliberately line-scoped, not
# block-scoped, so this exclusion can't accidentally mask an unrelated,
# genuinely-external call elsewhere in the same block).
#
# Checked against the line's CODE portion only (text before any `#`
# comment marker — see `code_part()`), not the raw line: matching the raw
# line would let a trailing comment like `# not localhost` on an otherwise
# fully external call suppress a real violation.
LOOPBACK_RE = re.compile(r"localhost|127\.0\.0\.1|0\.0\.0\.0|::1", re.IGNORECASE)
INTERNAL_SERVICE_RE = re.compile(r"\bCOORDINATOR_URL\b")


def code_part(line):
    """Return the portion of a line before its first `#` comment marker.

    Deliberately simple (no quote-awareness — a `#` inside a quoted string
    is still treated as a comment opener). For a line that is entirely a
    comment, this returns an empty/whitespace string, so neither the
    command-position vocabulary match nor the loopback/internal-service
    exclusion check ever considers comment text — closing the false-positive
    class where a fenced bash block merely narrates a vocabulary word in
    prose without invoking it (see PR #197 review)."""
    return line.split("#", 1)[0]


def iter_fenced_blocks(text):
    """Yield (first_code_line_no, lang, block_lines) for every fenced code
    block in a markdown file's text. first_code_line_no is the 1-indexed
    line number of the first line *inside* the fence (the line after the
    opening ``` marker)."""
    lines = text.splitlines()
    i = 0
    n = len(lines)
    while i < n:
        m = FENCE_RE.match(lines[i])
        if not m:
            i += 1
            continue
        lang = m.group(1).lower()
        j = i + 1
        block = []
        while j < n and not FENCE_RE.match(lines[j]):
            block.append(lines[j])
            j += 1
        yield i + 2, lang, block
        i = j + 1 if j < n else j


def check_file(path):
    """Check one markdown file. Returns a list of violation dicts."""
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return []

    violations = []
    for first_line_no, lang, block in iter_fenced_blocks(text):
        if lang not in BASHY_LANGS:
            continue
        block_text = "\n".join(block)
        if WRAPPED_RE.search(block_text):
            continue  # exclusion 1: already bounded

        for offset, line in enumerate(block):
            code = code_part(line)
            m = COMMAND_POS_RE.search(code)
            if not m:
                continue
            if LOOPBACK_RE.search(code) or INTERNAL_SERVICE_RE.search(code):
                continue  # exclusion 2: loopback / internal coordinator
            violations.append({
                "file": path,
                "line": first_line_no + offset,
                "call": m.group(1),
                "text": line.strip(),
            })
    return violations


def discover_markdown_files(paths):
    """Resolve a list of file/directory args to a sorted list of *.md
    files."""
    files = set()
    for raw in paths:
        p = Path(raw)
        if p.is_dir():
            files.update(p.rglob("*.md"))
        elif p.is_file() and p.suffix == ".md":
            files.add(p)
        # Silently skip paths that don't exist / aren't markdown — mirrors
        # check-allowed-tools.py's tolerance of a pre-commit deleted-file arg.
    return sorted(files)


def main(argv):
    args = argv[1:] or ["skills", "docs"]
    md_files = discover_markdown_files(args)

    if not md_files:
        print("check-bounded-external-waits: no markdown files found under "
              "given paths; nothing to check")
        return 0

    all_violations = []
    for f in md_files:
        all_violations.extend(check_file(f))

    if all_violations:
        for v in all_violations:
            try:
                rel = v["file"].relative_to(Path.cwd())
            except ValueError:
                rel = v["file"]
            print(f"VIOLATION: unbounded external call `{v['call']}` in a "
                  f"fenced bash block")
            print(f"  {rel}:{v['line']}: {v['text']}")
        print("")
        print(f"{len(all_violations)} unbounded-external-wait violation(s) "
              f"across {len({v['file'] for v in all_violations})} file(s).")
        print("A fenced bash block calls a known-flaky external command "
              "(curl/wget/ssh/osascript) without the hard-cap + "
              "kill-on-stall wrapper. Wrap it with run_bounded_external "
              "(skills/self-verify/references/bounded-external-waits.md), "
              "or if the target is genuinely internal/loopback, say so "
              "explicitly (e.g. localhost) so this check can tell.")
        return 1

    print(f"check-bounded-external-waits: {len(md_files)} file(s) checked, "
          f"no violations")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
