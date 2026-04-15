#!/usr/bin/env bash
# permission-blocked-signal.sh — PreToolUse hook for L0 sessions
#
# Detects tool calls that will trigger a permission prompt in L0 sessions
# and fires a "blocked" inbox signal so L1 sees the block immediately.
#
# Behavior:
#   - Only activates when CLAUDE_INBOX_SESSION_ID is set (L0 marker)
#   - Compares the tool call against the session's allow list
#   - If the tool would need permission: fires inbox-write.sh with
#     message_type=blocked, then returns "defer" to pause the session
#   - If the tool is allowed: exits 0 (no-op, normal flow)
#
# The "defer" decision pauses the session. L1 can resume with:
#   claude -p --resume
#
# Environment:
#   CLAUDE_INBOX_SESSION_ID — session identifier for inbox messages (set by dispatch)
#   CLAUDE_INBOX_WRITER     — path to inbox-write.sh (optional, defaults to skill path)

set -euo pipefail

# Only activate in L0 sessions with inbox configured
SESSION_ID="${CLAUDE_INBOX_SESSION_ID:-}"
if [[ -z "$SESSION_ID" ]]; then
  exit 0
fi

# Graceful degradation
if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
if [[ -z "$TOOL_NAME" ]]; then
  exit 0
fi

# Tools that never need permission (built-in read-only + always-allowed)
# These match the task-workflow settings.json.tmpl allow list
ALWAYS_ALLOWED=(
  "Read" "Glob" "Grep" "Edit" "Write" "WebFetch" "WebSearch"
  "TaskCreate" "TaskUpdate" "TaskList" "TaskGet"
  "Skill" "Agent"
)

for allowed in "${ALWAYS_ALLOWED[@]}"; do
  if [[ "$TOOL_NAME" == "$allowed" ]]; then
    exit 0
  fi
done

# For Bash tool, check if command matches allowed prefixes
if [[ "$TOOL_NAME" == "Bash" ]]; then
  COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
  if [[ -z "$COMMAND" ]]; then
    exit 0
  fi

  # Allowed Bash prefixes from settings.json.tmpl
  BASH_PREFIXES=(
    "git" "gh" "grep" "cat" "wc" "mkdir" "cp" "chmod"
    "docker" "shellcheck" "jq" "ls" "head" "tail" "diff"
    "sort" "pytest" "go test" "python -m pytest"
  )

  for prefix in "${BASH_PREFIXES[@]}"; do
    if [[ "$COMMAND" == "$prefix" || "$COMMAND" == "$prefix "* ]]; then
      exit 0
    fi
  done

  TOOL_DESC="Bash: ${COMMAND:0:100}"
else
  TOOL_DESC="$TOOL_NAME"
fi

# Tool call will need permission — fire blocked signal
WRITER="${CLAUDE_INBOX_WRITER:-$(dirname "$0")/../scripts/inbox-write.sh}"
if [[ -x "$WRITER" ]]; then
  "$WRITER" "prompt" "$SESSION_ID" "Permission needed: $TOOL_DESC" "blocked" || true
fi

# Return "defer" to pause the session until L1 resumes it
jq -n '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "defer",
    permissionDecisionReason: "L0 session blocked on permission prompt — inbox notified"
  }
}'
