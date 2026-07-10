#!/bin/bash
#
# Tests for close-workspace.sh TTY detection guards and task-id resolution
#
# Verifies that non-interactive mode (no TTY) is handled gracefully
# rather than failing with an opaque exit code from `read`, and that
# numeric/Jira-style task-id lookups in ~/src/work resolve correctly
# regardless of letter case.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/close-workspace.sh"

PASS=0
FAIL=0

#------------------------------------------------------------------------------
# Test helpers
#------------------------------------------------------------------------------

make_workspace() {
  local dir
  dir=$(mktemp -d)
  # Minimal DESIGN.md to pass validation
  echo "# 99: Test workspace" > "$dir/DESIGN.md"
  echo "$dir"
}

make_goal_workspace() {
  local dir
  dir=$(mktemp -d)
  # GOAL.md uses em-dash separator: "# <task-id> — <headline>"
  echo "# 99 — Goal-tree workspace" > "$dir/GOAL.md"
  echo "$dir"
}

make_empty_workspace() {
  mktemp -d
}

# Creates a workspace directory under ~/src/work/<epic>/<task_id>-<slug>, matching
# the layout close-workspace.sh's TASK_ID lookup (`find ~/src/work -maxdepth 2 ...`)
# searches. Echoes the created workspace directory path.
make_jira_workspace() {
  local task_id="$1"
  local epic_dir
  epic_dir="$HOME/src/work/test-close-workspace-$$-$RANDOM"
  mkdir -p "$epic_dir"
  local dir="$epic_dir/${task_id}-testtask"
  mkdir -p "$dir"
  echo "# ${task_id}: Test workspace" > "$dir/DESIGN.md"
  echo "$dir"
}

assert_exit_code() {
  local expected="$1" actual="$2" name="$3"
  if [[ "$actual" -eq "$expected" ]]; then
    echo "  PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (expected exit $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

assert_stderr_contains() {
  local pattern="$1" stderr_file="$2" name="$3"
  if grep -qF -- "$pattern" "$stderr_file"; then
    echo "  PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (stderr missing '$pattern')"
    echo "    stderr was: $(cat "$stderr_file")"
    FAIL=$((FAIL + 1))
  fi
}

#------------------------------------------------------------------------------
# Tests
#------------------------------------------------------------------------------

echo "=== close-workspace.sh TTY detection tests ==="
echo ""

# Test 1: Non-interactive without --force exits with EXIT_INVALID_ARGS
echo "Test 1: Non-interactive without --force"
ws=$(make_workspace)
stderr_file=$(mktemp)
exit_code=0
bash "$SCRIPT" "$ws" --no-archive --no-close-issue </dev/null 2>"$stderr_file" || exit_code=$?
assert_exit_code 1 "$exit_code" "exits with code 1"
assert_stderr_contains "Non-interactive mode" "$stderr_file" "stderr contains guidance"
assert_stderr_contains "--force" "$stderr_file" "stderr mentions --force flag"
rm -rf "$ws" "$stderr_file"

echo ""

# Test 2: Non-interactive with --force succeeds
echo "Test 2: Non-interactive with --force"
ws=$(make_workspace)
stderr_file=$(mktemp)
exit_code=0
bash "$SCRIPT" "$ws" --force --no-archive --no-close-issue </dev/null 2>"$stderr_file" || exit_code=$?
assert_exit_code 0 "$exit_code" "exits with code 0"
rm -rf "$ws" "$stderr_file"

echo ""

# Test 3: CWD safety check in non-interactive mode without --force
echo "Test 3: CWD safety check non-interactive"
ws=$(make_workspace)
stderr_file=$(mktemp)
exit_code=0
bash "$SCRIPT" "$ws" --caller-cwd "$ws" --no-archive --no-close-issue </dev/null 2>"$stderr_file" || exit_code=$?
assert_exit_code 1 "$exit_code" "CWD check exits with code 1"
assert_stderr_contains "Non-interactive mode" "$stderr_file" "CWD check stderr contains guidance"
rm -rf "$ws" "$stderr_file"

echo ""

# Test 4: CWD safety check with --force bypasses both prompts
echo "Test 4: CWD safety check with --force"
ws=$(make_workspace)
stderr_file=$(mktemp)
exit_code=0
bash "$SCRIPT" "$ws" --caller-cwd "$ws" --force --no-archive --no-close-issue </dev/null 2>"$stderr_file" || exit_code=$?
assert_exit_code 0 "$exit_code" "CWD check with --force exits 0"
rm -rf "$ws" "$stderr_file"

echo ""

# Test 5: Workspace directory is removed after --force close
echo "Test 5: Workspace removed after close"
ws=$(make_workspace)
exit_code=0
bash "$SCRIPT" "$ws" --force --no-archive --no-close-issue </dev/null 2>/dev/null || exit_code=$?
if [[ ! -d "$ws" ]]; then
  echo "  PASS: workspace directory removed"
  PASS=$((PASS + 1))
else
  echo "  FAIL: workspace directory still exists"
  FAIL=$((FAIL + 1))
  rm -rf "$ws"
fi

echo ""

# Test 6: Non-interactive without --force does NOT remove workspace directory
echo "Test 6: Non-interactive without --force preserves workspace"
ws=$(make_workspace)
exit_code=0
bash "$SCRIPT" "$ws" --no-archive --no-close-issue </dev/null 2>/dev/null || exit_code=$?
if [[ -d "$ws" ]]; then
  echo "  PASS: workspace directory preserved (not deleted)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: workspace directory was deleted without confirmation!"
  FAIL=$((FAIL + 1))
fi
rm -rf "$ws"

echo ""

# Test 7: Fail-fast message appears before any workspace output
echo "Test 7: Fail-fast exits before workspace processing"
ws=$(make_workspace)
stdout_file=$(mktemp)
stderr_file=$(mktemp)
exit_code=0
bash "$SCRIPT" "$ws" --no-archive --no-close-issue </dev/null >"$stdout_file" 2>"$stderr_file" || exit_code=$?
# Should NOT see "Workspace:" in stdout (never reached Step 1 output)
if grep -qF "Workspace:" "$stdout_file"; then
  echo "  FAIL: script proceeded past fail-fast gate"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: script exited before workspace processing"
  PASS=$((PASS + 1))
fi
rm -rf "$ws" "$stdout_file" "$stderr_file"

echo ""

# Test 8: GOAL.md fallback closes workspace and parses task-id/headline
echo "Test 8: GOAL.md fallback parses metadata and closes workspace"
ws=$(make_goal_workspace)
stdout_file=$(mktemp)
stderr_file=$(mktemp)
exit_code=0
bash "$SCRIPT" "$ws" --force --no-archive --no-close-issue </dev/null >"$stdout_file" 2>"$stderr_file" || exit_code=$?
assert_exit_code 0 "$exit_code" "GOAL.md fallback exits 0"
if grep -qF "Task:     99 - Goal-tree workspace" "$stdout_file"; then
  echo "  PASS: GOAL.md task-id and headline parsed"
  PASS=$((PASS + 1))
else
  echo "  FAIL: GOAL.md metadata not parsed correctly"
  echo "    stdout was:"
  sed 's/^/      /' "$stdout_file"
  FAIL=$((FAIL + 1))
fi
if [[ ! -d "$ws" ]]; then
  echo "  PASS: GOAL.md workspace removed"
  PASS=$((PASS + 1))
else
  echo "  FAIL: GOAL.md workspace still exists"
  FAIL=$((FAIL + 1))
  rm -rf "$ws"
fi
rm -rf "$stdout_file" "$stderr_file"

echo ""

# Test 9: Missing both DESIGN.md and GOAL.md exits with EXIT_WORKSPACE_NOT_FOUND
echo "Test 9: Missing both DESIGN.md and GOAL.md exits 2"
ws=$(make_empty_workspace)
stderr_file=$(mktemp)
exit_code=0
bash "$SCRIPT" "$ws" --force --no-archive --no-close-issue </dev/null 2>"$stderr_file" || exit_code=$?
assert_exit_code 2 "$exit_code" "exits with EXIT_WORKSPACE_NOT_FOUND"
assert_stderr_contains "No DESIGN.md or GOAL.md" "$stderr_file" "stderr names both files"
rm -rf "$ws" "$stderr_file"

echo ""

# Test 10: Jira-style task-id (uppercase) resolves via ~/src/work lookup and closes end-to-end
echo "Test 10: Jira-style task-id (uppercase) resolves and closes workspace"
task_id="ZZTEST-$RANDOM"
ws=$(make_jira_workspace "$task_id")
epic_dir=$(dirname "$ws")
stdout_file=$(mktemp)
stderr_file=$(mktemp)
exit_code=0
bash "$SCRIPT" "$task_id" --force --no-archive --no-close-issue </dev/null >"$stdout_file" 2>"$stderr_file" || exit_code=$?
assert_exit_code 0 "$exit_code" "uppercase Jira-id exits 0"
if grep -qF "Workspace: $ws" "$stdout_file"; then
  echo "  PASS: resolved to the created workspace"
  PASS=$((PASS + 1))
else
  echo "  FAIL: did not resolve to $ws"
  echo "    stdout was:"
  sed 's/^/      /' "$stdout_file"
  FAIL=$((FAIL + 1))
fi
if [[ ! -d "$ws" ]]; then
  echo "  PASS: workspace directory removed"
  PASS=$((PASS + 1))
else
  echo "  FAIL: workspace directory still exists"
  FAIL=$((FAIL + 1))
fi
rm -rf "$ws" "$epic_dir" "$stdout_file" "$stderr_file"

echo ""

# Test 11: lowercase/mixed-case Jira-style task-id normalizes to uppercase and
# resolves to the SAME workspace an uppercase form would (regression: the
# task-id validation regex accepts lowercase, but workspace directories are
# always created with uppercase Jira keys, so the lookup must uppercase the
# letter portion before searching).
echo "Test 11: lowercase/mixed-case Jira-style task-id resolves to same workspace"
task_id="ZZTEST-$RANDOM"
ws=$(make_jira_workspace "$task_id")
epic_dir=$(dirname "$ws")
lower_id=$(echo "$task_id" | tr '[:upper:]' '[:lower:]')
stdout_file=$(mktemp)
stderr_file=$(mktemp)
exit_code=0
bash "$SCRIPT" "$lower_id" --force --no-archive --no-close-issue </dev/null >"$stdout_file" 2>"$stderr_file" || exit_code=$?
assert_exit_code 0 "$exit_code" "lowercase Jira-id exits 0"
if grep -qF "Workspace: $ws" "$stdout_file"; then
  echo "  PASS: lowercase id resolved to the uppercase-named workspace"
  PASS=$((PASS + 1))
else
  echo "  FAIL: lowercase id did not resolve to $ws"
  echo "    stdout was:"
  sed 's/^/      /' "$stdout_file"
  FAIL=$((FAIL + 1))
fi
if [[ ! -d "$ws" ]]; then
  echo "  PASS: workspace directory removed"
  PASS=$((PASS + 1))
else
  echo "  FAIL: workspace directory still exists"
  FAIL=$((FAIL + 1))
fi
rm -rf "$ws" "$epic_dir" "$stdout_file" "$stderr_file"

echo ""

#------------------------------------------------------------------------------
# Summary
#------------------------------------------------------------------------------

TOTAL=$((PASS + FAIL))
echo "=========================================="
echo "Results: $PASS/$TOTAL passed"
if [[ "$FAIL" -gt 0 ]]; then
  echo "$FAIL FAILED"
  exit 1
fi
echo "All tests passed!"
