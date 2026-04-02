# Workspace Setup Operation

Creates complete development environment for a task.

## Purpose

Sets up a new task workspace with standardized structure, git worktrees, documentation files, and tmux session.

## Implementation

**Use the bootstrap script for deterministic workspace creation:**

```bash
${CLAUDE_PLUGIN_ROOT}/skills/task-workflow/scripts/create-workspace.sh \
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
| `--repos` | No | Comma-separated repo names | `cursor-rules`, `Dev-Stacks,bh-platform` |
| `--issue` | No | GitHub issue reference | `pfeff/cursor-rules#19` |
| `--description` | No | Extended description | `"Detailed task description..."` |

*When `--issue` is provided, `--task-id` and `--headline` are derived from the issue metadata if not explicitly given. Explicit flags override derived values.

## Prerequisites

The script will check for these before proceeding:

| Prerequisite | Purpose | Setup |
|--------------|---------|-------|
| `envsubst` | Template rendering | `brew install gettext` |
| `tmuxp` | Tmux session management | `pip install tmuxp` |
| `direnv` | Environment management | `brew install direnv` |
| 1Password CLI | Azure PAT retrieval (optional) | `brew install 1password-cli` |
| AWS CLI | Octopus API key retrieval (optional) | `brew install awscli` |

**Optional secrets:**
- **Azure PAT**: From 1Password item "Azure CLI PAT" (requires `op signin`)
- **Octopus API Key**: From AWS Secrets Manager (requires `aws sso login --profile tcetra-devops-sso`)

Secrets are optional - the script continues without them if unavailable.

## What Gets Created

### Directory Structure

```
~/src/work/<epic>/<task-id>-<slug>/
├── DESIGN.md           # Task design document
├── CLAUDE.md           # Workspace instructions for Claude
├── .envrc              # direnv configuration
├── .tmuxp.yaml         # Tmux session config
├── Obsidian/           # Symlink to Obsidian vault (if available)
└── <repo>/             # Git worktree (one per repo in --repos)
    └── docs/solutions/ # Solution documentation directories
```

### Generated Values

| Value | Source | Example |
|-------|--------|---------|
| `TASK_SLUG` | 2-3 keywords from headline | `deterministic-bootstrap` |
| `WORKSPACE_PATH` | `~/src/work/<epic>/<task-id>-<slug>` | `~/src/work/cursor-rules/19-deterministic-bootstrap` |
| `TASK_LIST_ID` | `<epic>-<task-id>` | `cursor-rules-19` |
| `SESSION_NAME` | `<task-id>: <headline>` | `19: Use deterministic script...` |
| `BRANCH_NAME` | `<task-id>/mbp/<slug>` | `19/mbp/deterministic-bootstrap` |

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
  ✓ .tmuxp.yaml exists with correct session
  ✓ Git worktree <repo> not on default branch
  ✓ Git worktree <repo> on correct branch
  ✓ Tmux session running
  ✓ direnv allowed

All verification checks passed!
```

Exit code 7 if any check fails.

### Branch Safety

Worktree creation includes a post-creation verification step. After each worktree is created, the script checks that `HEAD` is on the expected feature branch, not the default branch (`main`/`master`). If a worktree ends up on the default branch, the script automatically creates or switches to the feature branch. The Step 9 verification also explicitly fails if any worktree is still on a default branch.

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success, all verifications passed |
| 1 | Invalid arguments or missing required params |
| 2 | Prerequisite check failed |
| 3 | Template rendering failed |
| 4 | Git worktree creation failed |
| 5 | Secret fetching failed |
| 6 | Tmux session creation failed |
| 7 | Verification failed |
| 8 | Issue derivation failed (bad ref, gh unavailable, issue not found) |

## Example

```bash
${CLAUDE_PLUGIN_ROOT}/skills/task-workflow/scripts/create-workspace.sh \
  --task-id 19 \
  --epic cursor-rules \
  --headline "Use deterministic script for workspace bootstrapping" \
  --repos cursor-rules \
  --issue pfeff/cursor-rules#19
```

**Output:**

```
Creating workspace for task 19...
  Slug: use-deterministic-script
  Path: /Users/matt/src/work/cursor-rules/19-use-deterministic-script

Checking prerequisites...
  Prerequisites OK

Fetching secrets...
  Azure PAT: retrieved from 1Password
  Octopus API Key: skipped (no valid AWS session)

Creating workspace directory...
  Created: /Users/matt/src/work/cursor-rules/19-use-deterministic-script

Rendering templates...
  DESIGN.md: created
  CLAUDE.md: created
  .envrc: created

Creating git worktrees...
  cursor-rules:
    Source: /Users/matt/src/github/pfeff/cursor-rules
    Worktree: /Users/matt/src/work/cursor-rules/19-use-deterministic-script/cursor-rules
    Branch: 19/mbp/use-deterministic-script
    Created worktree

Configuring direnv...
  direnv: allowed

Creating Obsidian symlink...
  Obsidian: linked

Creating tmux session...
  Tmux session '19- Use deterministic script for workspace bootstrapping' created

Running verification checks...
  ✓ Workspace directory exists
  ✓ DESIGN.md first line format
  ✓ CLAUDE.md contains Task Details
  ✓ .envrc contains CLAUDE_CODE_TASK_LIST_ID
  ✓ .tmuxp.yaml exists with correct session
  ✓ Git worktree cursor-rules on correct branch
  ✓ Tmux session running
  ✓ direnv allowed

All verification checks passed!

==========================================
Workspace created successfully!
==========================================

  Path:         /Users/matt/src/work/cursor-rules/19-use-deterministic-script
  Task List ID: cursor-rules-19
  Tmux Session: 19- Use deterministic script for workspace bootstrapping

Files created:
  - DESIGN.md
  - CLAUDE.md
  - .envrc

Git worktrees:
  - cursor-rules (branch: 19/mbp/use-deterministic-script)

Next steps:
  tmux attach -t "19- Use deterministic script for workspace bootstrapping"
```

## Integration Points

- **Repository mapping**: Searches `~/src/github/<org>/<repo>` and `~/src/azdevops/`
- **Tmux session**: Delegates to `scripts/create-tmuxp-session.sh`
- **Opened by**: `/open-workspace` command
