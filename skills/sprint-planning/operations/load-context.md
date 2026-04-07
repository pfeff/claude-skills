# Load Context

Autonomously gather all project state before asking any questions. The goal is to understand the project deeply enough to ask informed, substantive questions in the interview phase.

## When to Use

Always — this is the mandatory first step of sprint planning. Never skip to interviewing.

## Prerequisites

- `project-board-helper` binary installed (sync, lookup, field, get-field commands)
- `sqlite3` CLI (ships with macOS)
- `gh` CLI authenticated
- Cache DB: `~/Library/Caches/guardian/project-board.db`

## Steps

### 1. Sync Cache and Identify Sprint Parameters

Refresh the local cache and determine the sprint being planned:

```bash
project-board-helper sync
```

Then fetch sprint field options:

```bash
project-board-helper field Sprint
```

- If argument provided (e.g., "Sprint 2"), match it against the option names
- Otherwise, identify the next upcoming sprint from the options list (earliest non-"Backlog" option)

### 2. Load Strategic Objectives

Find open strategic objective issues (prefixed with S1:, S2:, etc.) across repos:

```bash
# Search each repo for strategic objective issues
for repo in guardian agent-coordinator agent-orchestrator; do
  gh issue list --repo pfeff/$repo --state open --search "S1: OR S2: OR S3:" --limit 20
done
```

Read the body of each strategic objective to understand goals and key results.

### 3. Review Prior Sprint Outcomes

Query items from the previous sprint via the cache:

```bash
sqlite3 ~/Library/Caches/guardian/project-board.db "
  SELECT i.repo, i.issue_number, i.title,
         COALESCE(sv.value, '') as status
  FROM items i
  JOIN item_field_values spv ON i.item_id = spv.item_id
  JOIN fields spf ON spv.field_id = spf.field_id AND spf.name = 'Sprint'
  LEFT JOIN item_field_values sv ON i.item_id = sv.item_id
  LEFT JOIN fields sf ON sv.field_id = sf.field_id AND sf.name = 'Status'
  WHERE spv.value = '<previous_sprint>'
    AND i.content_type = 'Issue';
"
```

Categorize as Done vs. incomplete based on the status column.

If a sprint-review report exists for the prior sprint, read it for velocity data and recommendations.

### 4. Survey Open Issues Across Repos

For each in-scope repo, list open issues:

```bash
for repo in guardian agent-coordinator agent-orchestrator PfeffNet; do
  echo "=== $repo ==="
  gh issue list --repo pfeff/$repo --state open --limit 30
done
```

Group by theme: strategic work, process improvement, bugs, documentation, in-flight.

### 5. Detect In-Flight Work

Check for active tmux sessions that indicate work in progress:

```bash
tmux list-sessions 2>/dev/null
```

Cross-reference session names with issue numbers to identify active work.

### 6. Check Board State

Identify items currently on the board that aren't Done:

```bash
sqlite3 -separator ' | ' ~/Library/Caches/guardian/project-board.db "
  SELECT '#' || i.issue_number, COALESCE(sv.value, ''), 'Sprint: ' || COALESCE(spv.value, ''), i.title, i.repo
  FROM items i
  LEFT JOIN item_field_values sv ON i.item_id = sv.item_id
  LEFT JOIN fields sf ON sv.field_id = sf.field_id AND sf.name = 'Status'
  LEFT JOIN item_field_values spv ON i.item_id = spv.item_id
  LEFT JOIN fields spf ON spv.field_id = spf.field_id AND spf.name = 'Sprint'
  WHERE i.content_type = 'Issue'
    AND (sv.value IS NULL OR sv.value != 'Done')
  ORDER BY COALESCE(spv.value, 'zzz'), COALESCE(sv.value, 'zzz');
"
```

## Output

Produce an internal context summary (not shown to user yet) containing:

1. **Sprint target**: Which sprint is being planned, date range
2. **Strategic objectives**: Open S1/S2/S3 objectives with current status
3. **Prior sprint**: What shipped, what didn't, velocity if available
4. **Open issue landscape**: Grouped by repo and theme
5. **In-flight work**: Active tmux sessions and their associated issues
6. **Board state**: Non-Done items and their sprint assignments
7. **Hypothesis**: A proposed sprint focus based on the above

The hypothesis is critical — it transforms the interview from form-filling into a substantive discussion.

## Error Handling

- If a repo query fails, note it and continue with available data
- If cache is stale, re-run `project-board-helper sync`
- If no prior sprint data exists, note it as "first sprint" context
