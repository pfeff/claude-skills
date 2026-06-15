#!/bin/bash
#
# Tests for ac-count
#
# Counts acceptance criteria in BOTH formats:
#   - canonical task format:  - [ ] **AC-N (...)** ...
#   - goal-tree/node format:  plain - [ ] <criterion> under an
#                             ## Acceptance Criteria heading
#
# A line counts as an AC if it is a `- [ ]`/`- [x]` checkbox AND
# (it contains `**AC-` anywhere, OR it is under an Acceptance-Criteria
# heading). Met = checked box OR contains `_(deferred`.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/ac-count"

PASS=0
FAIL=0

#------------------------------------------------------------------------------
# Helpers
#------------------------------------------------------------------------------

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
    echo "PASS: $desc"
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $desc"
    echo "      expected: [$expected]"
    echo "      actual:   [$actual]"
  fi
}

mkfile() {
  local f
  f="$(mktemp)"
  printf '%s' "$1" > "$f"
  echo "$f"
}

#------------------------------------------------------------------------------
# Fixtures
#------------------------------------------------------------------------------

# Canonical **AC-N** format: checked, unchecked, deferred
CANON=$(mkfile '# Task

## Acceptance Criteria

- [x] **AC-1 (foo)** done already
- [ ] **AC-2 (bar)** still open
- [ ] **AC-3 (baz)** _(deferred: not now)_ skip
')

# Plain node format under heading
NODE=$(mkfile '# Node

## Acceptance Criteria

- [ ] Enumerates the paths.
- [x] Lists the signals.
- [ ] Notes privacy.
')

# Checkboxes OUTSIDE the AC section must NOT count
OUTSIDE=$(mkfile '# Doc

## Acceptance Criteria

- [ ] Real criterion one.
- [x] Real criterion two.

## Tasks

- [ ] not an AC, a todo
- [x] another todo done
- [ ] yet another todo
')

# Mixed: canonical **AC-** anywhere counts even outside a heading
MIXED=$(mkfile '# Mixed

Some prose.

- [x] **AC-1 (inline)** counts despite no heading

## Acceptance Criteria

- [ ] plain one
- [ ] **AC-2 (under heading)** counts

## Notes

- [ ] **AC-3 (in notes)** still counts via marker
- [ ] just a note, no marker, not under AC heading
')

EMPTY=$(mkfile '# Nothing here

Just prose, no criteria.
')

#------------------------------------------------------------------------------
# Tests: met/total
#------------------------------------------------------------------------------

assert_eq "canonical: 2 met of 3 (checked + deferred both met)" "2 3" "$("$SCRIPT" "$CANON")"
assert_eq "node format: 1 met of 3" "1 3" "$("$SCRIPT" "$NODE")"
assert_eq "checkboxes outside AC section excluded" "1 2" "$("$SCRIPT" "$OUTSIDE")"
assert_eq "mixed canonical+node: 1 met of 4" "1 4" "$("$SCRIPT" "$MIXED")"
assert_eq "empty doc: 0 0" "0 0" "$("$SCRIPT" "$EMPTY")"

#------------------------------------------------------------------------------
# Tests: --open flag (open = total - met)
#------------------------------------------------------------------------------

assert_eq "--open canonical: 1 open (only AC-2)" "1" "$("$SCRIPT" --open "$CANON")"
assert_eq "--open node: 2 open" "2" "$("$SCRIPT" --open "$NODE")"
assert_eq "--open outside: 1 open" "1" "$("$SCRIPT" --open "$OUTSIDE")"
assert_eq "--open empty: 0 open" "0" "$("$SCRIPT" --open "$EMPTY")"

#------------------------------------------------------------------------------
# Tests: sum across multiple files
#------------------------------------------------------------------------------

assert_eq "sum two files met/total" "3 6" "$("$SCRIPT" "$CANON" "$NODE")"
assert_eq "sum two files --open" "3" "$("$SCRIPT" --open "$CANON" "$NODE")"

#------------------------------------------------------------------------------
# Tests: fail-soft on missing files
#------------------------------------------------------------------------------

assert_eq "missing file alone: 0 0" "0 0" "$("$SCRIPT" /no/such/file.md)"
assert_eq "missing file mixed with real: still counts real" "2 3" "$("$SCRIPT" /no/such/file.md "$CANON")"
assert_eq "missing file does not crash --open" "1" "$("$SCRIPT" --open "$CANON" /no/such/file.md)"

#------------------------------------------------------------------------------
# Summary
#------------------------------------------------------------------------------

rm -f "$CANON" "$NODE" "$OUTSIDE" "$MIXED" "$EMPTY"

echo
echo "Passed: $PASS  Failed: $FAIL"
[ "$FAIL" -eq 0 ]
