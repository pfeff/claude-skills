#!/bin/bash
# Scan ~/.claude/tasks/ for workspace status using Claude native task lists
# Outputs: task_list_id|status|pending|in_progress|completed|total|workspace

TASKS_DIR="${HOME}/.claude/tasks"
WORK_DIR="${HOME}/src/work"

# Exit if tasks directory doesn't exist
if [ ! -d "$TASKS_DIR" ]; then
  exit 0
fi

# Build workspace lookup map (task_list_id -> workspace_path)
declare -A workspace_map
while IFS= read -r envrc_file; do
  task_id=$(grep -oP 'CLAUDE_CODE_TASK_LIST_ID="\K[^"]+' "$envrc_file" 2>/dev/null)
  if [ -n "$task_id" ]; then
    workspace_map["$task_id"]=$(dirname "$envrc_file")
  fi
done < <(find "$WORK_DIR" -name ".envrc" -type f 2>/dev/null)

# Scan each task list directory
for task_dir in "$TASKS_DIR"/*/; do
  [ -d "$task_dir" ] || continue

  task_list_id=$(basename "$task_dir")

  # Skip lock files and non-directories
  [ -f "${task_dir}.lock" ] && [ ! -d "$task_dir" ] && continue

  # Count tasks by status
  pending=0
  in_progress=0
  completed=0

  for json_file in "$task_dir"/*.json; do
    [ -f "$json_file" ] || continue

    status=$(grep -oP '"status":\s*"\K[^"]+' "$json_file" 2>/dev/null)
    case "$status" in
      pending) ((pending++)) ;;
      in_progress) ((in_progress++)) ;;
      completed) ((completed++)) ;;
    esac
  done

  total=$((pending + in_progress + completed))

  # Skip empty task lists
  [ $total -eq 0 ] && continue

  # Determine overall status
  if [ $in_progress -gt 0 ]; then
    overall_status="in-progress"
  elif [ $pending -gt 0 ]; then
    overall_status="pending"
  else
    overall_status="completed"
  fi

  # Find matching workspace
  workspace="${workspace_map[$task_list_id]:-}"

  # Output: task_list_id|status|pending|in_progress|completed|total|workspace
  echo "$task_list_id|$overall_status|$pending|$in_progress|$completed|$total|$workspace"
done | sort -t'|' -k1,1
