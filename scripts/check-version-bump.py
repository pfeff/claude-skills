#!/usr/bin/env python3
"""check-version-bump.py — enforce atomic, collision-safe plugin version bumps.

Under the atomic release scheme (see docs/skill-authoring.md §2) every PR that
changes the plugin's *shipped surface* (skills/** or .claude-plugin/**) must
carry its own version bump, in the same PR, and both manifests must agree.

The failure mode this closes: two PRs branched off the same main both hand-bump
to the *same* next version (e.g. both write "2.12.0"). The edits are
byte-identical, so git's merge machinery sees no conflict and lets both land
under one version number — N releases silently flatten into one. This check
turns that silent collision into a loud, blocking failure:

  * It compares the PR's committed version against the CURRENT tip of the base
    branch (origin/main), not against the PR's stale branch point. So the moment
    one PR merges and bumps main, every other open PR that reused that same
    version is measured against the new, equal base and FAILS the
    strictly-greater test — the author is told to rebase and re-bump.

  * Wired to run on `merge_group` as well as `pull_request` (see
    .github/workflows/version-gate.yml), it re-runs inside a GitHub merge queue
    against the real, serialized tip — closing even the exact-simultaneous-merge
    race that a pull_request-only check would miss.

Rules enforced:
  1. plugin.json `version` and marketplace.json `metadata.version` are in sync.
  2. If the PR changed the shipped surface, its version is strictly greater than
     the base branch's current version.
  3. The version never regresses below the base, even for non-shipping PRs.

Usage:
  scripts/check-version-bump.py [BASE_REF]     # BASE_REF defaults to origin/main

Exit 0 on pass, 1 on a violation (with a message explaining the fix). Run from
the repo root; requires the base ref to be fetched (CI uses fetch-depth: 0).
"""

import json
import re
import subprocess
import sys

VERSION_RE = re.compile(r"(\d+)\.(\d+)\.(\d+)")
PLUGIN_JSON = ".claude-plugin/plugin.json"
MARKETPLACE_JSON = ".claude-plugin/marketplace.json"

# A change under any of these prefixes alters what the published plugin ships,
# so the PR must carry its own version bump. Docs-only / scripts-only / CI-only
# PRs touch none of these and are not required to bump.
SHIPPED_PREFIXES = ("skills/", ".claude-plugin/")


def parse_version(text):
    """Parse "MAJOR.MINOR.PATCH" into an (int, int, int) tuple for ordering."""
    match = VERSION_RE.fullmatch(text.strip())
    if not match:
        raise ValueError(f"unrecognized version format: {text!r}")
    return tuple(int(part) for part in match.groups())


def plugin_version(blob):
    return json.loads(blob)["version"]


def marketplace_version(blob):
    return json.loads(blob)["metadata"]["version"]


def decide(base_version, head_plugin_version, head_marketplace_version, shipped_changed):
    """Pure decision — no git, no I/O. Returns (ok: bool, message: str).

    Separated from the git plumbing in main() so the whole rule set is unit
    testable without a repo.
    """
    if head_plugin_version != head_marketplace_version:
        return False, (
            f"version out of sync: {PLUGIN_JSON}={head_plugin_version}, "
            f"{MARKETPLACE_JSON}={head_marketplace_version}. "
            "Run scripts/bump-version.sh to bump both manifests together."
        )

    head = parse_version(head_plugin_version)
    base = parse_version(base_version)

    if not shipped_changed:
        if head < base:
            return False, (
                f"version regressed: {head_plugin_version} < base {base_version}. "
                "The version must never go backwards."
            )
        return True, (
            f"OK: no shipped-surface change; version {head_plugin_version} "
            f"(base {base_version})."
        )

    if head <= base:
        return False, (
            f"shipped surface changed but version {head_plugin_version} is not greater "
            f"than main's current {base_version}.\n"
            "  Another PR most likely bumped main after you branched, so your bump no "
            "longer leapfrogs it — this is the collision guard firing, not a false "
            "alarm.\n"
            "  Fix: rebase on the latest main and re-run scripts/bump-version.sh so your "
            "version lands strictly above main's."
        )

    return True, (
        f"OK: shipped surface changed; version {head_plugin_version} > base "
        f"{base_version}."
    )


def _git(args):
    return subprocess.run(
        ["git", *args], capture_output=True, text=True, check=True
    ).stdout


def _read_file_version(path, extractor):
    with open(path) as f:
        return extractor(f.read())


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    base_ref = argv[0] if argv else "origin/main"

    try:
        base_version = plugin_version(_git(["show", f"{base_ref}:{PLUGIN_JSON}"]))
    except subprocess.CalledProcessError:
        print(
            f"error: could not read {PLUGIN_JSON} at {base_ref!r}; ensure the base "
            "branch is fetched (CI uses fetch-depth: 0).",
            file=sys.stderr,
        )
        return 2

    head_plugin_version = _read_file_version(PLUGIN_JSON, plugin_version)
    head_marketplace_version = _read_file_version(MARKETPLACE_JSON, marketplace_version)

    merge_base = _git(["merge-base", base_ref, "HEAD"]).strip()
    changed = _git(["diff", "--name-only", f"{merge_base}..HEAD"]).splitlines()
    shipped_changed = any(
        path.startswith(SHIPPED_PREFIXES) for path in changed if path
    )

    ok, message = decide(
        base_version, head_plugin_version, head_marketplace_version, shipped_changed
    )
    print(message)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
