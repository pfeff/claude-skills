#!/bin/bash
#
# assert-worktree-branch.sh — Pre-commit guard: fail if the worktree directory
# basename does not align with the currently checked-out branch.
#
# Purpose: In git worktree workflows the directory path implies the branch
# (e.g. ~/src/work/<epic>/<task>/repo-name lives on branch <task>/repo-name),
# but git does not enforce this. An agent can silently switch branches inside
# a worktree; subsequent commits land on the wrong branch and require painful
# cherry-pick + force-push recovery.
#
# Install: this script is wired into .git/hooks/pre-commit by create-workspace.sh
# at workspace creation time. It can also be run standalone.
#
# Convention checked:
#   worktree path: ~/src/work/<epic>/<task-dir>/<repo>
#   expected branch prefix: <task-dir>/ (everything under the task directory)
#
#   A more specific check for node workspaces (goal-tree pattern):
#     path basename: <node-id>-<slug>
#     branch contains: <project-branch>/<node-id>
#
# Exit codes:
#   0 — OK (path and branch are aligned, or warn-only conditions)
#   1 — FAIL (clear mismatch; commit blocked)

set -euo pipefail

WARN_ONLY="${ASSERT_WORKTREE_BRANCH_WARN_ONLY:-0}"

# Get the worktree root (where .git pointer file or dir lives)
WORKTREE_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$WORKTREE_ROOT" ]]; then
  echo "assert-worktree-branch: not inside a git worktree, skipping" >&2
  exit 0
fi

# Get the current branch name
CURRENT_BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || true)"
if [[ -z "$CURRENT_BRANCH" ]]; then
  # Detached HEAD — can't enforce a convention, warn and let commit proceed
  echo "assert-worktree-branch: HEAD is detached, cannot enforce branch alignment — proceeding" >&2
  exit 0
fi

# -----------------------------------------------------------------------
# Strategy: derive the expected branch namespace from the directory path.
#
# Layout: ~/src/work/<epic>/<task-dir>/<repo>
#   parent dir of the worktree = <task-dir>
#   expected: branch starts with <task-dir>/
#
# For node workspaces: <project-dir>/<node-id>-<slug>/<repo>
#   parent dir of worktree = <node-id>-<slug>
#   node-id derived from parent basename prefix before first dash
#   expected: branch contains /<node-id> somewhere
# -----------------------------------------------------------------------

WORKTREE_PARENT="$(basename "$(dirname "$WORKTREE_ROOT")")"

# Extract the task-dir / node prefix from parent directory
# Task workspace: parent looks like "DO-540-manage-dev-stack" → expects "DO-540" or "DO-540/"
# Node workspace: parent looks like "A.1-cli-compile" → node-id "A.1"

FAIL=0
REASON=""

# Check 1: simple prefix match — branch should start with parent dir name or contain it
if [[ "$CURRENT_BRANCH" == "${WORKTREE_PARENT}/"* ]]; then
  # Perfect match: branch namespace == parent dir
  exit 0
fi

# Check 2: branch contains the parent basename anywhere (looser match for nested branches)
if echo "$CURRENT_BRANCH" | grep -qF "$WORKTREE_PARENT"; then
  exit 0
fi

# Check 3: node workspace pattern — parent is <node-id>-<slug>
# node-id = everything before the first hyphen (e.g. "A.1" from "A.1-cli-compile")
NODE_ID="${WORKTREE_PARENT%%-*}"
if [[ -n "$NODE_ID" && "$NODE_ID" != "$WORKTREE_PARENT" ]]; then
  if echo "$CURRENT_BRANCH" | grep -qF "/$NODE_ID"; then
    exit 0
  fi
fi

# Check 4: the branch could share just the worktree repo basename for simple feature branches
# e.g. repo is "claude-skills", branch is "self-improvement/2026-05-27" — acceptable drift
# but if branch is "main" or "master" that is definitely wrong.
if [[ "$CURRENT_BRANCH" == "main" || "$CURRENT_BRANCH" == "master" || "$CURRENT_BRANCH" == "develop" ]]; then
  FAIL=1
  REASON="on default/protected branch '$CURRENT_BRANCH' inside worktree '$WORKTREE_ROOT'"
else
  # Unrecognised pattern — warn but do not block (can't infer the mapping)
  echo "assert-worktree-branch: WARN — could not verify branch alignment" >&2
  echo "  worktree: $WORKTREE_ROOT" >&2
  echo "  branch:   $CURRENT_BRANCH" >&2
  echo "  expected a branch under namespace: $WORKTREE_PARENT/" >&2
  echo "  Proceeding (set ASSERT_WORKTREE_BRANCH_WARN_ONLY=1 to downgrade to warn-only)" >&2
  exit 0
fi

if [[ $FAIL -eq 1 ]]; then
  MSG="assert-worktree-branch: FAIL — $REASON"
  if [[ "$WARN_ONLY" == "1" ]]; then
    echo "assert-worktree-branch: WARN — $REASON (commit NOT blocked; WARN_ONLY=1)" >&2
    exit 0
  else
    echo "$MSG" >&2
    echo "  worktree: $WORKTREE_ROOT" >&2
    echo "  branch:   $CURRENT_BRANCH" >&2
    echo "  Fix: git checkout <correct-branch> or set ASSERT_WORKTREE_BRANCH_WARN_ONLY=1 to downgrade to a warning." >&2
    exit 1
  fi
fi

exit 0
