#!/bin/bash
#
# Tests for detect-workspace-kind.sh
#
# Uses tmp dirs and CURSOR_WORKTREES_ROOT / GITHUB_CLONES_ROOT overrides.
# Does not mutate the live ~/.cursor/worktrees tree.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/detect-workspace-kind.sh"

PASS=0
FAIL=0

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

assert_eq() {
  local expected="$1" actual="$2" name="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (expected '$expected', got '$actual')"
    FAIL=$((FAIL + 1))
  fi
}

assert_line() {
  local file="$1" pattern="$2" name="$3"
  if grep -qxF -- "$pattern" "$file"; then
    echo "  PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (missing exact line '$pattern')"
    echo "    stdout was:"
    sed 's/^/      /' "$file"
    FAIL=$((FAIL + 1))
  fi
}

run_detect() {
  local path="$1"
  local stdout_file="$2"
  local exit_code=0
  bash "$SCRIPT" "$path" >"$stdout_file" || exit_code=$?
  echo "$exit_code"
}

kind_of() {
  head -n 1 "$1"
}

echo "=== detect-workspace-kind.sh ==="
echo ""

#------------------------------------------------------------------------------
# Test 1: path prefix wins over a present CLAUDE.md
#------------------------------------------------------------------------------
echo "Test 1: Cursor worktree with CLAUDE.md is cursor-worktree"
cursor_root=$(mktemp -d)
export CURSOR_WORKTREES_ROOT="$cursor_root"
github_root=$(mktemp -d)
export GITHUB_CLONES_ROOT="$github_root"
wt="$cursor_root/dotfiles/feat-1"
mkdir -p "$wt"
echo "# repo CLAUDE.md" > "$wt/CLAUDE.md"
stdout=$(mktemp)
exit_code=$(run_detect "$wt" "$stdout")
assert_exit_code 0 "$exit_code" "exits 0"
assert_eq "cursor-worktree" "$(kind_of "$stdout")" "KIND is cursor-worktree"
assert_line "$stdout" "WORKSPACE_ROOT=$(cd "$wt" && pwd -P)" "WORKSPACE_ROOT is the worktree"
assert_line "$stdout" "WORKTREE_REPO=dotfiles" "WORKTREE_REPO=dotfiles"
assert_line "$stdout" "WORKTREE_NAME=feat-1" "WORKTREE_NAME=feat-1"
rm -rf "$cursor_root" "$github_root" "$stdout"

echo ""

#------------------------------------------------------------------------------
# Test 2: DESIGN.md at path is task-workspace
#------------------------------------------------------------------------------
echo "Test 2: DESIGN.md at path is task-workspace"
cursor_root=$(mktemp -d)
export CURSOR_WORKTREES_ROOT="$cursor_root"
github_root=$(mktemp -d)
export GITHUB_CLONES_ROOT="$github_root"
ws=$(mktemp -d)
echo "# 99: Test workspace" > "$ws/DESIGN.md"
echo "# workspace CLAUDE.md" > "$ws/CLAUDE.md"
stdout=$(mktemp)
exit_code=$(run_detect "$ws" "$stdout")
assert_exit_code 0 "$exit_code" "exits 0"
assert_eq "task-workspace" "$(kind_of "$stdout")" "KIND is task-workspace"
assert_line "$stdout" "WORKSPACE_ROOT=$(cd "$ws" && pwd -P)" "WORKSPACE_ROOT is the workspace"
if grep -q '^WORKTREE_REPO=' "$stdout"; then
  echo "  FAIL: task-workspace should not emit WORKTREE_REPO"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: no WORKTREE_REPO line"
  PASS=$((PASS + 1))
fi
rm -rf "$cursor_root" "$github_root" "$ws" "$stdout"

echo ""

#------------------------------------------------------------------------------
# Test 3: path under GITHUB_CLONES_ROOT is main-clone
#------------------------------------------------------------------------------
echo "Test 3: path under GITHUB_CLONES_ROOT is main-clone"
cursor_root=$(mktemp -d)
export CURSOR_WORKTREES_ROOT="$cursor_root"
github_root=$(mktemp -d)
export GITHUB_CLONES_ROOT="$github_root"
clone="$github_root/pfeff/claude-skills"
mkdir -p "$clone"
echo "# repo CLAUDE.md" > "$clone/CLAUDE.md"
stdout=$(mktemp)
exit_code=$(run_detect "$clone" "$stdout")
assert_exit_code 0 "$exit_code" "exits 0"
assert_eq "main-clone" "$(kind_of "$stdout")" "KIND is main-clone"
assert_line "$stdout" "WORKSPACE_ROOT=$(cd "$clone" && pwd -P)" "WORKSPACE_ROOT is the clone"
rm -rf "$cursor_root" "$github_root" "$stdout"

echo ""

#------------------------------------------------------------------------------
# Test 4: missing path is unknown
#------------------------------------------------------------------------------
echo "Test 4: missing path is unknown"
cursor_root=$(mktemp -d)
export CURSOR_WORKTREES_ROOT="$cursor_root"
github_root=$(mktemp -d)
export GITHUB_CLONES_ROOT="$github_root"
stdout=$(mktemp)
exit_code=$(run_detect "/does/not/exist-detect-workspace-kind-$$" "$stdout")
assert_exit_code 0 "$exit_code" "exits 0"
assert_eq "unknown" "$(kind_of "$stdout")" "KIND is unknown"
assert_line "$stdout" "WORKSPACE_ROOT=" "WORKSPACE_ROOT is empty"
rm -rf "$cursor_root" "$github_root" "$stdout"

echo ""

#------------------------------------------------------------------------------
# Test 5: DESIGN.md inside a Cursor worktree still yields cursor-worktree
#------------------------------------------------------------------------------
echo "Test 5: path prefix wins over DESIGN.md in a Cursor worktree"
cursor_root=$(mktemp -d)
export CURSOR_WORKTREES_ROOT="$cursor_root"
github_root=$(mktemp -d)
export GITHUB_CLONES_ROOT="$github_root"
wt="$cursor_root/claude-skills/with-design"
mkdir -p "$wt"
echo "# 1: Should not be a task workspace" > "$wt/DESIGN.md"
stdout=$(mktemp)
exit_code=$(run_detect "$wt" "$stdout")
assert_exit_code 0 "$exit_code" "exits 0"
assert_eq "cursor-worktree" "$(kind_of "$stdout")" "KIND is cursor-worktree"
assert_line "$stdout" "WORKTREE_REPO=claude-skills" "WORKTREE_REPO=claude-skills"
assert_line "$stdout" "WORKTREE_NAME=with-design" "WORKTREE_NAME=with-design"
rm -rf "$cursor_root" "$github_root" "$stdout"

echo ""

#------------------------------------------------------------------------------
# Test 6: subdirectory of a Cursor worktree reports the worktree root
#------------------------------------------------------------------------------
echo "Test 6: subdirectory of a Cursor worktree reports the worktree root"
cursor_root=$(mktemp -d)
export CURSOR_WORKTREES_ROOT="$cursor_root"
github_root=$(mktemp -d)
export GITHUB_CLONES_ROOT="$github_root"
wt="$cursor_root/dotfiles/feat-1"
mkdir -p "$wt/claude/commands"
echo "x" > "$wt/claude/commands/finish.md"
stdout=$(mktemp)
exit_code=$(run_detect "$wt/claude/commands" "$stdout")
assert_exit_code 0 "$exit_code" "exits 0"
assert_eq "cursor-worktree" "$(kind_of "$stdout")" "KIND is cursor-worktree"
assert_line "$stdout" "WORKSPACE_ROOT=$(cd "$wt" && pwd -P)" "WORKSPACE_ROOT is the worktree root"
assert_line "$stdout" "WORKTREE_REPO=dotfiles" "WORKTREE_REPO=dotfiles"
assert_line "$stdout" "WORKTREE_NAME=feat-1" "WORKTREE_NAME=feat-1"
rm -rf "$cursor_root" "$github_root" "$stdout"

echo ""

#------------------------------------------------------------------------------
# Test 7: incomplete Cursor path (repo only, no worktree name) is unknown
#------------------------------------------------------------------------------
echo "Test 7: ~/.cursor/worktrees/<repo> without a worktree name is unknown"
cursor_root=$(mktemp -d)
export CURSOR_WORKTREES_ROOT="$cursor_root"
github_root=$(mktemp -d)
export GITHUB_CLONES_ROOT="$github_root"
mkdir -p "$cursor_root/dotfiles"
stdout=$(mktemp)
exit_code=$(run_detect "$cursor_root/dotfiles" "$stdout")
assert_exit_code 0 "$exit_code" "exits 0"
assert_eq "unknown" "$(kind_of "$stdout")" "KIND is unknown"
rm -rf "$cursor_root" "$github_root" "$stdout"

echo ""

#------------------------------------------------------------------------------
# Test 8: empty tmp dir with neither DESIGN.md nor clone/worktree prefix
#------------------------------------------------------------------------------
echo "Test 8: empty directory is unknown"
cursor_root=$(mktemp -d)
export CURSOR_WORKTREES_ROOT="$cursor_root"
github_root=$(mktemp -d)
export GITHUB_CLONES_ROOT="$github_root"
empty=$(mktemp -d)
stdout=$(mktemp)
exit_code=$(run_detect "$empty" "$stdout")
assert_exit_code 0 "$exit_code" "exits 0"
assert_eq "unknown" "$(kind_of "$stdout")" "KIND is unknown"
assert_line "$stdout" "WORKSPACE_ROOT=$(cd "$empty" && pwd -P)" "WORKSPACE_ROOT is the empty dir"
rm -rf "$cursor_root" "$github_root" "$empty" "$stdout"

echo ""

#------------------------------------------------------------------------------
# Test 9: DESIGN.md inside a main clone is still main-clone
#------------------------------------------------------------------------------
echo "Test 9: github-clone prefix wins over DESIGN.md"
cursor_root=$(mktemp -d)
export CURSOR_WORKTREES_ROOT="$cursor_root"
github_root=$(mktemp -d)
export GITHUB_CLONES_ROOT="$github_root"
clone="$github_root/pfeff/claude-skills"
mkdir -p "$clone"
echo "# 1: Should not be a task workspace" > "$clone/DESIGN.md"
stdout=$(mktemp)
exit_code=$(run_detect "$clone" "$stdout")
assert_exit_code 0 "$exit_code" "exits 0"
assert_eq "main-clone" "$(kind_of "$stdout")" "KIND is main-clone"
assert_line "$stdout" "WORKSPACE_ROOT=$(cd "$clone" && pwd -P)" "WORKSPACE_ROOT is the clone"
rm -rf "$cursor_root" "$github_root" "$stdout"

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
