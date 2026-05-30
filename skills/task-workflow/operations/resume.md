# Resume Operation

Re-enters the auto-advance loop after a human intervention pause. Provides context about the pause state before resuming autonomous task processing.

**Requirements**: Must be run from within a workspace with an existing task list (`CLAUDE_CODE_TASK_LIST_ID` set in `.envrc`).

## Inputs

None — reads task state from the workspace's task list.

## Purpose

After auto-advance pauses (validation failure, ambiguous decision, commit failure), the human fixes the issue and invokes `/resume` to re-enter the loop. This operation provides context about where the loop left off, confirms readiness, and delegates to auto-advance for actual loop execution.

`/resume` is the re-entry path for the within-session driver: when a session is driven by `/goal` and halts while the tool-based complete-check still reports incomplete (pending tasks, unpushed commits, dirty tree), the loop is **re-driven** — re-issue `/goal` or invoke `/resume` to re-enter the auto-advance entry guard. A `/goal` halt is a turn-budget/driver signal, **not** node completion; authoritative "done" stays the tool-based complete-check defined in `auto-advance.md` (all native Tasks completed + validation + commit/PR), never `/goal`'s transcript evaluator. See `auto-advance.md` → "Within-Session Driver (`/goal`)".

## Execution Steps

### 1. Assess Task State

```
TaskList → categorize tasks:
  - completed: tasks with status "completed"
  - in_progress: tasks with status "in_progress"
  - pending: tasks with status "pending"
  - blocked: pending tasks where blockedBy is non-empty
```

### 2. Display Context

Show the user what happened before the pause:

```
## Resume Context

**Completed**: <N> tasks
<for each completed task>
  - <task subject>

**Current task**: <in_progress task subject, or "none">
<if in_progress task exists>
  <task description summary — first 2-3 lines>

**Pause reason**: <inferred from context>
  Check recent state to determine why the loop stopped:
  - Uncommitted changes + failing tests → "Validation failure"
  - No code changes on current task → "Ambiguous decision"
  - Git errors in recent output → "Commit failure"
  - If indeterminate → "Unknown — task was in progress when session ended"

**Remaining**: <N> pending (<M> blocked)
```

### 3. Confirm Readiness (Conditional)

If a task is `in_progress`, the loop was paused mid-task. Ask:

```
AskUserQuestion: "Task '<subject>' was in progress when the loop paused. Is the issue resolved?"
  Options:
    - "Yes, continue with this task" → proceed to step 4
    - "Reset task to pending" → TaskUpdate(taskId, status: "pending"), proceed to step 4
    - "Skip this task" → TaskUpdate(taskId, status: "completed"), proceed to step 4
```

If no task is `in_progress`, skip to step 4.

### 4. Enter Auto-Advance

Load and execute the auto-advance operation:

```
Read: skills/task-workflow/operations/auto-advance.md
```

The auto-advance entry guard handles all scenarios from the current task state.

## Error Handling

| Error | Response |
|-------|----------|
| No tasks exist | "No tasks to resume. Run /init-workspace first." |
| All tasks completed | "All tasks are already complete. Run /finish to create the PR." |
| TaskList unavailable | Stop, report tool error |

## Example

### Resume after validation failure fix

```
User: /resume

## Resume Context

**Completed**: 2 tasks
  - Implement webhook handler
  - Add authentication middleware

**Current task**: Write integration tests
  Requirement R3: Add integration tests for webhook + auth flow.

**Remaining**: 1 pending (0 blocked)

Q: "Task 'Write integration tests' was in progress when the loop paused. Is the issue resolved?"
A: "Yes, continue with this task"

[Auto-advance resumes from step 2: implement]
```

## Integration Points

- **Predecessor**: Human fixes the issue that caused auto-advance to pause
- **Successor**: `operations/auto-advance.md` — resumes the autonomous loop
- **Task tools**: `TaskList`, `TaskGet`, `TaskUpdate` — assess and adjust task state
