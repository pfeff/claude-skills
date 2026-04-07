#!/usr/bin/env bash
# Kill tmux sessions matching a project slug pattern.
#
# Usage: cleanup-sessions.sh <project_slug>

set -euo pipefail

PROJECT_SLUG="$1"

tmux list-sessions -F "#{session_name}" 2>/dev/null | while IFS= read -r session; do
  case "$session" in
    *"$PROJECT_SLUG"*)
      echo "Killing session: ${session}"
      tmux kill-session -t "$session" 2>/dev/null
      ;;
  esac
done

echo "Session cleanup complete"
