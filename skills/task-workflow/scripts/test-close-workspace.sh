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

# Test 11: lowercase/mixed-case Jira-style task-id resolves to the SAME workspace
# an uppercase form would (regression: the task-id validation regex accepts
# lowercase, but workspace directories are typically created with uppercase Jira
# keys, so the lookup must match case-insensitively — workspace-locator.sh uses
# `find -iname`, not case normalization of the query).
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

# Test 12: Jira-style task-id with a digit immediately after the first letter
# (e.g. "AB2-345") resolves correctly. Regression: the task-id regex used to
# require the letter-portion to be letters-only, rejecting real Jira keys
# like this one and falling through to "Not a valid path or task-id".
echo "Test 12: Jira-style task-id with digit after first letter resolves"
task_id="ZZ2$RANDOM-345"
ws=$(make_jira_workspace "$task_id")
epic_dir=$(dirname "$ws")
stdout_file=$(mktemp)
stderr_file=$(mktemp)
exit_code=0
bash "$SCRIPT" "$task_id" --force --no-archive --no-close-issue </dev/null >"$stdout_file" 2>"$stderr_file" || exit_code=$?
assert_exit_code 0 "$exit_code" "digit-after-letter task-id exits 0"
if grep -qF "Workspace: $ws" "$stdout_file"; then
  echo "  PASS: resolved to the created workspace"
  PASS=$((PASS + 1))
else
  echo "  FAIL: did not resolve to $ws"
  echo "    stdout was:"
  sed 's/^/      /' "$stdout_file"
  echo "    stderr was:"
  sed 's/^/      /' "$stderr_file"
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

# Test 13: workspace directory actually created with a lowercase/mixed-case
# name (simulating a workspace created from a lowercase/mixed-case task-id,
# since create-workspace.sh does not normalize case) resolves when queried
# with a different case, e.g. uppercase. Regression: the previous fix
# uppercased the query and did a case-sensitive `find -name`, which would
# never match a lowercase-named directory.
echo "Test 13: lowercase-named workspace directory resolves when queried uppercase"
dir_task_id="zzmixed$RANDOM-7"
ws=$(make_jira_workspace "$dir_task_id")
epic_dir=$(dirname "$ws")
query_id=$(echo "$dir_task_id" | tr '[:lower:]' '[:upper:]')
stdout_file=$(mktemp)
stderr_file=$(mktemp)
exit_code=0
bash "$SCRIPT" "$query_id" --force --no-archive --no-close-issue </dev/null >"$stdout_file" 2>"$stderr_file" || exit_code=$?
assert_exit_code 0 "$exit_code" "uppercase query against lowercase dir exits 0"
if grep -qF "Workspace: $ws" "$stdout_file"; then
  echo "  PASS: uppercase query resolved to the lowercase-named workspace"
  PASS=$((PASS + 1))
else
  echo "  FAIL: uppercase query did not resolve to $ws"
  echo "    stdout was:"
  sed 's/^/      /' "$stdout_file"
  echo "    stderr was:"
  sed 's/^/      /' "$stderr_file"
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

# Test 14: ambiguous task-id (matches workspaces in two different epics)
# errors out rather than silently picking one, per workspace-locator.sh's
# multi-match detection (which close-workspace.sh now delegates to instead
# of its own inline `find | head -1`).
echo "Test 14: ambiguous task-id errors instead of silently picking a match"
task_id="ZZDUP$RANDOM-1"
ws1=$(make_jira_workspace "$task_id")
epic_dir1=$(dirname "$ws1")
epic_dir2="$HOME/src/work/test-close-workspace-dup-$$-$RANDOM"
mkdir -p "$epic_dir2"
ws2="$epic_dir2/${task_id}-othertask"
mkdir -p "$ws2"
echo "# ${task_id}: Test workspace 2" > "$ws2/DESIGN.md"
stderr_file=$(mktemp)
exit_code=0
bash "$SCRIPT" "$task_id" --force --no-archive --no-close-issue </dev/null 2>"$stderr_file" || exit_code=$?
assert_exit_code 2 "$exit_code" "ambiguous task-id exits with EXIT_WORKSPACE_NOT_FOUND"
assert_stderr_contains "Multiple workspaces found" "$stderr_file" "stderr reports multiple matches"
if [[ -d "$ws1" && -d "$ws2" ]]; then
  echo "  PASS: neither workspace was touched"
  PASS=$((PASS + 1))
else
  echo "  FAIL: a workspace was removed despite ambiguity"
  FAIL=$((FAIL + 1))
fi
rm -rf "$ws1" "$epic_dir1" "$ws2" "$epic_dir2" "$stderr_file"

echo ""

# Test 15: ambiguous match WITHIN a specified epic errors instead of silently
# picking the first (epic-scoped branch of workspace-locator.sh). Case-insensitive
# `find -iname` makes collisions like FOO-1-old / foo-1-new possible in one epic
# dir, so the epic branch must apply the same multi-match guard as the no-epic
# branch. The specify-epic remediation the no-epic branch points to is exactly
# this path, so it must not itself silently guess.
echo "Test 15: ambiguous match within a specified epic errors"
LOCATOR="$SCRIPT_DIR/workspace-locator.sh"
task_id="ZZEPICDUP$RANDOM-1"
epic="test-close-workspace-epicdup-$$-$RANDOM"
epic_dir="$HOME/src/work/$epic"
mkdir -p "$epic_dir/${task_id}-old"
lower_id=$(echo "$task_id" | tr '[:upper:]' '[:lower:]')
mkdir -p "$epic_dir/${lower_id}-new"
stdout_file=$(mktemp)
stderr_file=$(mktemp)
exit_code=0
bash "$LOCATOR" "$task_id" "$epic" >"$stdout_file" 2>"$stderr_file" || exit_code=$?
assert_exit_code 1 "$exit_code" "epic-scoped ambiguous match exits 1"
assert_stderr_contains "Multiple workspaces found" "$stderr_file" "epic-scoped stderr reports multiple matches"
if [[ ! -s "$stdout_file" ]]; then
  echo "  PASS: no workspace path emitted on stdout"
  PASS=$((PASS + 1))
else
  echo "  FAIL: emitted a path despite ambiguity: $(cat "$stdout_file")"
  FAIL=$((FAIL + 1))
fi
rm -rf "$epic_dir" "$stdout_file" "$stderr_file"

echo ""

# Test 16: task-id matching no workspace, resolved through the
# close-workspace.sh -> workspace-locator.sh delegation path, returns the
# not-found exit code. This delegation path replaced previously-inline
# not-found handling and otherwise had no coverage.
echo "Test 16: unmatched task-id via delegation exits not-found"
task_id="ZZNOPE$RANDOM-9"
stderr_file=$(mktemp)
exit_code=0
bash "$SCRIPT" "$task_id" --force --no-archive --no-close-issue </dev/null 2>"$stderr_file" || exit_code=$?
assert_exit_code 2 "$exit_code" "unmatched task-id exits EXIT_WORKSPACE_NOT_FOUND"
rm -rf "$stderr_file"

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
