# Workspace Closing Operation

Cleanly tears down a task workspace by invoking `close-workspace.sh`.

## Purpose

Closes a task workspace when work is complete, preserving artifacts in a compressed archive while cleaning up active resources. All logic is handled by the deterministic script.

## Inputs

- **task-id** or **path** (optional): Task identifier or path to workspace. Defaults to current directory.
- **--no-archive** (optional): Skip archiving, just remove workspace components
- **--no-close-issue** (optional): Skip closing the linked GitHub issue (default: close it)

**Safety:** The script fails fast if `--force` is missing in non-interactive (non-TTY) environments,
and includes a defense-in-depth gate before destructive operations. Always pass `--force` from
non-interactive callers like Claude Code.

## Implementation Steps

### 1. Parse User Request

Extract task-id/path and flags from user input.

**Valid formats**:
- `/close-workspace`
- `/close-workspace 94`
- `/close-workspace ~/src/work/guardian/94-make-workspace-closure/`
- `/close-workspace 94 --no-archive`
- `/close-workspace --no-close-issue`

### 2. Build Script Arguments

Map parsed inputs to script arguments:

```
SCRIPT_PATH="skills/task-workflow/scripts/close-workspace.sh"
ARGS=""

# Positional: workspace path or task-id (if provided)
if [[ -n "$input" ]]; then
  ARGS="$input"
fi

# Flags
if no_archive requested; then
  ARGS="$ARGS --no-archive"
fi
if no_close_issue requested; then
  ARGS="$ARGS --no-close-issue"
fi
# Always force — Claude Code is non-interactive (no TTY)
ARGS="$ARGS --force"

# Always pass caller's cwd for safety check
ARGS="$ARGS --caller-cwd $(pwd)"
```

### 3. Invoke Script

**CRITICAL: CWD Safety** — The script runs as a subprocess, so its internal `cd $HOME` does NOT affect the calling shell. You MUST `cd ~/src` before invoking the script to prevent the shell from being stranded in a deleted directory.

```bash
cd ~/src && "$CURSOR_RULES_PATH/skills/task-workflow/scripts/close-workspace.sh" $ARGS
```

The script handles all operations:
- Workspace location and validation
- GitHub issue reference extraction from CLAUDE.md
- CWD safety warning (if `--caller-cwd` is inside workspace)
- Component inventory (worktrees, tmux, symlinks)
- User confirmation (unless `--force`)
- CWD safety (`cd $HOME` before destructive ops)
- Worktree removal via `git -C`
- Tmux session cleanup
- Archiving to `~/src/work/.archive/<epic>/<task-dir>.tar.gz`
- Directory removal
- Verification checks

### 4. Mark Task Completed

If the script exits successfully (exit code 0), mark the associated task as completed using `TaskUpdate(taskId, status: "completed")`. The task ID can be extracted from the workspace DESIGN.md first line (`# TASK-ID: Headline`) or from the `/close-workspace` arguments.

### 5. Report Results

Report the script's output to the user. On failure, relay the exit code meaning:

| Exit Code | Meaning |
|-----------|---------|
| 0 | Success |
| 1 | Invalid arguments |
| 2 | Workspace not found or invalid |
| 3 | Archive creation failed |
| 4 | Worktree removal failed |
| 5 | Verification failed |

## Error Handling

| Error | Response |
|-------|----------|
| Script not found | Report path and check cursor-rules repo location |
| Non-zero exit | Report exit code meaning from table above |
| User cancels (at script prompt) | Script exits 0, no action taken |

## Examples

### Close current workspace (with issue close)
```
User: /close-workspace

> Runs: close-workspace.sh --caller-cwd /home/user/src --force

Workspace: ~/src/work/platform/TOOS-24-fix-auth
  Task:     TOOS-24 - Fix authentication bug
  Epic:     platform
  Task Dir: TOOS-24-fix-auth
  GitHub Issue: user/repo#24

Inventorying components...
  Worktrees:        my-app
  Tmux session:     TOOS-24- Fix authentication bug

Archiving to: ~/src/work/.archive/platform/TOOS-24-fix-auth.tar.gz
Removing worktree: my-app
Removing workspace directory

All verification checks passed!

Workspace closed successfully!
```

### Close without closing the issue
```
User: /close-workspace --no-close-issue

> Runs: close-workspace.sh --no-close-issue --caller-cwd /home/user/src --force
Skipping issue close (--no-close-issue)
```

### Close by task ID without archive
```
User: /close-workspace 94 --no-archive

> Runs: close-workspace.sh 94 --no-archive --caller-cwd /home/user/src --force
```

## Integration Points

- **Script location**: `skills/task-workflow/scripts/close-workspace.sh`
- **Workspace structure**: `~/src/work/<epic>/<task-id>-<slug>/`
- **Archive structure**: `~/src/work/.archive/<epic>/<task-id>-<slug>.tar.gz`
- **DESIGN.md format**: First line `# TASK-ID: Headline`
- **Re-hydration**: Archive can be restored via `/open-workspace`
