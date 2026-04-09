# Start Task Operation

Chains pull-task → workspace-from-issue into a single control-session command, producing a ready-to-attach work session.

**Requirements**: Runs in the control session. The work session runs `/init-workspace` separately (session boundary — see DD1 in DESIGN.md).

## Purpose

Eliminates the manual three-command sequence (`/claude-skills:pull-task` → `/setup-workspace` → `/init-workspace`) by orchestrating the first two phases automatically and bridging to the third with attach instructions. Single decision point: issue selection (R1, R2).

## Coordinator Sync (Optional)

If `COORDINATOR_URL`, `COORDINATOR_TOKEN`, and `COORDINATOR_MISSION_ID` are set, the workspace will be configured with coordinator references. The `create-workspace.sh` script sets `COORDINATOR_TASK_ID` in `.envrc` when these are available, enabling downstream operations (auto-advance, finish, next-task) to sync state to the coordinator.

## Parameters

- **--skip-stale-check** (optional): Bypass the stale workspace blocking check

## Execution Steps

### 1. Stale Workspace Check

Before pulling a new task, check for stale workspaces (issue closed but workspace still open):

```bash
${CLAUDE_PLUGIN_ROOT}/skills/task-workflow/scripts/stale-workspaces.sh
```

**If `--skip-stale-check` was specified**: Skip this step entirely.

**If stale workspaces found** (exit code 1): Display the stale workspaces and abort:

```
Stale workspaces detected — close them before starting new work:

  ~/src/work/cursor-rules/36-task-slug   pfeff/cursor-rules#36   CLOSED
  ~/src/work/guardian/42-other-task      pfeff/guardian#42        CLOSED

To close a workspace:
  /close-workspace <path>

To bypass this check:
  /start-task --skip-stale-check
```

Stop — do not proceed to pull-task or workspace creation.

**If no stale workspaces** (exit code 0): Continue to step 2.

**If script errors** (exit code 2): Warn and continue — do not block on detection failures:

```
Warning: Could not check for stale workspaces. Continuing.
```

### 2. Invoke Pull-Task Logic (R2)

Load and execute the pull-task skill to present ranked candidates:

```
Read(${CLAUDE_PLUGIN_ROOT}/skills/pull-task/operations/pull-task.md)
```

The pull-task skill handles:
- Project discovery (auto-detect owner from workspace context)
- Item fetching (`gh project item-list`)
- Filtering by status (Backlog/Planned) and type (Issues only)
- Ranking by sprint, horizon, strategic objective, labels
- Presentation via AskUserQuestion (single decision point)

**Output**: Issue reference in `owner/repo#number` format.

If the user cancels selection, stop — do not proceed to workspace creation.

### 3. Check for Existing Workspace (R7)

Before creating a new workspace, check if one already exists for the selected issue:

```bash
# task_id is always numeric (GitHub issue number)
task_id=<number>

# Search for existing workspace directories matching the task ID
ls ~/src/work/*/${task_id}-*/CLAUDE.md 2>/dev/null
```

| Result | Action |
|--------|--------|
| Workspace found | Skip to step 7 (display attach instructions) |
| No workspace | Continue to step 4 |

### 4. Infer Parameters (R3)

Pass the selected issue reference to workspace-from-issue logic. Load the operation:

```
Read(${CLAUDE_PLUGIN_ROOT}/skills/task-workflow/operations/workspace-from-issue.md)
```

Execute workspace-from-issue from "Fetch Issue Metadata" through "Confirm Parameters" (skipping "Parse Issue Reference" since we already have it from pull-task).

### 5. Create Workspace (R4)

Delegate to the bootstrap script:

```bash
${CLAUDE_PLUGIN_ROOT}/skills/task-workflow/scripts/create-workspace.sh \
  --task-id <number> \
  --epic <epic> \
  --headline "<title>" \
  --repos <repo-list> \
  --issue <owner>/<repo>#<number>
```

The script creates:
- Workspace directory structure
- Template files (DESIGN.md, CLAUDE.md, .envrc)
- Git worktrees with feature branches
- Tmux session

If the script fails, show the exit code and error. Do not retry.

### 6. Capture Workspace Output

Extract from script output or derive from parameters:

```
workspace_path=~/src/work/<epic>/<task-id>-<slug>/
session_name="<task-id>: <issue-title>"
```

### 7. Display Next Steps (R5, R6)

```
Task started: <owner>/<repo>#<number>
  <issue title>

  Path:    <workspace_path>
  Session: <session_name>

Next:
  1. tmux attach -t "<session_name>"
  2. Run /init-workspace in the work session
```

The `/init-workspace` step (R5) must run in the work session because it uses `TaskCreate` which requires `CLAUDE_CODE_TASK_LIST_ID` from the workspace `.envrc`.

## Idempotency (R7)

Re-running `/start-task` is safe. Step 1 re-checks stale workspaces. Step 3 detects existing workspaces and skips to attach instructions. Delegated components (`create-workspace.sh`, tmux scripts) handle their own idempotency.

## Error Handling

Errors from pull-task and workspace-from-issue propagate naturally (each sub-operation defines its own error handling). Errors specific to start-task:

| Error | Response |
|-------|----------|
| Stale workspaces detected | Display list, abort (unless `--skip-stale-check`) |
| Stale check script fails | Warn, continue to pull-task |
| User cancels issue selection | Stop gracefully, no workspace created |
| `create-workspace.sh` fails | Show exit code and error, do not retry |
| Existing workspace found | Skip creation, show attach instructions |

## Integration Points

- **Invoked by**: `/start-task` command
- **Delegates to**: pull-task skill (step 1), workspace-from-issue operation (steps 3–4)
- **Succeeded by**: `/init-workspace` (in work session, user-initiated)
- **Tools used**: `gh` CLI, `create-workspace.sh`, `stale-workspaces.sh`, AskUserQuestion, Read
