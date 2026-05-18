#!/usr/bin/env bash
# Wrapper for backwards compatibility - delegates to unified script
#
# NOTE: This script creates HOST-DIRECTORY workspaces and is for TMUX DISPATCH ONLY.
# Container dispatch uses AC's volume-based workspaces via ac_node_update(action="dispatch").
# See dispatch-container.sh and dispatch-node.md for the volume-based flow.
#
# Usage: create-node-workspace.sh [--node-db-id <id>] <project_dir> <node_id> <project_branch> <owner> <repo1> [repo2 ...]
#
# This script maintains backwards compatibility with the original positional argument interface
# while delegating to the unified create-workspace.sh script.
#
# Optional flags (must appear before positional args):
#   --node-db-id <id>   Coordinator node DB id; written to workspace .envrc as
#                       COORDINATOR_TASK_ID so /finish can update coord status.

set -euo pipefail

# Resolve symlinks to find the real script location
SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$SOURCE" ]]; do
  DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"

NODE_DB_ID=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --node-db-id) NODE_DB_ID="$2"; shift 2 ;;
    --) shift; break ;;
    -*) echo "error: unknown flag '$1'" >&2; exit 1 ;;
    *) break ;;
  esac
done

PROJECT_DIR="$1"
NODE_ID="$2"
PROJECT_BRANCH="$3"
# $4 is OWNER — accepted for backwards compatibility but not passed to create-workspace.sh
shift 4

# Convert positional repos to comma-separated
REPOS=$(IFS=,; echo "$*")

# Find create-workspace.sh relative to this script's real location
CREATE_WORKSPACE="$SCRIPT_DIR/../../task-workflow/scripts/create-workspace.sh"

CWS_ARGS=(
  --node
  --node-id "$NODE_ID"
  --headline "Node $NODE_ID"
  --project-dir "$PROJECT_DIR"
  --project-branch "$PROJECT_BRANCH"
  --repos "$REPOS"
)
[[ -n "$NODE_DB_ID" ]] && CWS_ARGS+=(--node-db-id "$NODE_DB_ID")

exec "$CREATE_WORKSPACE" "${CWS_ARGS[@]}"
