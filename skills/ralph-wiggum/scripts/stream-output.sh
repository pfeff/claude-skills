#!/bin/bash
# Stream agent output to AC heartbeat endpoint
#
# Watches a log directory for iteration JSONL files and POSTs extracted
# assistant text to the coordinator every STREAM_INTERVAL seconds as
# heartbeat progress updates.
#
# Usage: ./stream-output.sh <log-dir>
#   log-dir: directory containing iteration-*.jsonl files (e.g., .ralph)
#
# Environment:
#   COORDINATOR_URL   - AC base URL (required)
#   COORDINATOR_TOKEN - Bearer token (required)
#   AC_TREE_ID        - Goal tree ID (required)
#   AC_NODE_ID        - Node ID string (required)
#   STREAM_INTERVAL   - Seconds between posts (default: 30)
#   STREAM_MAX_CHARS  - Max characters per chunk (default: 4000)

set -euo pipefail

LOG_DIR="${1:?Usage: stream-output.sh <log-dir>}"
INTERVAL="${STREAM_INTERVAL:-30}"
MAX_CHARS="${STREAM_MAX_CHARS:-4000}"

# Validate required env vars
for var in COORDINATOR_URL COORDINATOR_TOKEN AC_TREE_ID AC_NODE_ID; do
  if [[ -z "${!var:-}" ]]; then
    echo "stream-output: $var not set, exiting" >&2
    exit 1
  fi
done

MCP_URL="${COORDINATOR_URL}/mcp"

# Track which files and how many bytes we've already sent
declare -A FILE_OFFSETS

post_chunk() {
  local chunk="$1"
  [[ -z "$chunk" ]] && return 0

  # Escape for JSON
  local escaped
  escaped=$(printf '%s' "$chunk" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null) || return 1

  local payload
  payload=$(cat <<JSONEOF
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "id": "stream-$(date +%s)",
  "params": {
    "name": "ac_node_update",
    "arguments": {
      "tree_id": ${AC_TREE_ID},
      "node_id": "${AC_NODE_ID}",
      "action": "progress",
      "message": ${escaped}
    }
  }
}
JSONEOF
)

  curl -s -o /dev/null -w '' \
    -X POST "$MCP_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${COORDINATOR_TOKEN}" \
    -d "$payload" 2>/dev/null || true
}

# Extract readable text from stream-json JSONL
extract_text() {
  if command -v jq &>/dev/null; then
    jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text' 2>/dev/null || true
  else
    # Fallback: extract text fields
    grep -o '"text":"[^"]*"' 2>/dev/null | sed 's/"text":"//;s/"$//' || true
  fi
}

# Wait for log dir to appear
wait_count=0
while [[ ! -d "$LOG_DIR" ]] && [[ $wait_count -lt 60 ]]; do
  sleep 1
  wait_count=$((wait_count + 1))
done

if [[ ! -d "$LOG_DIR" ]]; then
  echo "stream-output: $LOG_DIR not found after 60s, exiting" >&2
  exit 1
fi

# Main streaming loop
while true; do
  sleep "$INTERVAL"

  # Collect new content from all iteration logs
  new_text=""
  for logfile in "$LOG_DIR"/iteration-*.jsonl; do
    [[ -f "$logfile" ]] || continue

    file_size=$(wc -c < "$logfile" 2>/dev/null || echo 0)
    file_size=$((file_size + 0))
    prev_offset="${FILE_OFFSETS[$logfile]:-0}"

    if [[ $file_size -le $prev_offset ]]; then
      continue
    fi

    # Read new bytes and extract assistant text
    chunk_text=$(tail -c +$((prev_offset + 1)) "$logfile" 2>/dev/null | extract_text)
    FILE_OFFSETS[$logfile]=$file_size

    if [[ -n "$chunk_text" ]]; then
      new_text="${new_text}${chunk_text}"
    fi
  done

  # Truncate to max chars (keep tail for most recent context)
  if [[ ${#new_text} -gt $MAX_CHARS ]]; then
    new_text="${new_text: -$MAX_CHARS}"
  fi

  post_chunk "$new_text"
done
