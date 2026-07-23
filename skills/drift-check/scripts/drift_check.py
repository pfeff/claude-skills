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


def _skill_doc_paths(skill_dir):
    """SKILL.md plus any operations/*.md files under a single skill directory."""
    docs = []
    skill_md = os.path.join(skill_dir, "SKILL.md")
    if os.path.isfile(skill_md):
        docs.append(skill_md)
    ops_dir = os.path.join(skill_dir, "operations")
    if os.path.isdir(ops_dir):
        for name in sorted(os.listdir(ops_dir)):
            if name.endswith(".md"):
                docs.append(os.path.join(ops_dir, name))
    return docs


def check_dangling_references(repo_root):
    """Check 2. Returns {"drifted": bool, "count": int,
    "findings": [(doc_path, raw_ref, resolved_path)]} (paths relative to repo_root)."""
    skills_dir = os.path.join(repo_root, "skills")
    findings = []
    if not os.path.isdir(skills_dir):
        return {"drifted": False, "count": 0, "findings": []}

    for skill_name in sorted(os.listdir(skills_dir)):
        skill_dir = os.path.join(skills_dir, skill_name)
        if not os.path.isdir(skill_dir):
            continue
        for doc_path in _skill_doc_paths(skill_dir):
            with open(doc_path, "r", encoding="utf-8") as f:
                text = f.read()
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
    return {"drifted": len(findings) > 0, "count": len(findings), "findings": findings}


# --- Check 3: registry mismatches ----------------------------------------------


def check_registry_mismatches(repo_root):
    """Check 3. Returns {"drifted": bool, "unregistered": [name], "missing_dirs": [name],
    "error": str | None}.
    "unregistered" = dirs under skills/ not in marketplace.json's skills array.
    "missing_dirs" = marketplace.json entries whose dir doesn't exist.
    "error" = set (and "drifted" forced True) when marketplace.json exists but can't be
    read or parsed; the registry comparison is skipped in that case rather than crashing."""
    skills_dir = os.path.join(repo_root, "skills")
    marketplace_path = os.path.join(repo_root, ".claude-plugin", "marketplace.json")

    actual = set()
    if os.path.isdir(skills_dir):
        actual = {
            name
            for name in os.listdir(skills_dir)
            if os.path.isdir(os.path.join(skills_dir, name))
        }

    registered = set()
    error = None
    if os.path.isfile(marketplace_path):
        try:
            with open(marketplace_path, "r", encoding="utf-8") as f:
                data = json.load(f)
        except (OSError, json.JSONDecodeError) as exc:
            error = f"could not read .claude-plugin/marketplace.json: {exc}"
        else:
            for plugin in data.get("plugins", []):
                for entry in plugin.get("skills", []):
                    registered.add(entry.rstrip("/").split("/")[-1])

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
