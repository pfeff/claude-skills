#!/usr/bin/env python3
"""check-allowed-tools.py — flag SKILL.md workflows that mandate a tool the
skill's own `allowed-tools` frontmatter does not declare.

Defect class (caught for real in pfeff/dotfiles PR #223): a skill's workflow
text (SKILL.md and/or its operations/*.md step files) imperatively invokes a
tool — e.g. "invoke the Agent tool" — that is absent from that skill's
`allowed-tools` list. The skill then aborts at runtime on the very step that
was supposed to be mandatory.

Runnable locally:  python3 scripts/check-allowed-tools.py skills
CI invokes it the same way (see .github/workflows/skill-lint.yml).
Pre-commit invokes it on the changed SKILL.md / operations/*.md paths.

Detection heuristic
--------------------
A tool reference counts as "mandatory" — and is checked against
`allowed-tools` — only when the text around it is unambiguously imperative:

  1. Call form:            Read(...), Agent(...), mcp__foo__bar(...)
  2. Imperative phrase:    "invoke/use/via the X tool" — a directive verb
                           immediately preceding "<Tool> tool".
  3. Parenthetical tag:    "(Task/Agent tool)" — a tool named inside
                           parentheses and tagged "tool)", the exact shape
                           of the PR #223 defect ("Spawn a sub-agent
                           (Task/Agent tool)").
  4. A MUST/SHALL line that also names a known tool on that same line.

A prohibition ("MUST NOT use the X tool", "never invoke the X tool") is the
opposite of a mandate and is exempted — but only for the specific tool it
names. A genuine mandate for a DIFFERENT tool later on the same line is
still flagged; prohibitions do not blank out the whole line.

Deliberately NOT flagged: a bare "the X tool" mention without an imperative
verb or parentheses (e.g. task-workflow's "the Task tool description
field", "parallel Task tool invocation"), a plural "X tools" category label,
a bare tool-namespace word inside a heading ("### 1. Task Creation"), and a
call-form token that an exemplification cue — "e.g.", "eg", "for example",
"such as" — *immediately introduces* (only whitespace, an opening backtick,
and/or an opening paren may sit between the cue and the "Tool(" token, e.g.
dispatch-gate's "(e.g. `Agent(isolation: \"worktree\")`)"), which
illustrates a pattern rather than mandating a step. The cue must directly
precede the call-form: a cue earlier on a line whose call-form is a genuine
mandate ("...e.g. the setup, then you MUST invoke `Agent(...)`") is still
flagged, and bare "like" is excluded as ordinary English ("I would like you
to invoke Agent(...)"). These produce real false positives against this
repo's own corpus, and per this validator's R4 (false positives are worse
than missed edge cases) they are left unmatched.

A skill's `allowed-tools` list is treated as "no restriction" (never
flagged) when: the key is absent from frontmatter entirely, the value is
`*`, or the value contains a bare `*` entry among a list.

Scope: for each skill directory (one containing a SKILL.md), this scans
SKILL.md itself plus any operations/**/*.md files in that same skill
directory — the standard "SKILL.md delegates steps to operations/*.md"
layout used across this repo (l1-review, l2-review, task-workflow,
goal-tree, planning-workflow, operator-interview, ...). references/,
scripts/, test-results/, and README.md are not scanned — they are not the
mandatory workflow surface.

No third-party dependencies (stdlib only) so it runs identically in
pre-commit and CI without an extra install step.
"""

import re
import sys
from pathlib import Path

# Known tool namespace (per spec). "Task" and "Agent" are both accepted as
# names for the sub-agent dispatch tool — different Claude Code versions and
# author habits call it either; PR #223's own defect text says "Task/Agent".
TOOL_NAMES = [
    "Bash", "Read", "Edit", "Write", "Glob", "Grep",
    "Task", "Agent", "Skill", "NotebookEdit",
    "WebFetch", "WebSearch", "TodoWrite",
]
MCP_PATTERN = r"mcp__[A-Za-z0-9_-]+"  # server/tool segments may contain hyphens
TOOL_ALT = "(?:" + "|".join(TOOL_NAMES) + "|" + MCP_PATTERN + ")"

TOOLS_GROUP = TOOL_ALT + r"(?:\s*/\s*" + TOOL_ALT + r")*"

CALL_FORM_RE = re.compile(r"\b(" + TOOL_ALT + r")\(")
# Exemplification cue that IMMEDIATELY INTRODUCES a call-form token: the cue
# ("e.g.", "eg", "for example", "such as") must sit right before the matched
# "Tool(" token, separated only by whitespace, an opening backtick, and/or an
# opening paren — e.g. dispatch-gate's "(e.g. `Agent(...)`)" or "such as
# (Agent(...)". Anchored with `$` so it matches only against the line prefix up
# to the call-form's start; a cue that merely appears earlier on the line (with
# a genuine mandate following later) does NOT exempt. Bare "like" is excluded —
# it is ordinary English ("I would like you to invoke Agent(...)"), not an
# exemplification marker. Applied only to CALL_FORM matches (see docstring).
EXEMPLIFICATION_INTRO_RE = re.compile(
    r"(?:\be\.g\.|\beg\b|\bfor example\b|\bsuch as\b)[\s`(]*$", re.IGNORECASE
)
# Imperative phrasing: a directive verb ("invoke/use/via", any case) right
# before "<Tool> tool". Tool names stay case-sensitive so ordinary lowercase
# words ("use the read below") are not mistaken for the Read tool.
TOOL_IMPERATIVE_RE = re.compile(
    r"\b(?:[Ii]nvoke[sd]?|[Ii]nvoking|[Uu]se[sd]?|[Uu]sing|[Vv]ia)"
    r"\s+(?:[Tt]he\s+)?(" + TOOLS_GROUP + r")\s+tool\b"
)
# Parenthetical tool tag: "(Task/Agent tool)" — the PR #223 defect shape.
TOOL_PAREN_RE = re.compile(r"\((" + TOOLS_GROUP + r")\s+tool\)")
MODAL_RE = re.compile(r"\bMUST\b|\bSHALL\b")
# Prohibition, not a mandate: "MUST NOT use the X tool", "never invoke the X
# tool". Captures the specific tool named so only that tool is exempted —
# not the whole line (a different, genuinely-mandated tool later on the same
# line must still be flagged).
NEGATION_RE = re.compile(
    r"\b(?:(?:MUST|SHALL)\s+(?:NOT|NEVER)|do not|don't|does not|doesn't|"
    r"never|cannot|can't)\s+\b(?:invoke|use|call|run)\s+"
    r"(?:the\s+)?(" + TOOLS_GROUP + r")\s+tool\b",
    re.IGNORECASE,
)
TOOL_TOKEN_RE = re.compile(r"\b(" + TOOL_ALT + r")\b")


def _strip_frontmatter(lines):
    """Return (frontmatter_lines, body_start_index) if the file opens with a
    `---`-delimited frontmatter block, else (None, 0)."""
    if not lines or lines[0].strip() != "---":
        return None, 0
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            return lines[1:i], i + 1
    return None, 0  # unterminated frontmatter — treat whole file as body


def _split_top_level(s, sep=","):
    """Split s on sep, ignoring separators inside ()/[]/{} nesting."""
    parts = []
    depth = 0
    current = []
    for ch in s:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth = max(0, depth - 1)
        if ch == sep and depth == 0:
            parts.append("".join(current))
            current = []
        else:
            current.append(ch)
    parts.append("".join(current))
    return parts


def parse_allowed_tools(frontmatter_lines):
    """Return (tool_set, wildcard) from a SKILL.md frontmatter block.

    wildcard=True means "no restriction — never flag this skill" (bare `*`
    entry, `allowed-tools: *`, or the key missing entirely)."""
    if frontmatter_lines is None:
        return set(), True

    key_re = re.compile(r"^allowed-tools:\s*(.*)$")
    idx = None
    inline_rest = None
    for i, line in enumerate(frontmatter_lines):
        m = key_re.match(line)
        if m:
            idx = i
            inline_rest = m.group(1).strip()
            break

    if idx is None:
        return set(), True  # no allowed-tools key declared -> unrestricted

    raw_items = []
    if inline_rest:
        # Inline form: `[a, b, c]` or a bare comma-separated list, or a
        # single scalar like `*`.
        text = inline_rest
        if text.startswith("["):
            # Bracket may close on a later line if it were ever wrapped;
            # in observed usage it's always single-line, but handle the
            # multi-line case defensively.
            j = idx
            while "]" not in text and j + 1 < len(frontmatter_lines):
                j += 1
                text += " " + frontmatter_lines[j].strip()
            text = text[1: text.rfind("]")] if "]" in text else text[1:]
        raw_items = _split_top_level(text)
    else:
        # Block list form: subsequent indented "  - Item" lines.
        for line in frontmatter_lines[idx + 1:]:
            if line.strip().startswith("#"):
                continue  # YAML comment interleaved among list items
            if re.match(r"^\s*-\s+", line):
                raw_items.append(re.sub(r"^\s*-\s+", "", line))
            elif line.strip() == "" or re.match(r"^\s", line):
                # blank line or unexpected continuation: stop only on a new
                # top-level key, keep scanning past blank lines
                if line.strip() == "":
                    continue
                break
            else:
                break  # next top-level key

    tools = set()
    wildcard = False
    for raw in raw_items:
        item = raw.strip().strip("'\"")
        if not item:
            continue
        if item == "*":
            wildcard = True
            continue
        # Strip a trailing YAML comment on inline scalars, e.g. "* # note"
        item = item.split("#", 1)[0].strip()
        if item == "*":
            wildcard = True
            continue
        # Base tool name: text before an optional "(scope:...)" suffix.
        base = item.split("(", 1)[0].strip()
        if base:
            tools.add(base)

    return tools, wildcard


def find_mandatory_refs(text):
    """Scan body text (frontmatter already stripped) for mandatory tool
    references. Returns a list of (line_no, tool_name, line_text)."""
    refs = []
    for line_no, line in enumerate(text.splitlines(), start=1):
        # Tools named in a prohibition on this line ("MUST NOT use the Bash
        # tool") are exempted individually — not the whole line, so a real
        # mandate for a different tool later on the same line still flags.
        negated_tools = set()
        for m in NEGATION_RE.finditer(line):
            for name in re.split(r"\s*/\s*", m.group(1)):
                negated_tools.add(name)

        seen_on_line = set()

        for m in CALL_FORM_RE.finditer(line):
            if EXEMPLIFICATION_INTRO_RE.search(line[:m.start()]):
                continue  # cue immediately introduces this call-form: an example
            seen_on_line.add(m.group(1))

        for rx in (TOOL_IMPERATIVE_RE, TOOL_PAREN_RE):
            for m in rx.finditer(line):
                for name in re.split(r"\s*/\s*", m.group(1)):
                    seen_on_line.add(name)

        if MODAL_RE.search(line):
            for m in TOOL_TOKEN_RE.finditer(line):
                seen_on_line.add(m.group(1))

        for name in sorted(seen_on_line - negated_tools):
            refs.append((line_no, name, line.strip()))

    return refs


def read_body(path):
    """Read a markdown file and return its content with any leading
    frontmatter block stripped (frontmatter is metadata, not workflow
    prose, and is never scanned for mandatory tool references)."""
    lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
    _, body_start = _strip_frontmatter(lines)
    return "".join(lines[body_start:])


def discover_skill_dirs(paths):
    """Resolve a list of file/directory args to a deduped, sorted set of
    skill directories (each directory contains a SKILL.md)."""
    skill_dirs = set()
    for raw in paths:
        p = Path(raw)
        if p.is_dir():
            for skill_md in p.rglob("SKILL.md"):
                skill_dirs.add(skill_md.parent.resolve())
        elif p.is_file():
            # Walk up from the file to find the nearest ancestor directory
            # that contains a SKILL.md.
            cur = p.resolve().parent
            if p.name == "SKILL.md":
                skill_dirs.add(p.resolve().parent)
                continue
            found = None
            for ancestor in [cur] + list(cur.parents):
                if (ancestor / "SKILL.md").is_file():
                    found = ancestor
                    break
            if found is not None:
                skill_dirs.add(found)
        # Silently skip paths that don't exist / aren't part of a skill —
        # pre-commit may pass deleted files or non-skill markdown.
    return sorted(skill_dirs)


def check_skill(skill_dir):
    """Check one skill directory. Returns a list of violation dicts."""
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.is_file():
        return []

    lines = skill_md.read_text(encoding="utf-8").splitlines(keepends=True)
    frontmatter_lines, _ = _strip_frontmatter(lines)
    allowed, wildcard = parse_allowed_tools(frontmatter_lines)

    if wildcard:
        return []

    scan_files = [skill_md]
    operations_dir = skill_dir / "operations"
    if operations_dir.is_dir():
        scan_files.extend(sorted(operations_dir.rglob("*.md")))

    violations = []
    for f in scan_files:
        try:
            body = read_body(f)
        except (OSError, UnicodeDecodeError):
            continue
        for line_no, tool_name, line_text in find_mandatory_refs(body):
            if tool_name not in allowed:
                violations.append({
                    "skill": skill_dir.name,
                    "file": f,
                    "line": line_no,
                    "tool": tool_name,
                    "text": line_text,
                    "allowed": sorted(allowed),
                })
    return violations


def main(argv):
    args = argv[1:] or ["skills"]
    skill_dirs = discover_skill_dirs(args)

    if not skill_dirs:
        print("check-allowed-tools: no skills found under given paths; nothing to check")
        return 0

    all_violations = []
    for skill_dir in skill_dirs:
        all_violations.extend(check_skill(skill_dir))

    if all_violations:
        for v in all_violations:
            try:
                rel = v["file"].relative_to(Path.cwd())
            except ValueError:
                rel = v["file"]
            print(f"VIOLATION: skill={v['skill']} tool={v['tool']} not in "
                  f"allowed-tools={v['allowed']}")
            print(f"  {rel}:{v['line']}: {v['text']}")
        print("")
        print(f"{len(all_violations)} allowed-tools violation(s) across "
              f"{len({v['skill'] for v in all_violations})} skill(s).")
        print("A mandatory workflow step invokes a tool the skill's "
              "allowed-tools frontmatter does not declare. Either add the "
              "tool to allowed-tools or rewrite the step to use a declared "
              "tool.")
        return 1

    print(f"check-allowed-tools: {len(skill_dirs)} skill(s) checked, no violations")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
