#!/usr/bin/env bash
#
# close-project.sh - Close a goal-tree project workspace
#
# Cleanly closes a project by removing all node worktrees, killing tmux
# sessions, archiving artifacts, and removing the project directory.
# Composes with close-workspace.sh for node-level cleanup.
#
# Usage:
#   close-project.sh [PROJECT_PATH] [OPTIONS]
#
# Arguments:
#   PROJECT_PATH    Path to project directory (defaults to CWD)
#
# Options:
#   --no-archive       Skip archiving before removal
#   --no-update-issue  Skip updating the guardian issue
#   --caller-cwd DIR   Caller's working directory (warns if inside project)
#   --force            Skip confirmation prompt
#
# Exit codes:
#   0 - Success
#   1 - Invalid arguments
#   2 - Project not found or invalid (no CLAUDE.md)
#   3 - Archive creation failed
#   4 - Verification failed

set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"

# Exit codes
EXIT_SUCCESS=0
EXIT_INVALID_ARGS=1
EXIT_PROJECT_NOT_FOUND=2
EXIT_ARCHIVE_FAILED=3
EXIT_VERIFICATION_FAILED=4

# Default values
PROJECT_PATH=""
NO_ARCHIVE=false
NO_UPDATE_ISSUE=false
FORCE=false
CALLER_CWD=""

#------------------------------------------------------------------------------
# Parse arguments
#------------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case $1 in
    --no-archive)     NO_ARCHIVE=true; shift ;;
    --no-update-issue) NO_UPDATE_ISSUE=true; shift ;;
    --caller-cwd)     CALLER_CWD="$2"; shift 2 ;;
    --force)          FORCE=true; shift ;;
    --help)
      echo "Usage: $(basename "$0") [PROJECT_PATH] [OPTIONS]"
      echo ""
      echo "Close a goal-tree project workspace."
      echo ""
      echo "Options:"
      echo "  --no-archive       Skip archiving before removal"
      echo "  --no-update-issue  Skip updating the guardian issue"
      echo "  --caller-cwd DIR   Caller's CWD (warns if inside project)"
      echo "  --force            Skip confirmation prompt"
      exit "$EXIT_SUCCESS"
      ;;
    -*)
      echo "Error: Unknown flag: $1" >&2
      exit "$EXIT_INVALID_ARGS"
      ;;
    *)
      if [[ -n "$PROJECT_PATH" ]]; then
        echo "Error: Multiple positional arguments provided" >&2
        exit "$EXIT_INVALID_ARGS"
      fi
      PROJECT_PATH="$1"
      shift
      ;;
  esac
done

#------------------------------------------------------------------------------
# Step 1: Locate project
#------------------------------------------------------------------------------

if [[ -z "$PROJECT_PATH" ]]; then
  PROJECT_PATH="$(pwd)"
elif [[ -d "$PROJECT_PATH" ]]; then
  PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"
else
  echo "Error: Not a valid path: $PROJECT_PATH" >&2
  exit "$EXIT_PROJECT_NOT_FOUND"
fi

if [[ ! -f "$PROJECT_PATH/CLAUDE.md" ]]; then
  echo "Error: No CLAUDE.md found in $PROJECT_PATH" >&2
  echo "This may not be a valid goal-tree project." >&2
  exit "$EXIT_PROJECT_NOT_FOUND"
fi

echo "Project: $PROJECT_PATH"

#------------------------------------------------------------------------------
# Step 2: Extract metadata
#------------------------------------------------------------------------------

# Project title from CLAUDE.md first line: "# Goal: <title>"
PROJECT_TITLE="$(head -1 "$PROJECT_PATH/CLAUDE.md" | sed 's/^# Goal: //')"
PROJECT_DIR_NAME="$(basename "$PROJECT_PATH")"
PARENT_DIR_NAME="$(basename "$(dirname "$PROJECT_PATH")")"

# Guardian issue from CLAUDE.md
GUARDIAN_ISSUE=""
GUARDIAN_REPO=""
GUARDIAN_NUM=""
if grep -q '^\- \*\*Issue\*\*:' "$PROJECT_PATH/CLAUDE.md"; then
  GUARDIAN_ISSUE="$(grep '^\- \*\*Issue\*\*:' "$PROJECT_PATH/CLAUDE.md" | head -1 | sed 's/.*Issue\*\*: //' | tr -d '[:space:]')"
  if [[ "$GUARDIAN_ISSUE" =~ ^([^#]+)#([0-9]+)$ ]]; then
    GUARDIAN_REPO="${BASH_REMATCH[1]}"
    GUARDIAN_NUM="${BASH_REMATCH[2]}"
  fi
fi

echo "  Title:    $PROJECT_TITLE"
echo "  Guardian: ${GUARDIAN_ISSUE:-none}"

#------------------------------------------------------------------------------
# Step 3: Inventory components
#------------------------------------------------------------------------------

echo ""
echo "Inventorying components..."

# Count node workspaces (subdirs with git worktrees)
NODE_DIRS=()
WORKTREE_COUNT=0
shopt -s nullglob
for node_dir in "$PROJECT_PATH"/*/; do
  node_name="$(basename "$node_dir")"
  # Skip non-node dirs (no repo worktrees inside)
  has_worktree=false
  for repo_dir in "$node_dir"*/; do
    if [[ -f "$repo_dir/.git" ]]; then
      has_worktree=true
      WORKTREE_COUNT=$((WORKTREE_COUNT + 1))
    fi
  done
  if [[ "$has_worktree" == true ]]; then
    NODE_DIRS+=("$node_name")
  fi
done

# Count tmux sessions matching project
SESSION_COUNT=0
if command -v tmux >/dev/null 2>&1; then
  SESSION_COUNT="$(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep -c "$PROJECT_DIR_NAME" || true)"
fi

echo "  Node workspaces:  ${#NODE_DIRS[@]} (${NODE_DIRS[*]:-none})"
echo "  Worktrees:        $WORKTREE_COUNT"
echo "  Tmux sessions:    $SESSION_COUNT"

# CWD safety check
if [[ -n "$CALLER_CWD" ]]; then
  RESOLVED_CWD="$(cd "$CALLER_CWD" 2>/dev/null && pwd || echo "$CALLER_CWD")"
  if [[ "$RESOLVED_CWD" == "$PROJECT_PATH" || "$RESOLVED_CWD" == "$PROJECT_PATH"/* ]]; then
    echo ""
    echo "WARNING: Your shell is inside the project being closed ($RESOLVED_CWD)" >&2
    echo "  Run: cd ~/src" >&2
    if [[ "$FORCE" != true ]]; then
      if [[ ! -t 0 ]]; then
        echo "Error: Non-interactive mode. Use --force to skip confirmation." >&2
        exit "$EXIT_INVALID_ARGS"
      fi
      read -r -p "Continue anyway? (y/n) " CWD_CONFIRM
      if [[ "$CWD_CONFIRM" != "y" && "$CWD_CONFIRM" != "Y" ]]; then
        echo "Cancelled."
        exit "$EXIT_SUCCESS"
      fi
    fi
  fi
fi

#------------------------------------------------------------------------------
# Step 4: Confirm
#------------------------------------------------------------------------------

if [[ "$FORCE" != true ]]; then
  if [[ ! -t 0 ]]; then
    echo "Error: Non-interactive mode. Use --force to skip confirmation." >&2
    exit "$EXIT_INVALID_ARGS"
  fi
  echo ""
  echo "Closing project: $PROJECT_TITLE"
  echo "Path: $PROJECT_PATH"
  echo ""
  echo "Will remove:"
  echo "  - ${#NODE_DIRS[@]} node workspaces with $WORKTREE_COUNT worktrees"
  echo "  - $SESSION_COUNT tmux sessions"
  if [[ "$NO_ARCHIVE" == true ]]; then
    echo "  - Archive: skipped (--no-archive)"
  else
    echo "  - Archive to: ~/src/work/.archive/$PARENT_DIR_NAME/$PROJECT_DIR_NAME.tar.gz"
  fi
  echo ""
  read -r -p "Proceed? (y/n) " CONFIRM
  if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Cancelled."
    exit "$EXIT_SUCCESS"
  fi
fi

#------------------------------------------------------------------------------
# Step 5: Move to safe directory
#------------------------------------------------------------------------------

cd "$HOME"

#------------------------------------------------------------------------------
# Step 6: Remove all worktrees via cleanup script
#------------------------------------------------------------------------------

echo ""
echo "Removing worktrees..."
"$SCRIPT_DIR/cleanup-worktrees.sh" "$PROJECT_PATH"

#------------------------------------------------------------------------------
# Step 7: Kill tmux sessions
#------------------------------------------------------------------------------

if [[ "$SESSION_COUNT" -gt 0 ]]; then
  echo ""
  echo "Killing tmux sessions..."
  "$SCRIPT_DIR/cleanup-sessions.sh" "$PROJECT_DIR_NAME"
fi

#------------------------------------------------------------------------------
# Step 8: Archive project
#------------------------------------------------------------------------------

ARCHIVE_PATH=""
if [[ "$NO_ARCHIVE" == true ]]; then
  echo ""
  echo "Skipping archive (--no-archive)"
else
  ARCHIVE_DIR="$HOME/src/work/.archive/$PARENT_DIR_NAME"
  ARCHIVE_PATH="$ARCHIVE_DIR/$PROJECT_DIR_NAME.tar.gz"
  mkdir -p "$ARCHIVE_DIR"

  echo ""
  echo "Archiving to: $ARCHIVE_PATH"
  if ! tar -czf "$ARCHIVE_PATH" \
    -C "$(dirname "$PROJECT_PATH")" \
    --exclude='*/.git' \
    "$PROJECT_DIR_NAME" 2>/dev/null; then
    echo "Error: Archive creation failed" >&2
    exit "$EXIT_ARCHIVE_FAILED"
  fi
fi

#------------------------------------------------------------------------------
# Step 9: Update guardian issue
#------------------------------------------------------------------------------

if [[ "$NO_UPDATE_ISSUE" == true ]]; then
  echo "Skipping guardian issue update (--no-update-issue)"
elif [[ -z "$GUARDIAN_NUM" ]]; then
  echo "No guardian issue linked, skipping update"
else
  echo ""
  echo "Adding closure comment to guardian issue: $GUARDIAN_ISSUE"
  gh issue comment "$GUARDIAN_NUM" --repo "$GUARDIAN_REPO" \
    --body "Project workspace closed and archived." 2>/dev/null || \
    echo "  Warning: Failed to comment on guardian issue" >&2
fi

#------------------------------------------------------------------------------
# Step 10: Remove project directory
#------------------------------------------------------------------------------

echo ""
echo "Removing project directory"
rm -rf "$PROJECT_PATH"

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

# Project directory removed
if [[ ! -d "$PROJECT_PATH" ]]; then
  verify_check "Project directory removed" "pass"
else
  verify_check "Project directory removed" "fail"
fi

# Tmux sessions gone
remaining_sessions=0
if command -v tmux >/dev/null 2>&1; then
  remaining_sessions="$(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep -c "$PROJECT_DIR_NAME" || true)"
fi
if [[ "$remaining_sessions" -eq 0 ]]; then
  verify_check "Tmux sessions removed" "pass"
else
  verify_check "Tmux sessions removed" "fail"
fi

# Archive exists (if requested)
if [[ "$NO_ARCHIVE" != true && -n "$ARCHIVE_PATH" ]]; then
  if [[ -f "$ARCHIVE_PATH" ]]; then
    verify_check "Archive created" "pass"
  else
    verify_check "Archive created" "fail"
  fi
fi

if [[ $VERIFICATION_FAILED -eq 1 ]]; then
  echo ""
  echo "Error: One or more verification checks failed" >&2
  exit "$EXIT_VERIFICATION_FAILED"
fi

#------------------------------------------------------------------------------
# Summary
#------------------------------------------------------------------------------

echo ""
echo "=========================================="
echo "Project closed successfully!"
echo "=========================================="
echo ""
echo "  Project:  $PROJECT_TITLE"
echo "  Path:     $PROJECT_PATH"
echo ""
echo "Removed:"
echo "  - Node workspaces: ${#NODE_DIRS[@]}"
echo "  - Worktrees: $WORKTREE_COUNT"
echo "  - Tmux sessions: $SESSION_COUNT"
if [[ -n "$ARCHIVE_PATH" ]]; then
  echo ""
  echo "Archived to: $ARCHIVE_PATH"
fi
if [[ -n "$GUARDIAN_ISSUE" ]]; then
  echo "Guardian issue: $GUARDIAN_ISSUE"
fi
