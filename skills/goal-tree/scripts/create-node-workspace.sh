#!/usr/bin/env bash
# Wrapper for backwards compatibility - delegates to unified script
#
# Usage: create-node-workspace.sh <project_dir> <node_id> <project_branch> <owner> <repo1> [repo2 ...]
#
# This script maintains backwards compatibility with the original positional argument interface
# while delegating to the unified create-workspace.sh script.

set -euo pipefail

PROJECT_DIR="$1"
NODE_ID="$2"
PROJECT_BRANCH="$3"
OWNER="$4"
shift 4

# Convert positional repos to comma-separated
REPOS=$(IFS=,; echo "$*")

exec ~/.claude/skills/task-workflow/scripts/create-workspace.sh \
  --node \
  --node-id "$NODE_ID" \
  --headline "Node $NODE_ID" \
  --project-dir "$PROJECT_DIR" \
  --project-branch "$PROJECT_BRANCH" \
  --repos "$REPOS"
