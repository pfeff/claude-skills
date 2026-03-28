# Resume Status Operation

Displays the current auto-advance loop state without resuming. Read-only inspection of task progress and pause context.

**Requirements**: Must be run from within a workspace with an existing task list (`CLAUDE_CODE_TASK_LIST_ID` set in `.envrc`).

## Inputs

None — reads task state from the workspace's task list.

## Purpose

Gives the human visibility into auto-advance progress without triggering a resume. Useful for checking status after stepping away, understanding why the loop paused, or deciding whether to `/resume` or take manual action.

## Execution Steps

### 1. Read Task State

```
TaskList → categorize all tasks:
  - completed: tasks with status "completed"
  - in_progress: tasks with status "in_progress" (at most one)
  - pending_unblocked: tasks with status "pending" and empty blockedBy
  - pending_blocked: tasks with status "pending" and non-empty blockedBy
```

### 2. Determine Loop State

Infer the auto-advance state from task data:

| Condition | State |
|-----------|-------|
| All tasks completed | `complete` |
| A task is `in_progress` | `paused` (loop stopped mid-task) |
| No `in_progress`, pending tasks exist | `ready` (can resume or start) |
| All remaining tasks are blocked | `blocked` |
| No tasks exist | `empty` |

### 3. Display Status

```
## Auto-Advance Status

**State**: <complete | paused | ready | blocked | empty>
**Progress**: <completed>/<total> tasks

### Completed
<for each completed task>
  - <task subject>

<if state == paused>
### Paused On
**Task**: <in_progress task subject>
**Description**: <first 3 lines of task description>

**Guidance**: Fix the issue and run `/resume` to continue the loop.

<if state == blocked>
### Blocked Tasks
<for each blocked task>
  - <task subject> (waiting on: <blockedBy task subjects>)

**Guidance**: Resolve blocking tasks first, then run `/resume`.

<if state == ready>
### Next Up
  - <first pending unblocked task subject>

**Guidance**: Run `/resume` to start the auto-advance loop.

<if state == complete>
**Guidance**: All tasks done. Run `/finish` to create the PR.
```

## Error Handling

| Error | Response |
|-------|----------|
| No tasks exist | "No task list found. Run /init-workspace first." |
| TaskList unavailable | Stop, report tool error |

## Example

### Paused state

```
User: /resume-status

## Auto-Advance Status

**State**: paused
**Progress**: 2/5 tasks

### Completed
  - Implement webhook handler
  - Add authentication middleware

### Paused On
**Task**: Write integration tests
**Description**: Requirement R3: Add integration tests for webhook + auth flow.

**Guidance**: Fix the issue and run `/resume` to continue the loop.
```

### All complete

```
User: /resume-status

## Auto-Advance Status

**State**: complete
**Progress**: 5/5 tasks

### Completed
  - Implement webhook handler
  - Add authentication middleware
  - Write integration tests
  - Update API documentation
  - Add monitoring alerts

**Guidance**: All tasks done. Run `/finish` to create the PR.
```

## Integration Points

- **Related**: `operations/resume.md` — actually resumes the loop (this operation is read-only)
- **Task tools**: `TaskList`, `TaskGet` — read task state
