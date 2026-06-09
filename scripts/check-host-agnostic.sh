#!/bin/sh
# check-host-agnostic.sh — fail if published content leaks host-specific or
# private-instance details.
#
# This plugin is public and host-agnostic. Committed skill/doc content must not
# carry absolute home/laptop paths, a specific machine hostname, or the author's
# private-instance repo. This script greps the published trees for those patterns
# and exits non-zero (printing file:line) on the first class that hits.
#
# Runnable locally:  sh scripts/check-host-agnostic.sh
# CI invokes it the same way (see .github/workflows/host-agnostic-lint.yml).
#
# Scope is deliberately narrow to avoid false positives. The following are NOT
# leaks and are intentionally allowed:
#   - ${CLAUDE_PLUGIN_ROOT}, $HOME-relative and ~/.claude/... install paths
#   - generic placeholders: /home/user/, /home/runner/ (CI), <owner>/<repo>, etc.
#   - the schema/runtime vocabulary guardian_issue / --guardian-issue /
#     GUARDIAN_APP* / ~/.config/guardian (the coordinator API + GitHub App
#     identifiers — renaming them changes behavior)
#   - host env-detection vocabulary (TCETRA, /mbp/) that drives functional
#     backend selection

set -eu

# Directories of published content to scan. Override for local experiments.
DIRS="${HOST_AGNOSTIC_DIRS:-skills docs}"

status=0

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

# 2. Specific machine hostname literal.
report "machine hostname literal (mbp2018)" \
  'mbp2018'

# 3. Author's private-instance repo. The bare word "guardian" is allowed where
#    it is schema/app vocabulary (guardian_issue, GUARDIAN_APP, ~/.config/guardian);
#    flag only the private repo slug and private path segments.
report "private repo slug (pfeff/guardian)" \
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
