#!/usr/bin/env bash
# bump-version.sh — minor-bump the plugin version in both manifests, in sync.
#
# Run this INSIDE the PR that changes what the plugin ships (see
# docs/skill-authoring.md §2 "atomic release scheme"). It bumps
# .claude-plugin/plugin.json + .claude-plugin/marketplace.json together, so the
# version travels with the change that necessitates it and both manifests stay
# byte-in-sync.
#
# The historical hazard — concurrent PRs both hand-bumping to the same "next"
# version, producing byte-identical edits that git merges with no conflict and
# thereby flattening N releases into one — is NOT fixed by keeping the bump out
# of PRs. It is fixed by the version gate (scripts/check-version-bump.py, wired
# in .github/workflows/version-gate.yml): the gate measures each PR's version
# against main's CURRENT tip, so once one PR merges and bumps main, any sibling
# PR that reused that version fails the strictly-greater check and is forced to
# rebase and re-run this script. The collision is now loud, not silent.
#
# Usage:
#   scripts/bump-version.sh          # bump the minor version, print old/new
#
# Run from the repo root (or anywhere; paths are resolved relative to this
# script's location). After a sibling PR merges and the gate reports your bump
# is no longer greater than main's, just rebase and run this again — it computes
# the next minor from main's new value.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
plugin_json="$repo_root/.claude-plugin/plugin.json"
marketplace_json="$repo_root/.claude-plugin/marketplace.json"

python3 - "$plugin_json" "$marketplace_json" <<'PYEOF'
import json
import re
import sys

plugin_path, marketplace_path = sys.argv[1], sys.argv[2]

with open(plugin_path) as f:
    plugin = json.load(f)

with open(marketplace_path) as f:
    marketplace = json.load(f)

current = plugin["version"]
marketplace_current = marketplace["metadata"]["version"]
if current != marketplace_current:
    sys.exit(
        f"error: version already out of sync before bump "
        f"(plugin.json={current}, marketplace.json={marketplace_current}); "
        f"reconcile manually before running this script"
    )

match = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)", current)
if not match:
    sys.exit(f"error: unrecognized version format: {current!r}")

major, minor, _patch = (int(part) for part in match.groups())
next_version = f"{major}.{minor + 1}.0"

plugin["version"] = next_version
marketplace["metadata"]["version"] = next_version

with open(plugin_path, "w") as f:
    json.dump(plugin, f, indent=2)
    f.write("\n")

with open(marketplace_path, "w") as f:
    json.dump(marketplace, f, indent=2)
    f.write("\n")

print(f"{current} -> {next_version}")
PYEOF
