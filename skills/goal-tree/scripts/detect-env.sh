#!/bin/bash
# Detect environment for goal-tree backend selection
#
# Outputs:
#   "work"     - TCETRA hostname detected, use GOAL.md backend
#   "personal" - Non-TCETRA hostname, use coordinator backend
#
# Usage:
#   ENV=$(~/.claude/skills/goal-tree/scripts/detect-env.sh)
#   source ~/.claude/skills/goal-tree/scripts/detect-env.sh

if hostname | grep -q '^TCETRA'; then
    echo "work"
else
    echo "personal"
fi
