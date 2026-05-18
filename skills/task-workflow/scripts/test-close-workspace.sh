#!/bin/bash
#
# Tests for close-workspace.sh TTY detection guards
#
# Verifies that non-interactive mode (no TTY) is handled gracefully
# rather than failing with an opaque exit code from `read`.

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
