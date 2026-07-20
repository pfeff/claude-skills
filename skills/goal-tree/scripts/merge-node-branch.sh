#!/usr/bin/env bash
# Merge a node branch into the integration branch via a temporary worktree.
# Cleans up node worktree and branch on success. Preserves state on conflict.
#
# Usage: merge-node-branch.sh <repo_source> <project_branch> <node_branch> <node_repo_dir>
#
# Exit codes:
#   0 — merge succeeded, cleanup complete
#   1 — merge conflict (worktree preserved for resolution)

set -euo pipefail

REPO_SOURCE="$1"
PROJECT_BRANCH="$2"
NODE_BRANCH="$3"
NODE_REPO_DIR="$4"

MERGE_DIR="$(mktemp -d)/merge-$(basename "$REPO_SOURCE")"

# Archive a worktree's uncommitted/untracked changes before it's removed.
# Committed work is already safe on its branch; this only protects content
# that was never committed anywhere (e.g. a document dropped in the checkout
# but never `git add`ed). Skips clean worktrees so a normal merge doesn't
# leave a tarball behind. If the archive fails, the script aborts (set -e)
# before the worktree is removed, so a failed archive can't destroy what it
# was meant to protect.
archive_worktree() {
  local dir="$1"
  if [[ -z "$(git -C "$dir" status --porcelain)" ]]; then
    return
  fi
  local archive_dir="$HOME/src/work/.archive/goal-tree-merges"
  mkdir -p "$archive_dir"
  local archive_path
  archive_path="$archive_dir/$(basename "$dir")-$(date +%Y%m%d%H%M%S).tar.gz"
  tar -czf "$archive_path" -C "$(dirname "$dir")" --exclude='*/.git' "$(basename "$dir")"
  echo "Archived uncommitted changes in ${dir} to ${archive_path}"
}

# Create temporary worktree on integration branch for merging
# (never checkout non-main branches in source repos — Safety Rule #1)
git -C "$REPO_SOURCE" worktree add "$MERGE_DIR" "$PROJECT_BRANCH"

if ! git -C "$MERGE_DIR" merge "$NODE_BRANCH"; then
  echo "CONFLICT: Merge conflict merging ${NODE_BRANCH} into ${PROJECT_BRANCH}"
  echo "Merge worktree preserved at: ${MERGE_DIR}"
  exit 1
fi

# Clean up merge worktree
archive_worktree "$MERGE_DIR"
git -C "$REPO_SOURCE" worktree remove "$MERGE_DIR"

# Clean up node worktree
archive_worktree "$NODE_REPO_DIR"
git -C "$REPO_SOURCE" worktree remove "$NODE_REPO_DIR"

# Delete node branch
git -C "$REPO_SOURCE" branch -d "$NODE_BRANCH"

echo "Merged ${NODE_BRANCH} into ${PROJECT_BRANCH}"
