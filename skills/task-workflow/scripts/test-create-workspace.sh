#!/bin/bash
#
# Tests for create-workspace.sh helpers: generate_slug, resolve_repo_path
#
# Sources create-workspace.sh with minimal valid args; the script's dispatcher
# is guarded so create_task_workspace does not actually run when sourced.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/create-workspace.sh"

PASS=0
FAIL=0

assert_eq() {
  local expected="$1" actual="$2" name="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name"
    echo "    expected: '$expected'"
    echo "    actual:   '$actual'"
    FAIL=$((FAIL + 1))
  fi
}

assert_rc() {
  local expected="$1" actual="$2" name="$3"
  if [[ "$actual" -eq "$expected" ]]; then
    echo "  PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (expected rc $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

assert_slug_excludes() {
  local needle="$1" slug="$2" name="$3"
  case "-$slug-" in
    *-"$needle"-*)
      echo "  FAIL: $name (slug '$slug' still contains stop word '$needle')"
      FAIL=$((FAIL + 1))
      ;;
    *)
      echo "  PASS: $name"
      PASS=$((PASS + 1))
      ;;
  esac
}

# Source the script. The dispatcher guard prevents create_task_workspace from
# running; the args just satisfy validation so the function definitions load.
# shellcheck disable=SC1090
source "$SCRIPT" --task-id 0 --epic test --headline test
# Sourced script enables `set -e`; turn it off so failed assertions don't abort.
set +e

#------------------------------------------------------------------------------
# generate_slug
#------------------------------------------------------------------------------

echo "=== generate_slug ==="

# Issue #85 example: stop words at the front must not leak into the slug.
slug=$(generate_slug "Update skills that reference Obsidian vault symlink to use CLI")
assert_slug_excludes "update" "$slug" "issue #85: 'update' filtered"
assert_slug_excludes "that"   "$slug" "issue #85: 'that' filtered"
assert_slug_excludes "to"     "$slug" "issue #85: 'to' filtered"

# Mid-sentence stop words are also filtered, slug fills to 3 content tokens.
slug=$(generate_slug "Fix the auth timeout in the gateway")
assert_eq "fix-auth-timeout" "$slug" "filters mid-sentence 'the' and 'in'"

# No stop words present: behavior unchanged (regression).
slug=$(generate_slug "Implement octopus deploy notifier")
assert_eq "implement-octopus-deploy" "$slug" "no stop words: first 3 tokens unchanged"

# All stop words: fall back to raw first-N tokens so the slug is never empty.
slug=$(generate_slug "the and or")
assert_eq "the-and-or" "$slug" "all stop words: fallback to raw tokens"

# Sprinkled stop words: skip them to fill 3 content slots.
slug=$(generate_slug "Add a feature and an extra knob")
assert_eq "add-feature-extra" "$slug" "skips mid-sentence stop words to fill 3 slots"

#------------------------------------------------------------------------------
# resolve_repo_path
#------------------------------------------------------------------------------

echo ""
echo "=== resolve_repo_path ==="

# Fixture filesystem; point $HOME at it so the function's ~/src/... globs
# resolve against fixtures rather than the developer's real tree.
FIXTURE=$(mktemp -d)
trap 'rm -rf "$FIXTURE"' EXIT
mkdir -p "$FIXTURE/src/github/pfeff/claude-skills"
mkdir -p "$FIXTURE/src/github/Tcetra/claude-skills"
mkdir -p "$FIXTURE/src/github/Tcetra/only-in-tcetra"
mkdir -p "$FIXTURE/src/github/pfeff/only-in-pfeff"
mkdir -p "$FIXTURE/src/azdevops/tcetra/Infra/legacy-repo"

ORIG_HOME="$HOME"
export HOME="$FIXTURE"

# Qualified form resolves to the named owner.
path=$(resolve_repo_path "pfeff/claude-skills")
rc=$?
assert_rc 0 "$rc" "qualified pfeff/claude-skills returns 0"
assert_eq "$FIXTURE/src/github/pfeff/claude-skills" "$path" "qualified pfeff/claude-skills path"

path=$(resolve_repo_path "Tcetra/claude-skills")
rc=$?
assert_rc 0 "$rc" "qualified Tcetra/claude-skills returns 0"
assert_eq "$FIXTURE/src/github/Tcetra/claude-skills" "$path" "qualified Tcetra/claude-skills path"

# Qualified form pointing at a missing owner returns failure (no fallback).
path=$(resolve_repo_path "nobody/claude-skills")
rc=$?
assert_rc 1 "$rc" "qualified nonexistent owner returns 1"

# Unqualified Tcetra-only repo still resolves via glob fallback.
path=$(resolve_repo_path "only-in-tcetra")
assert_eq "$FIXTURE/src/github/Tcetra/only-in-tcetra" "$path" "Tcetra-only unqualified resolves"

# Unqualified pfeff-only repo resolves.
path=$(resolve_repo_path "only-in-pfeff")
assert_eq "$FIXTURE/src/github/pfeff/only-in-pfeff" "$path" "pfeff-only unqualified resolves"

# Unqualified azdevops fallback continues to work.
path=$(resolve_repo_path "legacy-repo")
assert_eq "$FIXTURE/src/azdevops/tcetra/Infra/legacy-repo" "$path" "azdevops fallback"

export HOME="$ORIG_HOME"

#------------------------------------------------------------------------------
# Summary
#------------------------------------------------------------------------------

echo ""
TOTAL=$((PASS + FAIL))
echo "=========================================="
echo "Results: $PASS/$TOTAL passed"
if [[ "$FAIL" -gt 0 ]]; then
  echo "$FAIL FAILED"
  exit 1
fi
echo "All tests passed!"
