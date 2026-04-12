#!/usr/bin/env bash
# Report status of all repo worktrees in a project directory.
# Wraps check-workspace-state.sh with branch and recent commit info.
#
# Usage: workspace-status.sh <project_dir> [--format summary|detail]
#
# Output (summary, default):
#   <node_id> <repo> <clean|dirty> <branch> <last-commit-subject>
#
# Output (detail):
#   Same as summary, plus dirty files listed below each dirty repo.

set -euo pipefail

PROJECT_DIR="${1:?Usage: workspace-status.sh <project_dir> [--format summary|detail]}"
FORMAT="summary"

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --format) FORMAT="$2"; shift 2 ;;
    *) echo "error: unknown option '$1'" >&2; exit 1 ;;
  esac
done

shopt -s nullglob

for node_dir in "$PROJECT_DIR"/*/; do
  NODE_ID="$(basename "$node_dir")"

  for repo_dir in "$node_dir"*/; do
    repo="$(basename "$repo_dir")"

    if [ -d "${repo_dir}/.git" ] || [ -f "${repo_dir}/.git" ]; then
      porcelain="$(git -C "$repo_dir" status --porcelain 2>/dev/null)"
      branch="$(git -C "$repo_dir" branch --show-current 2>/dev/null || echo "detached")"
      last_commit="$(git -C "$repo_dir" log --oneline -1 --format='%s' 2>/dev/null || echo "no commits")"

      if [ -z "$porcelain" ]; then
        state="clean"
      else
        state="dirty"
      fi

      echo "${NODE_ID} ${repo} ${state} ${branch} ${last_commit}"

      if [[ "$FORMAT" == "detail" && "$state" == "dirty" ]]; then
        while IFS= read -r sc_line; do printf '    %s\n' "$sc_line"; done <<< "$porcelain"
      fi
    else
      echo "${NODE_ID} ${repo} missing - -"
    fi
  done
done
