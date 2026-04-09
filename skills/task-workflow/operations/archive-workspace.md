# Archive Workspace Operation

Archive completed workspaces rather than deleting them, preserving historical context for reference.

## When to Use

- Task is fully complete and no longer actively worked
- Workspace consuming disk space but may have valuable context
- Cleaning up `~/src/work/` directory while preserving history

## Archive Structure

```
~/src/work/.archive/<epic>/<task>/
├── DESIGN.md          # Preserved task documentation
├── notes/             # Any task-specific notes
└── metadata.yaml      # Archive metadata (includes task list ID)
```

## Implementation

### Step 1: Verify Completion

Use `TaskList` to verify all tasks are completed. All tasks should have status `completed`.

### Step 2: Archive Workspace

```bash
WORKSPACE_PATH=~/src/work/<epic>/<task>
ARCHIVE_PATH=~/src/work/.archive/<epic>/<task>
TASK_LIST_ID=$(grep CLAUDE_CODE_TASK_LIST_ID "$WORKSPACE_PATH/.envrc" | cut -d= -f2 | tr -d '"')

# Create archive directory
mkdir -p "$ARCHIVE_PATH"

# Preserve documentation
cp "$WORKSPACE_PATH/DESIGN.md" "$ARCHIVE_PATH/"

# Create archive metadata (includes task list ID for reference)
cat > "$ARCHIVE_PATH/metadata.yaml" << EOF
archived: $(date -Iseconds)
original_path: $WORKSPACE_PATH
task_id: <task-id>
headline: <task-headline>
task_list_id: $TASK_LIST_ID
repositories:
  - name: <repo>
    branch: <branch>
EOF
```

**Note**: Task history is preserved in `~/.claude/tasks/$TASK_LIST_ID.json`.

### Step 3: Remove Git Worktrees

```bash
# For each worktree in workspace
cd ~/src/github/<org>/<repo>  # or azdevops path
git worktree remove "$WORKSPACE_PATH/<repo>"
```

### Step 4: Clean Up Tmux Session

```bash
# Kill associated tmux session
tmux kill-session -t "<task-id>: <headline>"
```

### Step 5: Remove Workspace Directory

```bash
# Only after worktrees removed
rm -rf "$WORKSPACE_PATH"
```

## Archive vs Delete Decision Tree

```
Is the task complete?
├── No → Keep active, don't archive
└── Yes → Continue
    │
    Was significant learning captured?
    ├── Yes → Archive (preserve context)
    └── No → Continue
        │
        Was the task trivial (<1 day work)?
        ├── Yes → Safe to delete directly
        └── No → Archive (preserve history)
```

## Retrieving Archived Context

```bash
# Find archived workspace
ls ~/src/work/.archive/<epic>/

# Read archived documentation
cat ~/src/work/.archive/<epic>/<task>/DESIGN.md

# Get task list ID from metadata
grep task_list_id ~/src/work/.archive/<epic>/<task>/metadata.yaml

# View task history (if task list still exists)
cat ~/.claude/tasks/<task-list-id>.json
```

## Key Lesson

**Archive rather than delete** - Historical configurations and decisions provide valuable reference for similar future work. The disk space cost is minimal compared to the context preservation value.

## See Also

- `operations/list-workspaces.md` - List active workspaces
- `references/workspace-structure.md` - Standard workspace layout
