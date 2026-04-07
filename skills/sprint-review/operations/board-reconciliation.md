# Board Reconciliation Operation

Core comparison logic for board reconciliation. Compares project board items tagged for a sprint against actual repo activity and produces a discrepancy report.

**References**: R1-R5 (Board Reconciliation), DD1 (Internal Operation), DD2 (Delegate to github-projects), DD3 (Adapter Pattern)

## Inputs

| Input | Source | Description |
|-------|--------|-------------|
| issues | Caller (pre-fetched) | Issues closed in the sprint date range, each with `{repo, number, title, closedAt}` |
| prs | Caller (pre-fetched) | PRs merged in the sprint date range, each with `{repo, number, title}` |
| owner | SKILL.md config | GitHub owner (default: `pfeff`) |
| project-number | SKILL.md config | GitHub project number (default: `4`) |
| sprint-name | User argument | Sprint identifier to filter board items (e.g., `Sprint 2 (Feb 24 - Mar 7)`) |
| start-date | User argument | Sprint week start date (e.g., `2025-02-24`), used for temporal classification |

## Process

### 1. Sync Board Cache

Load and execute `github-projects` sync-cache:

```
Read: skills/github-projects/operations/sync-cache.md
```

Run:
```bash
project-board-helper sync
```

### 2. Query Board Items for Sprint

Load and execute `github-projects` list-by-sprint with the sprint name:

```
Read: skills/github-projects/operations/list-by-sprint.md
```

Query all items tagged with the sprint:

```bash
sqlite3 -separator '|' ~/Library/Caches/guardian/project-board.db "
  SELECT i.repo, i.issue_number, i.title, i.content_type,
         COALESCE(sv.value, '') as status
  FROM items i
  JOIN item_field_values spv ON i.item_id = spv.item_id
  JOIN fields spf ON spv.field_id = spf.field_id AND spf.name = 'Sprint'
  LEFT JOIN item_field_values sv ON i.item_id = sv.item_id
  LEFT JOIN fields sf ON sv.field_id = sf.field_id AND sf.name = 'Status'
  WHERE spv.value = '<sprint_name>'
    AND i.content_type = 'Issue'
  ORDER BY i.repo, i.issue_number;
"
```

Each row returns: `repo|issue_number|title|content_type|status`

If no board items match, warn the user and list available sprint values:

```bash
project-board-helper field Sprint
```

### 3. Build Comparison Sets

Construct two sets for comparison:

- **Board set**: `{repo#number}` for each board item matching the sprint
- **Activity set**: `{repo#number}` for each closed issue and merged PR from the pre-fetched inputs

### 4. Compute Differences

#### A. Worked but Not Board-Tracked

Items in the activity set but not in the board set:

```
untracked = activity_set - board_set
```

#### B. Board-Tracked but No Activity

Items in the board set but not in the activity set:

```
no_activity = board_set - activity_set
```

#### C. Board Items with Empty Status

Items in the board set where the `status` field is empty or null.

### 4.5. Classify Done Items by Timing

For each board item with Done status, compare its `closedAt` timestamp against the sprint `start_date`:

- If `closedAt < start_date` → **pre-sprint** (closed before sprint week began)
- If `closedAt >= start_date` → **sprint-week** (closed during sprint week)

Cross-reference board Done items with the `closedAt` field from the pre-fetched issues input. If a Done item has no matching issue in the pre-fetched set (e.g., closed before the date range), query its `closedAt` directly:

```bash
gh issue view <number> -R <owner>/<repo> --json closedAt -q '.closedAt'
```

Produce counts:
- `pre_sprint_done` = count of Done items where `closedAt < start_date`
- `sprint_week_done` = count of Done items where `closedAt >= start_date`

### 5. Calculate Tracking Coverage

```
tracking_coverage = |board_set ∩ activity_set| / |activity_set| × 100
```

## Output Format

```markdown
## Board Reconciliation

### Tracking Coverage

**${coverage}%** of sprint activity was board-tracked (${tracked} of ${total} items).

### Board Summary

| Metric | Count |
|--------|-------|
| Board items tagged for sprint | ${board_count} |
| Board items completed (Done) | ${done_count} |
| Actual issues closed | ${issues_closed} |
| Actual PRs merged | ${prs_merged} |
| Total activity | ${total_activity} |
| Tracking coverage | ${coverage}% |

### Board Items Completed

| Repo | # | Title | Status |
|------|---|-------|--------|
| guardian | #42 | Implement state machine | Done |
| ... | ... | ... | ... |

### Work Done but Not Board-Tracked

${untracked_count} items had activity but were not tagged on the sprint board:

| Repo | # | Title | Type |
|------|---|-------|------|
| guardian | #55 | Fix CI pipeline | Issue |
| ... | ... | ... | ... |

### Board Items with No Activity

${no_activity_count} board items had no closed issue or merged PR in the date range:

| Repo | # | Title | Board Status |
|------|---|-------|-------------|
| agent-orchestrator | #99 | Planned feature X | In Progress |
| ... | ... | ... | ... |

### Board Items with Empty Status

${empty_status_count} board items are missing a status update:

| Repo | # | Title |
|------|---|-------|
| guardian | #60 | Update docs |
| ... | ... | ... |

### Temporal Breakdown

| Timing | Done Items |
|--------|-----------|
| Closed before sprint week | ${pre_sprint_done} |
| Closed during sprint week | ${sprint_week_done} |
| **Total Done** | **${board_done}** |
```

## Handling Edge Cases

- **Sprint name mismatch**: If no board items match the sprint name, warn the user and list available sprint values via `project-board-helper field Sprint`.
- **Items in multiple sprints**: Count the item if any sprint field value matches.
- **Repos not in config**: Board items may reference repos outside the configured list. Include them in the board set but flag them in the output.
- **Empty activity set**: If no issues or PRs were provided, report 0% coverage and list all board items under "Board Items with No Activity."

## Output Consumers

This operation's output is consumed by:
- **reconcile-board** — the pipeline adapter that invokes this operation
- **generate-report** — tracking coverage and reconciliation tables go into the Completion Rate section
- **create-actions** — persistent low coverage may generate a process improvement action item
