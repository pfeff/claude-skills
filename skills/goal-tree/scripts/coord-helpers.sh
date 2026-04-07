#!/usr/bin/env bash
# Shared helper functions for coordinator API integration.
#
# Source this file in operation scripts that need coordinator sync:
#
#   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
#   source "${SCRIPT_DIR}/coord-helpers.sh"
#
# Or from operations that reference the goal-tree skill:
#
#   source ~/.claude/skills/goal-tree/scripts/coord-helpers.sh
#
# All functions are no-ops when coordinator env vars are unset,
# making them safe to call unconditionally. Failures are non-blocking
# (warn to stderr, return 0).
#
# Required env vars (all optional — functions are no-ops without them):
#   COORDINATOR_URL    - API base URL (e.g., http://localhost:4000)
#   COORDINATOR_TOKEN  - Bearer token for authentication
#
# Per-operation env vars:
#   COORDINATOR_MISSION_ID - Mission ID for task creation
#   COORDINATOR_TASK_ID    - Task ID for status sync

# Create a task in the coordinator. Returns the response JSON or empty on skip.
# Usage: coord_create_task <objective> [status]
coord_create_task() {
  local objective="$1" status="${2:-pending}"
  if [[ -z "${COORDINATOR_URL:-}" || -z "${COORDINATOR_TOKEN:-}" || -z "${COORDINATOR_MISSION_ID:-}" ]]; then
    return 0
  fi
  curl -s -X POST "${COORDINATOR_URL}/api/missions/${COORDINATOR_MISSION_ID}/tasks" \
    -H "Authorization: Bearer ${COORDINATOR_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"task\":{\"objective\":\"${objective}\",\"status\":\"${status}\"}}" 2>/dev/null || {
    echo "warning: coordinator task creation failed (non-blocking)" >&2
    return 0
  }
}

# Sync task status to the coordinator.
# Usage: coord_sync_status <task_id> <status>
coord_sync_status() {
  local task_id="$1" status="$2"
  if [[ -z "${COORDINATOR_URL:-}" || -z "${COORDINATOR_TOKEN:-}" ]]; then
    return 0
  fi
  local coord_task_id="${COORDINATOR_TASK_ID:-$task_id}"
  curl -s -X PATCH "${COORDINATOR_URL}/api/tasks/${coord_task_id}" \
    -H "Authorization: Bearer ${COORDINATOR_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"task\":{\"status\":\"${status}\"}}" > /dev/null 2>&1 || {
    echo "warning: coordinator status sync failed (non-blocking)" >&2
    return 0
  }
}

# Report task progress to the coordinator.
# Usage: coord_report_progress <status> <summary>
coord_report_progress() {
  local status="$1" summary="$2"
  if [[ -z "${COORDINATOR_URL:-}" || -z "${COORDINATOR_TOKEN:-}" ]]; then
    return 0
  fi
  local coord_task_id="${COORDINATOR_TASK_ID:-}"
  [[ -n "$coord_task_id" ]] || return 0
  curl -s -X POST "${COORDINATOR_URL}/api/tasks/${coord_task_id}/report" \
    -H "Authorization: Bearer ${COORDINATOR_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"status\":\"${status}\",\"outputs\":{\"summary\":\"${summary}\"}}" > /dev/null 2>&1 || {
    echo "warning: coordinator progress report failed (non-blocking)" >&2
    return 0
  }
}
