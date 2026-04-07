#!/usr/bin/env bash
# Check the state of all node workspaces in a project directory.
# Reports clean, dirty, or missing worktrees.
#
# Usage: check-workspace-state.sh <project_dir>
#
# Output: one line per repo worktree with status
#   <node_id> <repo> clean
#   <node_id> <repo> dirty
#   <node_id> <repo> missing

set -euo pipefail

PROJECT_DIR="$1"

shopt -s nullglob

for node_dir in "$PROJECT_DIR"/*/; do
  NODE_ID="$(basename "$node_dir")"

  for repo_dir in "$node_dir"*/; do
    repo="$(basename "$repo_dir")"

    if [ -d "${repo_dir}/.git" ] || [ -f "${repo_dir}/.git" ]; then
      status="$(git -C "$repo_dir" status --porcelain 2>/dev/null)"
      if [ -z "$status" ]; then
        echo "${NODE_ID} ${repo} clean"
      else
        echo "${NODE_ID} ${repo} dirty"
      fi
    else
      echo "${NODE_ID} ${repo} missing"
    fi
  done
done
