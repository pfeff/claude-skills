#!/bin/bash
# Detect environment for goal-tree backend selection
#
# Outputs:
#   "work"     - host runs in bootstrap mode (no coordinator), use GOAL.md backend
#   "personal" - coordinator-backed host, use coordinator backend
#
# Host-agnostic: this script names no specific machine. A host opts into
# bootstrap ("work") mode declaratively via its per-host config file, by
# setting GOAL_TREE_BACKEND=work in ~/.claude/hosts/<hostname>.md (or exporting
# GOAL_TREE_BACKEND=work in the environment). Any host without that opt-in, and
# with a reachable coordinator, uses the coordinator backend.
#
# Usage:
#   ENV=$(${CLAUDE_PLUGIN_ROOT}/skills/goal-tree/scripts/detect-env.sh)
#   source ${CLAUDE_PLUGIN_ROOT}/skills/goal-tree/scripts/detect-env.sh

if [ "${GOAL_TREE_BACKEND:-}" = "work" ]; then
    echo "work"
else
    echo "personal"
fi
