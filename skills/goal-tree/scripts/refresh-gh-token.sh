#!/usr/bin/env bash
#
# refresh-gh-token.sh - Refresh GH_TOKEN in the current shell
#
# Source this script when gh CLI returns auth errors (tokens expire after ~1h):
#   . refresh-gh-token.sh
#
# Do NOT run with `bash refresh-gh-token.sh` — the export won't persist.

_REFRESH_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_REFRESH_TOKEN_SCRIPT="$_REFRESH_SCRIPT_DIR/generate-app-token.sh"

if [[ ! -x "$_REFRESH_TOKEN_SCRIPT" ]]; then
  echo "Error: generate-app-token.sh not found at $_REFRESH_TOKEN_SCRIPT" >&2
  unset _REFRESH_SCRIPT_DIR _REFRESH_TOKEN_SCRIPT
  return 1 2>/dev/null || true
fi

if ! _REFRESH_NEW_TOKEN=$("$_REFRESH_TOKEN_SCRIPT") || [[ -z "$_REFRESH_NEW_TOKEN" ]]; then
  echo "Error: Failed to generate fresh token" >&2
  unset _REFRESH_SCRIPT_DIR _REFRESH_TOKEN_SCRIPT _REFRESH_NEW_TOKEN
  return 1 2>/dev/null || true
fi

export GH_TOKEN="$_REFRESH_NEW_TOKEN"
echo "GH_TOKEN refreshed" >&2

unset _REFRESH_SCRIPT_DIR _REFRESH_TOKEN_SCRIPT _REFRESH_NEW_TOKEN
