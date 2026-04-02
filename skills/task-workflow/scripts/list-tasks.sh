#!/bin/bash
# Extract task workspace data from ~/src/work
# Outputs: status|epic|task_id|headline|checked|total|workspace

# Find all workspaces with DESIGN.md (no maxdepth - they can be at various depths)
find ~/src/work -type f -name "DESIGN.md" 2>/dev/null | while IFS= read -r design_file; do
  workspace=$(dirname "$design_file")

  # Extract task ID and headline from first line of DESIGN.md
  first_line=$(head -n 1 "$design_file" 2>/dev/null)
  task_id=$(echo "$first_line" | sed 's/^# \([^:]*\):.*/\1/')
  headline=$(echo "$first_line" | sed 's/^# [^:]*: \(.*\)/\1/')

  # If sed didn't extract anything (malformed format), use the whole line
  if [ -z "$headline" ] || [ "$headline" = "$first_line" ]; then
    task_id="$first_line"
    headline="$first_line"
  fi

  # Extract epic from path (directory under ~/src/work/)
  epic=$(echo "$workspace" | sed 's|.*/src/work/\([^/]*\)/.*|\1|')

  # Check PLAN.md status
  plan_file="$workspace/PLAN.md"
  if [ ! -f "$plan_file" ]; then
    status="no-plan"
    checked=""
    total=""
  else
    # Use wc -l instead of grep -c to avoid empty string issues
    unchecked=$(grep "^- \[ \]" "$plan_file" 2>/dev/null | wc -l)
    checked=$(grep "^- \[x\]" "$plan_file" 2>/dev/null | wc -l)
    total=$((unchecked + checked))

    if [ $total -eq 0 ]; then
      status="no-todos"
    elif [ $unchecked -gt 0 ]; then
      status="in-progress"
    else
      status="completed"
    fi
  fi

  # Output format: status|epic|task_id|headline|checked|total|workspace
  echo "$status|$epic|$task_id|$headline|$checked|$total|$workspace"
done | sort -t'|' -k2,2 -k3,3
