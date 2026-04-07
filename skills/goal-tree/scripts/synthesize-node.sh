#!/usr/bin/env bash
# Commit outstanding changes and merge a node's repo worktrees into integration.
# Processes all repos in a single node workspace.
#
# Usage: synthesize-node.sh <project_dir> <node_id> <project_branch> <owner>
#
# Exit codes:
#   0 — all merges succeeded
#   1 — merge conflict (stops at first conflict, preserves state)

set -euo pipefail

PROJECT_DIR="$1"
NODE_ID="$2"
PROJECT_BRANCH="$3"
OWNER="$4"

NODE_DIR="${PROJECT_DIR}/${NODE_ID}"
NODE_BRANCH="${PROJECT_BRANCH}/${NODE_ID}"
SCRIPT_DIR="$(dirname "$0")"

shopt -s nullglob

for repo_dir in "$NODE_DIR"/*/; do
  repo="$(basename "$repo_dir")"
  REPO_SOURCE=~/src/github/"${OWNER}"/"${repo}"

  # Check for outstanding changes
  if [ -n "$(git -C "$repo_dir" status --porcelain 2>/dev/null)" ]; then
    echo "UNCOMMITTED: ${repo_dir} has uncommitted changes — commit before synthesizing"
    exit 1
  fi

  # Merge node branch into integration branch
  "$SCRIPT_DIR/merge-node-branch.sh" \
    "$REPO_SOURCE" \
    "$PROJECT_BRANCH" \
    "$NODE_BRANCH" \
    "$repo_dir"
done

# Remove node directory if empty
rmdir "$NODE_DIR" 2>/dev/null || true

echo "Synthesized node ${NODE_ID}"
