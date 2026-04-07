#!/usr/bin/env bash
#
# configure-child-auth.sh - Configure a workspace for GitHub App authentication
#
# Sets up git and gh CLI to use the Guardian worker app instead of the
# operator's personal credentials. Call this after worktrees are created.
#
# Usage:
#   configure-child-auth.sh <workspace_path> <repo1> [repo2 ...]
#
# What it does:
#   1. Switches worktree remotes from SSH to HTTPS
#   2. Configures git credential helper to use generate-app-token.sh
#   3. Appends GH_TOKEN setup to .envrc
#
# Exit codes:
#   0 - Success
#   1 - Invalid arguments
#   2 - Configuration failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOKEN_SCRIPT="$SCRIPT_DIR/generate-app-token.sh"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <workspace_path> <repo1> [repo2 ...]" >&2
  exit 1
fi

WORKSPACE_PATH="$1"
shift

if [[ ! -d "$WORKSPACE_PATH" ]]; then
  echo "Error: Workspace not found: $WORKSPACE_PATH" >&2
  exit 1
fi

if [[ ! -x "$TOKEN_SCRIPT" ]]; then
  echo "Error: Token script not found or not executable: $TOKEN_SCRIPT" >&2
  exit 1
fi

#------------------------------------------------------------------------------
# Configure each repo worktree
#------------------------------------------------------------------------------

for REPO in "$@"; do
  REPO_PATH="$WORKSPACE_PATH/$REPO"

  if [[ ! -d "$REPO_PATH" ]]; then
    echo "Warning: Repo worktree not found, skipping: $REPO_PATH" >&2
    continue
  fi

  echo "Configuring $REPO..."

  # Switch remote from SSH to HTTPS
  CURRENT_URL=$(git -C "$REPO_PATH" remote get-url origin 2>/dev/null || echo "")

  if [[ "$CURRENT_URL" == git@github.com:* ]]; then
    # Convert git@github.com:owner/repo.git -> https://github.com/owner/repo.git
    HTTPS_URL="${CURRENT_URL/git@github.com:/https://github.com/}"
    git -C "$REPO_PATH" remote set-url origin "$HTTPS_URL"
    echo "  Remote: $CURRENT_URL -> $HTTPS_URL"
  elif [[ "$CURRENT_URL" == https://* ]]; then
    echo "  Remote: already HTTPS"
  else
    echo "  Warning: Unrecognized remote URL format: $CURRENT_URL" >&2
  fi

  # Configure git credential helper for this repo
  EXPECTED_HELPER="!$TOKEN_SCRIPT --credential-helper"
  if git -C "$REPO_PATH" config --get-all credential.https://github.com.helper 2>/dev/null | grep -qF -- "--credential-helper"; then
    echo "  Credential helper: already configured"
  else
    git -C "$REPO_PATH" config --replace-all credential.https://github.com.helper "$EXPECTED_HELPER"
    echo "  Credential helper: configured"
  fi

  # Disable SSH signing if configured (app can't sign with SSH keys)
  git -C "$REPO_PATH" config --unset gpg.format 2>/dev/null || true
  git -C "$REPO_PATH" config --unset commit.gpgsign 2>/dev/null || true

  echo "  Done"
done

#------------------------------------------------------------------------------
# Append GH_TOKEN to .envrc
#------------------------------------------------------------------------------

ENVRC="$WORKSPACE_PATH/.envrc"

if [[ -f "$ENVRC" ]]; then
  if ! grep -q '# GitHub App authentication for child sessions' "$ENVRC"; then
    cat >> "$ENVRC" << EOF

# GitHub App authentication for child sessions
export GH_TOKEN=\$($TOKEN_SCRIPT)
refresh-gh-token() { . "$SCRIPT_DIR/refresh-gh-token.sh"; }
EOF
    echo "GH_TOKEN: added to .envrc"
  else
    echo "GH_TOKEN: already in .envrc"
  fi
fi

# Re-allow direnv
if command -v direnv &>/dev/null; then
  direnv allow "$WORKSPACE_PATH" 2>/dev/null || true
fi

echo ""
echo "Child auth configured for: $*"
echo "  Git: HTTPS + app credential helper"
echo "  gh:  GH_TOKEN via generate-app-token.sh"
