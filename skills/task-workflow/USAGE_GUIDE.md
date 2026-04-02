# Task Workflow - Usage Guide

User documentation for the task workflow skill.

## Overview

The task-workflow skill manages development task workspaces with standardized structure and automated setup. Task tracking uses Claude Code's native task tools for persistent progress tracking.

## Task Management

### Native Task Tools

Claude Code provides built-in task management that persists across sessions:

| Tool | Purpose | Example |
|------|---------|---------|
| `TaskList` | View all tasks with status | `TaskList` |
| `TaskCreate` | Add new task | `TaskCreate(subject: "...", description: "...", activeForm: "...")` |
| `TaskUpdate` | Change status, set dependencies | `TaskUpdate(taskId: "1", status: "completed")` |
| `TaskGet` | Get full task details | `TaskGet(taskId: "1")` |

### Task States

| Status | Meaning |
|--------|---------|
| `pending` | Not yet started |
| `in_progress` | Currently being worked on |
| `completed` | Finished and verified |
| `deleted` | Removed (permanent) |

### Basic Workflow

```
# Check available tasks
TaskList

# Start a task
TaskUpdate(taskId: "1", status: "in_progress")

# Complete a task
TaskUpdate(taskId: "1", status: "completed")

# Add a new task
TaskCreate(subject: "Fix auth bug", description: "Token expiration issue", activeForm: "Fixing auth bug")
```

### Task Dependencies

Tasks can block other tasks:

```
# Task 2 depends on task 1
TaskUpdate(taskId: "2", addBlockedBy: ["1"])

# Task 1 blocks tasks 2 and 3
TaskUpdate(taskId: "1", addBlocks: ["2", "3"])
```

## Workspace Task Integration

### How It Works

Each workspace has a unique task list ID stored in `CLAUDE_CODE_TASK_LIST_ID` environment variable. When you enter a workspace directory:

1. **direnv** loads the `.envrc` file
2. `CLAUDE_CODE_TASK_LIST_ID` is set (e.g., `ad-hoc-DO-242`)
3. Claude Code uses this ID to load/save tasks in `~/.claude/tasks/<id>.json`
4. Task state persists across sessions

### Setting Up a New Workspace

The `/create-workspace` command automatically:
- Creates `.envrc` with `CLAUDE_CODE_TASK_LIST_ID` set
- Generates a unique ID from `<epic>-<task-id>`
- Tasks created in this workspace are isolated from other workspaces

### Workspace Structure

```
~/src/work/<epic>/<task-id>-<slug>/
├── .envrc              # Contains CLAUDE_CODE_TASK_LIST_ID
├── DESIGN.md           # Task requirements and architecture
├── <repo>/             # Git worktrees
└── Obsidian/           # Vault symlink
```

### .envrc Contents

```bash
layout python3

export TF_VAR_azure_devops_pat="<pat>"
export AZURE_DEVOPS_EXT_PAT="<pat>"
export CLAUDE_CODE_TASK_LIST_ID="<epic>-<task-id>"
```

After entering a workspace, run `direnv allow` to activate the environment.

## Hybrid System

### New vs Legacy Workspaces

The system supports both native tasks and PLAN.md:

| Workspace Type | Detection | Task Tracking |
|----------------|-----------|---------------|
| **New** (native tasks) | Has `CLAUDE_CODE_TASK_LIST_ID` in `.envrc` | `TaskList`/`TaskUpdate` tools |
| **Legacy** | Missing task ID or has `PLAN.md` | `PLAN.md` checkbox scanning |

### Status Determination

`/list-workspaces` checks both sources:

1. **Native tasks**: Scans `~/.claude/tasks/*.json` for workspace status
2. **PLAN.md fallback**: Counts `- [ ]` and `- [x]` items

Status priority:
- Native tasks take precedence if `CLAUDE_CODE_TASK_LIST_ID` exists
- Falls back to PLAN.md for legacy workspaces

### Migration Path

Legacy workspaces continue to work. To migrate:

1. Add `CLAUDE_CODE_TASK_LIST_ID=<epic>-<task-id>` to `.envrc`
2. Run `direnv allow`
3. Create tasks using `TaskCreate` based on PLAN.md items
4. Optionally remove PLAN.md

## Operations Reference

### Creating a Workspace

```bash
/create-workspace --task-id DO-242 --epic platform --repos api,frontend
```

Result:
- Workspace at `~/src/work/platform/DO-242-<slug>/`
- `.envrc` with `CLAUDE_CODE_TASK_LIST_ID=platform-DO-242`
- Git worktrees for specified repos
- Tmux session ready

### Opening a Workspace

```bash
/open-workspace DO-242 platform
```

Result:
- Loads workspace environment
- Restores tmux session
- `TaskList` shows workspace tasks

### Listing Workspaces

```bash
/list-workspaces              # In-progress tasks
/list-workspaces all          # All tasks
/list-workspaces completed    # Completed tasks
```

Output shows:
- Task ID and headline
- Progress (tasks completed / total)
- Workspace path
- Data source (native tasks or PLAN.md)

## Best Practices

### Task Granularity

- Create tasks for discrete work items (2-8 hours of work)
- Use dependencies for ordered work
- Keep one task `in_progress` at a time
- Get human approval before marking tasks done or making git commits

### Task Descriptions

Include in descriptions:
- Acceptance criteria
- Key files to modify
- Testing requirements

```
TaskCreate(
  subject: "Add OAuth provider",
  description: "Implement Google OAuth. Acceptance: login button works, tokens stored securely, refresh handled.",
  activeForm: "Implementing OAuth"
)
```

### Daily Workflow

1. **Start of day**: `/list-workspaces in-progress` to see active work
2. **Enter workspace**: `/open-workspace <task-id> <epic>`
3. **Check tasks**: `TaskList` to see pending items
4. **Begin work**: `TaskUpdate(taskId: "X", status: "in_progress")`
5. **Complete work**: `TaskUpdate(taskId: "X", status: "completed")`
6. **Capture new work**: `TaskCreate(...)` for discovered items

### Preventing Side Quests

When you discover something that needs attention but isn't the current task:

```
TaskCreate(
  subject: "Noticed: Refactor auth module",
  description: "Auth module has tech debt. Not blocking current work.",
  activeForm: "Refactoring auth"
)
```

Continue with current task. Address new task later.

### Blocker Signal Recognition

When you encounter annotations like `TODO(BUG)`, `TODO(LATER)`, `FIXME(LATER)`, or similar patterns in code, treat them as **documentation directives** — the user wants the issue recorded for later, not addressed now.

**Do**:
```
# Encountered: TODO(BUG): auth token refresh fails silently
TaskCreate(
  subject: "Bug: auth token refresh fails silently",
  description: "Found TODO(BUG) in auth.py:42. Token refresh errors are swallowed. Needs investigation.",
  activeForm: "Investigating auth token refresh"
)
# Continue with current task
```

**Don't**:
```
# Encountered: TODO(BUG): auth token refresh fails silently
# ❌ Stop current task to investigate the bug
# ❌ Open the auth module and start debugging
# ❌ Add error handling to fix the silent failure
```

## Troubleshooting

### Tasks Not Persisting

**Symptom**: Tasks disappear between sessions

**Cause**: `CLAUDE_CODE_TASK_LIST_ID` not set before Claude Code starts

**Fix**:
1. Ensure `.envrc` contains `export CLAUDE_CODE_TASK_LIST_ID="<id>"`
2. Run `direnv allow` before starting Claude Code
3. Restart Claude Code after allowing direnv

### Wrong Task List

**Symptom**: Seeing tasks from another workspace

**Cause**: direnv not loaded or wrong directory

**Fix**:
1. Verify current directory: `pwd`
2. Check environment: `echo $CLAUDE_CODE_TASK_LIST_ID`
3. Reload if needed: `direnv allow`

### /list-workspaces Shows Incorrect Status

**Symptom**: Status doesn't match actual progress

**Cause**: Mixed data sources or stale cache

**Fix**:
1. Native task workspaces: Use `TaskList` for authoritative status
2. Legacy workspaces: Check PLAN.md directly
3. Run scan script: `${CLAUDE_PLUGIN_ROOT}/skills/task-workflow/scripts/scan-task-dirs.sh`

## Task Storage Details

### File Locations

```
~/.claude/tasks/
├── platform-DO-242.json    # Workspace-specific task list
├── ad-hoc-cache-debug.json
└── tooling-docs-update.json
```

### JSON Format

```json
{
  "tasks": [
    {
      "id": "1",
      "subject": "Task title",
      "description": "Full description",
      "status": "pending",
      "activeForm": "Working on task",
      "blocks": [],
      "blockedBy": []
    }
  ]
}
```

### Scanning for Status

The `scan-task-dirs.sh` script reads these JSON files to determine:
- Total task count
- Completed task count
- Current status (in-progress, completed, pending)

## Summary

The native task system provides:

1. **Persistence**: Tasks survive session restarts
2. **Isolation**: Each workspace has its own task list
3. **Integration**: `/list-workspaces` aggregates status
4. **Dependencies**: Tasks can block other tasks
5. **Backward compatibility**: Legacy PLAN.md workspaces continue working

Use `TaskList` to check progress, `TaskCreate` to add work items, and `TaskUpdate` to track completion.
