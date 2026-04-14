#!/usr/bin/env bash
#
# patch-finish-metrics.sh — Patch finish.jsonl entries with evaluation metrics.
#
# Closes the sequencing gap: /finish writes finish.jsonl before execute-tree
# evaluates, so entries lack criteria fields. This script patches the matching
# entry after evaluation.json is written.
#
# Usage:
#   patch-finish-metrics.sh <node-workspace> <node-id>
#
# Arguments:
#   node-workspace  Path to the node workspace containing .metrics/evaluation.json
#   node-id         Node ID (e.g., "C.3.6") used to match the finish.jsonl entry
#
# Environment:
#   FINISH_JSONL    Override finish.jsonl location (default: ~/src/work/.metrics/finish.jsonl)
#
# Backfill: Historical finish.jsonl entries (C.2.1–C.2.6, C.3.2, C.3.5, etc.)
# lack evaluation metrics because L1 evaluation was not run at close-out time.
# These entries are not backfilled — they retain value as timeline markers showing
# when metric collection began. The first entry with metrics is C.2.9. Future
# entries will be patched automatically by calling this script after evaluation.
#
# Exit codes:
#   0 - Success (patched or nothing to patch)
#   1 - Invalid arguments
#   2 - evaluation.json not found or invalid

set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

NODE_WORKSPACE="${1:-}"
NODE_ID="${2:-}"

[[ -n "$NODE_WORKSPACE" ]] || die "usage: patch-finish-metrics.sh <node-workspace> <node-id>"
[[ -n "$NODE_ID" ]] || die "usage: patch-finish-metrics.sh <node-workspace> <node-id>"

EVAL_FILE="${NODE_WORKSPACE}/.metrics/evaluation.json"
FINISH_JSONL="${FINISH_JSONL:-${HOME}/src/work/.metrics/finish.jsonl}"

# Guard: evaluation.json must exist
[[ -f "$EVAL_FILE" ]] || die "evaluation.json not found: $EVAL_FILE"

# Guard: finish.jsonl must exist
if [[ ! -f "$FINISH_JSONL" ]]; then
  echo "finish.jsonl not found at $FINISH_JSONL — skipping patch"
  exit 0
fi

# Validate evaluation.json is valid JSON with required fields
jq -e '.criteria_passed and .criteria_total' "$EVAL_FILE" >/dev/null 2>&1 \
  || die "evaluation.json missing required fields (criteria_passed, criteria_total): $EVAL_FILE"

# Patch: update matching entries that lack criteria fields
tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

jq -c --arg tid "$NODE_ID" --slurpfile eval "$EVAL_FILE" '
  if (.task_id == $tid and .criteria_passed == null) then
    . + {
      criteria_passed: $eval[0].criteria_passed,
      criteria_total: $eval[0].criteria_total,
      acceptance_rate: $eval[0].acceptance_rate
    } + (
      if ($eval[0].standing_rules | length) > 0 then {
        rules_passed: ([$eval[0].standing_rules[] | select(.status == "pass")] | length),
        rules_total: ($eval[0].standing_rules | length),
        rules_pass_rate: (([$eval[0].standing_rules[] | select(.status == "pass")] | length) / ($eval[0].standing_rules | length))
      } else {} end
    )
  else . end
' "$FINISH_JSONL" > "$tmpfile"

# Verify the output is valid before replacing
line_count_before=$(wc -l < "$FINISH_JSONL")
line_count_after=$(wc -l < "$tmpfile")
[[ "$line_count_before" -eq "$line_count_after" ]] \
  || die "line count mismatch: $line_count_before -> $line_count_after (aborting)"

mv "$tmpfile" "$FINISH_JSONL"
trap - EXIT

echo "Patched finish.jsonl entry for task_id=$NODE_ID with evaluation metrics"
