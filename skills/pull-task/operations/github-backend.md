# GitHub Backend

GitHub-specific implementation for pull-task. Uses `project-board-helper` for cached board queries and `gh` CLI for issue details and board mutations.

## Backend Interface

This backend implements the pull-task interface:
- `discover_context()` → Extract owner from workspace CLAUDE.md or ask user
- `fetch_candidates(filter)` → Query via `project-board-helper` SQLite cache
- `present_candidates(items)` → AskUserQuestion with top 4 candidates
- `fetch_details(item)` → `gh issue view`
- `transition_to_in_progress(item)` → `gh project item-edit`
- `format_reference(item)` → `owner/repo#number`

## Prerequisites

- `project-board-helper` binary installed (provides sync, lookup, field, get-field commands)
- `sqlite3` CLI (ships with macOS)
- `gh` CLI (for issue details and board mutations)

Cache DB location: `~/Library/Caches/<project>/project-board.db`

## Execution Steps

### 1. Determine Project Context

Extract project owner and number. Check these sources in order:

1. **Defaults**: owner=`<owner>`, project=`<project>` (project number + ID from config)
2. **Workspace CLAUDE.md**: If in a workspace, read `GitHub Issue:` field to extract the owner (e.g. `pfeff` from `<owner>/<repo>#77`)
3. **Ask user**: Only if defaults don't apply and no workspace context

If defaults match, skip project discovery and proceed directly to step 2.

### 2. Sync Cache and Discover Field Options

Refresh the local cache and extract field metadata:

```bash
project-board-helper sync
```

Then fetch field definitions:

```bash
project-board-helper field Status
project-board-helper field Sprint
```

Extract from the output:
- **Status field ID**: the `field_id` line
- **Status options**: the option IDs, especially "In Progress" (needed for step 6.5)
- **Sprint options**: all sprint names and IDs
- **Current sprint**: the earliest non-"Backlog" sprint option name (used for Pass 1 filtering in step 3)

### 3. Fetch and Filter Items (Two-Pass)

Use a two-pass approach to avoid ranking hundreds of items when pre-prioritized work exists. Query the SQLite cache directly for fast filtering.

#### Pass 1: Planned items in current sprint (short-circuit)

```bash
sqlite3 ~/Library/Caches/<project>/project-board.db "
  SELECT i.repo, i.issue_number, i.title
  FROM items i
  JOIN item_field_values sv ON i.item_id = sv.item_id
  JOIN fields sf ON sv.field_id = sf.field_id AND sf.name = 'Status'
  JOIN item_field_values spv ON i.item_id = spv.item_id
  JOIN fields spf ON spv.field_id = spf.field_id AND spf.name = 'Sprint'
  WHERE sv.value = 'Planned'
    AND spv.value = '<current_sprint>'
    AND i.content_type = 'Issue';
"
```

Replace `<current_sprint>` with the sprint name from step 2.

**If Pass 1 returns candidates**: Use them directly and **skip step 4** (no ranking needed — these items are already curated on the board). Proceed to step 5.

#### Pass 2: Full query with ranking (fallback)

Only if Pass 1 returns zero items:

```bash
sqlite3 -separator '|' ~/Library/Caches/<project>/project-board.db "
  SELECT i.repo, i.issue_number, i.title,
         COALESCE(spv.value, '') as sprint,
         COALESCE(hv.value, '') as horizon,
         COALESCE(sov.value, '') as strategic_objective
  FROM items i
  JOIN item_field_values sv ON i.item_id = sv.item_id
  JOIN fields sf ON sv.field_id = sf.field_id AND sf.name = 'Status'
  LEFT JOIN item_field_values spv ON i.item_id = spv.item_id
  LEFT JOIN fields spf ON spv.field_id = spf.field_id AND spf.name = 'Sprint'
  LEFT JOIN item_field_values hv ON i.item_id = hv.item_id
  LEFT JOIN fields hf ON hv.field_id = hf.field_id AND hf.name = 'Horizon'
  LEFT JOIN item_field_values sov ON i.item_id = sov.item_id
  LEFT JOIN fields sof ON sov.field_id = sof.field_id AND sof.name = 'Strategic Objective'
  WHERE (sv.value = 'Planned' OR sv.value = 'Backlog')
    AND i.content_type = 'Issue'
  ORDER BY
    CASE WHEN spv.value IS NOT NULL AND spv.value != 'Backlog' THEN 0 ELSE 1 END,
    CASE WHEN hv.value LIKE 'H1%' THEN 0
         WHEN hv.value LIKE 'H2%' THEN 1
         WHEN hv.value LIKE 'H3%' THEN 2
         ELSE 3 END,
    CASE WHEN sov.value IS NOT NULL AND sov.value != '' THEN 0 ELSE 1 END;
"
```

**Always excluded** (by the `WHERE` clause):
- Pull Requests (`content_type != 'Issue'`)
- Draft items without repos (excluded during sync)

Proceed to step 4 for label enrichment.

### 4. Enrich with Labels (Pass 2 only)

Labels are not stored in the project board cache. For the top candidates from Pass 2, fetch labels via:

```bash
gh issue view <number> --repo <repo> --json labels --jq '[.labels[].name] | join(",")'
```

Only fetch labels for the top ~6 candidates to avoid excessive API calls.

Build a ranked list with these display fields per item:
- Title
- Repository (short form: e.g. `acme/webapp` → `webapp`)
- Issue number
- Sprint
- Labels (comma-separated)
- Horizon

### 5. Present Candidates

Use AskUserQuestion to present the top candidates (up to 4 options due to tool constraints).

Format each option:
- **label**: `#<number>: <title>` (truncated to fit)
- **description**: `<repo> | <sprint> | <labels> | <horizon>`

If more than 4 candidates exist, show the top 4 with a note that more are available. The user can select "Other" to see the next batch or specify a different filter.

Example:
```
AskUserQuestion:
  question: "Which task would you like to pull?"
  options:
    - label: "#78: Unified workspace setup"
      description: "webapp | Sprint 1 (Feb 17-21) | enhancement | H1"
    - label: "#34: Execute Integration Tests"
      description: "agent-orchestrator | Backlog | enhancement | H1"
    - label: "#55: Multi-model support"
      description: "agent-orchestrator | Backlog | H1"
    - label: "#2: Prototype Coordination Service"
      description: "agent-coordinator | Backlog | H2"
```

### 6. Fetch Selected Issue Details

Once the user selects an item, fetch full issue details:

```bash
gh issue view <number> --repo <repo> --json title,body,labels,assignees,milestone
```

### 6.5. Move Item to In Progress

Look up the item ID and update the board status:

```bash
# Get item ID from cache
project-board-helper lookup <owner/repo> <issue_number>

# Get field and option IDs (from step 2, or re-fetch)
project-board-helper field Status
```

Then update the board:

```bash
gh project item-edit \
  --project-id <project_node_id> \
  --id <item_id> \
  --field-id <status_field_id> \
  --single-select-option-id <in_progress_option_id>
```

Values come from:
- `project_node_id`: the project's `id` from step 1 (default: `PVT_kwHNa8POARiyqQ`)
- `item_id`: from `project-board-helper lookup`
- `status_field_id`: from `project-board-helper field Status`
- `in_progress_option_id`: the "In Progress" option ID from the field output

### 7. Output for Workspace Creation

Present the selected issue in a format ready for `/create-workspace`:

```
## Selected Task

**Issue**: <owner>/<repo>#<number>
**Title**: <title>
**Labels**: <labels>
**Repository**: <repo>

**Next step**: Run `/create-workspace` to set up a workspace for this task, or copy the issue reference above.
```

The key output is the issue reference in `owner/repo#number` format, which is the input `/create-workspace` expects.

## Error Handling

| Error | Response |
|-------|----------|
| `project-board-helper` not installed | Error: "project-board-helper is required. Install via `go install github.com/pfeff/project-board-helper/cmd/project-board-helper@latest`" |
| `gh` not installed | Error: "gh CLI is required. Install from https://cli.github.com/" |
| Auth failure / missing project scope | Suggest: `gh auth refresh -s project` |
| Sync fails | Run `project-board-helper sync` and report the error |
| No items match filter | Inform user, offer to broaden filter (e.g. include all statuses) |
| Cache DB missing | `project-board-helper sync` will create it automatically |

## Configuration

**Defaults**:
- Pass 1 filter: `status == "Planned"` in current sprint (short-circuit)
- Pass 2 filter: `["Backlog", "Planned"]` across all sprints (fallback)
- Candidate display: top 4 ranked items
- Cache DB: `~/Library/Caches/<project>/project-board.db`
