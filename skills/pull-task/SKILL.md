---
name: pull-task
description: Pull the next task from a GitHub project board or Jira. Queries project items, filters by status and sprint, presents ranked candidates, and outputs the selected issue for workspace creation. Use when the user needs to pick their next task from the project board.
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
allowed-prompts:
  # GitHub operations
  - tool: Bash
    prompt: list GitHub projects
  - tool: Bash
    prompt: sync project board cache
  - tool: Bash
    prompt: query project board cache
  - tool: Bash
    prompt: look up board item ID
  - tool: Bash
    prompt: query board field metadata
  - tool: Bash
    prompt: view GitHub issue details
  - tool: Bash
    prompt: update GitHub project item status
  # Jira operations
  - tool: Bash
    prompt: check Jira authentication status
  - tool: Bash
    prompt: search Jira issues with JQL
  - tool: Bash
    prompt: view Jira issue details
  - tool: Bash
    prompt: transition Jira issue status
  - tool: Bash
    prompt: search Jira boards
  - tool: Bash
    prompt: list Jira board sprints
version: 1.1.0
---

# Pull Task Skill

Queries a GitHub project board or Jira and presents candidates for the user to select as their next task.

## Operation

**When**: User needs to pick the next task from the project board.

**Implementation**: Load `operations/github-backend.md` (GitHub) or `operations/jira-backend.md` (Jira) for detailed steps.

**Quick summary**: Detects backend (GitHub or Jira) from workspace context, fetches items filtered by status/sprint, ranks candidates, presents for selection, outputs issue reference for `/create-workspace`.

## Backend Detection

The skill detects which backend to use by checking workspace CLAUDE.md:
- `GitHub Issue:` field present → GitHub backend
- `Jira Ticket:` field present → Jira backend
- Neither or both → Ask user via AskUserQuestion

## Common Patterns

### GitHub Backend

**Cache sync**: `project-board-helper sync` refreshes the local SQLite cache at `~/Library/Caches/guardian/project-board.db`.

**Item filtering**: `sqlite3` queries against the cache DB, filtering by Status and Sprint field values.

**Field metadata**: `project-board-helper field <name>` returns field IDs and option IDs.

**Item lookup**: `project-board-helper lookup <owner/repo> <number>` resolves issue to project item ID.

**Issue reference**: Constructed from `repo` + `#` + `issue_number` (e.g., `pfeff/guardian#77`).

### Jira Backend

**Authentication check**: `acli jira auth status`

**Issue search**: `acli jira workitem search --jql "<query>" --json`

**Default JQL (Scrum)**: `sprint in openSprints() AND status = "To Do" AND project = <KEY>`

**Default JQL (Kanban)**: `status in ("To Do", "Backlog") AND project = <KEY>`

**Issue reference**: Project key + issue number (e.g., `DO-123`).

## Permissions

### GitHub

| Permission | Commands | Purpose |
|------------|----------|---------|
| sync project board cache | `project-board-helper sync` | Refresh local board cache |
| query project board cache | `sqlite3 ~/Library/Caches/guardian/project-board.db` | Filter items by status/sprint |
| look up board item ID | `project-board-helper lookup` | Resolve issue to item ID |
| query board field metadata | `project-board-helper field` | Discover field IDs and options |
| view GitHub issue details | `gh issue view` | Fetch full issue details for selected item |
| update GitHub project item status | `gh project item-edit` | Move selected item to "In Progress" |

### Jira

| Permission | Commands | Purpose |
|------------|----------|---------|
| check Jira authentication status | `acli jira auth status` | Verify acli is authenticated |
| search Jira issues with JQL | `acli jira workitem search` | Query issues by JQL |
| view Jira issue details | `acli jira workitem view` | Fetch full issue details |
| transition Jira issue status | `acli jira workitem transition` | Move issue to "In Progress" |
| search Jira boards | `acli jira board search` | Find board for a project |
| list Jira board sprints | `acli jira board list-sprints` | Discover active sprints |

## Commands

| Command | Operation |
|---------|-----------|
| `/claude-skills:pull-task` | pull-task |
