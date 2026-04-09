#!/usr/bin/env bash
# Dispatch a goal-tree node to Ralph's container for L0 execution.
#
# Translates DESIGN.md → Ralph workspace, invokes run-container.sh,
# parses result into goal-tree dispatch_result format.
#
# Usage: dispatch-container.sh <node-workspace-path> [--dry-run]
#
# Prerequisites:
#   - Node workspace exists with DESIGN.md populated
#   - Docker is running
#   - Ralph infrastructure at RALPH_DIR (default: ~/src/github/pfeff/cursor-rules/scripts/ralph)
#
# Output: dispatch_result JSON to stdout

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RALPH_DIR="${RALPH_DIR:-$HOME/src/github/pfeff/cursor-rules/scripts/ralph}"
RALPH_SKILL_DIR="${RALPH_SKILL_DIR:-$HOME/src/github/pfeff/cursor-rules/skills/ralph-wiggum}"
NODE_WORKSPACE="${1:?Usage: dispatch-container.sh <node-workspace-path> [--dry-run]}"
DRY_RUN=false

# Parse optional flags
shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Resolve to absolute path
NODE_WORKSPACE="$(cd "$NODE_WORKSPACE" && pwd)"

# --- Validation ---

if [[ ! -f "$NODE_WORKSPACE/DESIGN.md" ]]; then
  echo "Error: DESIGN.md not found in $NODE_WORKSPACE" >&2
  exit 1
fi

if [[ ! -f "$RALPH_DIR/run-container.sh" ]]; then
  echo "Error: run-container.sh not found at $RALPH_DIR" >&2
  echo "Set RALPH_DIR to the Ralph scripts directory" >&2
  exit 1
fi

# Docker validation deferred until after dry-run check (dry-run doesn't need Docker)

# --- Parse DESIGN.md ---

extract_section() {
  # Extract a markdown section by heading (## Heading)
  # Returns content between the heading and the next ## heading (or EOF)
  local file="$1"
  local heading="$2"
  awk -v h="$heading" '
    BEGIN { found=0 }
    /^## / {
      if (found) exit
      if ($0 ~ "^## " h) { found=1; next }
    }
    found { print }
  ' "$file"
}

extract_field() {
  # Extract a field value from "- **Field**: value" format
  # Uses sed instead of grep -P for macOS compatibility
  local file="$1"
  local field="$2"
  sed -n "s/^- \*\*${field}\*\*: *//p" "$file" 2>/dev/null | head -1
}

DESIGN="$NODE_WORKSPACE/DESIGN.md"
NODE_ID=$(extract_field "$DESIGN" "Node ID")
NODE_TITLE=$(head -1 "$DESIGN" | sed 's/^# //' | sed "s/^${NODE_ID}: //" )
PROJECT_BRANCH=$(extract_field "$DESIGN" "Branch")
REQUIREMENTS=$(extract_section "$DESIGN" "Requirements")
ACCEPTANCE_CRITERIA=$(extract_section "$DESIGN" "Acceptance Criteria")
DESIGN_DECISIONS=$(extract_section "$DESIGN" "Key Design Decisions")
PROJECT_CONTEXT=$(extract_section "$DESIGN" "Project Context")
PARENT_GOAL=$(echo "$PROJECT_CONTEXT" | sed -n 's/^- \*\*Parent goal\*\*: *//p' 2>/dev/null | head -1)
ROOT_OBJECTIVE=$(echo "$PROJECT_CONTEXT" | sed -n 's/^- \*\*Root objective\*\*: *//p' 2>/dev/null | head -1)

echo "Dispatching node $NODE_ID to container..."
echo "  Title: $NODE_TITLE"
echo "  Workspace: $NODE_WORKSPACE"

# --- Detect repos in workspace ---

# Repos are subdirectories with .git (file or directory)
REPOS=()
REPO_NAMES=()
for dir in "$NODE_WORKSPACE"/*/; do
  if [[ -e "$dir/.git" ]]; then
    repo_name=$(basename "$dir")
    REPOS+=("$dir")
    REPO_NAMES+=("$repo_name")
  fi
done

if [[ ${#REPOS[@]} -eq 0 ]]; then
  echo "Error: No git repos found in $NODE_WORKSPACE" >&2
  exit 1
fi

echo "  Repos: ${REPO_NAMES[*]}"
MULTI_REPO=false
if [[ ${#REPOS[@]} -gt 1 ]]; then
  MULTI_REPO=true
fi

# --- Set up Ralph workspace structure ---

# Create specs/ with task.md
mkdir -p "$NODE_WORKSPACE/specs"

cat > "$NODE_WORKSPACE/specs/task.md" <<SPEC
# ${NODE_ID}: ${NODE_TITLE}

## Requirements

${REQUIREMENTS}

## Acceptance Criteria

${ACCEPTANCE_CRITERIA}

## Context

- **Project**: ${ROOT_OBJECTIVE:-Autoresearch Loop Formalization}
- **Parent**: ${PARENT_GOAL:-unknown}
- **Branch**: ${PROJECT_BRANCH:-unknown}
SPEC

# Append design decisions if present
if [[ -n "$DESIGN_DECISIONS" ]]; then
  cat >> "$NODE_WORKSPACE/specs/task.md" <<DECISIONS

## Design Decisions

${DESIGN_DECISIONS}
DECISIONS
fi

echo "  Created: specs/task.md"

# --- Copy PROMPT files ---

for prompt_file in PROMPT_plan.md PROMPT_build.md; do
  if [[ ! -f "$NODE_WORKSPACE/$prompt_file" ]]; then
    cp "$RALPH_SKILL_DIR/$prompt_file" "$NODE_WORKSPACE/$prompt_file"
    echo "  Copied: $prompt_file"
  else
    echo "  Skipped: $prompt_file (exists)"
  fi
done

# --- Generate gates.md from Taskfile ---

generate_gates() {
  local repo_path="$1"
  local repo_name
  repo_name=$(basename "$repo_path")
  local gates_dir="$repo_path/.ralph"
  mkdir -p "$gates_dir"

  if [[ -f "$repo_path/Taskfile.yml" ]] || [[ -f "$repo_path/Taskfile.yaml" ]]; then
    # Read targets from Taskfile
    local test_cmd="" lint_cmd="" build_cmd="" typecheck_cmd=""

    # Check which standard targets exist (suppress stdout from --dry)
    if (cd "$repo_path" && task test --dry >/dev/null 2>&1); then
      test_cmd="task test"
    fi
    if (cd "$repo_path" && task lint --dry >/dev/null 2>&1); then
      lint_cmd="task lint"
    fi
    if (cd "$repo_path" && task build --dry >/dev/null 2>&1); then
      build_cmd="task build"
    fi
    if (cd "$repo_path" && task typecheck --dry >/dev/null 2>&1); then
      typecheck_cmd="task typecheck"
    fi

    cat > "$gates_dir/gates.md" <<GATES
# Gates

Project-specific commands for the Ralph Wiggum autonomous build loop.

## Commands

| Gate | Command |
|------|---------|
| lint | \`${lint_cmd}\` |
| typecheck | \`${typecheck_cmd}\` |
| test | \`${test_cmd}\` |
| build | \`${build_cmd}\` |

Run gates in order: lint → typecheck → test → build. Skip gates with empty commands.
GATES
    echo "  Generated gates.md for $repo_name (from Taskfile)"
  else
    # No Taskfile — generate empty gates
    echo "  Warning: No Taskfile.yml in $repo_name — gates will be empty" >&2
    cat > "$gates_dir/gates.md" <<GATES
# Gates

Project-specific commands for the Ralph Wiggum autonomous build loop.

## Commands

| Gate | Command |
|------|---------|
| lint | \`\` |
| typecheck | \`\` |
| test | \`\` |
| build | \`\` |

Run gates in order: lint → typecheck → test → build. Skip gates with empty commands.
GATES
  fi
}

for repo in "${REPOS[@]}"; do
  generate_gates "$repo"
done

# --- Generate workspace.md for multi-repo ---

if [[ "$MULTI_REPO" == true ]]; then
  mkdir -p "$NODE_WORKSPACE/.ralph"

  # Build repo table rows
  REPO_ROWS=""
  for repo in "${REPOS[@]}"; do
    repo_name=$(basename "$repo")
    REPO_ROWS+="| ${repo_name} | \`${repo_name}\` | \`${repo_name}/.ralph/gates.md\` |
"
  done

  cat > "$NODE_WORKSPACE/.ralph/workspace.md" <<WORKSPACE
# Workspace

Multi-repo workspace configuration for the Ralph Wiggum autonomous build loop.

## Repos

| Repo | Path | Gates |
|------|------|-------|
${REPO_ROWS}
## Branch

| Setting | Value |
|---------|-------|
| name | \`${PROJECT_BRANCH:-ralph/task}\` |
| strategy | \`workspace\` |

Branch strategy:
- \`workspace\` — use existing worktree branch if already checked out.

## Notes

- Each repo listed above must contain its own \`.ralph/gates.md\` with repo-specific gate commands
- Tasks in \`PLAN.md\` are annotated with \`[repo-name]\` prefix to indicate the target repo
- The agent cds to the repo path before implementing each task
- Commits are made in the repo that changed
WORKSPACE
  echo "  Created: .ralph/workspace.md (multi-repo: ${REPO_NAMES[*]})"
else
  # Single-repo: copy gates.md to workspace root .ralph/
  repo="${REPOS[0]}"
  mkdir -p "$NODE_WORKSPACE/.ralph"
  cp "$repo/.ralph/gates.md" "$NODE_WORKSPACE/.ralph/gates.md"
  echo "  Copied gates.md to workspace root (single-repo)"
fi

# --- Dry run: stop here ---

if [[ "$DRY_RUN" == true ]]; then
  echo ""
  echo "=== Dry run complete ==="
  echo "Workspace prepared at: $NODE_WORKSPACE"
  echo "Files created:"
  echo "  specs/task.md"
  echo "  PROMPT_plan.md"
  echo "  PROMPT_build.md"
  for repo in "${REPOS[@]}"; do
    echo "  $(basename "$repo")/.ralph/gates.md"
  done
  if [[ "$MULTI_REPO" == true ]]; then
    echo "  .ralph/workspace.md"
  else
    echo "  .ralph/gates.md"
  fi
  echo ""
  echo "To run manually:"
  echo "  $RALPH_DIR/run-container.sh $NODE_WORKSPACE -- plan"
  echo "  $RALPH_DIR/run-container.sh $NODE_WORKSPACE -- build"
  exit 0
fi

# --- Docker validation (skipped for dry-run) ---

if ! command -v docker &>/dev/null; then
  echo "Error: docker not found" >&2
  exit 1
fi

if ! docker info &>/dev/null 2>&1; then
  echo "Error: Docker is not running" >&2
  exit 1
fi

# --- Invoke Ralph ---

echo ""
echo "=== Starting container dispatch ==="

# Phase 1: Plan
echo "Phase 1: Planning..."
if ! "$RALPH_DIR/run-container.sh" "$NODE_WORKSPACE" -- plan; then
  echo "Error: Plan phase failed" >&2

  # Check for blockers
  if [[ -f "$NODE_WORKSPACE/BLOCKERS.md" ]] && [[ -s "$NODE_WORKSPACE/BLOCKERS.md" ]]; then
    BLOCKER_TEXT=$(cat "$NODE_WORKSPACE/BLOCKERS.md")
    cat <<RESULT
{
  "status": "blocked",
  "node_id": "${NODE_ID}",
  "files_modified": [],
  "changes_summary": "Plan phase produced blockers",
  "commits": [],
  "acceptance_criteria_met": [],
  "issues": $(echo "$BLOCKER_TEXT" | jq -Rs .),
  "dispatch_method": "container"
}
RESULT
    exit 0
  fi

  cat <<RESULT
{
  "status": "failure",
  "node_id": "${NODE_ID}",
  "files_modified": [],
  "changes_summary": "Plan phase failed",
  "commits": [],
  "acceptance_criteria_met": [],
  "issues": "run-container.sh plan exited with non-zero status",
  "dispatch_method": "container"
}
RESULT
  exit 0
fi

# Check for blockers after plan phase
if [[ -f "$NODE_WORKSPACE/BLOCKERS.md" ]] && [[ -s "$NODE_WORKSPACE/BLOCKERS.md" ]]; then
  BLOCKER_TEXT=$(cat "$NODE_WORKSPACE/BLOCKERS.md")
  echo "Plan phase produced blockers" >&2
  cat <<RESULT
{
  "status": "blocked",
  "node_id": "${NODE_ID}",
  "files_modified": [],
  "changes_summary": "Plan phase produced blockers",
  "commits": [],
  "acceptance_criteria_met": [],
  "issues": $(echo "$BLOCKER_TEXT" | jq -Rs .),
  "dispatch_method": "container"
}
RESULT
  exit 0
fi

# Phase 2: Build
echo "Phase 2: Building..."
BUILD_EXIT=0
"$RALPH_DIR/run-container.sh" "$NODE_WORKSPACE" -- build || BUILD_EXIT=$?

# --- Parse result ---

echo ""
echo "=== Parsing results ==="

# Check for blockers
if [[ -f "$NODE_WORKSPACE/BLOCKERS.md" ]] && [[ -s "$NODE_WORKSPACE/BLOCKERS.md" ]]; then
  BLOCKER_TEXT=$(cat "$NODE_WORKSPACE/BLOCKERS.md")
  echo "Build phase produced blockers" >&2
  cat <<RESULT
{
  "status": "blocked",
  "node_id": "${NODE_ID}",
  "files_modified": [],
  "changes_summary": "Build phase blocked",
  "commits": [],
  "acceptance_criteria_met": [],
  "issues": $(echo "$BLOCKER_TEXT" | jq -Rs .),
  "dispatch_method": "container"
}
RESULT
  exit 0
fi

# Check PLAN.md completion state
STATUS="failure"
SUMMARY="Build phase did not complete all tasks"
CRITERIA_MET="[]"

if [[ -f "$NODE_WORKSPACE/PLAN.md" ]]; then
  UNCHECKED=$(grep -c '^\- \[ \]' "$NODE_WORKSPACE/PLAN.md" 2>/dev/null || echo "0")
  CHECKED=$(grep -c '^\- \[x\]' "$NODE_WORKSPACE/PLAN.md" 2>/dev/null || echo "0")

  if [[ "$UNCHECKED" -eq 0 ]] && [[ "$CHECKED" -gt 0 ]]; then
    STATUS="success"
    SUMMARY="All $CHECKED tasks completed"
  elif [[ "$CHECKED" -gt 0 ]]; then
    STATUS="partial"
    SUMMARY="$CHECKED tasks completed, $UNCHECKED remaining"
  fi

  # Extract completed criteria text
  CRITERIA_MET=$(grep '^\- \[x\]' "$NODE_WORKSPACE/PLAN.md" 2>/dev/null | sed 's/^- \[x\] //' | jq -R . | jq -s .)
fi

# Collect modified files across repos
FILES_MODIFIED="[]"
COMMITS="[]"
for repo in "${REPOS[@]}"; do
  if [[ -d "$repo/.git" ]] || [[ -f "$repo/.git" ]]; then
    repo_files=$(git -C "$repo" diff --name-only HEAD~1 HEAD 2>/dev/null | jq -R . | jq -s . 2>/dev/null || echo "[]")
    repo_commits=$(git -C "$repo" log --oneline -5 --format="%H" 2>/dev/null | jq -R . | jq -s . 2>/dev/null || echo "[]")
    FILES_MODIFIED=$(echo "$FILES_MODIFIED $repo_files" | jq -s 'add')
    COMMITS=$(echo "$COMMITS $repo_commits" | jq -s 'add')
  fi
done

cat <<RESULT
{
  "status": "${STATUS}",
  "node_id": "${NODE_ID}",
  "files_modified": ${FILES_MODIFIED},
  "changes_summary": "${SUMMARY}",
  "commits": ${COMMITS},
  "acceptance_criteria_met": ${CRITERIA_MET},
  "issues": "none",
  "dispatch_method": "container"
}
RESULT
