#!/bin/bash
# Ralph Wiggum autonomous control loop orchestrator
# Usage: ./loop.sh [plan|build] [max-iterations]

set -euo pipefail

# Track background Claude PID for signal cleanup
CLAUDE_PID=""

# Ensure background Claude process is waited for before exit.
# Without this, SIGTERM from timeout kills loop.sh while Claude is
# still writing files, causing dispatch-container.sh to parse partial results.
# shellcheck disable=SC2317,SC2329  # invoked indirectly via trap
cleanup_claude() {
  if [[ -n "$CLAUDE_PID" ]] && kill -0 "$CLAUDE_PID" 2>/dev/null; then
    echo "  [cleanup: waiting for Claude PID $CLAUDE_PID]"
    kill "$CLAUDE_PID" 2>/dev/null || true
    wait "$CLAUDE_PID" 2>/dev/null || true
  fi
  sync 2>/dev/null || true
}
trap cleanup_claude EXIT

# Verify running inside container
is_container() {
  [[ -f /.dockerenv ]] || \
  [[ -f /run/.containerenv ]] || \
  grep -q 'docker\|containerd' /proc/1/cgroup 2>/dev/null
}

if ! is_container; then
  echo "Error: loop.sh must run inside the Ralph container"
  echo "Usage: ./run-container.sh [plan|build]"
  exit 1
fi

# Validate OAuth token is present (injected by run-container.sh)
if [[ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]]; then
  echo "Error: CLAUDE_CODE_OAUTH_TOKEN not set"
  echo "run-container.sh injects this automatically from host credentials"
  exit 1
fi

# Warn if API key is set (Ralph uses OAuth, not API credits)
if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
  echo "Warning: ANTHROPIC_API_KEY is set but will be ignored"
  echo "Ralph uses OAuth subscription, not API credits"
  echo "Consider unsetting ANTHROPIC_API_KEY to avoid confusion"
  echo ""
fi

# Pre-flight auth validation - verify credentials work before starting loop
preflight_auth_check() {
  echo "Validating credentials..."
  local temp_output
  temp_output=$(mktemp)

  # Minimal Claude call with short timeout to verify auth
  # --verbose required by Claude CLI when combining --print with --output-format=stream-json
  timeout 30 claude --output-format stream-json --verbose -p "Say OK" > "$temp_output" 2>&1 || true

  # Check for auth/credit errors in output
  if grep -qi 'credit balance is too low' "$temp_output" 2>/dev/null; then
    echo "Error: Credit balance too low"
    echo "Run 'claude' interactively to add credits or re-authenticate"
    rm -f "$temp_output"
    return 1
  fi

  if grep -qiE 'authentication.*(error|failed|invalid|expired)|invalid.*(api.?key|token|credential)|expired.*(token|session|credential)|unauthorized|permission.?denied' "$temp_output" 2>/dev/null; then
    echo "Error: Authentication failed"
    echo "Run 'claude' interactively to re-authenticate"
    rm -f "$temp_output"
    return 1
  fi

  # Verify we got a valid response (should contain "OK" or result type)
  if ! grep -q '"type":"result"' "$temp_output" 2>/dev/null; then
    echo "Error: Pre-flight check failed - no valid response"
    echo "Check network connectivity and Claude CLI installation"
    rm -f "$temp_output"
    return 1
  fi

  rm -f "$temp_output"
  echo "Credentials validated"
  return 0
}

if ! preflight_auth_check; then
  exit 1
fi

# Pre-flight service health check - verify external dependencies are reachable
# Services are started by run-container.sh on the host; this only checks health.
preflight_services_check() {
  local services_file=".ralph/services.md"

  # Skip silently if no services configured (backward compatible)
  if [[ ! -f "$services_file" ]]; then
    return 0
  fi

  echo "Checking external services..."

  # Parse and run health checks from markdown table
  # Format: | service_name | `command` | timeout_seconds |
  local failed=0
  while IFS='|' read -r _ service command timeout _; do
    # Skip header, separator, and template rows
    service=$(echo "$service" | xargs)
    # Single quotes intentional: matching literal backticks
    # shellcheck disable=SC2016
    command=$(echo "$command" | sed 's/^ *`//;s/` *$//' | xargs)
    timeout=$(echo "$timeout" | xargs | sed 's/s$//')

    [[ -z "$service" || "$service" == "Service" || "$service" == "---"* || "$service" == "{{service_name}}" ]] && continue
    [[ -z "$command" ]] && continue

    local timeout_secs="${timeout:-30}"
    echo "  Checking $service (timeout: ${timeout_secs}s)..."

    if ! timeout "$timeout_secs" bash -c "$command" >/dev/null 2>&1; then
      echo "  Error: $service health check failed: $command"
      failed=1
    else
      echo "  $service: healthy"
    fi
  done < <(grep '|.*|.*|.*|' "$services_file" | grep -v '^\s*|.*---')

  if [[ $failed -ne 0 ]]; then
    echo "Error: One or more service health checks failed"
    return 1
  fi

  echo "All services healthy"
  return 0
}

if ! preflight_services_check; then
  exit 1
fi

MODE=${1:-build}
MAX_ITER=${2:-20}
ITER=0
GRACE_PERIOD=5      # seconds to wait after result before killing
MAX_ITER_TIME=600   # max seconds per iteration (10 min)

# Validate mode
if [[ "$MODE" != "plan" && "$MODE" != "build" ]]; then
  echo "Error: mode must be 'plan' or 'build'"
  exit 1
fi

PROMPT_FILE="PROMPT_${MODE}.md"
if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "Error: $PROMPT_FILE not found"
  exit 1
fi

# Validate specs exist for plan mode
if [[ "$MODE" == "plan" ]]; then
  if [[ ! -d specs ]]; then
    echo "Error: specs/ directory not found"
    echo "Create spec files before running plan phase"
    exit 1
  fi
  if [[ -z $(find specs -maxdepth 1 -name '*.md' -type f 2>/dev/null) ]]; then
    echo "Error: No spec files found in specs/"
    echo "Create spec files before running plan phase"
    exit 1
  fi
fi

RALPH_CONFIG=".ralph/config.json"
WORKSPACE_MANIFEST=".ralph/workspace.md"

# Source shared library (co-located or mounted at /opt/ralph/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib.sh" ]]; then
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/lib.sh"
elif [[ -f "/opt/ralph/lib.sh" ]]; then
  # shellcheck disable=SC1091
  source "/opt/ralph/lib.sh"
fi

# Detect workspace mode
WORKSPACE_MODE=$(detect_workspace_mode "$WORKSPACE_MANIFEST")
echo "Workspace mode: ${WORKSPACE_MODE}-repo"

# Slugify a string for use as branch name
slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//'
}

# Derive branch name from first spec file
derive_branch_from_spec() {
  local spec_file
  spec_file=$(find specs -maxdepth 1 -name '*.md' -type f 2>/dev/null | head -1)

  if [[ -z "$spec_file" ]]; then
    echo "Error: No spec files found in specs/" >&2
    return 1
  fi

  # Extract filename without path and extension
  local basename
  basename=$(basename "$spec_file" .md)

  echo "ralph/$(slugify "$basename")"
}

# Ensure branch in a single git repo directory
# Args: $1 = repo_path (optional, defaults to current dir), $2 = branch_name
ensure_branch_in_repo() {
  local repo_path="${1:-.}"
  local target_branch="$2"

  pushd "$repo_path" > /dev/null

  # If this is a worktree, use whatever branch is already checked out
  if [[ -f ".git" ]]; then
    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    echo "  $repo_path: worktree on branch $current_branch (using as-is)"
    popd > /dev/null
    return 0
  fi

  # Regular repo — switch to target branch
  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD)

  if [[ "$current_branch" == "$target_branch" ]]; then
    echo "  $repo_path: already on $target_branch"
  elif git show-ref --verify --quiet "refs/heads/$target_branch"; then
    echo "  $repo_path: switching to $target_branch"
    git checkout "$target_branch"
  else
    echo "  $repo_path: creating $target_branch"
    git checkout -b "$target_branch"
  fi

  popd > /dev/null
}

# Ensure we're on the correct branch (single-repo mode)
ensure_branch() {
  # If config exists, use cached branch
  if [[ -f "$RALPH_CONFIG" ]]; then
    local cached_branch
    cached_branch=$(jq -r '.branch // empty' "$RALPH_CONFIG" 2>/dev/null)

    if [[ -n "$cached_branch" ]]; then
      local current_branch
      current_branch=$(git rev-parse --abbrev-ref HEAD)

      if [[ "$current_branch" != "$cached_branch" ]]; then
        echo "Switching to cached branch: $cached_branch"
        git checkout "$cached_branch"
      fi
      return 0
    fi
  fi

  # No cache - derive branch from spec
  local new_branch
  new_branch=$(derive_branch_from_spec) || return 1

  # Check if branch already exists
  if git show-ref --verify --quiet "refs/heads/$new_branch"; then
    echo "Switching to existing branch: $new_branch"
    git checkout "$new_branch"
  else
    echo "Creating new branch: $new_branch"
    git checkout -b "$new_branch"
  fi

  # Cache the branch name
  mkdir -p .ralph
  echo "{\"branch\": \"$new_branch\"}" > "$RALPH_CONFIG"

  # Ensure .ralph is gitignored
  if [[ -f .gitignore ]]; then
    if ! grep -q '^\.ralph/$' .gitignore 2>/dev/null; then
      echo ".ralph/" >> .gitignore
    fi
  else
    echo ".ralph/" > .gitignore
  fi
}

# Ensure branches across all repos (multi-repo mode)
ensure_branches_multi() {
  # If config exists, use cached branch
  local target_branch=""
  if [[ -f "$RALPH_CONFIG" ]]; then
    target_branch=$(jq -r '.branch // empty' "$RALPH_CONFIG" 2>/dev/null)
  fi

  # No cache - derive from spec
  if [[ -z "$target_branch" ]]; then
    target_branch=$(derive_branch_from_spec) || return 1
    mkdir -p .ralph
    jq -n --arg branch "$target_branch" '{"branch": $branch}' > "$RALPH_CONFIG"
  fi

  # Ensure .ralph is gitignored at workspace root
  if [[ -f .gitignore ]]; then
    if ! grep -q '^\.ralph/$' .gitignore 2>/dev/null; then
      echo ".ralph/" >> .gitignore
    fi
  else
    echo ".ralph/" > .gitignore
  fi

  echo "Target branch: $target_branch"
  echo "Setting up branches for all repos..."

  while IFS='|' read -r _name path; do
    if [[ ! -d "$path" ]]; then
      echo "  Error: repo path '$path' does not exist" >&2
      return 1
    fi
    ensure_branch_in_repo "$path" "$target_branch"
  done < <(parse_workspace_repos "$WORKSPACE_MANIFEST")
}

# Run Claude with hang detection workaround
# See: https://github.com/anthropics/claude-code/issues/19060
run_claude() {
  local prompt_file="$1"
  mkdir -p .ralph
  local iter_log=".ralph/iteration-${ITER}.jsonl"

  # Start claude in background with stream-json to detect completion
  claude --dangerously-skip-permissions --output-format stream-json --verbose \
    -p "$(cat "$prompt_file")" > "$iter_log" 2>&1 &
  CLAUDE_PID=$!

  # Poll for result with timeout
  local waited=0
  while kill -0 $CLAUDE_PID 2>/dev/null && [[ $waited -lt $MAX_ITER_TIME ]]; do
    if grep -q '"type":"result"' "$iter_log" 2>/dev/null; then
      # Result received - give process grace period to exit cleanly
      sleep $GRACE_PERIOD
      if kill -0 $CLAUDE_PID 2>/dev/null; then
        echo "  [killing hung process]"
        kill $CLAUDE_PID 2>/dev/null || true
      fi
      break
    fi
    sleep 1
    waited=$((waited + 1))
  done

  # Handle timeout
  if [[ $waited -ge $MAX_ITER_TIME ]]; then
    echo "Error: iteration timed out after ${MAX_ITER_TIME}s"
    kill $CLAUDE_PID 2>/dev/null || true
    wait $CLAUDE_PID 2>/dev/null || true
    CLAUDE_PID=""
    return 1
  fi

  wait $CLAUDE_PID 2>/dev/null || true
  CLAUDE_PID=""

  # Flush filesystem writes so devcontainer exec caller sees complete files
  sync 2>/dev/null || true

  # Extract and display assistant text from stream-json output
  if command -v jq &>/dev/null; then
    jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text' \
      "$iter_log" 2>/dev/null || true
  else
    # Fallback: show raw output if jq unavailable
    grep -o '"text":"[^"]*"' "$iter_log" 2>/dev/null | sed 's/"text":"//;s/"$//' || true
  fi

  # Check for API errors in output
  if grep -q '"type":"error"' "$iter_log" 2>/dev/null; then
    echo "API error detected:"
    grep '"type":"error"' "$iter_log" || true
    return 1
  fi

  # Check for credit balance errors (may appear as assistant text, not API error)
  if grep -qi 'credit balance is too low' "$iter_log" 2>/dev/null; then
    echo "Credit balance error detected"
    echo ""
    echo "To fix: Run 'claude' interactively and follow the prompts to add credits or re-authenticate."
    return 1
  fi

  # Check for authentication errors — only in error events, not in file contents the agent read
  local error_lines
  error_lines=$(grep '"type":"error"' "$iter_log" 2>/dev/null || true)
  if [[ -n "$error_lines" ]] && echo "$error_lines" | grep -qiE 'authentication|unauthorized|permission.?denied|invalid.*(api.?key|token|credential)|expired.*(token|session|credential)'; then
    echo "Authentication error detected"
    echo ""
    echo "To fix: Run 'claude' interactively to re-authenticate, or check your API key configuration."
    return 1
  fi

  return 0
}

# Ensure we're on the correct branch before starting
if [[ "$WORKSPACE_MODE" == "multi" ]]; then
  ensure_branches_multi
else
  ensure_branch
fi

# Invoke Claude with a string prompt, writing output to specified log file.
# Uses same hang-detection pattern as run_claude.
# Args: $1 = prompt string, $2 = log file path
invoke_claude_prompt() {
  local prompt="$1"
  local log_file="$2"

  : > "$log_file"
  claude --dangerously-skip-permissions --output-format stream-json --verbose \
    -p "$prompt" > "$log_file" 2>&1 &
  CLAUDE_PID=$!

  local waited=0
  while kill -0 $CLAUDE_PID 2>/dev/null && [[ $waited -lt $MAX_ITER_TIME ]]; do
    if grep -q '"type":"result"' "$log_file" 2>/dev/null; then
      sleep $GRACE_PERIOD
      if kill -0 $CLAUDE_PID 2>/dev/null; then
        echo "  [killing hung process]"
        kill $CLAUDE_PID 2>/dev/null || true
      fi
      break
    fi
    sleep 1
    waited=$((waited + 1))
  done

  if [[ $waited -ge $MAX_ITER_TIME ]]; then
    echo "Warning: Claude timed out after ${MAX_ITER_TIME}s"
    kill $CLAUDE_PID 2>/dev/null || true
    wait $CLAUDE_PID 2>/dev/null || true
    CLAUDE_PID=""
    return 1
  fi

  wait $CLAUDE_PID 2>/dev/null || true
  CLAUDE_PID=""
  sync 2>/dev/null || true
  return 0
}

# Run close-out phase: /finish then /review (build mode, completed only).
# Sets CLOSEOUT_PR_URL with the PR URL extracted from /finish output.
run_closeout() {
  echo ""
  echo "=== Close-out phase ==="
  mkdir -p .ralph

  CLOSEOUT_PR_URL=""

  # Run /finish to create PR
  echo "Running /finish..."
  local finish_log=".ralph/closeout-finish.jsonl"
  if invoke_claude_prompt "/finish" "$finish_log"; then
    CLOSEOUT_PR_URL=$(grep -oE 'https://github\.com/[^/]+/[^/]+/pull/[0-9]+' "$finish_log" 2>/dev/null | head -1 || true)
    if [[ -n "$CLOSEOUT_PR_URL" ]]; then
      echo "PR created: $CLOSEOUT_PR_URL"
    else
      echo "Warning: No PR URL found in /finish output"
    fi
  else
    echo "Warning: /finish failed"
  fi

  # Run /review to self-review the PR
  echo "Running /review..."
  local review_log=".ralph/closeout-review.jsonl"
  if ! invoke_claude_prompt "/review" "$review_log"; then
    echo "Warning: /review failed"
  fi

  echo "Close-out phase complete"
}

# Write exit summary and exit
# Args: $1 = reason, $2 = exit code
write_exit_summary() {
  local reason="$1"
  local exit_code="$2"
  local tasks_completed=0
  local tasks_total=0

  if [[ -f PLAN.md ]]; then
    tasks_completed=$(grep -c '^\- \[x\]' PLAN.md 2>/dev/null || true)
    tasks_completed=${tasks_completed:-0}
    local tasks_unchecked
    tasks_unchecked=$(grep -c '^\- \[ \]' PLAN.md 2>/dev/null || true)
    tasks_unchecked=${tasks_unchecked:-0}
    tasks_total=$(( tasks_completed + tasks_unchecked ))
  fi

  local pr_url="${CLOSEOUT_PR_URL:-}"

  cat > .ralph/exit-summary.json <<EXITEOF
{
  "reason": "$reason",
  "iterations_run": $ITER,
  "iterations_max": $MAX_ITER,
  "mode": "$MODE",
  "tasks_completed": $tasks_completed,
  "tasks_total": $tasks_total,
  "pr_url": $(if [[ -n "$pr_url" ]]; then printf '"%s"' "$pr_url"; else echo 'null'; fi)
}
EXITEOF

  exit "$exit_code"
}

echo "Starting Ralph loop (mode: $MODE, workspace: $WORKSPACE_MODE, max iterations: $MAX_ITER)"

EXIT_REASON=""
PREV_PROGRESS=""

while [ "$ITER" -lt "$MAX_ITER" ]; do
  ITER=$((ITER + 1))
  echo ""
  echo "=== Iteration $ITER / $MAX_ITER (mode: $MODE) ==="
  echo ""

  # Run Claude with hang detection
  if ! run_claude "$PROMPT_FILE"; then
    echo "Error: Claude invocation failed"
    EXIT_REASON="error"
    break
  fi

  # Check for blockers
  if [[ -f BLOCKERS.md ]] && [[ -s BLOCKERS.md ]]; then
    echo ""
    echo "=== Blockers found, stopping loop ==="
    cat BLOCKERS.md
    EXIT_REASON="blocked"
    break
  fi

  # Check completion (all tasks done in PLAN.md)
  if [[ -f PLAN.md ]]; then
    if ! grep -q '^\- \[ \]' PLAN.md 2>/dev/null; then
      echo ""
      echo "=== All tasks complete ==="
      EXIT_REASON="completed"
      break
    fi
  fi

  # In plan mode, exit after first iteration (plan is generated once)
  if [[ "$MODE" == "plan" ]]; then
    echo ""
    echo "=== Plan generated ==="
    EXIT_REASON="completed"
    break
  fi

  # Progress detection (build mode only)
  # md5sum is Linux-only (macOS uses md5) — fine since loop.sh runs in the Ralph container
  CURRENT_PROGRESS="$(grep -c '^\- \[x\]' PLAN.md 2>/dev/null || echo 0):$(git diff --stat 2>/dev/null | md5sum):$(git rev-parse HEAD 2>/dev/null)"
  if [[ "$CURRENT_PROGRESS" == "$PREV_PROGRESS" ]]; then
    echo ""
    echo "=== No progress detected, stopping loop ==="
    EXIT_REASON="no_progress"
    break
  fi
  PREV_PROGRESS="$CURRENT_PROGRESS"
done

# Fell through without breaking — max iterations
if [[ -z "$EXIT_REASON" ]]; then
  echo ""
  echo "=== Max iterations ($MAX_ITER) reached ==="
  EXIT_REASON="max_iterations"
fi

# Close-out phase: /finish and /review (build mode, completed only)
CLOSEOUT_PR_URL=""
if [[ "$MODE" == "build" && "$EXIT_REASON" == "completed" ]]; then
  run_closeout
fi

# Common exit
case "$EXIT_REASON" in
  completed)   write_exit_summary "$EXIT_REASON" 0 ;;
  *)           write_exit_summary "$EXIT_REASON" 1 ;;
esac
