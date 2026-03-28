# Workspace Setup Operation

Creates complete development environment for a task.

## Purpose

Sets up a new task workspace with standardized structure, git worktrees, documentation files, and tmux session.

## Implementation

**Use the bootstrap script for deterministic workspace creation:**

```bash
scripts/create-workspace.sh \
  --task-id <ID> \
  --epic <EPIC> \
  --headline "<HEADLINE>" \
  [--repos <REPOS>] \
  [--issue <ISSUE>] \
  [--description "<DESC>"]
```

The script handles all setup steps and runs verification checks.

## Parameters

| Parameter | Required | Description | Example |
|-----------|----------|-------------|---------|
| `--task-id` | Yes* | Task identifier | `19`, `DO-242` |
| `--epic` | Yes | Epic/project slug | `cursor-rules`, `ad-hoc` |
| `--headline` | Yes* | Task title | `"Use deterministic script..."` |
| `--repos` | No | Comma-separated repo names | `cursor-rules`, `my-app,my-lib` |
| `--issue` | No | GitHub issue reference | `user/repo#19` |
| `--description` | No | Extended description | `"Detailed task description..."` |

*When `--issue` is provided, `--task-id` and `--headline` are derived from the issue metadata if not explicitly given. Explicit flags override derived values.

## Prerequisites

The script will check for these before proceeding:

| Prerequisite | Purpose | Setup |
|--------------|---------|-------|
| `envsubst` | Template rendering | `brew install gettext` |
| `tmuxp` | Tmux session management | `pip install tmuxp` |
| `direnv` | Environment management | `brew install direnv` |

## What Gets Created

### Directory Structure

```
~/src/work/<epic>/<task-id>-<slug>/
├── DESIGN.md           # Task design document
├── CLAUDE.md           # Workspace instructions for Claude
├── .envrc              # direnv configuration
├── .tmuxp.yaml         # Tmux session config
└── <repo>/             # Git worktree (one per repo in --repos)
    └── docs/solutions/ # Solution documentation directories
```

### Generated Values

| Value | Source | Example |
|-------|--------|---------|
| `TASK_SLUG` | 2-3 keywords from headline | `deterministic-bootstrap` |
| `WORKSPACE_PATH` | `~/src/work/<epic>/<task-id>-<slug>` | `~/src/work/my-project/19-deterministic-bootstrap` |
| `TASK_LIST_ID` | `<epic>-<task-id>` | `my-project-19` |
| `SESSION_NAME` | `<task-id>: <headline>` | `19: Use deterministic script...` |
| `BRANCH_NAME` | `<task-id>/<slug>` | `19/deterministic-bootstrap` |

### Coordinator Integration (Optional)

When `COORDINATOR_URL` and `COORDINATOR_TOKEN` are available in the environment during workspace creation, the `.envrc` template includes coordinator references for downstream operations. These enable auto-advance, finish, and next-task to mirror state to the coordinator API.

| Variable | Source | Purpose |
|----------|--------|---------|
| `COORDINATOR_URL` | Parent environment | Coordinator API base URL |
| `COORDINATOR_TOKEN` | Parent environment | Bearer token for API auth |
| `COORDINATOR_MISSION_ID` | Parent environment | Mission this workspace belongs to |
| `COORDINATOR_TASK_ID` | Parent environment or created on setup | Task record in coordinator |

### Template Files

Templates are in `skills/task-workflow/templates/` and use `${VAR}` syntax for `envsubst`:

- `DESIGN.md.tmpl` - Task design document
- `CLAUDE.md.tmpl` - Workspace CLAUDE.md
- `.envrc.tmpl` - direnv configuration
- `solution.md.tmpl` - Solution documentation (used manually, not during setup)

## Verification

The script runs these checks after creation:

```
Running verification checks...
  ✓ Workspace directory exists
  ✓ DESIGN.md first line format
  ✓ CLAUDE.md contains Task Details
  ✓ .envrc contains CLAUDE_CODE_TASK_LIST_ID
  ✓ .claude/settings.json contains permissions
  ✓ .tmuxp.yaml exists with correct session
  ✓ Git worktree <repo> not on default branch
  ✓ Git worktree <repo> on correct branch
  ✓ Tmux session running
  ✓ direnv allowed

All verification checks passed!
```

Exit code 7 if any check fails.

### Branch Safety

Worktree creation includes a post-creation verification step. After each worktree is created, the script checks that `HEAD` is on the expected feature branch, not the default branch (`main`/`master`). If a worktree ends up on the default branch, the script automatically creates or switches to the feature branch. The verification also explicitly fails if any worktree is still on a default branch.

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success, all verifications passed |
| 1 | Invalid arguments or missing required params |
| 2 | Prerequisite check failed |
| 3 | Template rendering failed |
| 4 | Git worktree creation failed |
| 6 | Tmux session creation failed |
| 7 | Verification failed |
| 8 | Issue derivation failed (bad ref, gh unavailable, issue not found) |

## Example

```bash
scripts/create-workspace.sh \
  --task-id 19 \
  --epic my-project \
  --headline "Implement retry logic for webhook handler" \
  --repos my-app
```

**Output:**

```
Creating workspace for task 19...
  Slug: implement-retry-logic
  Path: ~/src/work/my-project/19-implement-retry-logic

Checking prerequisites...
  Prerequisites OK

Creating workspace directory...
  Created: ~/src/work/my-project/19-implement-retry-logic

Rendering templates...
  DESIGN.md: created
  CLAUDE.md: created
  .envrc: created
  .claude/settings.json: created

Creating git worktrees...
  my-app:
    Source: ~/src/github/user/my-app
    Worktree: ~/src/work/my-project/19-implement-retry-logic/my-app
    Branch: 19/implement-retry-logic
    Created worktree

Creating docs/solutions/ directories...
  my-app: docs/solutions/ created

Configuring direnv...
  direnv: allowed

Creating tmux session...
  Tmux session created

Running verification checks...
  ✓ Workspace directory exists
  ✓ DESIGN.md first line format
  ✓ CLAUDE.md contains Task Details
  ✓ .envrc contains CLAUDE_CODE_TASK_LIST_ID
  ✓ .claude/settings.json contains permissions
  ✓ .tmuxp.yaml exists with correct session
  ✓ Git worktree my-app on correct branch
  ✓ Tmux session running
  ✓ direnv allowed

All verification checks passed!

==========================================
Workspace created successfully!
==========================================

  Path:         ~/src/work/my-project/19-implement-retry-logic
  Task List ID: my-project-19
  Tmux Session: 19- Implement retry logic for webhook handler

Files created:
  - DESIGN.md
  - CLAUDE.md
  - .envrc
  - .claude/settings.json

Git worktrees:
  - my-app (branch: 19/implement-retry-logic)

Next steps:
  tmux attach -t "19- Implement retry logic for webhook handler"
```

## Integration Points

- **Repository mapping**: Searches `~/src/github/<org>/<repo>` for source repositories
- **Tmux session**: Delegates to `scripts/create-tmuxp-session.sh`
- **Opened by**: `/open-workspace` command
