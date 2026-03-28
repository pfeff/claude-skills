# Next Task Operation

Finds the next pending task and transitions to it, with a commit checkpoint to prevent losing uncommitted work.

## Inputs

- Workspace context (CLAUDE.md with repo paths, TaskList state)

## Coordinator Sync (Optional)

If `COORDINATOR_URL`, `COORDINATOR_TOKEN`, and `COORDINATOR_TASK_ID` are set, mirror status changes to the coordinator API.

```bash
coord_sync_status() {
  local task_id="$1" status="$2"
  if [[ -n "${COORDINATOR_URL:-}" && -n "${COORDINATOR_TOKEN:-}" && -n "${COORDINATOR_TASK_ID:-}" ]]; then
    curl -s -X PATCH "${COORDINATOR_URL}/api/tasks/${COORDINATOR_TASK_ID}" \
      -H "Authorization: Bearer ${COORDINATOR_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"task\":{\"status\":\"${status}\"}}" > /dev/null
  fi
}
```

## Implementation Steps

### 1. Check Current State

Use `TaskList` to view all tasks in the workspace.

- If a task is already `in_progress`, display it and stop (do not start a new one).
- If no pending tasks exist, inform the user the workspace has no remaining tasks and stop.
- Otherwise, identify the next pending task that is not blocked (no `blockedBy` dependencies).

### 2. Commit Checkpoint

Before transitioning to the new task, check for uncommitted work from the previous task.

**Discover repos**: Scan the workspace for git repositories (look for `.git` directories in the workspace root's subdirectories).

**Check each repo**:
```bash
git -C <repo_path> status --porcelain
```

**If any repo has uncommitted changes**:
- Report which repos have uncommitted changes
- Prompt the user with two options:
  - **Commit now**: Run `/commit-changes`, then continue to step 3
  - **Skip**: Proceed without committing

**If all repos are clean**: Proceed silently to step 3.

### 3. Start Task

1. Display the task details using `TaskGet`
2. Mark the task as `in_progress` using `TaskUpdate`
3. **Coordinator sync**: `coord_sync_status "$taskId" "in_progress"`
4. Present the task to the user:
   - Task subject and description
   - Any tasks this blocks (downstream impact)

Wait for user confirmation before beginning implementation.

## Rules

- Only one task should be `in_progress` at a time
- The commit checkpoint is non-blocking — if the user declines, proceed anyway
- During implementation, apply the git skill's **Incremental Commits** principle (see the git skill's SKILL.md) — commit at logical boundaries, don't wait until the task is fully complete

## Output Format

```
Starting: <task subject>

<task description>

Blocks: <list of tasks waiting on this one, or "None">

Ready to begin. What would you like to tackle first?
```

## Error Handling

| Condition | Behavior |
|-----------|----------|
| No tasks exist | Inform user, stop |
| Task already in_progress | Show it, stop |
| All tasks blocked | Report blocking relationships, stop |
| Git not available in repo | Skip that repo's check |
| `/commit-changes` fails | Report failure, ask user how to proceed |
