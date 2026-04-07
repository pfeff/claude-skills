#!/usr/bin/env bash
# Report PR and branch status across all repo worktrees in a project.
#
# Usage: workspace-pr-status.sh <project_dir>
#
# For each repo worktree, shows:
#   - Current branch
#   - Whether it has an open PR (and PR number/title if so)
#   - Commits ahead of main
#
# Requires: gh CLI authenticated

set -euo pipefail

PROJECT_DIR="${1:?Usage: workspace-pr-status.sh <project_dir>}"

shopt -s nullglob

# Cache: repo_name -> PR data (avoid repeated gh calls for same repo)
declare -A PR_CACHE

get_pr_for_branch() {
  local repo_dir="$1" branch="$2"

  # Determine remote owner/repo from origin URL
  local remote_url
  remote_url="$(git -C "$repo_dir" remote get-url origin 2>/dev/null || echo "")"
  if [[ -z "$remote_url" ]]; then
    echo "no-remote"
    return
  fi

  # Extract owner/repo from SSH or HTTPS URL
  local owner_repo
  owner_repo="$(echo "$remote_url" | sed -E 's#(git@github\.com:|https://github\.com/)##; s/\.git$//')"

  local cache_key="${owner_repo}:${branch}"
  if [[ -n "${PR_CACHE[$cache_key]+x}" ]]; then
    echo "${PR_CACHE[$cache_key]}"
    return
  fi

  local pr_info
  pr_info="$(gh pr list --repo "$owner_repo" --head "$branch" --state open --json number,title --jq '.[0] | "\(.number) \(.title)"' 2>/dev/null || echo "")"

  if [[ -z "$pr_info" ]]; then
    pr_info="none"
  fi

  PR_CACHE[$cache_key]="$pr_info"
  echo "$pr_info"
}

for node_dir in "$PROJECT_DIR"/*/; do
  NODE_ID="$(basename "$node_dir")"

  for repo_dir in "$node_dir"*/; do
    repo="$(basename "$repo_dir")"

    if [ -d "${repo_dir}/.git" ] || [ -f "${repo_dir}/.git" ]; then
      branch="$(git -C "$repo_dir" branch --show-current 2>/dev/null || echo "detached")"

      # Count commits ahead of main
      ahead="$(git -C "$repo_dir" rev-list --count main..HEAD 2>/dev/null || echo "?")"

      # Get PR status
      pr_info="$(get_pr_for_branch "$repo_dir" "$branch")"

      if [[ "$pr_info" == "none" ]]; then
        echo "${NODE_ID} ${repo} ${branch} ahead:${ahead} no-pr"
      elif [[ "$pr_info" == "no-remote" ]]; then
        echo "${NODE_ID} ${repo} ${branch} ahead:${ahead} no-remote"
      else
        echo "${NODE_ID} ${repo} ${branch} ahead:${ahead} PR#${pr_info}"
      fi
    fi
  done
done
