#!/usr/bin/env bash
# Dispatch a goal-tree node to Ralph's container for L0 execution.
#
# Translates DESIGN.md → Ralph workspace, invokes run-container.sh,
# parses result into goal-tree dispatch_result format.
#
# Usage: dispatch-container.sh <node-workspace-path> [--timeout <duration>] [--dry-run]
#
# Prerequisites:
#   - Node workspace exists with DESIGN.md populated
#   - Docker is running
#   - Ralph infrastructure at RALPH_DIR (default: sibling skill in claude-skills)
#   - GNU coreutils 'timeout' (Linux) or 'gtimeout' (macOS via brew install coreutils)
#
# Output: dispatch_result JSON to stdout

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RALPH_DIR="${RALPH_DIR:-$SCRIPT_DIR/../../ralph-wiggum/scripts}"
RALPH_SKILL_DIR="${RALPH_SKILL_DIR:-$SCRIPT_DIR/../../ralph-wiggum}"

DEFAULT_TIMEOUT="30m"
TIMEOUT="$DEFAULT_TIMEOUT"
DRY_RUN=false
NODE_WORKSPACE=""

usage() {
  cat <<EOF
Usage: dispatch-container.sh <node-workspace-path> [--timeout <duration>] [--dry-run]

Dispatch a goal-tree node to Ralph's container for L0 execution.

Options:
  --timeout <duration>  Wall-clock budget for the entire dispatch (plan + build
                        phases combined). Accepts duration suffixes: 30m, 1h, 90s,
                        or bare integer seconds. Default: ${DEFAULT_TIMEOUT}.
                        If exceeded, the dispatch terminates and emits a
                        dispatch_result with status "did_not_finish",
                        duration_seconds and timeout_seconds populated.
  --dry-run             Prepare the workspace (specs, gates, prompts) without
                        invoking the container.
  -h, --help            Show this help and exit.

Notes:
  - Timeout applies as a single combined wall-clock budget across plan and build
    phases. If plan alone exhausts the budget, build is skipped and the dispatch
    emits did_not_finish.
  - Requires GNU 'timeout' on Linux or 'gtimeout' on macOS (brew install coreutils).
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --timeout)
      [[ $# -ge 2 ]] || { echo "Error: --timeout requires a value" >&2; exit 2; }
      TIMEOUT="$2"
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [[ -z "$NODE_WORKSPACE" ]]; then
        NODE_WORKSPACE="$1"
        shift
      else
        echo "Error: unexpected argument: $1" >&2
        exit 2
      fi
      ;;
  esac
done

if [[ -z "$NODE_WORKSPACE" ]]; then
  echo "Error: <node-workspace-path> is required" >&2
  usage >&2
  exit 2
fi

# --- Timeout parsing and binary detection ---

parse_duration() {
  # Convert "30m" / "1h" / "90s" / bare integer → seconds
  local input="$1"
  [[ -n "$input" ]] || return 1
  if [[ "$input" =~ ^([0-9]+)([smh]?)$ ]]; then
    local n="${BASH_REMATCH[1]}"
    local unit="${BASH_REMATCH[2]}"
    case "$unit" in
      ""|s) echo "$n" ;;
      m)    echo "$((n * 60))" ;;
      h)    echo "$((n * 3600))" ;;
    esac
    return 0
  fi
  return 1
}

TIMEOUT_SEC=$(parse_duration "$TIMEOUT") || {
  echo "Error: invalid --timeout value: '$TIMEOUT' (expected format: 30s, 30m, 1h)" >&2
  exit 2
}
if [[ "$TIMEOUT_SEC" -le 0 ]]; then
  echo "Error: --timeout must be > 0 (got: '$TIMEOUT')" >&2
  exit 2
fi

if command -v timeout &>/dev/null; then
  TIMEOUT_BIN=timeout
elif command -v gtimeout &>/dev/null; then
  TIMEOUT_BIN=gtimeout
else
  echo "Error: neither 'timeout' (Linux) nor 'gtimeout' (macOS) is available on PATH" >&2
  echo "  Install GNU coreutils: brew install coreutils" >&2
  exit 2
fi

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

echo "Dispatching node $NODE_ID to container..." >&2
echo "  Title: $NODE_TITLE" >&2
echo "  Workspace: $NODE_WORKSPACE" >&2

# --- Detect repos in workspace ---
#
# Two valid layouts:
#   single-repo: $NODE_WORKSPACE itself is a git repo (or worktree)
#                → loop.sh runs git from the workspace root
#   multi-repo:  $NODE_WORKSPACE contains one or more subdirectories with .git
#                → loop.sh cd's into each repo per task
#
# The two are mutually exclusive — if the workspace itself has .git, treat
# as single-repo and ignore any nested .git subdirectories.

REPOS=()
REPO_NAMES=()
MULTI_REPO=false

if [[ -e "$NODE_WORKSPACE/.git" ]]; then
  # Single-repo: workspace IS the repo
  REPOS+=("$NODE_WORKSPACE")
  REPO_NAMES+=("$(basename "$NODE_WORKSPACE")")
else
  # Multi-repo: scan subdirectories
  for dir in "$NODE_WORKSPACE"/*/; do
    if [[ -e "$dir/.git" ]]; then
      repo_name=$(basename "$dir")
      REPOS+=("$dir")
      REPO_NAMES+=("$repo_name")
    fi
  done
  if [[ ${#REPOS[@]} -gt 0 ]]; then
    MULTI_REPO=true
  fi
fi

if [[ ${#REPOS[@]} -eq 0 ]]; then
  echo "Error: No git repos found in $NODE_WORKSPACE" >&2
  echo "  Expected either $NODE_WORKSPACE/.git (single-repo) or" >&2
  echo "  $NODE_WORKSPACE/<repo>/.git (multi-repo)" >&2
  exit 1
fi

echo "  Repos: ${REPO_NAMES[*]}" >&2

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

echo "  Created: specs/task.md" >&2

# --- Copy PROMPT files ---

for prompt_file in PROMPT_plan.md PROMPT_build.md; do
  if [[ ! -f "$NODE_WORKSPACE/$prompt_file" ]]; then
    cp "$RALPH_SKILL_DIR/$prompt_file" "$NODE_WORKSPACE/$prompt_file"
    echo "  Copied: $prompt_file" >&2
  else
    echo "  Skipped: $prompt_file (exists)" >&2
  fi
done

# --- Generate gates.md from Taskfile ---

discover_container_image() {
  # Discover the test container image from a repo's devcontainer.json.
  # Sets CONTAINER_IMAGE and IMAGE_SOURCE variables in the caller's scope.
  local repo_path="$1"
  CONTAINER_IMAGE=""
  IMAGE_SOURCE="ralph-default"

  # Check standard devcontainer.json locations
  local dc_file=""
  if [[ -f "$repo_path/.devcontainer/devcontainer.json" ]]; then
    dc_file="$repo_path/.devcontainer/devcontainer.json"
  elif [[ -f "$repo_path/devcontainer.json" ]]; then
    dc_file="$repo_path/devcontainer.json"
  fi

  if [[ -n "$dc_file" ]]; then
    local img
    img=$(jq -r '.image // empty' "$dc_file" 2>/dev/null || true)
    if [[ -n "$img" ]]; then
      CONTAINER_IMAGE="$img"
      IMAGE_SOURCE="devcontainer"
    fi
  fi
}

generate_gates() {
  local repo_path="$1"
  local repo_name
  repo_name=$(basename "$repo_path")
  local gates_dir="$repo_path/.ralph"
  mkdir -p "$gates_dir"

  # Discover container image
  discover_container_image "$repo_path"
  local image_display="${CONTAINER_IMAGE:-ralph base image}"

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

## Container

| Setting | Value |
|---------|-------|
| image | \`${image_display}\` |
| source | \`${IMAGE_SOURCE}\` |

## Commands

| Gate | Command |
|------|---------|
| lint | \`${lint_cmd}\` |
| typecheck | \`${typecheck_cmd}\` |
| test | \`${test_cmd}\` |
| build | \`${build_cmd}\` |

Run gates in order: lint → typecheck → test → build. Skip gates with empty commands.
GATES
    echo "  Generated gates.md for $repo_name (from Taskfile, image: ${IMAGE_SOURCE})" >&2
  else
    # No Taskfile — generate empty gates
    echo "  Warning: No Taskfile.yml in $repo_name — gates will be empty" >&2
    cat > "$gates_dir/gates.md" <<GATES
# Gates

Project-specific commands for the Ralph Wiggum autonomous build loop.

## Container

| Setting | Value |
|---------|-------|
| image | \`${image_display}\` |
| source | \`${IMAGE_SOURCE}\` |

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

  # Build repo table rows (extract image from each repo's generated gates.md)
  REPO_ROWS=""
  for repo in "${REPOS[@]}"; do
    repo_name=$(basename "$repo")
    # Extract image from the gates.md we just generated
    repo_image=$(sed -n 's/^| image | `\(.*\)` |$/\1/p' "$repo/.ralph/gates.md" 2>/dev/null || echo "ralph base image")
    REPO_ROWS+="| ${repo_name} | \`${repo_name}\` | \`${repo_name}/.ralph/gates.md\` | \`${repo_image}\` |
"
  done

  cat > "$NODE_WORKSPACE/.ralph/workspace.md" <<WORKSPACE
# Workspace

Multi-repo workspace configuration for the Ralph Wiggum autonomous build loop.

## Repos

| Repo | Path | Gates | Image |
|------|------|-------|-------|
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
  echo "  Created: .ralph/workspace.md (multi-repo: ${REPO_NAMES[*]})" >&2
else
  # Single-repo: gates.md must live at workspace root .ralph/
  # If the workspace IS the repo, gates.md is already at the right path —
  # generate_gates wrote it to "$repo/.ralph/gates.md" which equals
  # "$NODE_WORKSPACE/.ralph/gates.md". Otherwise (subdirectory repo) copy it up.
  repo="${REPOS[0]}"
  mkdir -p "$NODE_WORKSPACE/.ralph"
  src="$repo/.ralph/gates.md"
  dst="$NODE_WORKSPACE/.ralph/gates.md"
  if [[ "$(cd "$(dirname "$src")" && pwd)/$(basename "$src")" != "$(cd "$(dirname "$dst")" && pwd)/$(basename "$dst")" ]]; then
    cp "$src" "$dst"
    echo "  Copied gates.md to workspace root (single-repo)" >&2
  else
    echo "  gates.md already at workspace root (single-repo, workspace == repo)" >&2
  fi
fi

# --- Dry run: stop here ---

if [[ "$DRY_RUN" == true ]]; then
  echo "" >&2
  echo "=== Dry run complete ===" >&2
  echo "Workspace prepared at: $NODE_WORKSPACE" >&2
  echo "Files created:" >&2
  echo "  specs/task.md" >&2
  echo "  PROMPT_plan.md" >&2
  echo "  PROMPT_build.md" >&2
  for repo in "${REPOS[@]}"; do
    echo "  $(basename "$repo")/.ralph/gates.md" >&2
  done
  if [[ "$MULTI_REPO" == true ]]; then
    echo "  .ralph/workspace.md" >&2
  else
    echo "  .ralph/gates.md" >&2
  fi
  echo "" >&2
  echo "To run manually:" >&2
  echo "  $RALPH_DIR/run-container.sh $NODE_WORKSPACE -- plan" >&2
  echo "  $RALPH_DIR/run-container.sh $NODE_WORKSPACE -- build" >&2
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

echo "" >&2
echo "=== Starting container dispatch ===" >&2
echo "  Timeout: ${TIMEOUT} (${TIMEOUT_SEC}s combined wall-clock budget)" >&2

START_TS=$(date +%s)

elapsed_seconds() { echo $(( $(date +%s) - START_TS )); }
remaining_seconds() { echo $(( TIMEOUT_SEC - $(elapsed_seconds) )); }

emit_did_not_finish() {
  local reason="$1"
  cat <<RESULT
{
  "status": "did_not_finish",
  "node_id": $(printf '%s' "$NODE_ID" | jq -Rs .),
  "files_modified": [],
  "changes_summary": $(printf '%s' "$reason" | jq -Rs .),
  "commits": [],
  "acceptance_criteria_met": [],
  "issues": $(printf '%s' "$reason" | jq -Rs .),
  "dispatch_method": "container",
  "duration_seconds": $(elapsed_seconds),
  "timeout_seconds": ${TIMEOUT_SEC}
}
RESULT
}

# Preflight: verify workspace is writable (catches broken paths / permissions early)
SMOKE_FILE="$NODE_WORKSPACE/.ralph/smoke-test-$$"
echo "Preflight: testing workspace file writes..." >&2
mkdir -p "$NODE_WORKSPACE/.ralph"
if ! touch "$SMOKE_FILE" 2>/dev/null; then
  echo "Error: cannot write to workspace $NODE_WORKSPACE" >&2
  emit_did_not_finish "Workspace is not writable"
  exit 0
fi
rm -f "$SMOKE_FILE"
echo "Preflight: workspace writable" >&2

# Phase 1: Plan
PLAN_BUDGET=$(remaining_seconds)
if [[ "$PLAN_BUDGET" -le 0 ]]; then
  echo "Budget exhausted before plan phase started" >&2
  emit_did_not_finish "Budget exhausted before plan phase started"
  exit 0
fi
echo "Phase 1: Planning... (budget: ${PLAN_BUDGET}s)" >&2
PLAN_EXIT=0
"$TIMEOUT_BIN" "${PLAN_BUDGET}s" "$RALPH_DIR/run-container.sh" "$NODE_WORKSPACE" -- plan >&2 || PLAN_EXIT=$?

if [[ "$PLAN_EXIT" -eq 124 ]]; then
  echo "Plan phase exceeded wall-clock budget" >&2
  emit_did_not_finish "Plan phase exceeded wall-clock budget"
  exit 0
fi

if [[ "$PLAN_EXIT" -ne 0 ]]; then
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
  "dispatch_method": "container",
  "duration_seconds": $(elapsed_seconds),
  "timeout_seconds": ${TIMEOUT_SEC}
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
  "dispatch_method": "container",
  "duration_seconds": $(elapsed_seconds),
  "timeout_seconds": ${TIMEOUT_SEC}
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
  "dispatch_method": "container",
  "duration_seconds": $(elapsed_seconds),
  "timeout_seconds": ${TIMEOUT_SEC}
}
RESULT
  exit 0
fi

# Phase 2: Build
BUILD_BUDGET=$(remaining_seconds)
if [[ "$BUILD_BUDGET" -le 0 ]]; then
  echo "Budget exhausted by plan phase; build phase skipped" >&2
  emit_did_not_finish "Budget exhausted by plan phase; build phase skipped"
  exit 0
fi
echo "Phase 2: Building... (budget: ${BUILD_BUDGET}s)" >&2
BUILD_EXIT=0
"$TIMEOUT_BIN" "${BUILD_BUDGET}s" "$RALPH_DIR/run-container.sh" "$NODE_WORKSPACE" -- build >&2 || BUILD_EXIT=$?

if [[ "$BUILD_EXIT" -eq 124 ]]; then
  echo "Build phase exceeded wall-clock budget" >&2
  emit_did_not_finish "Build phase exceeded wall-clock budget"
  exit 0
fi

# --- Parse result ---

# Ensure filesystem writes from the container are visible before parsing
sync 2>/dev/null || true

echo "" >&2
echo "=== Parsing results ===" >&2

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
  "dispatch_method": "container",
  "duration_seconds": $(elapsed_seconds),
  "timeout_seconds": ${TIMEOUT_SEC}
}
RESULT
  exit 0
fi

# Check PLAN.md completion state
STATUS="failure"
SUMMARY="Build phase did not complete all tasks"
CRITERIA_MET="[]"
PR_URL=""

# Read PR URL from exit-summary if available
if [[ -f "$NODE_WORKSPACE/.ralph/exit-summary.json" ]]; then
  PR_URL=$(jq -r '.pr_url // empty' "$NODE_WORKSPACE/.ralph/exit-summary.json" 2>/dev/null || true)
fi

if [[ -f "$NODE_WORKSPACE/PLAN.md" ]]; then
  UNCHECKED=$(grep -c '^\- \[ \]' "$NODE_WORKSPACE/PLAN.md" 2>/dev/null || true)
  UNCHECKED=${UNCHECKED:-0}
  CHECKED=$(grep -c '^\- \[x\]' "$NODE_WORKSPACE/PLAN.md" 2>/dev/null || true)
  CHECKED=${CHECKED:-0}

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

# Collect modified files and commits — only when the dispatch made progress.
# On failure, preserving an empty list avoids polluting the payload with
# pre-existing branch history that has nothing to do with this dispatch.
FILES_MODIFIED="[]"
COMMITS="[]"
if [[ "$STATUS" == "success" ]] || [[ "$STATUS" == "partial" ]]; then
  for repo in "${REPOS[@]}"; do
    if [[ -d "$repo/.git" ]] || [[ -f "$repo/.git" ]]; then
      repo_files=$(git -C "$repo" diff --name-only HEAD~1 HEAD 2>/dev/null | jq -R . | jq -s . 2>/dev/null || echo "[]")
      repo_commits=$(git -C "$repo" log --oneline -5 --format="%H" 2>/dev/null | jq -R . | jq -s . 2>/dev/null || echo "[]")
      FILES_MODIFIED=$(echo "$FILES_MODIFIED $repo_files" | jq -s 'add')
      COMMITS=$(echo "$COMMITS $repo_commits" | jq -s 'add')
    fi
  done
fi

cat <<RESULT
{
  "status": "${STATUS}",
  "node_id": "${NODE_ID}",
  "files_modified": ${FILES_MODIFIED},
  "changes_summary": "${SUMMARY}",
  "commits": ${COMMITS},
  "acceptance_criteria_met": ${CRITERIA_MET},
  "issues": "none",
  "dispatch_method": "container",
  "duration_seconds": $(elapsed_seconds),
  "timeout_seconds": ${TIMEOUT_SEC},
  "pr_url": $(if [[ -n "$PR_URL" ]]; then printf '"%s"' "$PR_URL"; else echo 'null'; fi)
}
RESULT
