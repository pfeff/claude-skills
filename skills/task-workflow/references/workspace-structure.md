# Workspace Structure Reference

Standard layout for task workspaces.

## Structure

```
~/src/work/<project-slug>/<issue-slug>/
├── .envrc              # direnv config with Azure PAT and task list ID
├── DESIGN.md           # Task requirements, architecture, and QMD prior-context block
├── .tmuxp.yaml         # Tmux session configuration
├── <repo-1>/           # Git worktree for repository 1
├── <repo-2>/           # Git worktree for repository 2
└── ...
```

## .envrc Format

Each workspace includes a `.envrc` file for environment configuration:

```bash
layout python3

export TF_VAR_azure_devops_pat="<pat-value>"
export AZURE_DEVOPS_EXT_PAT="<pat-value>"
export CLAUDE_CODE_TASK_LIST_ID="<epic>-<task-id>"
```

- `TF_VAR_azure_devops_pat` - Terraform variable for Azure DevOps provider
- `AZURE_DEVOPS_EXT_PAT` - Azure CLI extension authentication
- `CLAUDE_CODE_TASK_LIST_ID` - Links workspace to Claude Code native task list

**Important**: Run `direnv allow` after workspace creation to activate the environment.

## DESIGN.md Format

First line must contain task metadata:
```markdown
# TASK-ID: Task Headline
```

Example:
```markdown
# DO-242: Implement OAuth Authentication
```

## Task Management

Workspaces use Claude Code's native task tools for progress tracking. Tasks persist in `~/.claude/tasks/<task-list-id>.json` and are linked via `CLAUDE_CODE_TASK_LIST_ID` in `.envrc`.

### Task Tools

| Tool | Purpose |
|------|---------|
| `TaskList` | View all tasks with status and dependencies |
| `TaskCreate` | Add new task with subject, description, activeForm |
| `TaskUpdate` | Change status, set dependencies, mark complete |
| `TaskGet` | Retrieve full task details by ID |

### Task Workflow

1. **Starting work**: `TaskUpdate(taskId, status: "in_progress")`
2. **Completing work**: `TaskUpdate(taskId, status: "completed")`
3. **Adding tasks**: `TaskCreate(subject, description, activeForm)`
4. **Checking progress**: `TaskList`

### Task States

| Status | Meaning |
|--------|---------|
| `pending` | Not yet started |
| `in_progress` | Currently being worked on |
| `completed` | Finished and verified |
| `deleted` | Removed (permanent) |

### Dependencies

Tasks can block other tasks:
- `addBlockedBy` - This task waits for listed tasks
- `addBlocks` - Listed tasks wait for this task

### Task Storage

Tasks are stored in JSON files at `~/.claude/tasks/`:
```
~/.claude/tasks/
├── <epic>-<task-id>.json    # Workspace-specific task list
└── ...
```

The `scan-task-dirs.sh` script scans these files to determine workspace status for `/list-workspaces`.

## Obsidian Symlink

Each workspace includes a symlink to the Obsidian vault:
```bash
Obsidian -> /path/to/obsidian/vault
```

## Solution Documentation

Solution retrieval now runs through QMD over the Obsidian vault (see the `## Prior Context (QMD)` block that `create-workspace.sh` injects into `DESIGN.md`). Capture new solution knowledge as regular Obsidian notes via `/finish`'s session-journal step or a direct note.

`docs/solutions/` in existing repos is treated as read-only historical material — no new writes. Legacy repos that still carry the tree are left alone per `MIGRATION.md`. `/compound` is deprecated and slated for removal after the Phase 5 observation window.

## Git Worktrees

Repositories are checked out as git worktrees from their main clones:
```bash
git worktree add ~/src/work/<project>/<task>/<repo> <branch>
```

## Submodule Management (Historical)

> **Note:** The `cursor-rules` submodule in dotfiles is deprecated. Skills and commands have been migrated to `claude-skills`. The patterns below are preserved as reference for any remaining git submodule workflows, but no longer apply to cursor-rules specifically.

Repositories using git submodules require special attention.

### Detached HEAD Issue

After `git submodule update --init --recursive` or dotbot install, submodules are often in **detached HEAD** state:

```bash
$ cd <submodule>
$ git status
HEAD detached at abc1234
```

This means:
- Local changes won't be on a branch
- Content from main may not be visible
- New file creation may conflict with existing files on main

### Sync Before Work Pattern

**Always sync submodules before creating new content**:

```bash
# Check current state
git -C <submodule> status

# Sync to main branch
git -C <submodule> checkout main
git -C <submodule> pull origin main
```

### When to Sync

Perform submodule sync:
1. **Before creating new skills** - Prevents duplicates
2. **After dotfiles install** - Restores branch tracking
3. **Before committing changes** - Ensures you're on correct branch
4. **When files seem missing** - May be on different branch

### Verification

```bash
# Verify branch state
git -C <submodule> branch -v

# Should show:
# * main  abc1234 [ahead N] Latest commit message
```

### Workspace-Specific Submodule Notes

When workspaces involve submodule changes:
1. Create a task noting submodule modifications are involved
2. Include submodule sync step in task plan
3. Commit submodule changes first, then update parent repo's submodule reference
