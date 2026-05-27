# L1 Review Protocol

Executable review protocol for L1 sessions. Invoked when a child session pushes a PR for a dispatched node.

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `pr_number` | Yes | PR number to review |
| `repo` | Yes | Repository in `owner/repo` format |
| `node_id` | Yes | Coordinator node ID |
| `tree_id` | Yes | Coordinator tree ID |
| `workspace_path` | No | Path to the node workspace (for reading DESIGN.md) |

## Protocol

### 1. Gather PR metadata

```bash
gh pr view $PR_NUMBER --repo $REPO --json files,additions,deletions,headRefName,baseRefName,title,body,state,mergeable,statusCheckRollup
```

### 2. Read the full diff

```bash
gh pr diff $PR_NUMBER --repo $REPO
```

### 3. Load the node spec

Load acceptance criteria from one of these sources (in priority order):

1. `$WORKSPACE_PATH/DESIGN.md` (if workspace_path provided and file exists)
2. Coordinator node description: `coord node get $TREE_ID $NODE_ID`
3. PR body (fallback — may contain spec summary)

Extract:
- Acceptance criteria checklist
- Requirements section
- Standing rules from project CLAUDE.md (if accessible)

### 4. Evaluate against acceptance criteria

For each acceptance criterion, assess pass/fail against the diff:

```
## L1 Review: PR #$PR_NUMBER ($REPO)

### Spec Compliance

| # | Criterion | Verdict | Evidence |
|---|-----------|---------|----------|
| 1 | <criterion text> | PASS/FAIL | <specific file:line or diff hunk reference> |
| 2 | <criterion text> | PASS/FAIL | <evidence> |

### Quality Checks

| Check | Verdict | Notes |
|-------|---------|-------|
| Tests present and covering key claims | PASS/FAIL | <test files, coverage notes> |
| Security concerns (injection, secrets, OWASP) | PASS/FAIL | <findings or "none detected"> |
| CI status (if available) | PASS/FAIL/PENDING | <check names and states — FAIL: attempt autonomous fix; if not fixable cheaply, ESCALATE to operator; do not merge with red CI without explicit operator override> |
| Code matches spec architecture | PASS/FAIL | <structural alignment notes> |

### Summary

- **Criteria passed**: N/M
- **Quality checks passed**: N/M
- **Verdict**: APPROVE / REJECT / ESCALATE
- **Reason**: <1-2 sentence summary>
```

### 5. Decision

#### Approve

All criteria pass and no quality check failures:

```bash
# Merge the PR
gh pr merge $PR_NUMBER --repo $REPO --merge --admin

# If repo is agent-coordinator: deploy
if [[ "$REPO" == */agent-coordinator ]]; then
  # Pull latest main
  cd $AC_REPO_PATH
  git pull origin main

  # Build release
  mix deps.get --only prod
  MIX_ENV=prod mix release --overwrite

  # Run migrations
  MIX_ENV=prod mix ecto.migrate

  # Restart the service
  launchctl kickstart -k gui/$(id -u)/com.pfeff.agent-coordinator

  # Verify health
  sleep 3
  curl -sf http://localhost:4000/api/health || echo "WARNING: Health check failed after deploy"
fi

# Update coordinator
coord node update $TREE_ID $NODE_ID --status completed --result "PR #$PR_NUMBER merged. <changes summary>"
```

#### Escalate (CI blocked)

CI is red and cannot be made green autonomously or without great expense. Surface to operator; do not merge.

```bash
gh pr comment $PR_NUMBER --repo $REPO --body "## L1 Review: ESCALATE — CI Blocked

CI is not green and cannot be resolved autonomously. Operator decision required before merge.

### Failing Checks

<list each failing check name and its current state>

### Why autonomous resolution is not viable

<one of:>
- Upstream dependency not yet merged: <dep PR or issue>
- Fix requires changes outside this PR's scope: <explanation>
- Estimated effort exceeds autonomous threshold: <explanation>

### Operator options

1. **Land the blocker first** — merge the upstream dependency, rebase this PR, re-request review.
2. **Restructure PR scope** — split or defer the parts that exercise the unresolved dependency.
3. **Override and merge** — reply with explicit approval if red CI is acceptable for this merge.
   Operator must confirm: the failing checks are understood, not a regression, and a follow-up is tracked.

---
*Automated L1 review via goal-tree operations/l1-review.md*"

# Update coordinator — stay blocked until operator responds
coord node update $TREE_ID $NODE_ID --status blocked --result "CI escalation: <concise reason>; awaiting operator decision"
```

#### Reject

Any criterion fails or quality check reveals a blocking issue:

```bash
# Post review feedback as PR comment
gh pr comment $PR_NUMBER --repo $REPO --body "## L1 Review: REJECT

### Failed Criteria

<for each failed criterion>
- **Criterion**: <text>
  **Verdict**: FAIL
  **Reasoning**: <specific feedback with file:line references>

### Required Changes

<numbered list of specific changes needed to pass review>

---
*Automated L1 review via goal-tree operations/l1-review.md*"

# Update coordinator
coord node update $TREE_ID $NODE_ID --status blocked --result "Review failed: <concise reason>"
```

## Decision Criteria

| Condition | Decision |
|-----------|----------|
| All acceptance criteria pass, no security issues, tests present | **APPROVE** |
| Any acceptance criterion fails | **REJECT** |
| Tests missing for key claims | **REJECT** |
| Security concern (secrets in code, injection vectors) | **REJECT** |
| CI checks failing — fixable autonomously (trivial rebase, cheap patch) | Fix CI, then re-evaluate |
| CI checks failing — not fixable autonomously or too expensive | **ESCALATE** to operator; do not merge without explicit operator override |
| CI checks failing — operator override explicitly granted | **APPROVE** (proceed to merge) |
| Code compiles but doesn't match spec architecture | **REJECT** |

## Agent-Coordinator Deploy Procedure

When the merged repo is `agent-coordinator`, the full deploy sequence is:

1. `git -C $AC_REPO_PATH pull origin main`
2. `cd $AC_REPO_PATH && mix deps.get --only prod`
3. `cd $AC_REPO_PATH && MIX_ENV=prod mix release --overwrite`
4. `cd $AC_REPO_PATH && MIX_ENV=prod mix ecto.migrate`
5. `launchctl kickstart -k gui/$(id -u)/com.pfeff.agent-coordinator`
6. Wait 3 seconds, then `curl -sf http://localhost:4000/api/health`
7. If health check fails, log warning but do not roll back (manual intervention needed)

## Integration Points

- **Called by**: execute-tree step 4c (PR detection), manual L1 invocation
- **Depends on**: `gh` CLI, coordinator CLI (`coord`), node spec (DESIGN.md or coordinator)
- **References**:
  - `operations/execute-tree.md` — monitoring loop that triggers this protocol
  - `operations/dispatch-node.md` — post-implementation lifecycle (child creates PR)
  - Project-level `nodes/C.3/l1-review-process.md` — detailed review quality signals
