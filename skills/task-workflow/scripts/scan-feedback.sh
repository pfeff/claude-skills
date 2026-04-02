#!/usr/bin/env bash
# Scan completed workspaces for FEEDBACK.md files and summarize entries.
#
# Usage: scan-feedback.sh <work_dir> [--verbose]
#
# Searches all workspace directories under <work_dir> for FEEDBACK.md files.
# Reports which workspaces have feedback and summarizes entry counts.
#
# Output:
#   <workspace> <section> <count> entries
#
# With --verbose, also prints entry content.

set -euo pipefail

WORK_DIR="${1:?Usage: scan-feedback.sh <work_dir> [--verbose]}"
VERBOSE=false

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose) VERBOSE=true; shift ;;
    *) echo "error: unknown option '$1'" >&2; exit 1 ;;
  esac
done

found=0

while IFS= read -r feedback_file; do
  found=$((found + 1))
  workspace="$(dirname "$feedback_file")"
  workspace_name="$(basename "$workspace")"

  # Count non-empty, non-comment lines under each section
  friction=$(grep -c '^\- \*\*pattern\*\*' "$feedback_file" 2>/dev/null || echo 0)
  tools=$(grep -c '^\- \*\*tool\*\*' "$feedback_file" 2>/dev/null || echo 0)
  patterns=$(grep -c '^\- \*\*pattern\*\*' "$feedback_file" 2>/dev/null || echo 0)

  total=$((friction + tools + patterns))

  if [[ "$total" -gt 0 ]]; then
    echo "${workspace_name}: ${total} entries (friction:${friction} tools:${tools} patterns:${patterns})"

    if [[ "$VERBOSE" == "true" ]]; then
      echo "  File: ${feedback_file}"
      # Print non-comment, non-empty content lines
      grep -v '^$\|^#\|^<!--' "$feedback_file" | sed 's/^/    /' || true
      echo ""
    fi
  else
    echo "${workspace_name}: FEEDBACK.md present but empty"
  fi
done < <(find "$WORK_DIR" -maxdepth 3 -name "FEEDBACK.md" -type f 2>/dev/null)

if [[ "$found" -eq 0 ]]; then
  echo "No FEEDBACK.md files found in ${WORK_DIR}"
fi

echo ""
echo "Total: ${found} workspace(s) with FEEDBACK.md"
