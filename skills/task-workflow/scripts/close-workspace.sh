#!/bin/bash
#
# close-workspace.sh - Deterministic workspace teardown
#
# Cleanly closes a task workspace by removing worktrees, killing tmux session,
# archiving artifacts, and removing the workspace directory.
#
# Usage:
#   close-workspace.sh [WORKSPACE_PATH | TASK_ID] [OPTIONS]
#
# Arguments:
#   WORKSPACE_PATH  Path to workspace directory (defaults to CWD)
#   TASK_ID         Task identifier (e.g., "94") to search for in ~/src/work
#
# Options:
#   --no-archive       Skip archiving before removal
#   --no-close-issue   Skip closing the linked GitHub issue
#   --caller-cwd DIR   Caller's working directory (warns if inside workspace)
#   --force            Skip confirmation prompt
#
# Exit codes:
#   0 - Success
#   1 - Invalid arguments
#   2 - Workspace not found or invalid
#   3 - Archive creation failed
#   4 - Worktree removal failed
#   5 - Verification failed

set -euo pipefail

# Script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Exit codes
EXIT_SUCCESS=0
EXIT_INVALID_ARGS=1
EXIT_WORKSPACE_NOT_FOUND=2
EXIT_ARCHIVE_FAILED=3
EXIT_WORKTREE_FAILED=4
EXIT_VERIFICATION_FAILED=5

# Default values
WORKSPACE_PATH=""
NO_ARCHIVE=false
NO_CLOSE_ISSUE=false
FORCE=false
CALLER_CWD=""

#------------------------------------------------------------------------------
# Helper functions
#------------------------------------------------------------------------------

usage() {
  echo "Usage: $(basename "$0") [WORKSPACE_PATH | TASK_ID] [OPTIONS]"
  echo ""
  echo "Close a task workspace by removing worktrees, tmux session, and archiving."
  echo ""
  echo "Arguments:"
  echo "  WORKSPACE_PATH  Path to workspace directory (defaults to CWD)"
  echo "  TASK_ID         Numeric task identifier to search for in ~/src/work"
  echo ""
  echo "Options:"
  echo "  --no-archive       Skip archiving before removal"
  echo "  --no-close-issue   Skip closing the linked GitHub issue"
  echo "  --caller-cwd DIR   Caller's working directory (warns if inside workspace)"
  echo "  --force            Skip confirmation prompt"
  echo "  --help             Show this help message"
  echo ""
  echo "Exit codes:"
  echo "  0  Success"
  echo "  1  Invalid arguments"
  echo "  2  Workspace not found or invalid"
  echo "  3  Archive creation failed"
  echo "  4  Worktree removal failed"
  echo "  5  Verification failed"
}

#------------------------------------------------------------------------------
# Parse arguments
#------------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case $1 in
    --no-archive)
      NO_ARCHIVE=true
      shift
      ;;
    --no-close-issue)
      NO_CLOSE_ISSUE=true
      shift
      ;;
    --caller-cwd)
      CALLER_CWD="$2"
      shift 2
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --help)
      usage
      exit "$EXIT_SUCCESS"
      ;;
    -*)
      echo "Error: Unknown flag: $1" >&2
      usage >&2
      exit "$EXIT_INVALID_ARGS"
      ;;
    *)
      if [[ -n "$WORKSPACE_PATH" ]]; then
        echo "Error: Multiple positional arguments provided" >&2
        usage >&2
        exit "$EXIT_INVALID_ARGS"
      fi
      WORKSPACE_PATH="$1"
      shift
      ;;
  esac
done

#------------------------------------------------------------------------------
# Fail fast: non-interactive without --force
#------------------------------------------------------------------------------

if [[ "$FORCE" != true && ! -t 0 ]]; then
  echo "Error: Non-interactive mode requires --force flag." >&2
  echo "  Pass --force to skip confirmation prompts." >&2
  exit "$EXIT_INVALID_ARGS"
fi

# Track whether confirmation was explicitly obtained
CONFIRMED=false
if [[ "$FORCE" == true ]]; then
  CONFIRMED=true
fi

#------------------------------------------------------------------------------
# Step 1: Locate workspace
#------------------------------------------------------------------------------

if [[ -z "$WORKSPACE_PATH" ]]; then
  # No argument: default to CWD
  WORKSPACE_PATH="$(pwd)"
elif [[ -d "$WORKSPACE_PATH" ]]; then
  # Explicit path: resolve to absolute
  WORKSPACE_PATH="$(cd "$WORKSPACE_PATH" && pwd)"
elif [[ "$WORKSPACE_PATH" =~ ^[0-9]+$ ]]; then
  # Numeric task-id: search ~/src/work
  found=$(find ~/src/work -maxdepth 2 -type d -name "${WORKSPACE_PATH}-*" 2>/dev/null | head -1)
  if [[ -z "$found" ]]; then
    echo "Error: No workspace found for task-id: $WORKSPACE_PATH" >&2
    echo "Searched: ~/src/work/*/${WORKSPACE_PATH}-*" >&2
    exit "$EXIT_WORKSPACE_NOT_FOUND"
  fi
  WORKSPACE_PATH="$found"
else
  echo "Error: Not a valid path or task-id: $WORKSPACE_PATH" >&2
  exit "$EXIT_WORKSPACE_NOT_FOUND"
fi

echo "Workspace: $WORKSPACE_PATH"

#------------------------------------------------------------------------------
# Step 2: Validate workspace and extract metadata
#------------------------------------------------------------------------------

if [[ ! -f "$WORKSPACE_PATH/DESIGN.md" ]]; then
  echo "Error: No DESIGN.md found in $WORKSPACE_PATH" >&2
  echo "This may not be a valid task workspace." >&2
  exit "$EXIT_WORKSPACE_NOT_FOUND"
fi

# Extract task-id and headline from DESIGN.md first line: "# <task-id>: <headline>"
FIRST_LINE=$(head -1 "$WORKSPACE_PATH/DESIGN.md")
TASK_ID=$(echo "$FIRST_LINE" | sed 's/^# \([^:]*\):.*/\1/')
HEADLINE=$(echo "$FIRST_LINE" | sed 's/^# [^:]*: //')

# Extract epic and task directory from path
EPIC=$(basename "$(dirname "$WORKSPACE_PATH")")
TASK_DIR=$(basename "$WORKSPACE_PATH")

echo "  Task:     $TASK_ID - $HEADLINE"
echo "  Epic:     $EPIC"
echo "  Task Dir: $TASK_DIR"

# Extract GitHub issue reference from CLAUDE.md (format: "owner/repo#number")
GITHUB_ISSUE_REF=""
GITHUB_REPO=""
GITHUB_ISSUE_NUM=""
if [[ -f "$WORKSPACE_PATH/CLAUDE.md" ]]; then
  GITHUB_ISSUE_REF=$(grep 'GitHub Issue' "$WORKSPACE_PATH/CLAUDE.md" | head -1 | sed 's/.*GitHub Issue[*]*:[[:space:]]*//' | tr -d '[:space:]' || true)
  if [[ -n "$GITHUB_ISSUE_REF" && "$GITHUB_ISSUE_REF" =~ ^([^#]+)#([0-9]+)$ ]]; then
    GITHUB_REPO="${BASH_REMATCH[1]}"
    GITHUB_ISSUE_NUM="${BASH_REMATCH[2]}"
    echo "  GitHub Issue: $GITHUB_REPO#$GITHUB_ISSUE_NUM"
  elif [[ -n "$GITHUB_ISSUE_REF" ]]; then
    echo "  Warning: Could not parse GitHub issue reference: $GITHUB_ISSUE_REF" >&2
    GITHUB_ISSUE_REF=""
  fi
fi

# CWD safety check: warn if caller's working directory is inside the workspace
if [[ -n "$CALLER_CWD" ]]; then
  RESOLVED_CWD=$(cd "$CALLER_CWD" 2>/dev/null && pwd || echo "$CALLER_CWD")
  if [[ "$RESOLVED_CWD" == "$WORKSPACE_PATH" || "$RESOLVED_CWD" == "$WORKSPACE_PATH"/* ]]; then
    echo ""
    echo "WARNING: Your shell is inside the workspace being closed ($RESOLVED_CWD)" >&2
    echo "  Run: cd ~/src" >&2
    if [[ "$FORCE" != true ]]; then
      if [[ ! -t 0 ]]; then
        echo "Error: Non-interactive mode. Use --force to skip confirmation." >&2
        exit "$EXIT_INVALID_ARGS"
      fi
      read -r -p "Continue anyway? (y/n) " CWD_CONFIRM
      if [[ "$CWD_CONFIRM" != "y" && "$CWD_CONFIRM" != "Y" ]]; then
        echo "Cancelled. Navigate outside the workspace first."
        exit "$EXIT_SUCCESS"
      fi
    fi
  fi
fi

#------------------------------------------------------------------------------
# Step 3: Inventory components
#------------------------------------------------------------------------------

echo ""
echo "Inventorying components..."

# Find git worktrees
WORKTREES=()
WORKTREE_MAIN_REPOS=()
for dir in "$WORKSPACE_PATH"/*/; do
  [[ -d "$dir" ]] || continue
  if [[ -f "$dir/.git" ]]; then
    repo_name=$(basename "$dir")
    main_repo=$(sed -n 's|^gitdir: \(.*\)/\.git/worktrees/.*|\1|p' "$dir/.git")
    WORKTREES+=("$repo_name")
    WORKTREE_MAIN_REPOS+=("$main_repo")
  fi
done

# Check for tmux session
# Primary: read session name from .tmuxp.yaml (authoritative, set at creation time)
# Fallback: reconstruct from DESIGN.md (for workspaces without .tmuxp.yaml)
TMUX_SESSION=""
TMUXP_FILE="$WORKSPACE_PATH/.tmuxp.yaml"
if [[ -f "$TMUXP_FILE" ]]; then
  TMUXP_SESSION=$(sed -n 's/^session_name: *"\(.*\)"/\1/p' "$TMUXP_FILE")
  # Handle unquoted or single-quoted session names
  if [[ -z "$TMUXP_SESSION" ]]; then
    TMUXP_SESSION=$(sed -n "s/^session_name: *'\(.*\)'/\1/p" "$TMUXP_FILE")
  fi
  if [[ -z "$TMUXP_SESSION" ]]; then
    TMUXP_SESSION=$(sed -n 's/^session_name: *\([^"'"'"' ].*\)/\1/p' "$TMUXP_FILE")
  fi
fi
if [[ -n "${TMUXP_SESSION:-}" ]]; then
  SESSION_NAME="$TMUXP_SESSION"
else
  # Fallback: reconstruct from DESIGN.md (existing logic)
  SESSION_NAME=$(echo "$TASK_ID: $HEADLINE" | sed 's/:/-/g; s/\.//g')
fi
if tmux has-session -t "=$SESSION_NAME" 2>/dev/null; then
  TMUX_SESSION="$SESSION_NAME"
fi

WORKTREE_COUNT=${#WORKTREES[@]}

if [[ "$WORKTREE_COUNT" -gt 0 ]]; then
  echo "  Worktrees:        ${WORKTREES[*]}"
else
  echo "  Worktrees:        none"
fi
echo "  Tmux session:     ${TMUX_SESSION:-none}"

#------------------------------------------------------------------------------
# Step 4: Confirm with user
#------------------------------------------------------------------------------

if [[ "$FORCE" != true ]]; then
  if [[ ! -t 0 ]]; then
    echo "Error: Non-interactive mode. Use --force to skip confirmation." >&2
    exit "$EXIT_INVALID_ARGS"
  fi
  echo ""
  echo "Closing workspace: $TASK_ID - $HEADLINE"
  echo "Path: $WORKSPACE_PATH"
  echo ""
  echo "Components to remove:"
  if [[ "$WORKTREE_COUNT" -gt 0 ]]; then
    echo "  - Git worktrees: ${WORKTREES[*]}"
  else
    echo "  - Git worktrees: none"
  fi
  echo "  - Tmux session: ${TMUX_SESSION:-none}"
  if [[ "$NO_ARCHIVE" == true ]]; then
    echo "  - Archive: skipped (--no-archive)"
  else
    echo "  - Archive to: ~/src/work/.archive/$EPIC/$TASK_DIR.tar.gz"
  fi
  echo ""
  read -r -p "Proceed? (y/n) " CONFIRM
  if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Cancelled."
    exit "$EXIT_SUCCESS"
  fi
  CONFIRMED=true
fi

#------------------------------------------------------------------------------
# Step 5: CWD safety - move to safe directory
#------------------------------------------------------------------------------

cd "$HOME"

#------------------------------------------------------------------------------
# Defense-in-depth: abort if confirmation was never obtained
#------------------------------------------------------------------------------

if [[ "$CONFIRMED" != true ]]; then
  echo "Error: Cannot proceed without confirmation (internal safety gate)." >&2
  exit "$EXIT_INVALID_ARGS"
fi

#------------------------------------------------------------------------------
# Step 6: Remove git worktrees
#------------------------------------------------------------------------------

WORKTREE_ERRORS=0
if [[ "$WORKTREE_COUNT" -gt 0 ]]; then
  for i in "${!WORKTREES[@]}"; do
    repo="${WORKTREES[$i]}"
    main_repo="${WORKTREE_MAIN_REPOS[$i]}"
    worktree_path="$WORKSPACE_PATH/$repo"

    echo "Removing worktree: $repo"
    if [[ -n "$main_repo" ]] && [[ -d "$main_repo" ]]; then
      if ! git -C "$main_repo" worktree remove "$worktree_path" --force 2>/dev/null; then
        echo "  Warning: git worktree remove failed, removing directory" >&2
        rm -rf "$worktree_path"
        WORKTREE_ERRORS=1
      fi
    else
      echo "  Warning: main repo not found, removing directory" >&2
      rm -rf "$worktree_path"
      WORKTREE_ERRORS=1
    fi
  done

  # Prune stale worktree references
  for main_repo in $(printf '%s\n' "${WORKTREE_MAIN_REPOS[@]}" | sort -u); do
    [[ -d "$main_repo" ]] && git -C "$main_repo" worktree prune 2>/dev/null || true
  done

  if [[ "$WORKTREE_ERRORS" -eq 1 && "$FORCE" != true ]]; then
    echo "Warning: Some worktrees could not be removed cleanly" >&2
  fi
fi

#------------------------------------------------------------------------------
# Step 7: Kill tmux session
#------------------------------------------------------------------------------

if [[ -n "$TMUX_SESSION" ]]; then
  echo "Killing tmux session: $TMUX_SESSION"
  tmux kill-session -t "=$TMUX_SESSION" 2>/dev/null || true
fi

#------------------------------------------------------------------------------
# Step 8: Archive workspace
#------------------------------------------------------------------------------

ARCHIVE_PATH=""
if [[ "$NO_ARCHIVE" == true ]]; then
  echo "Skipping archive (--no-archive)"
else
  ARCHIVE_DIR="$HOME/src/work/.archive/$EPIC"
  ARCHIVE_PATH="$ARCHIVE_DIR/$TASK_DIR.tar.gz"
  mkdir -p "$ARCHIVE_DIR"

  echo "Archiving to: $ARCHIVE_PATH"
  if ! tar -czf "$ARCHIVE_PATH" \
    -C "$(dirname "$WORKSPACE_PATH")" \
    --exclude='*/.git' \
    "$TASK_DIR" 2>/dev/null; then
    echo "Error: Archive creation failed" >&2
    exit "$EXIT_ARCHIVE_FAILED"
  fi
fi

#------------------------------------------------------------------------------
# Step 9: Close linked GitHub issue
#------------------------------------------------------------------------------

ISSUE_CLOSED=false
if [[ "$NO_CLOSE_ISSUE" == true ]]; then
  echo "Skipping issue close (--no-close-issue)"
elif [[ -z "$GITHUB_ISSUE_NUM" ]]; then
  echo "No GitHub issue linked, skipping issue close"
else
  echo "Closing GitHub issue: $GITHUB_REPO#$GITHUB_ISSUE_NUM"
  if gh issue close "$GITHUB_ISSUE_NUM" --repo "$GITHUB_REPO" 2>/dev/null; then
    ISSUE_CLOSED=true
  else
    echo "  Warning: Failed to close GitHub issue (gh CLI error)" >&2
  fi
fi

#------------------------------------------------------------------------------
# Step 10: Remove workspace directory
#------------------------------------------------------------------------------

echo "Removing workspace directory"
rm -rf "$WORKSPACE_PATH"

#------------------------------------------------------------------------------
# Step 11: Verification
#------------------------------------------------------------------------------

echo ""
echo "Running verification checks..."

VERIFICATION_FAILED=0

verify_check() {
  local name="$1"
  local result="$2"
  if [[ "$result" == "pass" ]]; then
    echo "  ✓ $name"
  else
    echo "  ✗ $name"
    VERIFICATION_FAILED=1
  fi
}

# Check: workspace directory removed
if [[ ! -d "$WORKSPACE_PATH" ]]; then
  verify_check "Workspace directory removed" "pass"
else
  verify_check "Workspace directory removed" "fail"
fi

# Check: tmux session gone
if ! tmux has-session -t "=$SESSION_NAME" 2>/dev/null; then
  verify_check "Tmux session removed" "pass"
else
  verify_check "Tmux session removed" "fail"
fi

# Check: worktrees pruned from main repos
if [[ "$WORKTREE_COUNT" -gt 0 ]]; then
  for i in "${!WORKTREES[@]}"; do
    repo="${WORKTREES[$i]}"
    main_repo="${WORKTREE_MAIN_REPOS[$i]}"
    worktree_path="$WORKSPACE_PATH/$repo"
    if [[ -d "$main_repo" ]]; then
      if git -C "$main_repo" worktree list 2>/dev/null | grep -q "$worktree_path"; then
        verify_check "Worktree $repo pruned" "fail"
      else
        verify_check "Worktree $repo pruned" "pass"
      fi
    else
      verify_check "Worktree $repo pruned (main repo gone)" "pass"
    fi
  done
fi

# Check: archive exists (if archiving was requested)
if [[ "$NO_ARCHIVE" != true && -n "$ARCHIVE_PATH" ]]; then
  if [[ -f "$ARCHIVE_PATH" ]]; then
    verify_check "Archive created" "pass"
  else
    verify_check "Archive created" "fail"
  fi
fi

# Check: GitHub issue closed (if closing was requested and issue was linked)
if [[ "$NO_CLOSE_ISSUE" != true && -n "$GITHUB_ISSUE_NUM" ]]; then
  if [[ "$ISSUE_CLOSED" == true ]]; then
    verify_check "GitHub issue closed" "pass"
  else
    verify_check "GitHub issue closed" "fail"
  fi
fi

if [[ $VERIFICATION_FAILED -eq 1 ]]; then
  echo ""
  echo "Error: One or more verification checks failed" >&2
  exit "$EXIT_VERIFICATION_FAILED"
fi

echo ""
echo "All verification checks passed!"

#------------------------------------------------------------------------------
# Step 12: Summary
#------------------------------------------------------------------------------

echo ""
echo "=========================================="
echo "Workspace closed successfully!"
echo "=========================================="
echo ""
echo "  Task:      $TASK_ID - $HEADLINE"
echo "  Path:      $WORKSPACE_PATH"
echo ""
echo "Removed:"
echo "  - Worktrees: $WORKTREE_COUNT"
echo "  - Tmux session: ${TMUX_SESSION:-skipped}"
if [[ -n "$ARCHIVE_PATH" ]]; then
  echo ""
  echo "Archived to: $ARCHIVE_PATH"
fi
if [[ "$ISSUE_CLOSED" == true ]]; then
  echo "GitHub issue: $GITHUB_REPO#$GITHUB_ISSUE_NUM closed"
elif [[ "$NO_CLOSE_ISSUE" == true && -n "$GITHUB_ISSUE_NUM" ]]; then
  echo "GitHub issue: $GITHUB_REPO#$GITHUB_ISSUE_NUM (skipped)"
fi
