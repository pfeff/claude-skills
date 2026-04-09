#!/usr/bin/env bash
# Compute baseline metrics from finish.jsonl, grouped by epic.
# Outputs baselines.jsonl with mean/stddev for each numeric metric.
#
# Usage: seed-baselines.sh [--threshold N]
#   --threshold N  Number of stddevs to flag as regression (default: 1)

set -euo pipefail

METRICS_DIR=~/src/work/.metrics
FINISH_FILE="$METRICS_DIR/finish.jsonl"
BASELINES_FILE="$METRICS_DIR/baselines.jsonl"
THRESHOLD=1

if [[ "${1:-}" == "--threshold" ]]; then
  THRESHOLD="${2:-1}"
fi

if [[ ! -f "$FINISH_FILE" ]]; then
  echo "Error: $FINISH_FILE not found" >&2
  exit 1
fi

jq -s --argjson threshold "$THRESHOLD" '
  group_by(.epic) | map(
    . as $rows |
    ($rows | length) as $n |
    ($rows[0].epic) as $epic |

    # elapsed_hours: filter entries that have the field
    ($rows | map(select(.elapsed_hours != null) | .elapsed_hours)) as $hrs |
    ($hrs | if length > 0 then add / length else 0 end) as $hrs_avg |
    ($hrs | if length > 1 then
      (map(. - $hrs_avg | . * .) | add / (length - 1) | sqrt)
    else 0 end) as $hrs_std |

    # review_rounds
    ($rows | map(select(.review_rounds != null) | .review_rounds)) as $rvw |
    ($rvw | if length > 0 then add / length else 0 end) as $rvw_avg |
    ($rvw | if length > 1 then
      (map(. - $rvw_avg | . * .) | add / (length - 1) | sqrt)
    else 0 end) as $rvw_std |

    # task_count
    ($rows | map(.task_count // 0)) as $tc |
    ($tc | if length > 0 then add / length else 0 end) as $tc_avg |
    ($tc | if length > 1 then
      (map(. - $tc_avg | . * .) | add / (length - 1) | sqrt)
    else 0 end) as $tc_std |

    {
      epic: $epic,
      sample_size: $n,
      computed_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
      elapsed_hours_avg: ($hrs_avg * 10 | round / 10),
      elapsed_hours_stddev: ($hrs_std * 10 | round / 10),
      review_rounds_avg: ($rvw_avg * 10 | round / 10),
      review_rounds_stddev: ($rvw_std * 10 | round / 10),
      task_count_avg: ($tc_avg * 10 | round / 10),
      task_count_stddev: ($tc_std * 10 | round / 10),
      regression_threshold: $threshold
    }
  ) | .[] ' "$FINISH_FILE" | jq -c '.' > "$BASELINES_FILE"

EPIC_COUNT=$(wc -l < "$BASELINES_FILE" | tr -d ' ')
echo "Wrote $EPIC_COUNT baselines to $BASELINES_FILE"
