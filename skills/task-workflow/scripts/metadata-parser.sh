#!/usr/bin/env bash
# metadata-parser.sh - Parse DESIGN.md metadata
# Usage: metadata-parser.sh <design-file-path>
# Output: task_id|headline

set -euo pipefail

design_file="${1:-}"

if [ -z "$design_file" ]; then
  echo "Error: design file path required" >&2
  echo "Usage: metadata-parser.sh <design-file-path>" >&2
  exit 1
fi

if [ ! -f "$design_file" ]; then
  echo "Error: File not found: $design_file" >&2
  exit 1
fi

# Read first line
first_line=$(head -n 1 "$design_file" 2>/dev/null)

# Extract task-id and headline from pattern: # TASK-ID: Headline
task_id="${first_line%%:*}"
task_id="${task_id#\# }"
headline="${first_line#*: }"

# Validate extraction
if [ -z "$headline" ] || [ "$headline" = "$first_line" ]; then
  # Fallback: use whole line for both
  task_id="$first_line"
  headline="$first_line"
fi

# Output pipe-delimited
echo "$task_id|$headline"
