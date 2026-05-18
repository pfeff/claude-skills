#!/bin/bash

# Create and launch a tmuxp session from template
# Usage: create-tmuxp-session.sh <session_name> <workspace_directory>

set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <session_name> <workspace_directory>" >&2
  exit 1
fi

SESSION_NAME="$1"
WORKSPACE_DIR="$2"

# Sanitize session name for tmux compatibility
# tmux session names cannot contain: . : (but spaces are allowed)
# Replace colons with hyphens, remove periods
SANITIZED_SESSION_NAME=$(echo "$SESSION_NAME" | sed 's/:/-/g; s/\.//g')

# Validate workspace directory exists
if [ ! -d "$WORKSPACE_DIR" ]; then
  echo "Error: Workspace directory does not exist: $WORKSPACE_DIR" >&2
  exit 1
fi

# Create .tmuxp.yaml in workspace directory
TMUXP_CONFIG="$WORKSPACE_DIR/.tmuxp.yaml"

cat >"$TMUXP_CONFIG" <<EOF
session_name: "$SANITIZED_SESSION_NAME"
start_directory: $WORKSPACE_DIR
windows:
  - window_name: nvim
    start_directory: $WORKSPACE_DIR
    panes:
      - nvim

  - window_name: zsh
    start_directory: $WORKSPACE_DIR
    panes:
      - null

  - window_name: claude
    start_directory: $WORKSPACE_DIR
    window_index: 9
    panes:
      - ${CLAUDE_LAUNCH_CMD:-claude-safe}
EOF

# Kill existing session if it exists (tmuxp doesn't handle this automatically)
if tmux has-session -t "$SANITIZED_SESSION_NAME" 2>/dev/null; then
  tmux kill-session -t "$SANITIZED_SESSION_NAME"
fi

# Load the session using tmuxp
tmuxp load -d "$TMUXP_CONFIG"

echo "Tmux session '$SANITIZED_SESSION_NAME' created in $WORKSPACE_DIR"
if [ "$SESSION_NAME" != "$SANITIZED_SESSION_NAME" ]; then
  echo "Note: Session name sanitized from '$SESSION_NAME' to '$SANITIZED_SESSION_NAME'"
fi
echo "Attach with: tmux attach -t \"$SANITIZED_SESSION_NAME\""
