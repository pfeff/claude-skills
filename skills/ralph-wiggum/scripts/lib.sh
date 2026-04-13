#!/bin/bash
# Shared library for Ralph Wiggum scripts
# Sourced by loop.sh and run-container.sh

# Detect workspace mode from manifest presence
# Sets WORKSPACE_MODE ("single" or "multi")
detect_workspace_mode() {
  local manifest="${1:-.ralph/workspace.md}"
  if [[ -f "$manifest" ]]; then
    echo "multi"
  else
    echo "single"
  fi
}

# Validate a repo path from workspace manifest
# Returns 0 if path is safe, 1 if not
validate_repo_path() {
  local path="$1"
  local base_dir="${2:-.}"

  # Reject empty paths
  [[ -z "$path" ]] && return 1

  # Reject absolute paths
  [[ "$path" = /* ]] && return 1

  # Reject paths with .. components
  if echo "$path" | grep -q '\.\.'; then
    echo "  Error: repo path '$path' contains '..' (rejected)" >&2
    return 1
  fi

  # Verify resolved path is within base directory
  local resolved
  resolved="$(cd "$base_dir" && realpath -m "$path" 2>/dev/null || echo "$base_dir/$path")"
  local abs_base
  abs_base="$(cd "$base_dir" && pwd)"

  case "$resolved" in
    "$abs_base"/*)
      return 0
      ;;
    *)
      echo "  Error: repo path '$path' resolves outside workspace (rejected)" >&2
      return 1
      ;;
  esac
}

# Parse repo paths from workspace manifest
# Returns lines of "repo_name|repo_path"
# Args: $1 = manifest path (default: .ralph/workspace.md)
#        $2 = base directory for path validation (default: .)
parse_workspace_repos() {
  local manifest="${1:-.ralph/workspace.md}"
  local base_dir="${2:-.}"

  if [[ ! -f "$manifest" ]]; then
    return 1
  fi

  # Parse the Repos table: | repo_name | `repo_path` | `gates_path` |
  grep '|.*|.*|.*|' "$manifest" | grep -v '^\s*|.*---' | while IFS='|' read -r _ name path _rest; do
    name=$(echo "$name" | xargs)
    # Single quotes intentional: matching literal backticks
    # shellcheck disable=SC2016
    path=$(echo "$path" | sed 's/^ *`//;s/` *$//' | xargs)

    [[ -z "$name" || "$name" == "Repo" ]] && continue
    [[ -z "$path" ]] && continue

    # Validate path safety
    if ! validate_repo_path "$path" "$base_dir"; then
      continue
    fi

    echo "${name}|${path}"
  done
}
