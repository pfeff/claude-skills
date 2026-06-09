# Jira Backend

Jira-specific implementation for pull-task. Queries Jira issues via `acli` CLI using JQL.

## Backend Interface

This backend implements the pull-task interface:
- `discover_context()` → Extract project key from workspace CLAUDE.md or ask user
- `fetch_candidates(filter)` → Query via `acli jira workitem search --jql`
- `present_candidates(items)` → AskUserQuestion with top 4 candidates
- `fetch_details(item)` → `acli jira workitem view`
- `transition_to_in_progress(item)` → `acli jira workitem transition`
- `format_reference(item)` → `PROJECT-123`

## Execution Steps

### 1. Check Prerequisites

Verify `acli` is installed and authenticated:

```bash
command -v acli >/dev/null 2>&1 || echo "acli not found"
acli jira auth status
```

If `acli` is not installed, error with install instructions.
If not authenticated, suggest: `acli jira auth login --web`

### 2. Determine Project Context

Extract Jira project key. Check these sources in order:

1. **Workspace CLAUDE.md**: Read `Jira Ticket:` field to extract project key (e.g. `DO` from `DO-123`)
2. **Ask user**: If no workspace context, use AskUserQuestion:
   - "Which Jira project key?" (free text, e.g., "DO", "INFRA")

Store the project key for JQL construction.

### 3. Detect Board Type and Build JQL

Attempt to detect whether this is a Scrum or Kanban project by checking for active sprints:

```bash
# First, find the board for this project
acli jira board search --project <KEY> --json 2>/dev/null

# Then list sprints for that board
acli jira board list-sprints --board-id <board_id> --json 2>/dev/null | jq '[.[] | select(.state == "active")]'
```

**If board ID is unknown** (common case), skip sprint detection and use a universal JQL that works for both:

#### Default JQL (works for both Scrum and Kanban)

```jql
project = <KEY> AND status in ("To Do", "Backlog", "Open") AND assignee is EMPTY ORDER BY priority DESC, created ASC
```

#### Scrum-specific JQL (if sprint detection succeeds)

```jql
project = <KEY> AND sprint in openSprints() AND status = "To Do" ORDER BY priority DESC, created ASC
```

#### Kanban-specific JQL (explicit fallback)

```jql
project = <KEY> AND status in ("To Do", "Backlog") ORDER BY priority DESC, created ASC
```

### 4. Fetch and Filter Items

Query issues using the constructed JQL:

```bash
acli jira workitem search --jql "<jql_query>" --json --limit 50
```

**Note**: Project keys that are reserved JQL words (e.g., "DO", "IN", "AS") must be quoted in JQL:
```jql
project = "DO" AND status in ("To Do", "Backlog")
```

Parse the JSON response to extract:
- Issue key (e.g., `DO-123`)
- Summary (title)
- Status
- Priority
- Labels
- Sprint (if available)
- Assignee

**Filtering**: The JQL handles most filtering. Post-process to exclude:
- Issues already assigned (unless user requests their own assignments)
- Subtasks (unless explicitly requested)

### 5. Rank Candidates

Sort filtered items by these criteria (highest priority first):

1. **Sprint**: Items in active sprint rank above backlog items
2. **Priority**: Urgent > High > Medium > Low
3. **Labels**: Items with labels rank above unlabeled items
4. **Created date**: Older items rank higher (FIFO within priority)

Build a ranked list with these display fields per item:
- Issue key
- Summary (title)
- Priority
- Sprint (or "Backlog")
- Labels (comma-separated)

### 6. Present Candidates

Use AskUserQuestion to present the top candidates (up to 4 options due to tool constraints).

Format each option:
- **label**: `<key>: <summary>` (truncated to fit)
- **description**: `<priority> | <sprint> | <labels>`

If more than 4 candidates exist, show the top 4 with a note that more are available. The user can select "Other" to see the next batch or specify a different JQL.

Example:
```
AskUserQuestion:
  question: "Which task would you like to pull?"
  options:
    - label: "DO-456: Fix authentication timeout"
      description: "High | Sprint 5 | bug, auth"
    - label: "DO-123: Add user preferences page"
      description: "Medium | Sprint 5 | enhancement"
    - label: "DO-789: Update API documentation"
      description: "Low | Backlog | docs"
    - label: "DO-234: Refactor database queries"
      description: "Medium | Backlog | tech-debt"
```

### 7. Fetch Selected Issue Details

Once the user selects an item, fetch full issue details:

```bash
acli jira workitem view <issue_key>
```

This returns:
- Full description
- Comments
- Attachments list
- Linked issues
- Custom fields

### 8. Move Item to In Progress

Transition the selected issue to "In Progress":

```bash
acli jira workitem transition --key <issue_key> --status "In Progress" --yes
```

**Note**: The exact status name may vary by project workflow. Common alternatives:
- "In Progress"
- "In Development"
- "Started"

If the transition fails due to workflow restrictions, inform the user and continue (non-blocking).

### 9. Output for Workspace Creation

Present the selected issue in a format ready for `/create-workspace`:

```
## Selected Task

**Issue**: <issue_key>
**Title**: <summary>
**Priority**: <priority>
**Labels**: <labels>

**Next step**: Run `/create-workspace` to set up a workspace for this task, or copy the issue reference above.
```

The key output is the issue key in `PROJECT-123` format, which `/create-workspace` should recognize.

## Error Handling

| Error | Response |
|-------|----------|
| `acli` not installed | Error: "acli CLI is required. Install from https://developer.atlassian.com/cloud/acli/" |
| Auth failure | Suggest: `acli jira auth login --web` |
| Invalid project key | Error: "Project '<KEY>' not found. Check the project key and try again." |
| No items match JQL | Inform user, offer to broaden JQL (e.g., include more statuses) |
| Transition failed | Warning: "Could not transition to In Progress (workflow restriction). Continuing..." |
| `jq` not installed | Error: "jq is required for JSON processing. Install via brew install jq" |

## Configuration

**Defaults**:
- Default JQL: `project = <KEY> AND status in ("To Do", "Backlog", "Open") AND assignee is EMPTY ORDER BY priority DESC, created ASC`
- Item limit: 50 (Jira API default)
- Candidate display: top 4 ranked items

**Environment Variables** (optional, from atlassian-cli skill):
- `JIRA_SITE`: Jira instance (e.g., your-org.atlassian.net)
- `JIRA_EMAIL`: Atlassian email for API auth
