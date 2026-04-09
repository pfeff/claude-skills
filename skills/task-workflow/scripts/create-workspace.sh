#!/bin/bash
#
# create-workspace.sh - Deterministic workspace bootstrapping
#
# Creates a complete development workspace with standardized structure,
# git worktrees, documentation, and tmux session.
#
# Usage:
#   create-workspace.sh --task-id ID --epic EPIC --headline "HEADLINE" \
#     [--repos REPOS] [--issue ISSUE] [--description DESC]
#
# When --issue is provided, --task-id and --headline can be omitted and will
# be derived from the GitHub issue metadata via `gh issue view`.
# Explicit flags always override derived values.
#
# Exit codes:
#   0 - Success
#   1 - Invalid arguments
#   2 - Prerequisite check failed
#   3 - Template rendering failed
#   4 - Git worktree creation failed
#   6 - Tmux session creation failed
#   7 - Verification failed
#   8 - Issue derivation failed

set -euo pipefail

# Script location for finding templates (resolve symlinks)
SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$SOURCE" ]]; do
  DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/../templates"

# Default values
TASK_ID=""
EPIC=""
HEADLINE=""
REPOS=""
ISSUE_REF=""
DESCRIPTION=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --task-id)
      TASK_ID="$2"
      shift 2
      ;;
    --epic)
      EPIC="$2"
      shift 2
      ;;
    --headline)
      HEADLINE="$2"
      shift 2
      ;;
    --repos)
      REPOS="$2"
      shift 2
      ;;
    --issue)
      ISSUE_REF="$2"
      shift 2
      ;;
    --description)
      DESCRIPTION="$2"
      shift 2
      ;;
    *)
      echo "Error: Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

#------------------------------------------------------------------------------
# Derive params from --issue when not explicitly provided
#------------------------------------------------------------------------------

if [[ -n "$ISSUE_REF" && ( -z "$TASK_ID" || -z "$HEADLINE" ) ]]; then
  # Parse issue reference: org/repo#number
  if [[ "$ISSUE_REF" =~ ^([^/]+)/([^#]+)#([0-9]+)$ ]]; then
    ISSUE_OWNER="${BASH_REMATCH[1]}"
    ISSUE_REPO="${BASH_REMATCH[2]}"
    ISSUE_NUMBER="${BASH_REMATCH[3]}"
  else
    echo "Error: Cannot parse issue reference '$ISSUE_REF'. Expected format: owner/repo#number" >&2
    exit 8
  fi

  # Check gh CLI is available
  if ! command -v gh &>/dev/null; then
    echo "Error: gh CLI is required to derive params from --issue. Install with: brew install gh" >&2
    exit 8
  fi

  # Derive task-id from issue number (explicit flag wins)
  if [[ -z "$TASK_ID" ]]; then
    TASK_ID="$ISSUE_NUMBER"
  fi

  # Derive headline from issue title via gh (explicit flag wins)
  if [[ -z "$HEADLINE" ]]; then
    HEADLINE=$(gh issue view "$ISSUE_NUMBER" --repo "$ISSUE_OWNER/$ISSUE_REPO" --json title --jq '.title' 2>&1) || {
      echo "Error: Failed to fetch issue $ISSUE_REF: $HEADLINE" >&2
      exit 8
    }
    if [[ -z "$HEADLINE" ]]; then
      echo "Error: Could not derive headline from issue $ISSUE_REF" >&2
      exit 8
    fi
  fi

  echo "Derived from issue $ISSUE_REF:"
  echo "  task-id:  $TASK_ID"
  echo "  headline: $HEADLINE"
fi

#------------------------------------------------------------------------------
# Validate required arguments
#------------------------------------------------------------------------------

if [[ -z "$TASK_ID" ]]; then
  echo "Error: --task-id is required (provide explicitly or use --issue to derive)" >&2
  exit 1
fi
if [[ -z "$EPIC" ]]; then
  echo "Error: --epic is required (provide explicitly or use agent-level derivation)" >&2
  exit 1
fi
if [[ -z "$HEADLINE" ]]; then
  echo "Error: --headline is required (provide explicitly or use --issue to derive)" >&2
  exit 1
fi

#------------------------------------------------------------------------------
# Helper functions
#------------------------------------------------------------------------------

# Generate 2-3 word slug from headline
generate_slug() {
  local headline="$1"
  echo "$headline" | tr '[:upper:]' '[:lower:]' | \
    sed 's/[^a-z0-9 ]//g' | \
    tr -s ' ' | \
    awk '{for(i=1;i<=NF && i<=3;i++) printf "%s-", $i}' | \
    sed 's/-$//'
}

# Resolve repository path
# Tries: ~/src/github/<org>/<repo>, ~/src/azdevops/<org>/<project>/<repo>
resolve_repo_path() {
  local repo_name="$1"

  # Reject names with glob or path characters
  if [[ "$repo_name" == /* && -d "$repo_name" ]]; then
    echo "$repo_name"
    return 0
  fi
  if [[ ! "$repo_name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    return 1
  fi

  # Try ~/src/github/<org>/<repo> (known structure, no find)
  local match
  for match in ~/src/github/*/"$repo_name"; do
    if [[ -d "$match" ]]; then
      echo "$match"
      return 0
    fi
  done

  # Try ~/src/azdevops/<org>/<project>/<repo> (known structure, no find)
  for match in ~/src/azdevops/*/*/"$repo_name"; do
    if [[ -d "$match" ]]; then
      echo "$match"
      return 0
    fi
  done

  return 1
}

# Generate issue URL from issue reference
generate_issue_url() {
  local issue_ref="$1"

  if [[ -z "$issue_ref" ]]; then
    echo ""
    return
  fi

  # Parse org/repo#number format
  if [[ "$issue_ref" =~ ^([^/]+)/([^#]+)#([0-9]+)$ ]]; then
    local org="${BASH_REMATCH[1]}"
    local repo="${BASH_REMATCH[2]}"
    local number="${BASH_REMATCH[3]}"
    echo "https://github.com/$org/$repo/issues/$number"
  else
    echo ""
  fi
}

# Format repos list as markdown
format_repos_list() {
  local repos="$1"
  local workspace_path="$2"

  if [[ -z "$repos" ]]; then
    echo "- (none specified)"
    return
  fi

  local IFS=','
  for repo in $repos; do
    repo=$(echo "$repo" | xargs)  # trim whitespace
    echo "- $repo: \`$workspace_path/$repo\`"
  done
}

# Verification check helper
# Usage: verify_check "Check name" "pass|fail"
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

#------------------------------------------------------------------------------
# Main workspace creation
#------------------------------------------------------------------------------

echo "Creating workspace for task $TASK_ID..."

# Generate derived values
TASK_SLUG=$(generate_slug "$HEADLINE")
WORKSPACE_PATH="$HOME/src/work/$EPIC/$TASK_ID-$TASK_SLUG"
TASK_LIST_ID="$EPIC-$TASK_ID"
SESSION_NAME="$TASK_ID: $HEADLINE"
ISSUE_URL=$(generate_issue_url "$ISSUE_REF")
REPOS_LIST=$(format_repos_list "$REPOS" "$WORKSPACE_PATH")

# Use headline as description if not provided
if [[ -z "$DESCRIPTION" ]]; then
  DESCRIPTION="$HEADLINE"
fi

echo "  Slug: $TASK_SLUG"
echo "  Path: $WORKSPACE_PATH"

#------------------------------------------------------------------------------
# Step 1: Check prerequisites
#------------------------------------------------------------------------------

echo "Checking prerequisites..."

# Check if workspace already exists
if [[ -d "$WORKSPACE_PATH" ]]; then
  echo "Error: Workspace already exists: $WORKSPACE_PATH" >&2
  echo "Delete it first or use a different task-id/epic." >&2
  exit 2
fi

# Check for required templates
for tmpl in DESIGN.md.tmpl CLAUDE.md.tmpl .envrc.tmpl settings.json.tmpl; do
  if [[ ! -f "$TEMPLATE_DIR/$tmpl" ]]; then
    echo "Error: Template not found: $TEMPLATE_DIR/$tmpl" >&2
    exit 2
  fi
done

# Check for envsubst
if ! command -v envsubst &>/dev/null; then
  echo "Error: envsubst not found. Install gettext." >&2
  exit 2
fi

# Check for tmuxp
if ! command -v tmuxp &>/dev/null; then
  echo "Error: tmuxp not found. Install with: pip install tmuxp" >&2
  exit 2
fi

# Validate repositories exist (if specified)
if [[ -n "$REPOS" ]]; then
  IFS=',' read -ra REPO_ARRAY <<< "$REPOS"
  for repo in "${REPO_ARRAY[@]}"; do
    repo=$(echo "$repo" | xargs)
    if ! resolve_repo_path "$repo" &>/dev/null; then
      echo "Error: Repository not found: $repo" >&2
      echo "Searched in ~/src/github and ~/src/azdevops" >&2
      exit 2
    fi
  done
fi

echo "  Prerequisites OK"

#------------------------------------------------------------------------------
# Step 2: Create workspace directory
#------------------------------------------------------------------------------

echo "Creating workspace directory..."
mkdir -p "$WORKSPACE_PATH"
echo "  Created: $WORKSPACE_PATH"

#------------------------------------------------------------------------------
# Step 3: Render templates
#------------------------------------------------------------------------------

echo "Rendering templates..."

# Export all variables for envsubst
export TASK_ID EPIC HEADLINE TASK_SLUG ISSUE_REF ISSUE_URL
export WORKSPACE_PATH TASK_LIST_ID SESSION_NAME DESCRIPTION REPOS_LIST

# Render DESIGN.md
if envsubst < "$TEMPLATE_DIR/DESIGN.md.tmpl" > "$WORKSPACE_PATH/DESIGN.md"; then
  echo "  DESIGN.md: created"
else
  echo "Error: Failed to render DESIGN.md" >&2
  exit 3
fi

# Render CLAUDE.md
if envsubst < "$TEMPLATE_DIR/CLAUDE.md.tmpl" > "$WORKSPACE_PATH/CLAUDE.md"; then
  echo "  CLAUDE.md: created"
else
  echo "Error: Failed to render CLAUDE.md" >&2
  exit 3
fi

# Render .envrc
if envsubst < "$TEMPLATE_DIR/.envrc.tmpl" > "$WORKSPACE_PATH/.envrc"; then
  echo "  .envrc: created"
else
  echo "Error: Failed to render .envrc" >&2
  exit 3
fi

# Copy settings.json (static template, no envsubst needed)
mkdir -p "$WORKSPACE_PATH/.claude"
if cp "$TEMPLATE_DIR/settings.json.tmpl" "$WORKSPACE_PATH/.claude/settings.json"; then
  echo "  .claude/settings.json: created"
else
  echo "Error: Failed to copy settings.json" >&2
  exit 3
fi

#------------------------------------------------------------------------------
# Step 4: Create git worktrees
#------------------------------------------------------------------------------

if [[ -n "$REPOS" ]]; then
  echo "Creating git worktrees..."

  IFS=',' read -ra REPO_ARRAY <<< "$REPOS"
  for repo in "${REPO_ARRAY[@]}"; do
    repo=$(echo "$repo" | xargs)
    repo_path=$(resolve_repo_path "$repo")
    repo_basename=$(basename "$repo_path")
    worktree_path="$WORKSPACE_PATH/$repo_basename"
    branch_name="$TASK_ID/$TASK_SLUG"

    echo "  $repo_basename:"
    echo "    Source: $repo_path"
    echo "    Worktree: $worktree_path"
    echo "    Branch: $branch_name"

    # Update main/master branch before creating worktree
    cd "$repo_path"
    default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
    git fetch origin "$default_branch" --quiet 2>/dev/null || true

    # Create worktree
    if ! git worktree add "$worktree_path" -b "$branch_name" "origin/$default_branch" 2>/dev/null; then
      # Branch might already exist, try without -b
      if ! git worktree add "$worktree_path" "$branch_name" 2>/dev/null; then
        echo "Error: Failed to create worktree for $repo" >&2
        exit 4
      fi
    fi

    # Verify worktree is on a feature branch, not the default branch
    actual_branch=$(cd "$worktree_path" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    if [[ "$actual_branch" == "$default_branch" ]]; then
      echo "    WARNING: Worktree on default branch '$default_branch', switching to feature branch..."
      if (cd "$worktree_path" && git checkout -b "$branch_name" 2>/dev/null); then
        echo "    Created and switched to branch '$branch_name'"
      elif (cd "$worktree_path" && git checkout "$branch_name" 2>/dev/null); then
        echo "    Switched to existing branch '$branch_name'"
      else
        echo "Error: Failed to switch worktree to feature branch '$branch_name'" >&2
        exit 4
      fi
    fi

    echo "    Created worktree"
  done
fi

#------------------------------------------------------------------------------
# Step 5: Create docs/solutions/ directories in repo worktrees
#------------------------------------------------------------------------------

SOLUTION_CATEGORIES="build-errors test-failures performance-issues runtime-errors integration-issues workflow-issues best-practices patterns"

if [[ -n "$REPOS" ]]; then
  echo "Creating docs/solutions/ directories..."

  IFS=',' read -ra REPO_ARRAY <<< "$REPOS"
  for repo in "${REPO_ARRAY[@]}"; do
    repo=$(echo "$repo" | xargs)
    repo_path=$(resolve_repo_path "$repo")
    repo_basename=$(basename "$repo_path")
    worktree_path="$WORKSPACE_PATH/$repo_basename"

    if [[ -d "$worktree_path" ]]; then
      for category in $SOLUTION_CATEGORIES; do
        mkdir -p "$worktree_path/docs/solutions/$category"
      done

      # Add .gitkeep to empty directories so git tracks them
      for category in $SOLUTION_CATEGORIES; do
        if [[ ! "$(ls -A "$worktree_path/docs/solutions/$category" 2>/dev/null)" ]]; then
          touch "$worktree_path/docs/solutions/$category/.gitkeep"
        fi
      done

      echo "  $repo_basename: docs/solutions/ created"
    fi
  done
else
  echo "Skipping docs/solutions/ (no repos specified)"
fi

#------------------------------------------------------------------------------
# Step 6: Run direnv allow
#------------------------------------------------------------------------------

echo "Configuring direnv..."
if command -v direnv &>/dev/null; then
  direnv allow "$WORKSPACE_PATH"
  echo "  direnv: allowed"
else
  echo "  direnv: skipped (not installed)"
fi

#------------------------------------------------------------------------------
# Step 7: Create tmux session
#------------------------------------------------------------------------------

echo "Creating tmux session..."
if "$SCRIPT_DIR/create-tmuxp-session.sh" "$SESSION_NAME" "$WORKSPACE_PATH"; then
  echo "  Tmux session created"
else
  echo "Error: Failed to create tmux session" >&2
  exit 6
fi

#------------------------------------------------------------------------------
# Step 8: Verification
#------------------------------------------------------------------------------

echo ""
echo "Running verification checks..."

SANITIZED_SESSION=$(echo "$SESSION_NAME" | sed 's/:/-/g; s/\.//g')
VERIFICATION_FAILED=0

# Check 1: Workspace directory exists
if [[ -d "$WORKSPACE_PATH" ]]; then
  verify_check "Workspace directory exists" "pass"
else
  verify_check "Workspace directory exists" "fail"
fi

# Check 2: DESIGN.md has correct first line
EXPECTED_FIRST_LINE="# $TASK_ID: $HEADLINE"
if [[ -f "$WORKSPACE_PATH/DESIGN.md" ]]; then
  ACTUAL_FIRST_LINE=$(head -1 "$WORKSPACE_PATH/DESIGN.md")
  if [[ "$ACTUAL_FIRST_LINE" == "$EXPECTED_FIRST_LINE" ]]; then
    verify_check "DESIGN.md first line format" "pass"
  else
    verify_check "DESIGN.md first line format" "fail"
  fi
else
  verify_check "DESIGN.md first line format" "fail"
fi

# Check 3: CLAUDE.md contains task details section
if [[ -f "$WORKSPACE_PATH/CLAUDE.md" ]] && grep -q "## Task Details" "$WORKSPACE_PATH/CLAUDE.md"; then
  verify_check "CLAUDE.md contains Task Details" "pass"
else
  verify_check "CLAUDE.md contains Task Details" "fail"
fi

# Check 4: .envrc contains CLAUDE_CODE_TASK_LIST_ID
if [[ -f "$WORKSPACE_PATH/.envrc" ]] && grep -q "CLAUDE_CODE_TASK_LIST_ID" "$WORKSPACE_PATH/.envrc"; then
  verify_check ".envrc contains CLAUDE_CODE_TASK_LIST_ID" "pass"
else
  verify_check ".envrc contains CLAUDE_CODE_TASK_LIST_ID" "fail"
fi

# Check 5: .claude/settings.json exists with permissions
if [[ -f "$WORKSPACE_PATH/.claude/settings.json" ]] && grep -q '"permissions"' "$WORKSPACE_PATH/.claude/settings.json"; then
  verify_check ".claude/settings.json contains permissions" "pass"
else
  verify_check ".claude/settings.json contains permissions" "fail"
fi

# Check 6: .tmuxp.yaml exists with correct session name
if [[ -f "$WORKSPACE_PATH/.tmuxp.yaml" ]] && grep -q "session_name.*$SANITIZED_SESSION" "$WORKSPACE_PATH/.tmuxp.yaml"; then
  verify_check ".tmuxp.yaml exists with correct session" "pass"
else
  verify_check ".tmuxp.yaml exists with correct session" "fail"
fi

# Check 7: Git worktrees on correct branches (if repos specified)
if [[ -n "$REPOS" ]]; then
  IFS=',' read -ra REPO_ARRAY <<< "$REPOS"
  for repo in "${REPO_ARRAY[@]}"; do
    repo=$(echo "$repo" | xargs)
    repo_path=$(resolve_repo_path "$repo")
    repo_basename=$(basename "$repo_path")
    worktree_path="$WORKSPACE_PATH/$repo_basename"
    expected_branch="$TASK_ID/$TASK_SLUG"
    if [[ -d "$worktree_path/.git" ]] || [[ -f "$worktree_path/.git" ]]; then
      actual_branch=$(cd "$worktree_path" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
      # Guard: worktree must not be on the default branch
      wt_default_branch=$(cd "$repo_path" && git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
      if [[ "$actual_branch" == "$wt_default_branch" ]]; then
        verify_check "Git worktree $repo_basename not on default branch" "fail"
      elif [[ "$actual_branch" == "$expected_branch" ]]; then
        verify_check "Git worktree $repo_basename on correct branch" "pass"
      else
        verify_check "Git worktree $repo_basename on correct branch" "fail"
      fi
    else
      verify_check "Git worktree $repo_basename exists" "fail"
    fi
  done
fi

# Check 8: Tmux session running
if tmux has-session -t "$SANITIZED_SESSION" 2>/dev/null; then
  verify_check "Tmux session running" "pass"
else
  verify_check "Tmux session running" "fail"
fi

# Check 9: direnv allowed
if command -v direnv &>/dev/null; then
  if direnv status 2>/dev/null | grep -q "Found RC allowed true" || [[ -f "$WORKSPACE_PATH/.direnv" ]] || direnv allow "$WORKSPACE_PATH" 2>/dev/null; then
    verify_check "direnv allowed" "pass"
  else
    verify_check "direnv allowed" "fail"
  fi
else
  verify_check "direnv allowed (skipped - not installed)" "pass"
fi

if [[ $VERIFICATION_FAILED -eq 1 ]]; then
  echo ""
  echo "Error: One or more verification checks failed" >&2
  exit 7
fi

echo ""
echo "All verification checks passed!"

#------------------------------------------------------------------------------
# Summary
#------------------------------------------------------------------------------

echo ""
echo "=========================================="
echo "Workspace created successfully!"
echo "=========================================="
echo ""
echo "  Path:         $WORKSPACE_PATH"
echo "  Task List ID: $TASK_LIST_ID"
echo "  Tmux Session: $(echo "$SESSION_NAME" | sed 's/:/-/g; s/\.//g')"
echo ""
echo "Files created:"
echo "  - DESIGN.md"
echo "  - CLAUDE.md"
echo "  - .envrc"
echo "  - .claude/settings.json"
if [[ -n "$REPOS" ]]; then
  echo ""
  echo "Git worktrees:"
  IFS=',' read -ra REPO_ARRAY <<< "$REPOS"
  for repo in "${REPO_ARRAY[@]}"; do
    repo=$(echo "$repo" | xargs)
    repo_path=$(resolve_repo_path "$repo")
    repo_basename=$(basename "$repo_path")
    echo "  - $repo_basename (branch: $TASK_ID/$TASK_SLUG)"
  done
fi
echo ""
echo "Next steps:"
echo "  tmux attach -t \"$(echo "$SESSION_NAME" | sed 's/:/-/g; s/\.//g')\""
