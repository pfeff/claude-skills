#!/usr/bin/env bash
# Shared inbox writer for subagent, sub-session, and blocked notifications.
# Usage: inbox-write.sh <source_type> <source_id> <summary> [message_type]
#
# message_type defaults to "info". Use "blocked" for permission/dependency/stuck signals.

set -euo pipefail

SOURCE_TYPE="${1:?usage: inbox-write.sh <source_type> <source_id> <summary> [message_type]}"
SOURCE_ID="${2:?usage: inbox-write.sh <source_type> <source_id> <summary> [message_type]}"
SUMMARY="${3:?usage: inbox-write.sh <source_type> <source_id> <summary> [message_type]}"
MESSAGE_TYPE="${4:-info}"

INBOX_FILE="$HOME/.claude/inbox.jsonl"
COUNT_FILE="/tmp/claude-inbox-count"

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Build JSON line — use jq if available, else printf
if command -v jq &>/dev/null; then
  LINE=$(jq -cn \
    --arg ts "$TS" \
    --arg source "$SOURCE_TYPE" \
    --arg source_id "$SOURCE_ID" \
    --arg summary "$SUMMARY" \
    --arg message_type "$MESSAGE_TYPE" \
    '{ts: $ts, source: $source, source_id: $source_id, summary: $summary, message_type: $message_type}')
else
  # Escape quotes in summary for safe JSON
  ESC_SUMMARY="${SUMMARY//\"/\\\"}"
  LINE="{\"ts\":\"$TS\",\"source\":\"$SOURCE_TYPE\",\"source_id\":\"$SOURCE_ID\",\"summary\":\"$ESC_SUMMARY\",\"message_type\":\"$MESSAGE_TYPE\"}"
fi

# Append to inbox (atomic small write on local FS)
echo "$LINE" >> "$INBOX_FILE"

# Increment count
CURRENT=0
if [[ -f "$COUNT_FILE" ]]; then
  CURRENT=$(<"$COUNT_FILE")
  CURRENT="${CURRENT//[^0-9]/}"
  CURRENT="${CURRENT:-0}"
fi
echo $(( CURRENT + 1 )) > "$COUNT_FILE"
