#!/usr/bin/env bash
#
# discuss-dispatch.sh — Atomic setup for discuss-and-dispatch workflow.
#
# Creates a coordinator node, workspace, initial DESIGN.md, and registers
# the node for completion tracking — all in one operation.
#
# Usage:
#   discuss-dispatch.sh --tree-id <id> --node-id <id> --title <title> \
#     --project-dir <dir> --project-branch <branch> --repos <repo1,repo2> \
#     [--description <desc>] [--parent-id <db-id>]
#
# Outputs (on success):
#   NODE_DB_ID=<db-id>
#   WORKSPACE_PATH=<path>
#   BRANCH=<branch>
#
# Exit codes:
#   0  Success
#   1  Argument error
#   2  coord node create failed
#   3  Workspace creation failed
#   4  Status update failed (workspace exists, node created)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COORD="${SCRIPT_DIR}/coord"

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------

TREE_ID="" NODE_ID="" TITLE="" DESCRIPTION="" PROJECT_DIR="" PROJECT_BRANCH=""
REPOS="" PARENT_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tree-id)         TREE_ID="$2"; shift 2 ;;
    --node-id)         NODE_ID="$2"; shift 2 ;;
    --title)           TITLE="$2"; shift 2 ;;
    --description)     DESCRIPTION="$2"; shift 2 ;;
    --project-dir)     PROJECT_DIR="$2"; shift 2 ;;
    --project-branch)  PROJECT_BRANCH="$2"; shift 2 ;;
    --repos)           REPOS="$2"; shift 2 ;;
    --parent-id)       PARENT_ID="$2"; shift 2 ;;
    *) echo "error: unknown option '$1'" >&2; exit 1 ;;
  esac
done

# Validate required arguments
for var in TREE_ID NODE_ID TITLE PROJECT_DIR PROJECT_BRANCH REPOS; do
  if [[ -z "${!var}" ]]; then
    echo "error: --$(echo "$var" | tr '[:upper:]' '[:lower:]' | tr '_' '-') is required" >&2
    exit 1
  fi
done

# Derive owner from first repo (org/repo format)
FIRST_REPO="${REPOS%%,*}"
OWNER="${FIRST_REPO%%/*}"

# ---------------------------------------------------------------------------
# Step 1: Create coordinator node
# ---------------------------------------------------------------------------

echo "Creating coordinator node ${NODE_ID}..." >&2

COORD_ARGS=(
  "$TREE_ID"
  --node-id "$NODE_ID"
  --title "$TITLE"
  --repos "$REPOS"
)
[[ -n "$DESCRIPTION" ]] && COORD_ARGS+=(--description "$DESCRIPTION")
[[ -n "$PARENT_ID" ]]   && COORD_ARGS+=(--parent-id "$PARENT_ID")

NODE_RESPONSE=$("$COORD" node create "${COORD_ARGS[@]}") || {
  echo "error: coord node create failed" >&2
  echo "PARTIAL: nothing created" >&2
  exit 2
}

NODE_DB_ID=$(echo "$NODE_RESPONSE" | jq -r '.data.id')
if [[ -z "$NODE_DB_ID" || "$NODE_DB_ID" == "null" ]]; then
  echo "error: could not extract node DB ID from response" >&2
  echo "PARTIAL: node may have been created but ID extraction failed" >&2
  exit 2
fi

echo "Node created: DB ID ${NODE_DB_ID}" >&2

# ---------------------------------------------------------------------------
# Step 2: Create workspace
# ---------------------------------------------------------------------------

echo "Creating workspace..." >&2

NODE_BRANCH="${PROJECT_BRANCH}/${NODE_ID}"

# Convert comma-separated repos to positional args for create-node-workspace.sh
IFS=',' read -ra REPO_ARRAY <<< "$REPOS"

# create-node-workspace.sh passes --headline "Node $NODE_ID" to create-workspace.sh.
# Workspace path pattern: $PROJECT_DIR/$NODE_ID-<slug of headline>
# e.g. NODE_ID=V, headline="Node V" → slug="node-v" → path="$PROJECT_DIR/V-node-v"
"${SCRIPT_DIR}/create-node-workspace.sh" \
  --node-db-id "$NODE_DB_ID" \
  "$PROJECT_DIR" "$NODE_ID" "$PROJECT_BRANCH" "$OWNER" "${REPO_ARRAY[@]}" || {
  echo "error: workspace creation failed" >&2
  echo "PARTIAL: coordinator node ${NODE_DB_ID} created, workspace NOT created" >&2
  exit 3
}

# Derive workspace path using same slug logic as create-workspace.sh
NODE_SLUG=$(echo "Node ${NODE_ID}" | tr '[:upper:]' '[:lower:]' | \
  sed 's/[^a-z0-9 ]//g' | tr -s ' ' | \
  awk '{for(i=1;i<=NF && i<=3;i++) printf "%s-", $i}' | sed 's/-$//')
WORKSPACE_PATH="${PROJECT_DIR}/${NODE_ID}-${NODE_SLUG}"

if [[ ! -d "$WORKSPACE_PATH" ]]; then
  # Fall back to finding it
  WORKSPACE_PATH=$(find "$PROJECT_DIR" -maxdepth 1 -type d -name "${NODE_ID}-*" | head -1)
  if [[ -z "$WORKSPACE_PATH" || ! -d "$WORKSPACE_PATH" ]]; then
    echo "error: workspace created but path not found" >&2
    echo "PARTIAL: coordinator node ${NODE_DB_ID} created, workspace path unknown" >&2
    exit 3
  fi
fi

echo "Workspace created: ${WORKSPACE_PATH}" >&2

# ---------------------------------------------------------------------------
# Step 3: Update node status to in_progress
# ---------------------------------------------------------------------------

echo "Updating node status to in_progress..." >&2

"$COORD" node update "$TREE_ID" "$NODE_DB_ID" --status in_progress || {
  echo "error: status update failed" >&2
  echo "PARTIAL: node ${NODE_DB_ID} created, workspace at ${WORKSPACE_PATH}, status NOT updated" >&2
  exit 4
}

# ---------------------------------------------------------------------------
# Step 4: Register in .active-nodes for completion tracking
# ---------------------------------------------------------------------------

ACTIVE_NODES_FILE="${PROJECT_DIR}/.active-nodes"

# Format: node_id|db_id|workspace_path|branch|tree_id|timestamp
echo "${NODE_ID}|${NODE_DB_ID}|${WORKSPACE_PATH}|${NODE_BRANCH}|${TREE_ID}|$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  >> "$ACTIVE_NODES_FILE"

echo "Registered in ${ACTIVE_NODES_FILE}" >&2

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

echo "NODE_DB_ID=${NODE_DB_ID}"
echo "WORKSPACE_PATH=${WORKSPACE_PATH}"
echo "BRANCH=${NODE_BRANCH}"
