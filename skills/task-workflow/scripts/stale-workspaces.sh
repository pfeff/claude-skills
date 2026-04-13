#!/bin/bash
#
# stale-workspaces.sh - Detect stale workspaces (issue closed, workspace still open)
#
# Scans ~/src/work/ for active workspaces, extracts GitHub issue references
# from CLAUDE.md, and checks issue state via gh CLI.
#
# Usage:
#   stale-workspaces.sh [OPTIONS]
#
# Options:
#   --quiet    Suppress progress messages, only output stale workspace lines
#   --help     Show this help message
#
# Output:
#   One line per stale workspace (tab-separated):
#     <workspace_path>\t<issue_ref>\t<issue_state>
#
# Exit codes:
#   0 - No stale workspaces found
#   1 - Stale workspaces found
#   2 - Error (e.g., gh CLI not available)

set -euo pipefail

WORK_DIR="${HOME}/src/work"
QUIET=false

#------------------------------------------------------------------------------
# Helper functions
#------------------------------------------------------------------------------

usage() {
  echo "Usage: $(basename "$0") [OPTIONS]"
  echo ""
  echo "Detect stale workspaces (GitHub issue closed but workspace still open)."
  echo ""
  echo "Options:"
  echo "  --quiet    Suppress progress messages, only output stale lines"
  echo "  --help     Show this help message"
  echo ""
  echo "Output (tab-separated per stale workspace):"
  printf "  <workspace_path>\\t<issue_ref>\\t<issue_state>\\n"
  echo ""
  echo "Exit codes:"
  echo "  0  No stale workspaces found"
  echo "  1  Stale workspaces found"
  echo "  2  Error"
}

log() {
  if [[ "$QUIET" != true ]]; then
    echo "$@" >&2
  fi
}

#------------------------------------------------------------------------------
# Parse arguments
#------------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case $1 in
    --quiet)
      QUIET=true
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Error: Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

#------------------------------------------------------------------------------
# Verify prerequisites
#------------------------------------------------------------------------------

if ! command -v gh &>/dev/null; then
  echo "Error: gh CLI not found" >&2
  exit 2
fi

if [[ ! -d "$WORK_DIR" ]]; then
  log "No work directory found at $WORK_DIR"
  exit 0
fi

#------------------------------------------------------------------------------
# Scan workspaces
#------------------------------------------------------------------------------

stale_count=0
checked_count=0
skipped_count=0
error_count=0

# Find all workspace CLAUDE.md files (pattern: ~/src/work/<epic>/<task-dir>/CLAUDE.md)
# Exclude .archive directory
while IFS= read -r claude_md; do
  workspace_path=$(dirname "$claude_md")

  # Skip archived workspaces
  if [[ "$workspace_path" == *"/.archive/"* ]]; then
    continue
  fi

  # Extract GitHub issue reference (requires colon after "GitHub Issue")
  issue_ref=$(grep 'GitHub Issue.*:' "$claude_md" | head -1 | sed 's/.*GitHub Issue[*]*:[[:space:]]*//' | tr -d '[:space:]' || true)

  if [[ -z "$issue_ref" ]]; then
    ((skipped_count++))
    continue
  fi

  # Parse owner/repo#number
  if [[ "$issue_ref" =~ ^([^#]+)#([0-9]+)$ ]]; then
    repo="${BASH_REMATCH[1]}"
    issue_num="${BASH_REMATCH[2]}"
  else
    log "Warning: Could not parse issue reference: $issue_ref ($workspace_path)"
    ((skipped_count++))
    continue
  fi

  # Check issue state via gh CLI
  issue_state=$(gh issue view "$issue_num" --repo "$repo" --json state --jq '.state' 2>/dev/null || echo "ERROR")

  if [[ "$issue_state" == "ERROR" ]]; then
    log "Warning: Could not check issue status for $repo#$issue_num ($workspace_path)"
    ((error_count++))
    continue
  fi

  ((checked_count++))

  if [[ "$issue_state" == "CLOSED" ]]; then
    ((stale_count++))
    printf '%s\t%s\t%s\n' "$workspace_path" "$repo#$issue_num" "$issue_state"
  fi

done < <(find "$WORK_DIR" -maxdepth 3 -name "CLAUDE.md" -type f 2>/dev/null | sort)

#------------------------------------------------------------------------------
# Summary
#------------------------------------------------------------------------------

log ""
log "Checked: $checked_count, Stale: $stale_count, Skipped: $skipped_count, Errors: $error_count"

if [[ $stale_count -gt 0 ]]; then
  exit 1
else
  exit 0
fi
