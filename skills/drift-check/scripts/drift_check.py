#!/usr/bin/env python3
"""drift_check.py — mechanical spec-vs-reality drift detection for the skills estate.

Three deterministic checks (report-only — this module never edits anything it finds):

  1. Unreleased plugin content: commits touching skills/** or .claude-plugin/** merged
     after the last version-bump commit to .claude-plugin/plugin.json.
  2. Dangling file references: a SKILL.md / operations/*.md doc referencing a
     repo-relative or ${CLAUDE_PLUGIN_ROOT}-relative path that does not exist.
  3. Registry mismatches: directories under skills/ absent from
     .claude-plugin/marketplace.json's skills array, or registry entries pointing at
     directories that don't exist.

Runnable locally: python3 skills/drift-check/scripts/drift_check.py [repo_root]
Repo root defaults to walking up from CWD looking for .claude-plugin/plugin.json, so this
is testable against fixture repos passed explicitly.
"""

import json
import os
import re
import subprocess
import sys


# --- Repo root discovery ------------------------------------------------------


def find_repo_root(start=None):
    """Walk up from ``start`` (default CWD) looking for a directory containing
    .claude-plugin/plugin.json. Returns the absolute path, or None if none is found
    before reaching the filesystem root."""
    path = os.path.abspath(start or os.getcwd())
    while True:
        if os.path.isfile(os.path.join(path, ".claude-plugin", "plugin.json")):
            return path
        parent = os.path.dirname(path)
        if parent == path:
            return None
        path = parent


# --- subprocess hygiene (timeout, never raises — see kb-lint's kb_lint_git.py) ----


def _run_git(args, cwd, timeout=10):
    """Run ``git <args>`` in ``cwd``; return stdout on success, None on any failure
    (missing git, bad path, non-zero exit, timeout). Never raises."""
    try:
        result = subprocess.run(
            ["git", "-C", cwd] + args,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if result.returncode != 0:
        return None
    return result.stdout


# --- Check 1: unreleased plugin content ---------------------------------------

PR_NUMBER_RE = re.compile(r"\(#(\d+)\)")
VERSION_LINE_RE = re.compile(r'^[+-]\s*"version":', re.MULTILINE)


def last_version_bump_commit(repo_root):
    """Return the hash of the most recent commit that changed the ``version`` line
    of .claude-plugin/plugin.json, or None if the file has no history (or repo_root
    isn't a git repo)."""
    out = _run_git(
        ["log", "--format=%H", "--", ".claude-plugin/plugin.json"],
        repo_root,
    )
    if not out:
        return None
    for commit_hash in out.strip().splitlines():
        diff = _run_git(["show", commit_hash, "--", ".claude-plugin/plugin.json"], repo_root)
        if diff and VERSION_LINE_RE.search(diff):
            return commit_hash
    return None


def unreleased_commits(repo_root, since_commit):
    """List of (hash, subject) tuples for commits after ``since_commit`` (exclusive) up
    to HEAD that touch skills/** or .claude-plugin/**. Empty if since_commit is None or
    the git query fails."""
    if not since_commit:
        return []
    out = _run_git(
        [
            "log",
            "--format=%H%x1f%s",
            f"{since_commit}..HEAD",
            "--",
            "skills",
            ".claude-plugin",
        ],
        repo_root,
    )
    if not out:
        return []
    commits = []
    for line in out.strip().splitlines():
        if "\x1f" not in line:
            continue
        commit_hash, subject = line.split("\x1f", 1)
        commits.append((commit_hash, subject))
    return commits


def check_unreleased_drift(repo_root):
    """Check 1. Returns {"drifted": bool, "count": int, "commits": [(hash, subject)],
    "pr_numbers": [str]}."""
    since = last_version_bump_commit(repo_root)
    commits = unreleased_commits(repo_root, since)
    pr_numbers = []
    for _, subject in commits:
        m = PR_NUMBER_RE.search(subject)
        if m:
            pr_numbers.append(m.group(1))
    return {
        "drifted": len(commits) > 0,
        "count": len(commits),
        "commits": commits,
        "pr_numbers": pr_numbers,
    }


# --- Check 2: dangling file references -----------------------------------------
#
# High-precision, not high-recall (deliberate — see SKILL.md "Known limitations"):
# only backtick-quoted or ${CLAUDE_PLUGIN_ROOT}-relative paths containing "/" and ending
# in a real file extension are matched. Fenced code blocks, bare prose, and extension-less
# references are not scanned.

CLAUDE_PLUGIN_ROOT_RE = re.compile(r"\$\{CLAUDE_PLUGIN_ROOT\}/([\w\-./]+\.\w+)")
SKILLS_REL_RE = re.compile(r"`(skills/[\w\-./]+\.\w+)`")
SCRIPTS_REL_RE = re.compile(r"`(scripts/[\w\-./]+\.\w+)`")

FENCE_OPEN_CLOSE_RE = re.compile(r"^(`{3,}|~{3,})")


def strip_fenced_code_blocks(text):
    """Return ``text`` with the contents of fenced code blocks (``` or ~~~ fences)
    blanked to empty lines, so path references appearing only inside a fenced example
    (e.g. a ``${CLAUDE_PLUGIN_ROOT}/skills/my-skill/SKILL.md`` placeholder in a shell
    snippet) are not scanned. This honors the documented "references inside fenced code
    blocks are not scanned" precision contract (see SKILL.md "Known limitations"), which
    the whole-file regexes would otherwise violate.

    Detection is line-based: a line whose first non-whitespace run is >=3 backticks or
    >=3 tildes opens or closes a fence; the closing fence must be the same marker char.
    Inline code spans (single backticks) are left intact — only fenced blocks are
    stripped. Line count is preserved (each stripped line becomes ""), so this is safe
    to run before any position-dependent scanning."""
    out = []
    fence_char = None
    for line in text.split("\n"):
        m = FENCE_OPEN_CLOSE_RE.match(line.lstrip())
        if m:
            marker = m.group(1)[0]
            if fence_char is None:
                fence_char = marker
                out.append("")
                continue
            if marker == fence_char:
                fence_char = None
                out.append("")
                continue
        out.append("" if fence_char is not None else line)
    return "\n".join(out)


def extract_path_references(text):
    """Return a list of (raw_reference, kind) pairs found in ``text``. ``kind`` is
    "plugin-root" (repo-root-relative via ${CLAUDE_PLUGIN_ROOT}/), "skills-relative"
    (repo-root-relative, bare backtick `skills/...`), or "skill-relative" (relative to
    the skill's own directory, bare backtick `scripts/...`)."""
    refs = []
    for m in CLAUDE_PLUGIN_ROOT_RE.finditer(text):
        refs.append((m.group(1), "plugin-root"))
    for m in SKILLS_REL_RE.finditer(text):
        refs.append((m.group(1), "skills-relative"))
    for m in SCRIPTS_REL_RE.finditer(text):
        refs.append((m.group(1), "skill-relative"))
    return refs


def resolve_candidates(raw_ref, kind, repo_root, skill_dir):
    """Return the ordered list of absolute paths a reference could resolve to.

    Bare backtick `scripts/...` references are genuinely ambiguous in this repo: some
    skills use it for their own `scripts/` subdirectory (kb-core's `scripts/kb_core.py`),
    others for the repo's top-level `scripts/` maintainer tooling (cadence-goals'
    `scripts/sync-codex-skills.sh`, skillify's `scripts/bump-version.sh`). Both
    candidates are tried — in skill-dir-first order — before a reference is flagged as
    dangling, so this convention split doesn't produce false positives."""
    if kind in ("plugin-root", "skills-relative"):
        return [os.path.join(repo_root, raw_ref)]
    if kind == "skill-relative":
        return [os.path.join(skill_dir, raw_ref), os.path.join(repo_root, raw_ref)]
    raise ValueError(f"unknown reference kind: {kind}")


def _skill_doc_paths(skill_dir, repo_root):
    """SKILL.md plus any operations/*.md files under a single skill directory.
    Returns (docs, errors) — "errors" is a list of descriptive strings when the
    operations/ subdirectory exists but can't be listed (OSError, e.g. unreadable);
    docs still includes SKILL.md (if present) in that case."""
    docs = []
    errors = []
    skill_md = os.path.join(skill_dir, "SKILL.md")
    if os.path.isfile(skill_md):
        docs.append(skill_md)
    ops_dir = os.path.join(skill_dir, "operations")
    if os.path.isdir(ops_dir):
        try:
            names = sorted(os.listdir(ops_dir))
        except OSError as exc:
            errors.append(f"could not list {os.path.relpath(ops_dir, repo_root)}: {exc}")
            names = []
        for name in names:
            if name.endswith(".md"):
                docs.append(os.path.join(ops_dir, name))
    return docs, errors


def check_dangling_references(repo_root):
    """Check 2. Returns {"drifted": bool, "count": int,
    "findings": [(doc_path, raw_ref, resolved_path)], "error": str | None} (paths relative
    to repo_root).
    "error" = set (and "drifted" forced True) when one or more docs can't be read (OSError,
    e.g. unreadable) or decoded (UnicodeDecodeError, e.g. invalid UTF-8), or when skills/ or
    a skill's operations/ subdirectory can't be listed (OSError, e.g. unreadable); those docs
    or directories are skipped rather than crashing the scan, and remaining docs are still
    checked."""
    skills_dir = os.path.join(repo_root, "skills")
    findings = []
    errors = []
    if not os.path.isdir(skills_dir):
        return {"drifted": False, "count": 0, "findings": [], "error": None}

    try:
        skill_names = sorted(os.listdir(skills_dir))
    except OSError as exc:
        errors.append(f"could not list skills/: {exc}")
        skill_names = []

    for skill_name in skill_names:
        skill_dir = os.path.join(skills_dir, skill_name)
        if not os.path.isdir(skill_dir):
            continue
        docs, doc_list_errors = _skill_doc_paths(skill_dir, repo_root)
        errors.extend(doc_list_errors)
        for doc_path in docs:
            try:
                with open(doc_path, "r", encoding="utf-8") as f:
                    text = f.read()
            except (OSError, UnicodeDecodeError) as exc:
                errors.append(f"could not read {os.path.relpath(doc_path, repo_root)}: {exc}")
                continue
            text = strip_fenced_code_blocks(text)
            for raw_ref, kind in extract_path_references(text):
                candidates = resolve_candidates(raw_ref, kind, repo_root, skill_dir)
                if not any(os.path.isfile(c) for c in candidates):
                    findings.append(
                        (
                            os.path.relpath(doc_path, repo_root),
                            raw_ref,
                            os.path.relpath(candidates[0], repo_root),
                        )
                    )
    error = "; ".join(errors) if errors else None
    return {
        "drifted": len(findings) > 0 or bool(errors),
        "count": len(findings),
        "findings": findings,
        "error": error,
    }


# --- Check 3: registry mismatches ----------------------------------------------


def _extract_registered_skills(data):
    """Validate the parsed marketplace.json ``data`` and extract the set of registered
    skill names. Returns (registered_set, error_detail). ``error_detail`` is None on
    success; on any structural-shape failure (top level not an object, "plugins" not a
    list, a plugin entry not an object, a plugin's "skills" not a list, or a skills entry
    not a string) it is a short human-readable description and registered_set is empty."""
    if not isinstance(data, dict):
        return set(), f"top-level value is {type(data).__name__}, expected an object"
    plugins = data.get("plugins", [])
    if not isinstance(plugins, list):
        return set(), f'"plugins" is {type(plugins).__name__}, expected a list'
    registered = set()
    for plugin in plugins:
        if not isinstance(plugin, dict):
            return set(), f"a plugin entry is {type(plugin).__name__}, expected an object"
        skills_list = plugin.get("skills", [])
        if not isinstance(skills_list, list):
            return set(), (
                f'a plugin\'s "skills" is {type(skills_list).__name__}, expected a list'
            )
        for entry in skills_list:
            if not isinstance(entry, str):
                return set(), f"a skills entry is {type(entry).__name__}, expected a string"
            registered.add(entry.rstrip("/").split("/")[-1])
    return registered, None


def check_registry_mismatches(repo_root):
    """Check 3. Returns {"drifted": bool, "unregistered": [name], "missing_dirs": [name],
    "error": str | None}.
    "unregistered" = dirs under skills/ not in marketplace.json's skills array.
    "missing_dirs" = marketplace.json entries whose dir doesn't exist.
    "error" = set (and "drifted" forced True) when marketplace.json exists but can't be
    read, parsed, or has an unexpected structure (e.g. "plugins" not a list, a plugin
    entry not an object), or when skills/ exists but can't be listed (OSError, e.g.
    unreadable); the registry comparison is skipped in that case rather than crashing."""
    skills_dir = os.path.join(repo_root, "skills")
    marketplace_path = os.path.join(repo_root, ".claude-plugin", "marketplace.json")

    actual = set()
    error = None
    if os.path.isdir(skills_dir):
        try:
            actual = {
                name
                for name in os.listdir(skills_dir)
                if os.path.isdir(os.path.join(skills_dir, name))
            }
        except OSError as exc:
            error = f"could not list skills/: {exc}"

    registered = set()
    if error is None and os.path.isfile(marketplace_path):
        try:
            with open(marketplace_path, "r", encoding="utf-8") as f:
                data = json.load(f)
        except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
            error = f"could not read .claude-plugin/marketplace.json: {exc}"
        else:
            registered, structure_error = _extract_registered_skills(data)
            if structure_error:
                error = f"marketplace.json has unexpected structure: {structure_error}"

    unregistered = sorted(actual - registered) if error is None else []
    missing_dirs = sorted(registered - actual) if error is None else []
    return {
        "drifted": bool(unregistered or missing_dirs or error),
        "unregistered": unregistered,
        "missing_dirs": missing_dirs,
        "error": error,
    }


# --- Orchestration + report rendering -------------------------------------------


def run_all_checks(repo_root):
    return {
        "unreleased_drift": check_unreleased_drift(repo_root),
        "dangling_references": check_dangling_references(repo_root),
        "registry_mismatches": check_registry_mismatches(repo_root),
    }


def format_report(results):
    lines = []

    ud = results["unreleased_drift"]
    lines.append("## Unreleased plugin content")
    if ud["drifted"]:
        lines.append(
            f"DRIFT: {ud['count']} commit(s) touching skills/** or .claude-plugin/** "
            "merged since the last version bump."
        )
        if ud["pr_numbers"]:
            lines.append(f"  PRs: {', '.join('#' + n for n in ud['pr_numbers'])}")
        for commit_hash, subject in ud["commits"]:
            lines.append(f"  - {commit_hash[:9]} {subject}")
    else:
        lines.append("OK: no unreleased plugin content.")

    dr = results["dangling_references"]
    lines.append("")
    lines.append("## Dangling file references")
    if dr["drifted"]:
        lines.append(f"DRIFT: {dr['count']} dangling reference(s).")
        if dr.get("error"):
            lines.append(f"  - {dr['error']}")
        for doc_path, raw_ref, resolved in dr["findings"]:
            lines.append(f"  - {doc_path}: `{raw_ref}` -> {resolved} (missing)")
    else:
        lines.append("OK: no dangling references found.")

    rm = results["registry_mismatches"]
    lines.append("")
    lines.append("## Registry mismatches")
    if rm["drifted"]:
        lines.append("DRIFT:")
        if rm.get("error"):
            lines.append(f"  - {rm['error']}")
        for name in rm["unregistered"]:
            lines.append(f"  - unregistered dir: skills/{name}")
        for name in rm["missing_dirs"]:
            lines.append(f"  - registered but missing dir: skills/{name}")
    else:
        lines.append("OK: registry matches skills/ dirs.")

    return "\n".join(lines)


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    repo_root = argv[0] if argv else find_repo_root()
    if not repo_root or not os.path.isdir(repo_root):
        print(
            "drift_check: could not locate repo root "
            "(no .claude-plugin/plugin.json found)",
            file=sys.stderr,
        )
        return 1
    results = run_all_checks(repo_root)
    print(format_report(results))
    return 0


if __name__ == "__main__":
    sys.exit(main())
