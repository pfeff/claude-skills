#!/bin/bash
# Run Ralph Wiggum loop inside devcontainer
# Usage: ./run-container.sh [workspace-folder] [--network] [-- loop-args...]
#
# Uses Ralph's generic devcontainer image. Project devcontainers define
# test images only and are not merged into the editor container.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${1:-.}"
LOOP_ARGS=()

# Parse arguments
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --network)
      # Kept for backward compatibility; devcontainer uses bridge network by default
      shift
      ;;
    --)
      shift
      LOOP_ARGS=("$@")
      break
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [workspace-folder] [--network] [-- loop-args...]"
      exit 1
      ;;
  esac
done

# Resolve workspace to absolute path
WORKSPACE="$(cd "$WORKSPACE" && pwd)"

# Extract OAuth token from macOS Keychain
if ! command -v security &>/dev/null; then
  echo "Error: 'security' command not found (macOS required)" >&2
  exit 1
fi

CREDS=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null) || {
  echo "Error: Claude credentials not found. Run 'claude login'" >&2
  exit 1
}

CLAUDE_CODE_OAUTH_TOKEN=$(echo "$CREDS" | jq -r '.claudeAiOauth.accessToken')
export CLAUDE_CODE_OAUTH_TOKEN
if [[ -z "$CLAUDE_CODE_OAUTH_TOKEN" || "$CLAUDE_CODE_OAUTH_TOKEN" == "null" ]]; then
  echo "Error: OAuth token missing. Run 'claude logout && claude login'" >&2
  exit 1
fi

# Set git config from host
GIT_AUTHOR_NAME=$(git config user.name 2>/dev/null || echo 'Ralph Wiggum')
export GIT_AUTHOR_NAME
GIT_AUTHOR_EMAIL=$(git config user.email 2>/dev/null || echo 'ralph@localhost')
export GIT_AUTHOR_EMAIL
export GIT_COMMITTER_NAME=$GIT_AUTHOR_NAME
export GIT_COMMITTER_EMAIL=$GIT_AUTHOR_EMAIL

# Pass coordinator env vars through for MCP client config inside container
export COORDINATOR_URL="${COORDINATOR_URL:-}"
export COORDINATOR_TOKEN="${COORDINATOR_TOKEN:-}"
if [[ -z "$COORDINATOR_URL" || -z "$COORDINATOR_TOKEN" ]]; then
  echo "Warning: COORDINATOR_URL/COORDINATOR_TOKEN not set — AC MCP tools will be unavailable inside container" >&2
fi

# SSH agent forwarding (for git push)
# On macOS with Docker Desktop, Unix sockets don't work across the VM boundary.
# Docker Desktop provides /run/host-services/ssh-auth.sock for SSH agent forwarding.
SSH_MOUNT_ARGS=()
if [[ "$(uname)" == "Darwin" ]]; then
  # macOS: Use Docker Desktop's built-in SSH agent forwarding
  if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
    echo "  SSH agent: using Docker Desktop forwarding"
    SSH_MOUNT_ARGS=(--mount "type=bind,source=/run/host-services/ssh-auth.sock,target=/run/host-services/ssh-auth.sock")
    export SSH_AUTH_SOCK_CONTAINER="/run/host-services/ssh-auth.sock"
  else
    echo "  SSH agent: not available (git push will require manual intervention)"
  fi
else
  # Linux: Direct socket forwarding works
  if [[ -n "${SSH_AUTH_SOCK:-}" && -S "$SSH_AUTH_SOCK" ]]; then
    echo "  SSH agent: forwarding from $SSH_AUTH_SOCK"
    SSH_MOUNT_ARGS=(--mount "type=bind,source=$SSH_AUTH_SOCK,target=/tmp/ssh-agent.sock")
    export SSH_AUTH_SOCK_CONTAINER="/tmp/ssh-agent.sock"
  else
    echo "  SSH agent: not available (git push will require manual intervention)"
  fi
fi

# Create temp directory for devcontainer config
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT
mkdir -p "$TEMP_DIR/.devcontainer"

# Source shared library
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

# Detect workspace mode
WORKSPACE_MANIFEST="$WORKSPACE/.ralph/workspace.md"
WORKSPACE_MODE=$(detect_workspace_mode "$WORKSPACE_MANIFEST")
echo "  Workspace mode: ${WORKSPACE_MODE}-repo"

# Detect git worktrees and prepare mount args
# In multi-repo mode, scan all repo subdirectories for worktrees
# In single-repo mode, check the workspace itself
WORKTREE_MOUNT_ARGS=()

resolve_worktree_mount() {
  local dir="$1"
  if [[ -f "$dir/.git" ]]; then
    # This is a worktree - .git is a file pointing to the main repo
    local gitdir
    gitdir=$(sed 's/^gitdir: //' "$dir/.git")
    # Resolve relative paths
    if [[ ! "$gitdir" = /* ]]; then
      gitdir="$(cd "$dir" && cd "$(dirname "$gitdir")" && pwd)/$(basename "$gitdir")"
    fi
    # Get the main .git directory (parent of worktrees/)
    local main_git_dir
    main_git_dir=$(dirname "$(dirname "$gitdir")")
    echo "$main_git_dir"
  fi
}

if [[ "$WORKSPACE_MODE" == "multi" ]]; then
  # Parse repo paths from workspace manifest and check each for worktrees
  # Use newline-separated string for dedup (portable, no bash 4+ needed)
  MOUNTED_GIT_DIRS=""
  while IFS='|' read -r name path; do
    local_path="$WORKSPACE/$path"
    if [[ -d "$local_path" ]]; then
      git_dir=$(resolve_worktree_mount "$local_path" || true)
      if [[ -n "$git_dir" ]] && ! echo "$MOUNTED_GIT_DIRS" | grep -qxF "$git_dir"; then
        echo "  Worktree ($name): mounting $git_dir"
        WORKTREE_MOUNT_ARGS+=(--mount "type=bind,source=$git_dir,target=$git_dir")
        MOUNTED_GIT_DIRS="${MOUNTED_GIT_DIRS}${git_dir}
"
      fi
    fi
  done < <(parse_workspace_repos "$WORKSPACE_MANIFEST" "$WORKSPACE")
else
  # Single-repo: check workspace itself
  if [[ -f "$WORKSPACE/.git" ]]; then
    git_dir=$(resolve_worktree_mount "$WORKSPACE" || true)
    if [[ -n "$git_dir" ]]; then
      echo "  Worktree detected: mounting $git_dir"
      WORKTREE_MOUNT_ARGS=(--mount "type=bind,source=$git_dir,target=$git_dir")
    fi
  fi
fi

# Copy Ralph devcontainer.json (editor container always uses Ralph generic image)
echo "  Config: using ralph defaults"
cp "$SCRIPT_DIR/.devcontainer/devcontainer.json" "$TEMP_DIR/.devcontainer/devcontainer.json"

# If services are configured, add --network=host so the container can reach
# host-side Docker Compose services via localhost
if [[ -f "$WORKSPACE/.ralph/services.md" ]]; then
  local_config="$TEMP_DIR/.devcontainer/devcontainer.json"
  # shellcheck disable=SC2016
  compose_enabled=$(grep '| enabled' "$WORKSPACE/.ralph/services.md" | sed 's/.*`\(.*\)`.*/\1/' 2>/dev/null || echo "")
  if [[ "$compose_enabled" == "true" || "$compose_enabled" == "yes" ]]; then
    echo "  Network: adding --network=host for service connectivity"
    jq '.runArgs = ((.runArgs // []) + ["--network=host"] | unique)' "$local_config" > "${local_config}.tmp" \
      && mv "${local_config}.tmp" "$local_config"
  fi
fi

# Copy ralph infrastructure files to workspace
# Scripts live inside the ralph-wiggum skill, so the parent dir IS the skill root.
SKILLS_DIR="$SCRIPT_DIR/.."
echo "Copying ralph infrastructure to workspace..."

# Copy PROMPT files if they don't exist (allow project overrides)
for prompt_file in PROMPT_plan.md PROMPT_build.md; do
  if [[ ! -f "$WORKSPACE/$prompt_file" ]]; then
    cp "$SKILLS_DIR/$prompt_file" "$WORKSPACE/$prompt_file"
    echo "  Copied: $prompt_file"
  else
    echo "  Skipped: $prompt_file (project override exists)"
  fi
done

# Start host-side Docker Compose services if configured
start_host_services() {
  local services_file="$WORKSPACE/.ralph/services.md"

  # Skip silently if no services configured
  if [[ ! -f "$services_file" ]]; then
    return 0
  fi

  echo "Checking external services..."

  # Parse Docker Compose settings from markdown table
  local compose_enabled compose_file
  # shellcheck disable=SC2016
  compose_enabled=$(grep '| enabled' "$services_file" | sed 's/.*`\(.*\)`.*/\1/' 2>/dev/null || echo "")
  # shellcheck disable=SC2016
  compose_file=$(grep '| file' "$services_file" | sed 's/.*`\(.*\)`.*/\1/' 2>/dev/null || echo "")

  if [[ "$compose_enabled" != "true" && "$compose_enabled" != "yes" ]]; then
    return 0
  fi

  local dc_file="${compose_file:-docker-compose.yml}"
  local dc_path="$WORKSPACE/$dc_file"

  if [[ ! -f "$dc_path" ]]; then
    echo "Warning: Docker Compose file '$dc_file' not found in workspace, skipping"
    return 0
  fi

  echo "  Starting Docker Compose services ($dc_file)..."
  docker compose -f "$dc_path" up -d || {
    echo "Error: docker compose up failed"
    return 1
  }

  # Run health checks
  local failed=0
  while IFS='|' read -r _ service command timeout _; do
    service=$(echo "$service" | xargs)
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

if ! start_host_services; then
  exit 1
fi

echo "Starting devcontainer..."
echo "  Workspace: $WORKSPACE"
echo "  Auth: oauth (from Keychain)"

# Start container with merged config and mount loop.sh + lib.sh + stream-output.sh
LOOP_MOUNT_ARGS=(--mount "type=bind,source=$SCRIPT_DIR/loop.sh,target=/opt/ralph/loop.sh" --mount "type=bind,source=$SCRIPT_DIR/lib.sh,target=/opt/ralph/lib.sh" --mount "type=bind,source=$SCRIPT_DIR/stream-output.sh,target=/opt/ralph/stream-output.sh")
devcontainer up --workspace-folder "$WORKSPACE" --config "$TEMP_DIR/.devcontainer/devcontainer.json" ${WORKTREE_MOUNT_ARGS[@]+"${WORKTREE_MOUNT_ARGS[@]}"} ${SSH_MOUNT_ARGS[@]+"${SSH_MOUNT_ARGS[@]}"} ${LOOP_MOUNT_ARGS[@]+"${LOOP_MOUNT_ARGS[@]}"}

# Execute loop inside container
CONFIG="$TEMP_DIR/.devcontainer/devcontainer.json"
if [[ ${#LOOP_ARGS[@]} -gt 0 ]]; then
  devcontainer exec --workspace-folder "$WORKSPACE" --config "$CONFIG" /opt/ralph/loop.sh "${LOOP_ARGS[@]}"
else
  devcontainer exec --workspace-folder "$WORKSPACE" --config "$CONFIG" /opt/ralph/loop.sh build
fi
