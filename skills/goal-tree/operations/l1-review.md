# Post-Review Merge Action (deprecated L1 review)

> **DEPRECATED as a review.** The L1 review *judgment* is now the doctrine-based
> `/l1-review` (3 axes — Conformance / Process / Objective Advancement — verdict
> `CLEAN` / `NEEDS-WORK` / `BLOCKING`), which also posts the canonical
> `<!-- l1-review:metadata -->` marker that `lN-lifecycle-doctrine` complete-check
> condition 4 requires. **Do not use this file to judge a PR.** See
> `lN-review-doctrine` for the judgment.
>
> This file is retained only for the goal-tree-specific **merge / agent-coordinator
> deploy / coordinator-node-update mechanics**, which run *after* `/l1-review` returns a
> verdict. Per-verdict action: `CLEAN` → run the Merge action below; `NEEDS-WORK` /
> `BLOCKING` → the child addresses the `/l1-review` feedback and the node is set blocked.
> For the legacy `APPROVE`/`REJECT`/`ESCALATE` → doctrine-verdict mapping, see
> `lN-review-doctrine` "Single verdict vocabulary" — the single source of truth; it is
> not restated here.

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `pr_number` | Yes | PR number that `/l1-review` reviewed |
| `repo` | Yes | Repository in `owner/repo` format |
| `node_id` | Yes | Coordinator node ID |
| `tree_id` | Yes | Coordinator tree ID |
| `verdict` | Yes | The `/l1-review` verdict for this PR (`CLEAN` / `NEEDS-WORK` / `BLOCKING`) |

## When to run

Invoked by `execute-tree` step 4c **after** `/l1-review` has reviewed the PR and
posted its verdict + `<!-- l1-review:metadata -->` marker. This action does not
re-review — it acts on the verdict:

- `CLEAN` → run the **Merge action** below.
- `NEEDS-WORK` / `BLOCKING` → see **On NEEDS-WORK / BLOCKING**; `/l1-review` has
  already posted the findings, so this action only sets the coordinator node blocked.

## Merge action (CLEAN verdict)

`/l1-review` has already posted the `CLEAN` marker, so the lifecycle
`merged → complete` gate is satisfiable. Merge, deploy if needed, mark complete:

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

## On NEEDS-WORK / BLOCKING

`/l1-review` has already posted its findings as the canonical PR comment. **Do not
post a second review verdict here.** Mark the node blocked so the child picks up the
feedback and retries:

```bash
coord node update $TREE_ID $NODE_ID --status blocked --result "l1-review <VERDICT>: <concise reason>"
```

For a red-CI `BLOCKING` that needs an operator decision (the former `ESCALATE` case),
surface to the operator and keep the node blocked — do not merge with red CI without
explicit operator override.

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

- **Called by**: execute-tree step 4c, after `/l1-review` returns a verdict
- **Depends on**: `/l1-review` (the judgment + marker), `gh` CLI, coordinator CLI (`coord`)
- **References**:
  - `lN-review-doctrine` — the review judgment this action consumes (CLEAN/NEEDS-WORK/BLOCKING)
  - `operations/execute-tree.md` — monitoring loop that triggers this action
  - `operations/dispatch-node.md` — post-implementation lifecycle (child creates PR)
  - Project-level `nodes/C.3/l1-review-process.md` — detailed review quality signals
