# Pull Task Operation

Queries a GitHub project board, filters and ranks candidates, presents them for selection, and outputs the chosen issue for workspace creation.

## Purpose

Eliminates the context-switch to the browser when starting new work. Replaces manual board browsing with a terminal-native flow that feeds directly into `/create-workspace`.

## Execution Steps

### 1. Determine Project Context

Extract project owner and number. Check these sources in order:

1. **Defaults**: owner=`<owner>`, project=`<project>` (project number + ID from config)
2. **Workspace CLAUDE.md**: If in a workspace, read `GitHub Issue:` field to extract the owner (e.g. `pfeff` from `<owner>/<repo>#77`)
3. **Ask user**: Only if defaults don't apply and no workspace context

If defaults match, skip project discovery and proceed directly to step 2.

### 2. Discover Field Options

Fetch the project's field definitions to know valid status and sprint values:

```bash
gh project field-list <number> --owner <owner> --format json
```

Extract:
- **Status field ID**: from field named "Status" (type `ProjectV2SingleSelectField`)
- **Status options**: including the "In Progress" option ID (needed for step 6.5)
- **Sprint options**: from field named "Sprint" (type `ProjectV2SingleSelectField`)
- **Current sprint**: the earliest non-"Backlog" sprint option name (this is used for Pass 1 filtering in step 3)

These are needed for filtering in step 3 and for updating status in step 6.5.

### 3. Fetch and Filter Items (Two-Pass)

Use a two-pass approach to avoid fetching and ranking hundreds of items when pre-prioritized work exists.

#### Pass 1: Planned items in current sprint (short-circuit)

Query only items with `status == "Planned"` in the current sprint (determined in step 2):

```bash
gh project item-list <number> --owner <owner> --format json --limit 500 \
  | jq --arg sprint "<current_sprint>" '[.items[] | select(.status == "Planned") | select(.sprint == $sprint) | select(.content.type == "Issue")]'
```

**Always exclude**:
- Pull Requests (`content.type != "Issue"`)
- Items with null content (draft items without linked issues)

**If Pass 1 returns candidates**: Use them directly and **skip step 4** (no ranking needed — these items are already curated on the board). Proceed to step 5.

#### Pass 2: Full fetch with ranking (fallback)

Only if Pass 1 returns zero items, widen to the original filter:

```bash
gh project item-list <number> --owner <owner> --format json --limit 500 \
  | jq '[.items[] | select(.status == "Backlog" or .status == "Planned") | select(.content.type == "Issue")]'
```

**Default status filter**: "Backlog" and "Planned" (pre-work statuses).

**Always exclude**:
- Pull Requests (`content.type != "Issue"`)
- Items with null content (draft items without linked issues)

Proceed to step 4 for ranking.

### 4. Rank Candidates (Pass 2 only)

This step is only reached when Pass 1 (step 3) returned no Planned items in the current sprint.

Sort filtered items by these criteria (highest priority first):

1. **Sprint**: Items in the current sprint rank above backlog items
2. **Horizon**: H1 > H2 > H3 > unset
3. **Strategic Objective**: Items with a strategic objective rank above those without
4. **Labels**: Items with labels rank above unlabeled items

**jq ranking note**: When constructing jq expressions with `!=`, write the filter to a temp file and use `jq -f /tmp/filter.jq` to avoid zsh escaping issues. Alternatively, use `| not` instead of `!=` (e.g. `select(.foo == null | not)` instead of `select(.foo != null)`).

Build a ranked list with these display fields per item:
- Title
- Repository (short form: `repo` from `content.repository`, e.g. `acme/webapp` → `webapp`)
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
gh issue view <number> --repo <content.repository> --json title,body,labels,assignees,milestone
```

### 6.5. Move Item to In Progress

Update the selected item's status to "In Progress" on the project board:

```bash
gh project item-edit \
  --project-id <project_node_id> \
  --id <item_id> \
  --field-id <status_field_id> \
  --single-select-option-id <in_progress_option_id>
```

Values come from:
- `project_node_id`: the project's `id` from step 1 (`gh project list` output)
- `item_id`: the selected item's `id` from the item-list data (step 3)
- `status_field_id`: the Status field's `id` from step 2
- `in_progress_option_id`: the "In Progress" option's `id` from step 2

This ensures the board reflects work-in-progress immediately, without a separate browser visit.

### 7. Output for Workspace Creation

Present the selected issue in a format ready for `/create-workspace`:

```
## Selected Task

**Issue**: <owner>/<repo>#<number>
**Title**: <title>
**Labels**: <labels>
**Repository**: <content.repository>

**Next step**: Run `/create-workspace` to set up a workspace for this task, or copy the issue reference above.
```

The key output is the issue reference in `owner/repo#number` format, which is the input `/create-workspace` expects.

## Error Handling

| Error | Response |
|-------|----------|
| `gh` not installed | Error: "gh CLI is required. Install from https://cli.github.com/" |
| Auth failure / missing project scope | Suggest: `gh auth refresh -s project` |
| No projects found | Error: "No projects found for owner '<owner>'" |
| No items match filter | Inform user, offer to broaden filter (e.g. include all statuses) |
| `jq` not installed | Error: "jq is required for filtering. Install via brew install jq" |

## Configuration

No configuration file needed. The skill auto-detects context and prompts for anything missing.

**Defaults**:
- Pass 1 filter: `status == "Planned"` in current sprint (short-circuit)
- Pass 2 filter: `["Backlog", "Planned"]` across all sprints (fallback)
- Item limit: 500
- Candidate display: top 4 ranked items
