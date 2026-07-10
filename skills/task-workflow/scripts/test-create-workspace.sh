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
assert_eq "skills-reference-obsidian" "$slug" "issue #85 example: stop words filtered"

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
mkdir -p "$FIXTURE/src/github/Acme/claude-skills"
mkdir -p "$FIXTURE/src/github/Acme/only-in-acme"
mkdir -p "$FIXTURE/src/github/pfeff/only-in-pfeff"
mkdir -p "$FIXTURE/src/azdevops/acme/Infra/legacy-repo"

ORIG_HOME="$HOME"
export HOME="$FIXTURE"

# Qualified form resolves to the named owner.
path=$(resolve_repo_path "pfeff/claude-skills")
rc=$?
assert_rc 0 "$rc" "qualified pfeff/claude-skills returns 0"
assert_eq "$FIXTURE/src/github/pfeff/claude-skills" "$path" "qualified pfeff/claude-skills path"

path=$(resolve_repo_path "Acme/claude-skills")
rc=$?
assert_rc 0 "$rc" "qualified Acme/claude-skills returns 0"
assert_eq "$FIXTURE/src/github/Acme/claude-skills" "$path" "qualified Acme/claude-skills path"

# Qualified form pointing at a missing owner returns failure (no fallback).
path=$(resolve_repo_path "nobody/claude-skills")
rc=$?
assert_rc 1 "$rc" "qualified nonexistent owner returns 1"

# Path traversal attempts must be rejected, even when the resulting filesystem
# path would exist (e.g. `pfeff/..` resolves to `$HOME/src/github`).
mkdir -p "$FIXTURE/src/github/pfeff"  # parent dir exists
path=$(resolve_repo_path "pfeff/..")
rc=$?
assert_rc 1 "$rc" "qualified 'pfeff/..' rejected (path traversal)"

path=$(resolve_repo_path "../pfeff/claude-skills" 2>/dev/null)
rc=$?
# This one fails the regex outright (multiple slashes), but exercise it anyway.
assert_rc 1 "$rc" "'../pfeff/claude-skills' rejected"

path=$(resolve_repo_path "pfeff/.")
rc=$?
assert_rc 1 "$rc" "qualified 'pfeff/.' rejected"

path=$(resolve_repo_path "foo..bar/claude-skills")
rc=$?
assert_rc 1 "$rc" "qualified segment containing '..' rejected"

# Bare-name path traversal: '..' alone passes the existing char-class regex
# but must be rejected by the dedicated check.
path=$(resolve_repo_path "..")
rc=$?
assert_rc 1 "$rc" "bare-name '..' rejected"

path=$(resolve_repo_path ".")
rc=$?
assert_rc 1 "$rc" "bare-name '.' rejected"

# Ambiguous unqualified — claude-skills exists under both pfeff and Acme in
# the fixture. Document the alphabetical-first behavior (the exact scenario R2
# motivates) as a regression baseline.
path=$(resolve_repo_path "claude-skills")
case "$path" in
  "$FIXTURE/src/github/"*"/claude-skills")
    echo "  PASS: ambiguous unqualified resolves to one of the fixtures (alphabetical-first)"
    PASS=$((PASS + 1))
    ;;
  *)
    echo "  FAIL: ambiguous unqualified did not resolve under fixtures (got '$path')"
    FAIL=$((FAIL + 1))
    ;;
esac

# Unqualified Acme-only repo still resolves via glob fallback.
path=$(resolve_repo_path "only-in-acme")
assert_eq "$FIXTURE/src/github/Acme/only-in-acme" "$path" "Acme-only unqualified resolves"

# Unqualified pfeff-only repo resolves.
path=$(resolve_repo_path "only-in-pfeff")
assert_eq "$FIXTURE/src/github/pfeff/only-in-pfeff" "$path" "pfeff-only unqualified resolves"

# Unqualified azdevops fallback continues to work.
path=$(resolve_repo_path "legacy-repo")
assert_eq "$FIXTURE/src/azdevops/acme/Infra/legacy-repo" "$path" "azdevops fallback"

export HOME="$ORIG_HOME"

#------------------------------------------------------------------------------
# Meta mode - end-to-end (real subprocess, not sourced, against a fixture HOME)
#------------------------------------------------------------------------------

echo ""
echo "=== meta mode (end-to-end) ==="

META_FIXTURE=$(mktemp -d)
mkdir -p "$META_FIXTURE/src/work"
META_OUT=$(mktemp)

# --meta with no --repos: bare tracked directory + DESIGN.md stub only.
HOME="$META_FIXTURE" bash "$SCRIPT" --meta --name test-meta-ws --headline "Ephemeral test workspace" \
  >"$META_OUT" 2>&1
rc=$?
assert_rc 0 "$rc" "meta mode (no repos) exits 0"

META_WS="$META_FIXTURE/src/work/meta/test-meta-ws"
if [[ -d "$META_WS" ]]; then
  echo "  PASS: meta workspace directory created at \$HOME/src/work/meta/<name>"
  PASS=$((PASS + 1))
else
  echo "  FAIL: meta workspace directory not created"
  FAIL=$((FAIL + 1))
fi

assert_eq "# test-meta-ws: Ephemeral test workspace" "$(head -1 "$META_WS/DESIGN.md" 2>/dev/null)" \
  "meta DESIGN.md stub matches close-workspace.sh's expected '# id: headline' format"

# No tmuxp/CLAUDE.md/.envrc ceremony for meta mode.
if [[ ! -f "$META_WS/.tmuxp.yaml" && ! -f "$META_WS/CLAUDE.md" && ! -f "$META_WS/.envrc" ]]; then
  echo "  PASS: meta workspace has no tmuxp/CLAUDE.md/.envrc scaffolding"
  PASS=$((PASS + 1))
else
  echo "  FAIL: meta workspace unexpectedly contains task-mode scaffolding"
  FAIL=$((FAIL + 1))
fi

# close-workspace.sh must tear this down without any special-casing.
CLOSE_SCRIPT="$SCRIPT_DIR/close-workspace.sh"
bash "$CLOSE_SCRIPT" "$META_WS" --force --no-archive --no-close-issue </dev/null >"$META_OUT" 2>&1
rc=$?
assert_rc 0 "$rc" "close-workspace.sh tears down a meta workspace"

if [[ ! -d "$META_WS" ]]; then
  echo "  PASS: meta workspace removed by close-workspace.sh"
  PASS=$((PASS + 1))
else
  echo "  FAIL: meta workspace still exists after close-workspace.sh"
  FAIL=$((FAIL + 1))
fi

rm -rf "$META_FIXTURE" "$META_OUT"

# --meta with --name only (no --headline): defaults headline to name.
META_FIXTURE2=$(mktemp -d)
mkdir -p "$META_FIXTURE2/src/work"
META_OUT2=$(mktemp)
HOME="$META_FIXTURE2" bash "$SCRIPT" --meta --name bare-name-ws >"$META_OUT2" 2>&1
rc=$?
assert_rc 0 "$rc" "meta mode without --headline exits 0"
assert_eq "# bare-name-ws: bare-name-ws" \
  "$(head -1 "$META_FIXTURE2/src/work/meta/bare-name-ws/DESIGN.md" 2>/dev/null)" \
  "meta headline defaults to --name when omitted"
rm -rf "$META_FIXTURE2" "$META_OUT2"

# --meta without --name is a validation error (exit 1).
META_OUT3=$(mktemp)
rc=0
bash "$SCRIPT" --meta >"$META_OUT3" 2>&1 || rc=$?
assert_rc 1 "$rc" "meta mode without --name exits 1"
rm -f "$META_OUT3"
rm -f /tmp/meta-noname.out

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
