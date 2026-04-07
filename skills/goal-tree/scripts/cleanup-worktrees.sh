#!/usr/bin/env bash
# Remove all node workspace worktrees in a project directory.
#
# Usage: cleanup-worktrees.sh <project_dir>
#
# Iterates node directories, detects git worktrees, and removes them.

set -euo pipefail

PROJECT_DIR="$1"

shopt -s nullglob

for node_dir in "$PROJECT_DIR"/*/; do
  for repo_dir in "$node_dir"*/; do
    if git -C "$repo_dir" rev-parse --is-inside-work-tree 2>/dev/null; then
      echo "Removing worktree: ${repo_dir}"
      git worktree remove "$repo_dir" 2>/dev/null
    fi
  done
done

echo "Worktree cleanup complete"
