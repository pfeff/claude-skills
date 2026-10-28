#!/usr/bin/env bash
# detect-workspace-kind.sh - Classify a path as a Cursor-managed worktree,
# task-workflow workspace, main clone, or unknown.
#
# Usage: detect-workspace-kind.sh [path]
#   path defaults to the current working directory.
#
# Output (stdout):
#   KIND
#   WORKSPACE_ROOT=<absolute path>
#   REPO=<repo>                 # cursor-worktree only
#   WORKTREE_NAME=<name>        # cursor-worktree only
#
# KIND is one of: cursor-worktree | task-workspace | main-clone | unknown
#
# Cursor-managed trees are checked first so a repo CLAUDE.md inside
# ~/.cursor/worktrees/<repo>/<name> is never mistaken for a task workspace.
#
# Test overrides:
#   CURSOR_WORKTREES_ROOT  default $HOME/.cursor/worktrees
#   GITHUB_CLONES_ROOT     default $HOME/src/github

set -euo pipefail

CURSOR_WORKTREES_ROOT="${CURSOR_WORKTREES_ROOT:-$HOME/.cursor/worktrees}"
GITHUB_CLONES_ROOT="${GITHUB_CLONES_ROOT:-$HOME/src/github}"

input="${1:-.}"

emit() {
  local kind="$1"
  local root="${2:-}"
  echo "$kind"
  echo "WORKSPACE_ROOT=$root"
  shift 2 || true
  local kv
  for kv in "$@"; do
    echo "$kv"
  done
}

resolve_dir() {
  local path="$1"
  if [[ -d "$path" ]]; then
    (cd "$path" && pwd -P)
  else
    return 1
  fi
}

if [[ ! -e "$input" ]]; then
  emit unknown ""
  exit 0
fi

if [[ -d "$input" ]]; then
  resolved=$(resolve_dir "$input")
else
  resolved=$(cd "$(dirname "$input")" && pwd -P)
fi

cursor_root=""
if cursor_root=$(resolve_dir "$CURSOR_WORKTREES_ROOT" 2>/dev/null); then
  case "$resolved" in
    "$cursor_root"/*)
      rel="${resolved#"$cursor_root"/}"
      repo="${rel%%/*}"
      rest="${rel#*/}"
      if [[ -n "$repo" && "$rest" != "$rel" && -n "${rest%%/*}" ]]; then
        name="${rest%%/*}"
        wt_root="$cursor_root/$repo/$name"
        emit cursor-worktree "$wt_root" "REPO=$repo" "WORKTREE_NAME=$name"
        exit 0
      fi
      ;;
  esac
fi

if [[ -f "$resolved/DESIGN.md" ]]; then
  emit task-workspace "$resolved"
  exit 0
fi

github_root=""
if github_root=$(resolve_dir "$GITHUB_CLONES_ROOT" 2>/dev/null); then
  case "$resolved" in
    "$github_root"|"$github_root"/*)
      emit main-clone "$resolved"
      exit 0
      ;;
  esac
fi

emit unknown "$resolved"
exit 0
