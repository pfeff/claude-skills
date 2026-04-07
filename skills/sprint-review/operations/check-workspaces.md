# Check Workspaces Operation

Scan open workspaces and check GitHub issue status to detect stale workspaces — issues closed or PRs merged but workspace still open.

**References**: R2 (Workspace Hygiene Check), DD2 (Sprint-review integration over polling)

## Inputs

| Input | Source | Description |
|-------|--------|-------------|
| Closed issues list | gather-data output | Issues closed in the sprint date range (used to reduce API calls) |

## Process

### 1. Discover Open Workspaces

Scan for workspaces using the same pattern as `list-workspaces`:

```bash
~/.claude/skills/task-workflow/scripts/scan-task-dirs.sh
```

This returns all workspaces with their task list status. Filter to workspaces where status is `in-progress` or `pending` — these are the candidates for staleness.

For each candidate workspace, extract metadata:
- **Task ID**: From DESIGN.md first line (`# TASK-ID: Headline`)
- **Workspace path**: From scan output
- **Epic**: From workspace path segment (`~/src/work/<epic>/...`)

### 2. Extract Issue References

For each workspace, read the CLAUDE.md file and extract the GitHub issue reference:

```
Pattern: GitHub Issue: <owner>/<repo>#<number>
Example: GitHub Issue: pfeff/cursor-rules#70
```

**If no issue reference found**: Skip this workspace. It was created without issue tracking and cannot be checked for staleness.

### 3. Check Issue Status

For each workspace with an issue reference, determine if the issue is closed.

**Optimization**: First cross-reference against the closed issues list from gather-data. If the issue appears in the gather-data output, it's closed — no additional API call needed.

For issue refs not found in gather-data (issues in repos not covered by the sprint review, or closed outside the date range):

```bash
gh issue view <number> --repo <owner>/<repo> --json state --jq '.state'
```

**On API failure**: Warn and continue to next workspace:

```
⚠ Could not check issue status for <owner>/<repo>#<number>: <error>
```

### 4. Classify Workspaces

For each workspace, assign a status:

| Issue State | Workspace Status |
|-------------|-----------------|
| CLOSED | **Stale** — issue closed, workspace still open |
| OPEN | Healthy — workspace is active |
| API error | Unknown — could not determine |
| No issue ref | Skipped — no issue to check |

### 5. Format Output

Produce a markdown section for the sprint review report:

```markdown
## Workspace Hygiene

### Summary

${stale_count} stale workspace(s) detected (issue closed but workspace still open).

### Stale Workspaces

| Task ID | Epic | Issue | Issue State | Workspace Path |
|---------|------|-------|-------------|----------------|
| 36 | cursor-rules | pfeff/cursor-rules#36 | CLOSED | ~/src/work/cursor-rules/36-task-slug |
| 37 | cursor-rules | pfeff/cursor-rules#37 | CLOSED | ~/src/work/cursor-rules/37-task-slug |

To clean up, run from a control session:

  /close-workspace

### Healthy Workspaces

${healthy_count} workspace(s) have open issues and are active.
```

**If zero stale workspaces**:

```markdown
## Workspace Hygiene

All ${total_count} open workspace(s) have active issues. No cleanup needed.
```

**If workspaces were skipped or had errors**, append:

```markdown
### Notes

- ${skipped_count} workspace(s) skipped (no GitHub issue reference)
- ${error_count} workspace(s) could not be checked (API errors)
```

## Handling Edge Cases

- **No open workspaces found**: Output "No open workspaces found in ~/src/work/. Nothing to check."
- **All workspaces skipped**: Output summary with note that no workspaces had issue references
- **Workspace in repo not in sprint scope**: Still check via `gh issue view` — workspace hygiene is repo-agnostic
- **Multiple workspaces for same issue**: Each workspace checked independently

## Related: Shared Stale Detection Script

The task-workflow skill provides a reusable stale detection script:

```bash
~/.claude/skills/task-workflow/scripts/stale-workspaces.sh [--quiet]
```

This script implements the same detection logic (steps 1-4 above) as a standalone shell script. It can be used as an alternative to the inline detection in this operation, or as a quick check outside of sprint review context.

The script is also used by:
- **start-task.md** — blocks `/start-task` when stale workspaces exist
- **finish.md** — prints manual close instructions after PR creation

## Output Consumers

This operation's output is consumed by:
- **generate-report** — Workspace Hygiene section inserted after Board Reconciliation
- **create-actions** — persistent stale workspaces may generate a cleanup action item
