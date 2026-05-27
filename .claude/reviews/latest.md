---
target: PR #96
timestamp: 2026-05-27T18:00:00Z
agents: 4
degraded: false
blocking: 1
advisory: 7
verdict: BLOCKING
---

## Review Summary

**Target**: PR #96 — Apply 2026-05-27 lessons-learned recs
**Agents**: 4 (security, simplicity, architecture, correctness)
**Verdict**: BLOCKING — 1 issue must be resolved

### Blocking

- **skills/task-workflow/scripts/create-workspace.sh:679** — [correctness] _correctness_ — Git worktree pre-commit hooks are installed in the wrong directory. For `git worktree add`, `ACTUAL_GIT` resolves to `<main>/.git/worktrees/<name>`, so `HOOKS_DIR="$ACTUAL_GIT/hooks"` writes to `<main>/.git/worktrees/<name>/hooks/`. Git does NOT consult that path for hook execution in worktrees — it reads hooks from `<main>/.git/hooks/` only (absent `core.hooksPath`). The installed hook will never fire, making REC-001 entirely non-functional. Fix: derive main hooks dir from `ACTUAL_GIT`: `HOOKS_DIR="$(dirname "$(dirname "$ACTUAL_GIT")")/hooks"`. Same issue at line 1014 (node mode).

### Advisory

- **skills/task-workflow/scripts/create-workspace.sh:694** — [correctness] _idempotency_ (warning) — Hook append has no duplicate guard. If `create-workspace.sh` is re-run (e.g. after a partial failure), the assert invocation is appended again, causing the check to run multiple times per commit. Add `grep -qF "$ASSERT_SCRIPT" "$HOOK_FILE" ||` before the append.
- **skills/task-workflow/scripts/create-workspace.sh:1034** — [architecture] _completeness_ (info) — Node mode hook block (lines 1020–1034) has no `else` branch when `$ASSERT_SCRIPT` is not executable. Task mode (line 707) emits `WARNING:` to stderr. Node mode silently skips install — the REC-001 guard is absent with no indication. Add a matching `else` warning.
- **skills/task-workflow/scripts/create-workspace.sh:671** — [architecture] _dead-code_ (warning) — `HOOK_TARGET="$worktree_path/.git"` is assigned but never read; all downstream code uses `ACTUAL_GIT`/`HOOKS_DIR`. Remove the assignment.
- **skills/task-workflow/scripts/create-workspace.sh:1008** — [simplicity] _duplication_ (warning) — The entire hook-install block is duplicated verbatim between task mode (~lines 669–709) and node mode (~lines 1008–1035). Extract to a helper function `install_worktree_branch_hook "$worktree_path"`.
- **skills/task-workflow/scripts/assert-worktree-branch.sh:106** — [architecture] _misleading-docs_ (warning) — Help text says "set ASSERT_WORKTREE_BRANCH_WARN_ONLY=0 to block on unknown patterns" but 0 is the default blocking value. Operators following this advice see no change. Should read "set ASSERT_WORKTREE_BRANCH_WARN_ONLY=1 to downgrade to a warning" (consistent with line 119 and default=0 at line 29).
- **skills/task-workflow/scripts/assert-worktree-branch.sh:47** — [simplicity] _dead-code_ (warning) — `WORKTREE_BASENAME="$(basename "$WORKTREE_ROOT")"` is computed (spawns a subprocess) but never referenced anywhere in the script. Remove it.
- **skills/task-workflow/scripts/assert-worktree-branch.sh:89** — [simplicity] _dead-code_ (warning) — Check 3's second `grep -qF "/$NODE_ID."` is unreachable: any branch matching `/$NODE_ID.` already matches `/$NODE_ID` (line 85). With `-F` the dot is a literal character, not a wildcard — the intent (match any char after NODE_ID) is unachieved. Remove lines 88–91.
