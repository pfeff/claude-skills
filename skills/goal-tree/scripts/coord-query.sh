#!/usr/bin/env bash
# Thin wrapper for common coord API queries with formatted output.
# Replaces complex python/jq pipelines agents compose to extract data.
#
# Usage: coord-query.sh <query> <tree-id> [options]
#
# Queries:
#   pending-nodes <tree-id>    List nodes with status=pending
#   ready-nodes <tree-id>      List nodes ready for dispatch
#   node-status <tree-id>      List all nodes with status
#   tree-summary <tree-id>     One-line summary (total/pending/completed)
#   node-list <tree-id>        Full node list with details
#
# Requires: coord CLI configured (COORDINATOR_URL, COORDINATOR_TOKEN)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COORD="${SCRIPT_DIR}/coord"

QUERY="${1:?Usage: coord-query.sh <query> <tree-id>}"
TREE_ID="${2:?Usage: coord-query.sh <query> <tree-id>}"

case "$QUERY" in
  pending-nodes)
    "$COORD" tree show "$TREE_ID" 2>/dev/null | jq -r '
      .data.nodes[]
      | select(.status == "pending")
      | "\(.node_id): \(.title)"
    '
    ;;

  ready-nodes)
    "$COORD" tree ready "$TREE_ID" 2>/dev/null | jq -r '
      .data[]
      | "\(.node_id): \(.title) [deps: \(.dependencies | length)]"
    '
    ;;

  node-status)
    "$COORD" tree show "$TREE_ID" 2>/dev/null | jq -r '
      .data.nodes[]
      | "\(.node_id)\t\(.status)\t\(.title)"
    ' | column -t -s $'\t'
    ;;

  tree-summary)
    "$COORD" tree show "$TREE_ID" 2>/dev/null | jq -r '
      .data as $tree |
      ($tree.nodes | length) as $total |
      ([.data.nodes[] | select(.status == "pending")] | length) as $pending |
      ([.data.nodes[] | select(.status == "completed")] | length) as $completed |
      ([.data.nodes[] | select(.status == "in_progress")] | length) as $in_progress |
      "\($tree.title): \($total) nodes (\($completed) done, \($in_progress) active, \($pending) pending)"
    '
    ;;

  node-list)
    "$COORD" tree show "$TREE_ID" 2>/dev/null | jq -r '
      .data.nodes[]
      | "\(.node_id)\t\(.status)\t\(.title)\t\(.repos // [] | join(","))"
    ' | column -t -s $'\t'
    ;;

  *)
    echo "error: unknown query '$QUERY'" >&2
    echo "Available: pending-nodes, ready-nodes, node-status, tree-summary, node-list" >&2
    exit 1
    ;;
esac
