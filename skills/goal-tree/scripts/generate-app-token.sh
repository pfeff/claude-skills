#!/usr/bin/env bash
#
# generate-app-token.sh - Generate a GitHub App installation access token
#
# Reads app credentials from ~/.config/guardian/app-config.env, creates a JWT,
# and exchanges it for an installation token via the GitHub API. Caches the
# token until 5 minutes before expiry. Validates cached tokens against
# GET /rate_limit before returning — revoked tokens trigger regeneration.
# Fails open on network errors (returns cached token if validation unreachable).
#
# Usage:
#   generate-app-token.sh                  # print token to stdout
#   generate-app-token.sh --credential-helper  # git credential helper mode
#
# Exit codes:
#   0 - Success
#   1 - Missing config or dependencies
#   2 - JWT generation failed
#   3 - Token exchange failed

set -euo pipefail

CONFIG_FILE="$HOME/.config/guardian/app-config.env"
CACHE_FILE="$HOME/.config/guardian/.token-cache"

#------------------------------------------------------------------------------
# Load config
#------------------------------------------------------------------------------

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: Config not found: $CONFIG_FILE" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

# Expand $HOME in key path
GUARDIAN_APP_KEY="${GUARDIAN_APP_KEY/#\$HOME/$HOME}"

if [[ ! -f "$GUARDIAN_APP_KEY" ]]; then
  echo "Error: Private key not found: $GUARDIAN_APP_KEY" >&2
  exit 1
fi

#------------------------------------------------------------------------------
# Check cache
#------------------------------------------------------------------------------

# Validate a token against the GitHub API. Returns 0 if valid, 1 if revoked.
# Fails open on network errors — a timeout or non-401 error returns 0.
validate_token() {
  local token="$1"
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/rate_limit") || return 0
  if [[ "$http_code" == "401" ]]; then
    return 1
  fi
  return 0
}

get_cached_token() {
  if [[ -f "$CACHE_FILE" ]]; then
    local cached_expiry cached_token
    cached_expiry=$(head -1 "$CACHE_FILE")
    cached_token=$(tail -1 "$CACHE_FILE")
    local now
    now=$(date +%s)
    # Valid if more than 5 minutes remain
    if [[ "$cached_expiry" -gt $((now + 300)) ]] && [[ -n "$cached_token" ]]; then
      # Validate the token hasn't been revoked server-side
      if validate_token "$cached_token"; then
        echo "$cached_token"
        return 0
      else
        echo "Cached token revoked, regenerating..." >&2
        rm -f "$CACHE_FILE"
        return 1
      fi
    fi
  fi
  return 1
}

if token=$(get_cached_token); then
  if [[ "${1:-}" == "--credential-helper" ]]; then
    # Git credential helper protocol
    echo "username=x-access-token"
    echo "password=$token"
    echo ""
  else
    echo "$token"
  fi
  exit 0
fi

#------------------------------------------------------------------------------
# Generate JWT
#------------------------------------------------------------------------------

# Base64url encode (no padding, URL-safe)
b64url() {
  openssl base64 -e | tr -d '=' | tr '/+' '_-' | tr -d '\n'
}

NOW=$(date +%s)
IAT=$((NOW - 60))
EXP=$((NOW + 600))

HEADER=$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)
PAYLOAD=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' "$IAT" "$EXP" "$GUARDIAN_APP_ID" | b64url)

SIGNATURE=$(printf '%s.%s' "$HEADER" "$PAYLOAD" | \
  openssl dgst -sha256 -sign "$GUARDIAN_APP_KEY" | b64url)

JWT="$HEADER.$PAYLOAD.$SIGNATURE"

#------------------------------------------------------------------------------
# Exchange JWT for installation token
#------------------------------------------------------------------------------

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Bearer $JWT" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/app/installations/$GUARDIAN_INSTALLATION_ID/access_tokens")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" != "201" ]]; then
  echo "Error: Token exchange failed (HTTP $HTTP_CODE)" >&2
  echo "$BODY" >&2
  exit 3
fi

TOKEN=$(echo "$BODY" | jq -r '.token')
EXPIRES_AT=$(echo "$BODY" | jq -r '.expires_at')

if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
  echo "Error: No token in response" >&2
  echo "$BODY" >&2
  exit 3
fi

#------------------------------------------------------------------------------
# Cache token
#------------------------------------------------------------------------------

# Convert ISO 8601 expiry to epoch
if date -j -f "%Y-%m-%dT%H:%M:%SZ" "$EXPIRES_AT" +%s &>/dev/null 2>&1; then
  # macOS date
  EXPIRY_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$EXPIRES_AT" +%s)
elif date -d "$EXPIRES_AT" +%s &>/dev/null 2>&1; then
  # GNU date
  EXPIRY_EPOCH=$(date -d "$EXPIRES_AT" +%s)
else
  # Fallback: 55 minutes from now
  EXPIRY_EPOCH=$((NOW + 3300))
fi

install -m 600 /dev/null "$CACHE_FILE"
printf '%s\n%s\n' "$EXPIRY_EPOCH" "$TOKEN" > "$CACHE_FILE"

#------------------------------------------------------------------------------
# Output
#------------------------------------------------------------------------------

if [[ "${1:-}" == "--credential-helper" ]]; then
  echo "username=x-access-token"
  echo "password=$TOKEN"
  echo ""
else
  echo "$TOKEN"
fi
