#!/bin/bash
#
# create-workspace.sh - Deterministic workspace bootstrapping
#
# Creates a complete development workspace with standardized structure,
# git worktrees, documentation, and tmux session.
#
# Usage:
#   create-workspace.sh --task-id ID --epic EPIC --headline "HEADLINE" \
#     [--repos REPOS] [--model ALIAS] [--issue ISSUE] [--description DESC]
#
# When --issue is provided, --task-id and --headline can be omitted and will
# be derived from the GitHub issue metadata via `gh issue view`.
# Explicit flags always override derived values.
#
# --model ALIAS   Claude model alias for the workspace session (e.g. opus,
#                 sonnet, haiku, or full model IDs). Defaults to "sonnet" when
#                 omitted.
#
# Exit codes:
#   0 - Success
#   1 - Invalid arguments
#   2 - Prerequisite check failed
#   3 - Template rendering failed
#   4 - Git worktree creation failed
#   5 - Secret fetching failed
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
MODEL=""
ISSUE_REF=""
DESCRIPTION=""

# Node mode values
MODE=""
NODE_ID=""
NODE_DB_ID=""
PROJECT_DIR=""
PROJECT_BRANCH=""

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
    --model)
      MODEL="$2"
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
    --node)
      MODE="node"
      shift
      ;;
    --node-id)
      NODE_ID="$2"
      shift 2
      ;;
    --node-db-id)
      NODE_DB_ID="$2"
      shift 2
      ;;
    --project-dir)
      PROJECT_DIR="$2"
      shift 2
      ;;
    --project-branch)
      PROJECT_BRANCH="$2"
      shift 2
      ;;
    *)
      echo "Error: Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# Set default mode
MODE="${MODE:-task}"

#------------------------------------------------------------------------------
# Validate arguments based on mode
#------------------------------------------------------------------------------

if [[ "$MODE" == "node" ]]; then
  # Node mode validation
  if [[ -z "$NODE_ID" ]]; then
    echo "Error: --node-id is required for node mode" >&2
    exit 1
  fi
  if [[ -z "$PROJECT_DIR" || ! -d "$PROJECT_DIR" ]]; then
    echo "Error: --project-dir must be an existing directory" >&2
    exit 1
  fi
  if [[ ! -f "$PROJECT_DIR/CLAUDE.md" ]]; then
    echo "Error: Project directory must contain CLAUDE.md" >&2
    exit 1
  fi
  if [[ -z "$REPOS" ]]; then
    echo "Error: --repos is required for node mode" >&2
    exit 1
  fi
  if [[ -z "$HEADLINE" ]]; then
    HEADLINE="Node $NODE_ID"
  fi
else
  # Task mode validation
  # Derive params from --issue when not explicitly provided
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

  # Validate required arguments for task mode
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
fi

#------------------------------------------------------------------------------
# Helper functions
#------------------------------------------------------------------------------

# Generate 2-3 word slug from headline, filtering common stop words.
# Falls back to the raw first-3 tokens if every token is a stop word, so the
# slug is never empty for a non-empty headline.
generate_slug() {
  local headline="$1"
  local stopwords="update the that to a an and or for of with in on at from"
  echo "$headline" | tr '[:upper:]' '[:lower:]' | \
    sed 's/[^a-z0-9 ]//g' | \
    tr -s ' ' | \
    awk -v stop="$stopwords" '
      BEGIN {
        n = split(stop, arr, " ")
        for (i = 1; i <= n; i++) sw[arr[i]] = 1
      }
      {
        picked = 0
        for (i = 1; i <= NF && picked < 3; i++) {
          word = $i
          if (!(word in sw)) {
            printf "%s-", word
            picked++
          }
        }
        if (picked == 0) {
          for (i = 1; i <= NF && i <= 3; i++) printf "%s-", $i
        }
      }
    ' | \
    sed 's/-$//'
}

# Resolve repository path.
#
# Accepts:
#   - Absolute path to an existing directory.
#   - Owner-qualified `owner/repo` form — resolves to ~/src/github/<owner>/<repo>
#     only; never falls back to the unqualified globs. Callers that know which
#     owner they want (e.g. derived from an issue reference) should pass this
#     form to avoid ambiguity when a repo name exists under multiple owners.
#   - Bare repo name — globs ~/src/github/*/<repo>, then ~/src/azdevops/*/*/<repo>.
#     Glob ordering is alphabetical; if the same repo name exists under more
#     than one owner, the result is whichever comes first. Use the qualified
#     form to disambiguate.
resolve_repo_path() {
  local repo_name="$1"

  if [[ "$repo_name" == /* && -d "$repo_name" ]]; then
    echo "$repo_name"
    return 0
  fi

  if [[ "$repo_name" =~ ^([a-zA-Z0-9._-]+)/([a-zA-Z0-9._-]+)$ ]]; then
    local owner="${BASH_REMATCH[1]}"
    local repo="${BASH_REMATCH[2]}"
    # Reject path-traversal segments. The regex above permits `.` because dots
    # are valid in repo names (e.g. `repo.go`), but `.`, `..`, or any segment
    # containing `..` would escape `$HOME/src/github` via path traversal.
    if [[ "$owner" == . || "$owner" == .. || "$owner" == *..* ]]; then return 1; fi
    if [[ "$repo"  == . || "$repo"  == .. || "$repo"  == *..* ]]; then return 1; fi
    local qualified="$HOME/src/github/$owner/$repo"
    if [[ -d "$qualified" ]]; then
      echo "$qualified"
      return 0
    fi
    return 1
  fi

  if [[ ! "$repo_name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    return 1
  fi
  if [[ "$repo_name" == . || "$repo_name" == .. || "$repo_name" == *..* ]]; then
    return 1
  fi

  local match
  for match in ~/src/github/*/"$repo_name"; do
    if [[ -d "$match" ]]; then
      echo "$match"
      return 0
    fi
  done

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

# Format repos list as markdown.
# When given owner-qualified names like `pfeff/claude-skills`, the displayed
# label keeps the qualifier (informative) but the path uses the basename to
# match where the worktree actually lands (`create_task_workspace` builds
# `worktree_path` from `basename "$repo_path"`).
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
    local repo_path
    repo_path=$(resolve_repo_path "$repo" 2>/dev/null || echo "$repo")
    local repo_basename
    repo_basename=$(basename "$repo_path")
    echo "- $repo_basename: \`$workspace_path/$repo_basename\`"
  done
}

# Detect organization context.
# Config-driven (host-agnostic): set WORKSPACE_ORG in the environment or your
# per-host config (~/.claude/hosts/<hostname>.md) to a work-org identifier on
# machines that need org-specific workspace setup. Defaults to "personal".
# Returns: org identifier (e.g., a work-org slug, or "personal")
detect_org() {
  echo "${WORKSPACE_ORG:-personal}"
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
# install_worktree_branch_hook - Install pre-commit guard for worktree-branch
# alignment (REC-001). Idempotent: re-running will not append duplicates.
# Usage: install_worktree_branch_hook <worktree_path>
#------------------------------------------------------------------------------

install_worktree_branch_hook() {
  local worktree_path="$1"
  local actual_git hooks_dir hook_file assert_script

  # Resolve the hooks directory. For git worktrees, .git is a file
  # "gitdir: <path>" pointing to <main>/.git/worktrees/<name>. Git reads
  # hooks from <main>/.git/hooks/, NOT from <main>/.git/worktrees/<name>/hooks/,
  # so walk up two levels from the resolved gitdir.
  if [[ -f "$worktree_path/.git" ]]; then
    actual_git=$(awk '/^gitdir:/{print $2}' "$worktree_path/.git")
    if [[ "$actual_git" != /* ]]; then
      actual_git="$worktree_path/$actual_git"
    fi
    hooks_dir="$(dirname "$(dirname "$actual_git")")/hooks"
  elif [[ -d "$worktree_path/.git/hooks" ]]; then
    hooks_dir="$worktree_path/.git/hooks"
  else
    return 0  # No .git found; silently skip
  fi

  mkdir -p "$hooks_dir"
  hook_file="$hooks_dir/pre-commit"
  assert_script="$SCRIPT_DIR/assert-worktree-branch.sh"

  if [[ ! -x "$assert_script" ]]; then
    echo "    WARNING: assert-worktree-branch.sh not found at $assert_script; skipping hook install" >&2
    return 0
  fi

  if [[ -f "$hook_file" ]]; then
    # Append only if not already present (idempotent)
    if ! grep -qF "$assert_script" "$hook_file"; then
      {
        echo ""
        echo "# worktree-branch alignment check (task-workflow REC-001)"
        echo "\"$assert_script\""
      } >> "$hook_file"
    fi
  else
    {
      echo "#!/bin/bash"
      echo "# Auto-installed by create-workspace.sh (task-workflow REC-001)"
      echo "\"$assert_script\""
    } > "$hook_file"
    chmod +x "$hook_file"
  fi
  echo "    Installed pre-commit hook (assert-worktree-branch)"
}

#------------------------------------------------------------------------------
# create_task_workspace - Create a task workspace (original behavior)
#------------------------------------------------------------------------------

create_task_workspace() {

echo "Creating workspace for task $TASK_ID..."

# Generate derived values
TASK_SLUG=$(generate_slug "$HEADLINE")
WORKSPACE_PATH="$HOME/src/work/$EPIC/$TASK_ID-$TASK_SLUG"
TASK_LIST_ID="$EPIC-$TASK_ID"
SESSION_NAME="$TASK_ID: $HEADLINE"
ISSUE_URL=$(generate_issue_url "$ISSUE_REF")
REPOS_LIST=$(format_repos_list "$REPOS" "$WORKSPACE_PATH")
ORG_CONTEXT=$(detect_org)

# Use headline as description if not provided
if [[ -z "$DESCRIPTION" ]]; then
  DESCRIPTION="$HEADLINE"
fi

echo "  Slug: $TASK_SLUG"
echo "  Path: $WORKSPACE_PATH"
echo "  Org:  $ORG_CONTEXT"

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
# Step 2: Fetch secrets (epic-specific)
#------------------------------------------------------------------------------

# Secret configuration by epic
# Format: epic|secret_type|source|identifier
# Sources: 1password, aws-secrets-manager
# Add new epics here as needed
# Example rows use the placeholder epic "work-org"; replace with your epic name.
SECRETS_CONFIG="
work-org|AZURE_PAT|1password|Azure CLI PAT
work-org|OCTOPUS_API_KEY|aws-secrets-manager|devops-sso:DevExtTFEnv/octopus/api_key
"

# Initialize secret variables (referenced indirectly via ${!secret_var})
# shellcheck disable=SC2034
AZURE_PAT=""
# shellcheck disable=SC2034
OCTOPUS_API_KEY=""

# Fetch secrets for current epic
fetch_secret() {
  local secret_type="$1"
  local source="$2"
  local identifier="$3"

  case "$source" in
    1password)
      if command -v op &>/dev/null; then
        if value=$(op item get "$identifier" --fields password --reveal 2>/dev/null); then
          echo "$value"
          return 0
        fi
      fi
      ;;
    aws-secrets-manager)
      local profile="${identifier%%:*}"
      local secret_id="${identifier#*:}"
      if command -v aws &>/dev/null; then
        if AWS_PROFILE="$profile" aws sts get-caller-identity &>/dev/null 2>&1; then
          if value=$(AWS_PROFILE="$profile" aws secretsmanager get-secret-value \
            --secret-id "$secret_id" --query SecretString --output text 2>/dev/null); then
            echo "$value"
            return 0
          fi
        fi
      fi
      ;;
  esac
  return 1
}

echo "Fetching secrets for epic '$EPIC'..."

while IFS='|' read -r cfg_epic secret_type source identifier; do
  # Skip empty lines and trim whitespace
  cfg_epic=$(echo "$cfg_epic" | xargs)
  [[ -z "$cfg_epic" ]] && continue

  # Only process secrets for current epic
  if [[ "$cfg_epic" == "$EPIC" ]]; then
    if value=$(fetch_secret "$secret_type" "$source" "$identifier"); then
      export "$secret_type=$value"
      echo "  $secret_type: retrieved"
    else
      echo "  $secret_type: not available"
    fi
  fi
done <<< "$SECRETS_CONFIG"

# Check if any secrets were configured for this epic
if ! echo "$SECRETS_CONFIG" | grep -q "^$EPIC|"; then
  echo "  No secrets configured for epic '$EPIC'"
fi

#------------------------------------------------------------------------------
# Step 3: Create workspace directory
#------------------------------------------------------------------------------

echo "Creating workspace directory..."
mkdir -p "$WORKSPACE_PATH"
echo "  Created: $WORKSPACE_PATH"

#------------------------------------------------------------------------------
# Step 4: Render templates
#------------------------------------------------------------------------------

echo "Rendering templates..."

# Export all variables for envsubst
export TASK_ID EPIC HEADLINE TASK_SLUG ISSUE_REF ISSUE_URL
export WORKSPACE_PATH TASK_LIST_ID SESSION_NAME DESCRIPTION REPOS_LIST
# Secret variables exported above if configured for this epic

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

# Render settings.json (envsubst for MODEL variable)
MODEL="${MODEL:-sonnet}"
mkdir -p "$WORKSPACE_PATH/.claude"
if envsubst < "$TEMPLATE_DIR/settings.json.tmpl" > "$WORKSPACE_PATH/.claude/settings.json"; then
  echo "  .claude/settings.json: created"
else
  echo "Error: Failed to render settings.json" >&2
  exit 3
fi

# Append org-specific .envrc content (any non-personal work-org)
if [[ -n "$ORG_CONTEXT" && "$ORG_CONTEXT" != "personal" ]]; then
  {
    echo ""
    echo "# Organization-specific configuration ($ORG_CONTEXT)"
    echo "layout python3"
  } >> "$WORKSPACE_PATH/.envrc"
  echo "  .envrc: appended $ORG_CONTEXT org config"
fi

# Append epic-specific environment variables to .envrc
# Environment variable configuration by epic
# Format: epic|env_var|value_source
# value_source: secret:VAR_NAME (use fetched secret) or literal:value
# Example rows use the placeholder epic "work-org"; replace with your epic name.
ENVRC_CONFIG="
work-org|TF_VAR_azure_devops_pat|secret:AZURE_PAT
work-org|AZURE_DEVOPS_EXT_PAT|secret:AZURE_PAT
work-org|OCTOPUS_API_KEY|secret:OCTOPUS_API_KEY
work-org|OCTOPUS_SERVER|literal:https://deploy.example.octopus.app
"

has_epic_config=false
while IFS='|' read -r cfg_epic env_var value_source; do
  cfg_epic=$(echo "$cfg_epic" | xargs)
  [[ -z "$cfg_epic" ]] && continue

  if [[ "$cfg_epic" == "$EPIC" ]]; then
    if [[ "$has_epic_config" == "false" ]]; then
      echo "" >> "$WORKSPACE_PATH/.envrc"
      echo "# Epic-specific configuration ($EPIC)" >> "$WORKSPACE_PATH/.envrc"
      has_epic_config=true
    fi

    case "$value_source" in
      secret:*)
        secret_var="${value_source#secret:}"
        value="${!secret_var}"
        ;;
      literal:*)
        value="${value_source#literal:}"
        ;;
    esac

    echo "export $env_var=\"$value\"" >> "$WORKSPACE_PATH/.envrc"
  fi
done <<< "$ENVRC_CONFIG"

#------------------------------------------------------------------------------
# Step 5: Create git worktrees
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
        # Local-only repo (no origin): create new branch from current HEAD
        if ! git worktree add "$worktree_path" -b "$branch_name" 2>/dev/null; then
          echo "Error: Failed to create worktree for $repo" >&2
          exit 4
        fi
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

    # Install pre-commit hook for worktree-branch alignment (REC-001)
    install_worktree_branch_hook "$worktree_path"
  done
fi

#------------------------------------------------------------------------------
# Step 6: (removed) docs/solutions/ scaffold — retrieval now lives in QMD over
# the Obsidian vault (DD4). Repo-local solution trees are no longer a retrieval
# surface and scaffolding empty subdirectories just attracts drift.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Step 7: Run direnv allow
#------------------------------------------------------------------------------

echo "Configuring direnv..."
if command -v direnv &>/dev/null; then
  direnv allow "$WORKSPACE_PATH"
  echo "  direnv: allowed"
else
  echo "  direnv: skipped (not installed)"
fi

#------------------------------------------------------------------------------
# Step 8: Create tmux session
#------------------------------------------------------------------------------

echo "Creating tmux session..."
if "$SCRIPT_DIR/create-tmuxp-session.sh" "$SESSION_NAME" "$WORKSPACE_PATH"; then
  echo "  Tmux session created"
else
  echo "Error: Failed to create tmux session" >&2
  exit 6
fi

#------------------------------------------------------------------------------
# Step 9: Verification
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

# Check 5: .claude/settings.json exists with permissions and model
if [[ -f "$WORKSPACE_PATH/.claude/settings.json" ]] && grep -q '"permissions"' "$WORKSPACE_PATH/.claude/settings.json" && grep -q '"model"' "$WORKSPACE_PATH/.claude/settings.json"; then
  verify_check ".claude/settings.json contains permissions and model" "pass"
else
  verify_check ".claude/settings.json contains permissions and model" "fail"
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
  # Check if .envrc is in direnv's allow list
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
}

#------------------------------------------------------------------------------
# create_node_workspace - Create a node workspace within a goal-tree project
#------------------------------------------------------------------------------

create_node_workspace() {
  echo "Creating node workspace for $NODE_ID..."

  # Derive paths
  NODE_SLUG=$(generate_slug "$HEADLINE")
  WORKSPACE_PATH="$PROJECT_DIR/$NODE_ID-$NODE_SLUG"

  # Extract project branch from project .envrc or use provided value
  if [[ -z "$PROJECT_BRANCH" ]]; then
    PROJECT_BRANCH=$(grep -oP 'PROJECT_BRANCH="\K[^"]+' "$PROJECT_DIR/.envrc" 2>/dev/null || echo "")
    if [[ -z "$PROJECT_BRANCH" ]]; then
      # Fallback: derive from project dir name
      PROJECT_BRANCH="$(basename "$PROJECT_DIR")/mbp/integration"
    fi
  fi

  # Strip "-main" integration-branch suffix when composing the node-branch prefix.
  # Projects whose parent branch ends in "-main" (e.g. loop-optimizer-main) use a "-"
  # for the integration branch but a "/" namespace for nodes (loop-optimizer/<node>),
  # because git refuses both a leaf branch <X> and a directory <X>/<Y>. Without the
  # strip, the node branch (loop-optimizer-main/<node>) collides with the leaf.
  NODE_BRANCH="${PROJECT_BRANCH%-main}/$NODE_ID"

  echo "  Path: $WORKSPACE_PATH"
  echo "  Branch: $NODE_BRANCH"

  # Step 1: Check if workspace already exists
  if [[ -d "$WORKSPACE_PATH" ]]; then
    echo "Error: Node workspace already exists: $WORKSPACE_PATH" >&2
    exit 2
  fi

  # Validate repositories exist
  IFS=',' read -ra REPO_ARRAY <<< "$REPOS"
  for repo in "${REPO_ARRAY[@]}"; do
    repo=$(echo "$repo" | xargs)
    if ! resolve_repo_path "$repo" &>/dev/null; then
      echo "Error: Repository not found: $repo" >&2
      echo "Searched in ~/src/github and ~/src/azdevops" >&2
      exit 2
    fi
  done

  # Step 2: Create workspace directory
  mkdir -p "$WORKSPACE_PATH"

  # Step 3: Render NODE_CLAUDE.md template
  export NODE_ID HEADLINE PROJECT_DIR PROJECT_BRANCH NODE_BRANCH
  export WORKSPACE_PATH
  PROJECT_SLUG="$(basename "$PROJECT_DIR")"
  export PROJECT_SLUG
  REPOS_LIST=$(format_repos_list "$REPOS" "$WORKSPACE_PATH")
  export REPOS_LIST

  if envsubst < "$TEMPLATE_DIR/NODE_CLAUDE.md.tmpl" > "$WORKSPACE_PATH/CLAUDE.md"; then
    echo "  CLAUDE.md: created"
  else
    echo "Error: Failed to render CLAUDE.md" >&2
    exit 3
  fi

  # Step 3b: Render NODE_DESIGN.md template
  if envsubst < "$TEMPLATE_DIR/NODE_DESIGN.md.tmpl" > "$WORKSPACE_PATH/DESIGN.md"; then
    echo "  DESIGN.md: created"
  else
    echo "Error: Failed to render DESIGN.md" >&2
    exit 3
  fi

  # Step 4: Create .envrc that sources parent
  # Generate unique task list ID so child doesn't clobber parent's task list
  CHILD_TASK_LIST_ID="$(uuidgen | tr '[:upper:]' '[:lower:]')"
  COORD_LINE=""
  [[ -n "$NODE_DB_ID" ]] && COORD_LINE="export COORDINATOR_TASK_ID=\"$NODE_DB_ID\""
  cat > "$WORKSPACE_PATH/.envrc" << EOF
# Node workspace - inherits from project
source_up

# Override parent task list — each workspace gets its own
export CLAUDE_CODE_TASK_LIST_ID="$CHILD_TASK_LIST_ID"
export NODE_ID="$NODE_ID"
export NODE_BRANCH="$NODE_BRANCH"
$COORD_LINE
EOF
  echo "  .envrc: created"

  # Step 5: Create git worktrees
  echo "Creating git worktrees..."
  for repo in "${REPO_ARRAY[@]}"; do
    repo=$(echo "$repo" | xargs)
    repo_path=$(resolve_repo_path "$repo")
    repo_basename=$(basename "$repo_path")
    worktree_path="$WORKSPACE_PATH/$repo_basename"

    echo "  $repo_basename:"
    echo "    Source: $repo_path"
    echo "    Worktree: $worktree_path"
    echo "    Branch: $NODE_BRANCH"

    cd "$repo_path"
    default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
    git fetch origin "$default_branch" --quiet 2>/dev/null || true

    if ! git worktree add "$worktree_path" -b "$NODE_BRANCH" "origin/$default_branch" 2>/dev/null; then
      # Branch might already exist
      if ! git worktree add "$worktree_path" "$NODE_BRANCH" 2>/dev/null; then
        # Local-only repo (no origin): create new branch from current HEAD
        if ! git worktree add "$worktree_path" -b "$NODE_BRANCH" 2>/dev/null; then
          echo "Error: Failed to create worktree for $repo_basename" >&2
          exit 4
        fi
      fi
    fi
    echo "    Created worktree"

    # Install pre-commit hook for worktree-branch alignment (REC-001)
    install_worktree_branch_hook "$worktree_path"
  done

  # Step 6: Render .claude/settings.json (envsubst for MODEL variable)
  echo "Rendering settings..."
  MODEL="${MODEL:-sonnet}"
  mkdir -p "$WORKSPACE_PATH/.claude"
  if envsubst < "$TEMPLATE_DIR/settings.json.tmpl" > "$WORKSPACE_PATH/.claude/settings.json"; then
    echo "  .claude/settings.json: created"
  else
    echo "  .claude/settings.json: failed (non-fatal)" >&2
  fi

  # Step 7: Configure child session auth (GitHub App)
  AUTH_SCRIPT="$HOME/.claude/skills/goal-tree/scripts/configure-child-auth.sh"
  if [[ -x "$AUTH_SCRIPT" ]]; then
    echo "Configuring child session auth..."
    IFS=',' read -ra AUTH_REPOS <<< "$REPOS"
    TRIMMED_REPOS=()
    for r in "${AUTH_REPOS[@]}"; do
      TRIMMED_REPOS+=("$(echo "$r" | xargs)")
    done
    "$AUTH_SCRIPT" "$WORKSPACE_PATH" "${TRIMMED_REPOS[@]}"
  else
    echo "  Warning: configure-child-auth.sh not found, skipping app auth" >&2
  fi

  # Step 8: Run direnv allow
  if command -v direnv &>/dev/null; then
    direnv allow "$WORKSPACE_PATH"
    echo "  direnv: allowed"
  fi

  # Step 9: Create tmux session (identical to task mode)
  SESSION_NAME="$NODE_ID: $HEADLINE"
  SANITIZED_SESSION=$(echo "$SESSION_NAME" | sed 's/:/-/g; s/\.//g')
  echo "Creating tmux session..."
  if "$SCRIPT_DIR/create-tmuxp-session.sh" "$SESSION_NAME" "$WORKSPACE_PATH"; then
    echo "  Tmux session created: $SANITIZED_SESSION"
  else
    echo "Error: Failed to create tmux session" >&2
    exit 6
  fi

  # Step 10: Verification
  echo ""
  echo "Running verification checks..."
  VERIFICATION_FAILED=0

  if [[ -d "$WORKSPACE_PATH" ]]; then verify_check "Workspace directory exists" "pass"; else verify_check "Workspace directory exists" "fail"; fi
  if [[ -f "$WORKSPACE_PATH/CLAUDE.md" ]]; then verify_check "CLAUDE.md exists" "pass"; else verify_check "CLAUDE.md exists" "fail"; fi
  if [[ -f "$WORKSPACE_PATH/DESIGN.md" ]]; then verify_check "DESIGN.md exists" "pass"; else verify_check "DESIGN.md exists" "fail"; fi
  if [[ -f "$WORKSPACE_PATH/.envrc" ]]; then verify_check ".envrc exists" "pass"; else verify_check ".envrc exists" "fail"; fi
  if [[ -f "$WORKSPACE_PATH/.claude/settings.json" ]]; then verify_check ".claude/settings.json exists" "pass"; else verify_check ".claude/settings.json exists" "fail"; fi

  # Check worktrees
  for repo in "${REPO_ARRAY[@]}"; do
    repo=$(echo "$repo" | xargs)
    repo_path=$(resolve_repo_path "$repo")
    repo_basename=$(basename "$repo_path")
    worktree_path="$WORKSPACE_PATH/$repo_basename"
    if [[ -d "$worktree_path/.git" ]] || [[ -f "$worktree_path/.git" ]]; then
      actual_branch=$(cd "$worktree_path" && git rev-parse --abbrev-ref HEAD)
      if [[ "$actual_branch" == "$NODE_BRANCH" ]]; then
        verify_check "Worktree $repo_basename on correct branch" "pass"
      else
        verify_check "Worktree $repo_basename on correct branch ($actual_branch != $NODE_BRANCH)" "fail"
      fi
    else
      verify_check "Worktree $repo_basename exists" "fail"
    fi
  done

  # Check tmux session
  if tmux has-session -t "$SANITIZED_SESSION" 2>/dev/null; then
    verify_check "Tmux session running" "pass"
  else
    verify_check "Tmux session running" "fail"
  fi

  # Check .tmuxp.yaml
  if [[ -f "$WORKSPACE_PATH/.tmuxp.yaml" ]]; then
    verify_check ".tmuxp.yaml exists" "pass"
  else
    verify_check ".tmuxp.yaml exists" "fail"
  fi

  if [[ $VERIFICATION_FAILED -eq 1 ]]; then
    echo ""
    echo "Error: One or more verification checks failed" >&2
    exit 7
  fi

  echo ""
  echo "All verification checks passed!"

  # Summary
  echo ""
  echo "=========================================="
  echo "Node workspace created successfully!"
  echo "=========================================="
  echo ""
  echo "  Path:         $WORKSPACE_PATH"
  echo "  Branch:       $NODE_BRANCH"
  echo "  Tmux Session: $SANITIZED_SESSION"
  echo ""
  echo "Next steps:"
  echo "  tmux attach -t \"$SANITIZED_SESSION\""
  echo ""
}

#------------------------------------------------------------------------------
# Mode dispatcher
#------------------------------------------------------------------------------

# Skip the dispatcher when sourced (e.g. by test-create-workspace.sh), so the
# helper functions above can be exercised without creating a real workspace.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "$MODE" in
    task) create_task_workspace ;;
    node) create_node_workspace ;;
  esac
fi
