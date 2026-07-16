#!/usr/bin/env bash
# bump-version.sh — minor-bump the plugin version in both manifests, in sync.
#
# Defect this closes: individual skill-adding PRs used to hand-bump
# .claude-plugin/plugin.json + .claude-plugin/marketplace.json themselves
# (see docs/skill-authoring.md history). When multiple such PRs are open
# concurrently, each computes the same "next" version independently — a
# batch of N concurrent skill PRs all claim version X+1 instead of
# leapfrogging X+1..X+N. Because the resulting text is byte-identical, git's
# merge machinery sees no conflict and lets every PR land under the same
# version number — a silent hygiene defect, not a merge failure.
#
# Fix: skill-adding PRs register the skill in marketplace.json's `skills`
# array (alphabetical) but do NOT touch either version field. A maintainer
# runs this script once, as a separate step, after merging a batch of
# skill-adding PRs to main — one minor bump covering the whole batch.
#
# Usage:
#   scripts/bump-version.sh          # bump the minor version, print old/new
#
# Run from the repo root (or anywhere; paths are resolved relative to this
# script's location).
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
