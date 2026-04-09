# Workspace Listing Operation

Lists workspaces filtered by status with progress information.

## Purpose

Shows all task workspaces in `~/src/work/`, filtered by completion status, with task progress tracking from Claude native task lists.

## Inputs

- **status** (optional): Filter by task status
  - `in-progress` (default): Tasks with pending or in-progress items
  - `completed`: Tasks with all items completed
  - `all`: All tasks regardless of status

## Implementation Steps

### 1. Parse User Request

Extract status filter from user input.

**Valid formats**:
- `/list-workspaces`
- `/list-workspaces in-progress`
- `/list-workspaces completed`
- `/list-workspaces all`
- `Show me all my tasks`
- `List completed tasks`

**Default**: `in-progress` if no status specified

### 2. Extract Task Data

Run both data extraction scripts to gather workspace information:

**Primary source** - Claude native task lists:
```bash
${CLAUDE_PLUGIN_ROOT}/skills/task-workflow/scripts/scan-task-dirs.sh
```
Output: `task_list_id|status|pending|in_progress|completed|total|workspace`

**Fallback source** - PLAN.md-based tracking (for legacy workspaces):
```bash
${CLAUDE_PLUGIN_ROOT}/skills/task-workflow/scripts/list-tasks.sh
```
Output: `status|epic|task_id|headline|checked|total|workspace`

### 3. Merge Data Sources

1. Start with task list data from `scan-task-dirs.sh`
2. Add PLAN.md data for workspaces not covered by task lists
3. Prefer task list status over PLAN.md status when both exist

**Status mapping**:

| Task List Status | Display Status |
|------------------|----------------|
| `in-progress` | In-Progress |
| `pending` | In-Progress |
| `completed` | Completed |

| PLAN.md Status | Display Status |
|----------------|----------------|
| `in-progress` | In-Progress |
| `completed` | Completed |
| `no-todos` | No TODOs |
| `no-plan` | No Tracking |

### 4. Enrich with Metadata

For each workspace, extract additional metadata from DESIGN.md:
- Task ID (from first line: `# TASK-ID: Headline`)
- Headline
- Epic (from path: `~/src/work/<epic>/...`)

### 5. Filter by Status Parameter

Apply filter logic based on user request:

- **`in-progress`**: Show tasks where status is in-progress or pending
- **`completed`**: Show tasks where status is completed
- **`all`**: Show all tasks, grouped by status

### 6. Format Display

For each filtered task, format as:
```
TASK-ID • epic
  Headline
  Progress: completed/total tasks (source: task-list|plan.md)
  ~/path/to/workspace
```

**Group headings** (when showing multiple statuses):
```
In-Progress Tasks (count):
Completed Tasks (count):
Tasks Without Tracking (count):
```

**Sort order**: Epic alphabetically, then task-id alphabetically

**Spacing**: Blank line between tasks

### 7. Handle Edge Cases

| Case | Response |
|------|----------|
| No workspaces found | "No task workspaces found in ~/src/work/" |
| No matches for filter | "No {status} tasks found" |
| Script fails | "Error running script: {error}" |
| Empty output | "No task workspaces found" |

## Output Examples

### In-progress tasks (default)
```
In-Progress Tasks (2):

DO-242 • ad-hoc
  Fix authentication bug
  Progress: 2/5 tasks (task-list)
  ~/src/work/ad-hoc/DO-242-fix-auth-bug

skills-workflow • tooling
  Refactor workflow system using skills
  Progress: 15/25 tasks (plan.md)
  ~/src/work/tooling/skills-workflow
```

### All tasks
```
In-Progress Tasks (2):
[tasks as above]

Completed Tasks (1):

TOOS-24 • platform
  Implement OAuth integration
  Progress: 12/12 tasks (task-list)
  ~/src/work/platform/TOOS-24-oauth-integration

Tasks Without Tracking (1):

HOTFIX-42 • platform
  Emergency fix
  ~/src/work/platform/HOTFIX-42-emergency
```

## Data Source Priority

1. **Claude native task lists** (`~/.claude/tasks/`): Primary source
   - Identified by `CLAUDE_CODE_TASK_LIST_ID` in workspace `.envrc`
   - Status from task JSON files: pending, in_progress, completed
   - Progress: count of completed vs total tasks

2. **PLAN.md** (legacy): Fallback for older workspaces
   - Checkbox format: `- [ ]` unchecked, `- [x]` checked
   - Only top-level items counted (not sub-items)

## Scripts Reference

| Script | Purpose | Output Format |
|--------|---------|---------------|
| `scan-task-dirs.sh` | Scan Claude task lists | `task_list_id\|status\|pending\|in_progress\|completed\|total\|workspace` |
| `list-tasks.sh` | Scan PLAN.md files | `status\|epic\|task_id\|headline\|checked\|total\|workspace` |

## Implementation Checklist

When implementing this operation:

1. Parse user request for status filter (default: `in-progress`)
2. Run `scan-task-dirs.sh` for task list data
3. Run `list-tasks.sh` for PLAN.md data
4. Merge results, preferring task list status
5. Extract metadata from DESIGN.md for each workspace
6. Group tasks by status
7. Filter based on user-requested status
8. Format output with proper grouping and spacing
9. Handle empty results with appropriate message
