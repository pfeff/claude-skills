#!/usr/bin/env bash
# workspace-locator.sh - Find workspace by task ID
# Usage: workspace-locator.sh <task-id> [epic]
# Output: Workspace path if found (exit 0), error message to stderr (exit 1)

set -euo pipefail

task_id="${1:-}"
epic="${2:-}"

if [ -z "$task_id" ]; then
  echo "Error: task-id required" >&2
  echo "Usage: workspace-locator.sh <task-id> [epic]" >&2
  exit 1
fi

# Search with epic filter
if [ -n "$epic" ]; then
  workspace=$(find ~/src/work/"$epic" -maxdepth 1 -type d -name "$task_id-*" 2>/dev/null | head -1)

  if [ -z "$workspace" ]; then
    echo "Error: No workspace found for task $task_id in epic $epic" >&2
    echo "Searched in: ~/src/work/$epic/" >&2
    exit 1
  fi

  echo "$workspace"
  exit 0
fi

# Search without epic filter
matches=$(find ~/src/work -maxdepth 2 -type d -name "$task_id-*" 2>/dev/null)
match_count=$(echo "$matches" | grep -c "^" || true)

if [ "$match_count" -eq 0 ]; then
  echo "Error: No workspace found for task $task_id" >&2
  echo "Searched in: ~/src/work/*/" >&2
  exit 1
elif [ "$match_count" -gt 1 ]; then
  echo "Error: Multiple workspaces found for $task_id:" >&2
  echo "$matches" >&2
  echo "" >&2
  echo "Please specify epic:" >&2
  echo "workspace-locator.sh $task_id <epic>" >&2
  exit 1
fi

echo "$matches"
exit 0
