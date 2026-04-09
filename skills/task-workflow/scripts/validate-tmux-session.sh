#!/bin/bash

# Validate that a tmux session has the expected window layout
# Usage: validate-tmux-session.sh <session_name>
#
# Expected windows: nvim, zsh, claude
# Exit codes:
#   0 - Session is compliant (has all expected windows)
#   1 - Session does not exist
#   2 - Session is missing one or more expected windows

set -euo pipefail

EXPECTED_WINDOWS=("nvim" "zsh" "claude")

if [ $# -lt 1 ]; then
  echo "Usage: $0 <session_name>" >&2
  echo "" >&2
  echo "Validates that a tmux session has expected windows: ${EXPECTED_WINDOWS[*]}" >&2
  exit 1
fi

SESSION_NAME="$1"

# Check if session exists
if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  echo "Session '$SESSION_NAME' does not exist" >&2
  exit 1
fi

# Get list of window names in the session
WINDOWS=$(tmux list-windows -t "$SESSION_NAME" -F '#{window_name}')

# Check for each expected window
MISSING=()
for expected in "${EXPECTED_WINDOWS[@]}"; do
  if ! echo "$WINDOWS" | grep -q "^${expected}$"; then
    MISSING+=("$expected")
  fi
done

# Report results
if [ ${#MISSING[@]} -eq 0 ]; then
  echo "Session '$SESSION_NAME' is compliant"
  echo "Windows: $(echo "$WINDOWS" | tr '\n' ' ')"
  exit 0
else
  echo "Session '$SESSION_NAME' is missing windows: ${MISSING[*]}" >&2
  echo "Found windows: $(echo "$WINDOWS" | tr '\n' ' ')" >&2
  exit 2
fi
