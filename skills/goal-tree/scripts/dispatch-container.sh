#!/usr/bin/env bash
# Dispatch a goal-tree node to AC's volume-based container execution.
#
# Delegates volume creation, repo cloning, spec injection, and container
# lifecycle to the Agent Coordinator via ac_node_update(action="dispatch").
# No host-directory workspace is created — AC manages Docker volumes.
#
# Usage: dispatch-container.sh <node-workspace-path> [--context-depth lean|standard|full] [--image <docker-image>] [--dry-run]
#
# Prerequisites:
#   - Node workspace exists with DESIGN.md populated
#   - COORDINATOR_URL and COORDINATOR_TOKEN environment variables set
#   - COORDINATOR_TREE_ID environment variable set (or tree_id in DESIGN.md)
#   - curl and jq available
#
# Output: dispatch_initiated JSON to stdout

set -euo pipefail

DRY_RUN=false
NODE_WORKSPACE=""
IMAGE_OVERRIDE=""
CONTEXT_DEPTH="standard"

usage() {
  cat <<EOF
Usage: dispatch-container.sh <node-workspace-path> [--context-depth lean|standard|full] [--image <docker-image>] [--dry-run]

Dispatch a goal-tree node to AC's volume-based container execution.

AC handles the full lifecycle:
  - Docker volume creation with ac.* labels
  - Fresh repo clones into the volume
  - DESIGN.md (spec) and CLAUDE.md injection
  - Editor container launch with volume mounted
  - Result extraction when node completes
  - Volume cleanup after extraction

Options:
  --context-depth <depth>  Context depth: lean, standard (default), or full.
                           lean: task description + acceptance criteria only.
                           standard: + standing rules + repo structure summary.
                           full: + GOAL.md context + node history + project CLAUDE.md.
  --image <image>          Docker image override (default: AC's ghcr.io/pfeff/ralph:latest)
  --dry-run                Show what would be sent to AC without dispatching.
  -h, --help               Show this help and exit.

Environment:
  COORDINATOR_URL     AC API base URL (required)
  COORDINATOR_TOKEN   AC API bearer token (required)
  COORDINATOR_TREE_ID Goal tree ID (required, or extracted from DESIGN.md)
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --context-depth)
      [[ $# -ge 2 ]] || { echo "Error: --context-depth requires a value (lean|standard|full)" >&2; exit 2; }
      case "$2" in
        lean|standard|full) CONTEXT_DEPTH="$2" ;;
        *) echo "Error: --context-depth must be lean, standard, or full" >&2; exit 2 ;;
      esac
      shift 2
      ;;
    --image)
      [[ $# -ge 2 ]] || { echo "Error: --image requires a value" >&2; exit 2; }
      IMAGE_OVERRIDE="$2"
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [[ -z "$NODE_WORKSPACE" ]]; then
        NODE_WORKSPACE="$1"
        shift
      else
        echo "Error: unexpected argument: $1" >&2
        exit 2
      fi
      ;;
  esac
done

if [[ -z "$NODE_WORKSPACE" ]]; then
  echo "Error: <node-workspace-path> is required" >&2
  usage >&2
  exit 2
fi

# Resolve to absolute path
NODE_WORKSPACE="$(cd "$NODE_WORKSPACE" && pwd)"

# --- Validation ---

if [[ ! -f "$NODE_WORKSPACE/DESIGN.md" ]]; then
  echo "Error: DESIGN.md not found in $NODE_WORKSPACE" >&2
  exit 1
fi

if [[ -z "${COORDINATOR_URL:-}" ]]; then
  echo "Error: COORDINATOR_URL is not set" >&2
  exit 1
fi

if [[ -z "${COORDINATOR_TOKEN:-}" ]]; then
  echo "Error: COORDINATOR_TOKEN is not set" >&2
  exit 1
fi

if ! command -v curl &>/dev/null; then
  echo "Error: curl not found" >&2
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq not found" >&2
  exit 1
fi

# --- Parse DESIGN.md ---

extract_field() {
  local file="$1"
  local field="$2"
  sed -n "s/^- \*\*${field}\*\*: *//p" "$file" 2>/dev/null | head -1
}

DESIGN="$NODE_WORKSPACE/DESIGN.md"
NODE_ID=$(extract_field "$DESIGN" "Node ID")
NODE_TITLE=$(head -1 "$DESIGN" | sed 's/^# //' | sed "s/^${NODE_ID}: //" )
PROJECT_BRANCH=$(extract_field "$DESIGN" "Branch")
TREE_ID="${COORDINATOR_TREE_ID:-$(extract_field "$DESIGN" "Tree ID")}"

if [[ -z "$NODE_ID" ]]; then
  echo "Error: Could not extract Node ID from DESIGN.md" >&2
  exit 1
fi

if [[ -z "$TREE_ID" ]]; then
  echo "Error: Could not determine tree ID (set COORDINATOR_TREE_ID or add Tree ID to DESIGN.md)" >&2
  exit 1
fi

echo "Dispatching node $NODE_ID to AC container..." >&2
echo "  Title: $NODE_TITLE" >&2
echo "  Tree ID: $TREE_ID" >&2
echo "  Branch: ${PROJECT_BRANCH:-$NODE_ID}" >&2

# --- Detect repo remote URLs ---

REPO_URLS=()
REPO_NAMES=()

if [[ -e "$NODE_WORKSPACE/.git" ]]; then
  url=$(git -C "$NODE_WORKSPACE" remote get-url origin 2>/dev/null || true)
  if [[ -n "$url" ]]; then
    REPO_URLS+=("$url")
    REPO_NAMES+=("$(basename "$NODE_WORKSPACE")")
  fi
else
  for dir in "$NODE_WORKSPACE"/*/; do
    if [[ -e "$dir/.git" ]]; then
      repo_name=$(basename "$dir")
      url=$(git -C "$dir" remote get-url origin 2>/dev/null || true)
      if [[ -n "$url" ]]; then
        REPO_URLS+=("$url")
        REPO_NAMES+=("$repo_name")
      fi
    fi
  done
fi

if [[ ${#REPO_URLS[@]} -eq 0 ]]; then
  echo "Error: No git repos with remotes found in $NODE_WORKSPACE" >&2
  exit 1
fi

echo "  Repos: ${REPO_NAMES[*]}" >&2

# --- Read spec content (filtered by context depth) ---

echo "  Context depth: $CONTEXT_DEPTH" >&2

if [[ "$CONTEXT_DEPTH" == "full" ]]; then
  # Full: entire DESIGN.md as-is
  SPEC_CONTENT=$(cat "$DESIGN")
elif [[ "$CONTEXT_DEPTH" == "lean" ]]; then
  # Lean: extract only task description and acceptance criteria sections
  SPEC_CONTENT=$(awk '
    /^# / { title = $0; printed_title = 0 }
    /^## (Task Information|Requirements|Acceptance Criteria)/ { section = 1 }
    /^## / && !/^## (Task Information|Requirements|Acceptance Criteria)/ { section = 0 }
    section == 1 || /^# / { if (!printed_title) { print title; printed_title = 1 }; print }
  ' "$DESIGN")
  # If awk produced nothing, fall back to full content
  if [[ -z "$SPEC_CONTENT" ]]; then
    SPEC_CONTENT=$(cat "$DESIGN")
  fi
else
  # Standard (default): full DESIGN.md content
  SPEC_CONTENT=$(cat "$DESIGN")
fi

# --- Build MCP JSON-RPC request ---

BRANCH="${PROJECT_BRANCH:-$NODE_ID}"

# Build repos JSON array
REPOS_JSON=$(printf '%s\n' "${REPO_URLS[@]}" | jq -R . | jq -s .)

MCP_ARGS=$(jq -n \
  --arg action "dispatch" \
  --arg node_id "$NODE_ID" \
  --argjson tree_id "$TREE_ID" \
  --argjson repos "$REPOS_JSON" \
  --arg branch "$BRANCH" \
  --arg spec_content "$SPEC_CONTENT" \
  --arg image "$IMAGE_OVERRIDE" \
  '{
    action: $action,
    node_id: $node_id,
    tree_id: $tree_id,
    repos: $repos,
    branch: $branch,
    spec_content: $spec_content
  }
  | if $image != "" then .image = $image else . end')

MCP_REQUEST=$(jq -n \
  --argjson args "$MCP_ARGS" \
  '{
    jsonrpc: "2.0",
    id: 1,
    method: "tools/call",
    params: {
      name: "ac_node_update",
      arguments: $args
    }
  }')

# --- Dry run: show request and stop ---

if [[ "$DRY_RUN" == true ]]; then
  echo "" >&2
  echo "=== Dry run ===" >&2
  echo "Would send to ${COORDINATOR_URL}/mcp:" >&2
  echo "$MCP_REQUEST" | jq . >&2
  echo "" >&2
  echo "Repos: ${REPO_NAMES[*]}" >&2
  echo "Branch: $BRANCH" >&2
  echo "Context depth: $CONTEXT_DEPTH" >&2
  echo "Spec content: $(echo "$SPEC_CONTENT" | wc -l | tr -d ' ') lines" >&2
  exit 0
fi

# --- Call AC MCP endpoint ---

echo "" >&2
echo "=== Calling AC dispatch ===" >&2

RESPONSE=$(curl -sf \
  -X POST "${COORDINATOR_URL}/mcp" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${COORDINATOR_TOKEN}" \
  -d "$MCP_REQUEST" 2>/dev/null) || {
  echo "Error: AC MCP call failed" >&2
  cat <<RESULT
{
  "status": "failure",
  "node_id": $(printf '%s' "$NODE_ID" | jq -Rs .),
  "dispatch_method": "container",
  "issues": "AC MCP call failed — check COORDINATOR_URL and COORDINATOR_TOKEN"
}
RESULT
  exit 0
}

# Check for JSON-RPC error
ERROR=$(echo "$RESPONSE" | jq -r '.error.message // empty' 2>/dev/null || true)
if [[ -n "$ERROR" ]]; then
  echo "Error: AC returned error: $ERROR" >&2
  cat <<RESULT
{
  "status": "failure",
  "node_id": $(printf '%s' "$NODE_ID" | jq -Rs .),
  "dispatch_method": "container",
  "issues": $(printf '%s' "$ERROR" | jq -Rs .)
}
RESULT
  exit 0
fi

# Extract result text from MCP response
RESULT_TEXT=$(echo "$RESPONSE" | jq -r '.result.content[0].text // .result // empty' 2>/dev/null || true)

echo "AC response: $RESULT_TEXT" >&2

# --- Output dispatch_initiated ---

cat <<RESULT
{
  "node_id": $(printf '%s' "$NODE_ID" | jq -Rs .),
  "dispatch_method": "container",
  "status": "dispatched",
  "ac_response": $(printf '%s' "$RESULT_TEXT" | jq -Rs .)
}
RESULT
