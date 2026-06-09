#!/bin/sh
# check-host-agnostic.sh — fail if published content leaks host-specific or
# private-instance details.
#
# This plugin is public and host-agnostic. Committed skill/doc content must not
# carry absolute home/laptop paths, a private machine hostname, or the author's
# private-instance repo. This script greps the published trees for those patterns
# and exits non-zero (printing file:line) on the first class that hits.
#
# Runnable locally:  sh scripts/check-host-agnostic.sh
# CI invokes it the same way (see .github/workflows/host-agnostic-lint.yml).
#
# Host-agnostic by construction: this script itself names NO private hostname.
# The private-hostname blocklist is sourced from the running host, never from a
# literal embedded here (that would itself be a leak):
#   1. Basenames of the host's ~/.claude/hosts/*.md config files (each file is
#      named for a host the operator runs on). The ".md" and "-setup" suffixes
#      are stripped, e.g. "<host>-setup.md" and "<host>.md" -> token "<host>".
#   2. Plus any tokens listed (one per line) in a host-local, gitignored
#      scripts/.private-tokens file. See scripts/.private-tokens.example.
# A token blocks both its literal and lower-cased form in published content.
#
# Scope is deliberately narrow to avoid false positives. The following are NOT
# leaks and are intentionally allowed:
#   - ${CLAUDE_PLUGIN_ROOT}, $HOME-relative and ~/.claude/... install paths
#   - generic placeholders: /home/user/, /home/runner/ (CI), <owner>/<repo>, etc.
#   - the schema/runtime vocabulary guardian_issue / --guardian-issue /
#     GUARDIAN_APP* / ~/.config/guardian (the coordinator API + GitHub App
#     identifiers — renaming them changes behavior)

set -eu

# Directories of published content to scan. Override for local experiments.
DIRS="${HOST_AGNOSTIC_DIRS:-skills docs}"

# Where to discover private-host tokens. Overridable for testing.
HOSTS_DIR="${HOST_AGNOSTIC_HOSTS_DIR:-$HOME/.claude/hosts}"
TOKENS_FILE="${HOST_AGNOSTIC_TOKENS_FILE:-scripts/.private-tokens}"

status=0

# --- Build the private-hostname blocklist from the running host ---------------
# Emit one token per line, deduped, comments/blanks stripped.
private_tokens() {
  {
    if [ -d "$HOSTS_DIR" ]; then
      for f in "$HOSTS_DIR"/*.md; do
        [ -e "$f" ] || continue
        b=$(basename "$f" .md)
        # Strip a trailing "-setup" so "<host>-setup.md" and "<host>.md" collapse.
        b=${b%-setup}
        [ -n "$b" ] && echo "$b"
      done
    fi
    if [ -f "$TOKENS_FILE" ]; then
      # Drop comment and blank lines.
      grep -vE '^\s*(#|$)' "$TOKENS_FILE" 2>/dev/null || true
    fi
  } | sort -u
}

# Compose an alternation pattern matching each token literally and lower-cased.
# Empty if no tokens were discovered.
build_host_pattern() {
  pat=""
  while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    lower=$(printf '%s' "$tok" | tr '[:upper:]' '[:lower:]')
    for v in "$tok" "$lower"; do
      if [ -z "$pat" ]; then
        pat="$v"
      else
        pat="$pat|$v"
      fi
    done
  done <<EOF
$(private_tokens)
EOF
  printf '%s' "$pat"
}

# Only scan trees that exist (docs/ or skills/ may be absent in some checkouts).
scan_dirs=""
for d in $DIRS; do
  [ -d "$d" ] && scan_dirs="$scan_dirs $d"
done
if [ -z "$scan_dirs" ]; then
  echo "check-host-agnostic: no scan directories found ($DIRS); nothing to check"
  exit 0
fi

# report NAME PATTERN [GREP-V-FILTER]
# Prints any matching file:line and flips status to 1 on a hit.
report() {
  name="$1"
  pattern="$2"
  filter="${3:-}"

  [ -n "$pattern" ] || return 0

  if [ -n "$filter" ]; then
    # shellcheck disable=SC2086
    hits=$(grep -rnE "$pattern" $scan_dirs 2>/dev/null | grep -vE "$filter" || true)
  else
    # shellcheck disable=SC2086
    hits=$(grep -rnE "$pattern" $scan_dirs 2>/dev/null || true)
  fi

  if [ -n "$hits" ]; then
    echo "LEAK: $name"
    echo "$hits" | sed 's/^/  /'
    status=1
  fi
}

# 1. Absolute home/laptop paths. Allow the generic example/runner paths.
report "absolute home/laptop path (/Users/<name> or /home/<name>)" \
  '/Users/[A-Za-z]|/home/[A-Za-z]' \
  '/home/user/|/home/runner/'

# 2. Private machine hostname literals, discovered from the running host's
#    ~/.claude/hosts/ config (and scripts/.private-tokens). Names no host here.
host_pattern=$(build_host_pattern)
if [ -z "$host_pattern" ]; then
  echo "check-host-agnostic: no private-host tokens discovered" \
       "($HOSTS_DIR, $TOKENS_FILE); skipping hostname check"
else
  report "private machine hostname literal" "$host_pattern"
fi

# 3. Author's private-instance repo. The bare word "guardian" is allowed where
#    it is schema/app vocabulary (guardian_issue, GUARDIAN_APP, ~/.config/guardian);
#    flag only the private repo slug and private path segments.
report "private repo slug (private-org/guardian)" \
  'pfeff/guardian'

report "private-instance path segment (Caches/guardian, .../github/<o>/guardian, work/guardian)" \
  '(Caches|/work)/guardian([/\"[:space:]]|$)|github/[A-Za-z0-9_.-]+/guardian([/\"[:space:]]|$)'

if [ "$status" -ne 0 ]; then
  echo ""
  echo "Host-specific or private-instance content found in published files."
  echo "Genericize to discovery rules / \$HOME-relative / \${CLAUDE_PLUGIN_ROOT} /"
  echo "<placeholder> before committing. See scripts/check-host-agnostic.sh for the"
  echo "allowed (non-violation) patterns."
fi

exit "$status"
