---
name: task-workflow
description: Manage development task workspaces with standardized structure including workspace creation, git worktree management, tmux session orchestration, and progress tracking. Use when creating tasks, setting up workspaces, resuming work, listing tasks by status, navigating task plans, or finishing a workspace. Supports multi-repository projects with automated environment setup.
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - AskUserQuestion
allowed-prompts:
  - tool: Bash
    prompt: create tmux sessions
  - tool: Bash
    prompt: list tmux sessions
  - tool: Bash
    prompt: check tmux session existence
  - tool: Bash
    prompt: kill tmux sessions
  - tool: Bash
    prompt: remove git worktrees
  - tool: Bash
    prompt: create archive tarballs
  - tool: Bash
    prompt: extract archive tarballs
  - tool: Bash
    prompt: render task dependency graph
  - tool: Bash
    prompt: run project tests
  - tool: Bash
    prompt: run lint and format checks
  - tool: Bash
    prompt: check existing workspaces
  - tool: Bash
    prompt: create workspace from script
  - tool: Bash
    prompt: check git status
  - tool: Bash
    prompt: view GitHub PRs
  - tool: Bash
    prompt: check GitHub PR CI status
  - tool: Bash
    prompt: create GitHub PRs
  - tool: Bash
    prompt: write metrics log
  - tool: Bash
    prompt: sleep for backoff between retries
version: 1.0.0
---

# Task Workflow Skill

Manages development task workspaces with standardized structure, git worktree management, tmux session orchestration, and progress tracking.

## Core Concepts

**Workspace Structure**: `~/src/work/<epic-slug>/<task-id>-<task-slug>/`

Each workspace contains:
- **.envrc**: direnv config with `CLAUDE_CODE_TASK_LIST_ID` for native task tracking
- **DESIGN.md**: Task overview with format `# TASK-ID: Headline` on first line
- **Git worktrees**: Per repository specified
- **Tmux session**: Named `"<task-id>: <headline>"`

**Metadata Format**:
- Task ID: Short identifier (e.g., `DO-242`, `skills-workflow`)
- Epic: Category slug (e.g., `ad-hoc`, `tooling`, `platform`)
- Slug: 2-3 word concise identifier from headline

## Operations

### 1. Task Creation

Creates task documentation in `docs/tasks/` with interactive Q&A.

**When**: User requests task documentation or needs planning.

**Implementation**: Load `operations/create-task.md` for detailed steps.

**Quick summary**: Mode-based questioning (quick/progressive/full), outputs task file.

### 2. Workspace Setup

Creates complete development environment for a task.

**When**: User needs to start active work on a task.

**Implementation**: Load `operations/workspace-setup.md` for detailed steps.

**Quick summary**: Creates directory, DESIGN.md, .envrc (with task list ID), git worktrees, tmux session.

### 3. Workspace Opening

Discovers and opens existing workspace.

**When**: User returns to previous work or switches workspaces.

**Implementation**: Load `operations/open-workspace.md` for detailed steps.

**Quick summary**: Locate workspace, extract metadata, restore tmux session.

### 4. Workspace Listing

Shows all workspaces filtered by status with progress.

**When**: User needs overview of active/completed work.

**Implementation**: Load `operations/list-workspaces.md` for detailed steps.

**Quick summary**: Scan workspaces, parse TODO progress, format by status.

### 5. Task Navigation

Finds the next pending task and transitions to it, with a commit checkpoint to prevent losing uncommitted work.

**When**: User needs to know what to work on next, or is transitioning between tasks.

**Implementation**: Load `operations/next-task.md` for detailed steps.

**Quick summary**: Checks for uncommitted changes in workspace repos before transitioning. If dirty, prompts user to commit or skip. Then displays next pending task and marks it in_progress.

### 6. Dependency Graph

Renders task dependency relationships as an ASCII diagram or mermaid flowchart.

**When**: User wants to visualize task ordering, blocking relationships, or dependency chains.

**Implementation**: Load `operations/dependency-graph.md` for detailed steps.

**Quick summary**: Runs `render_deps.py` against current workspace's task list. Outputs layered ASCII graph with status icons, or mermaid flowchart with `--mermaid`.

### 7. Validate Implementation

Runs tests and lint checks after task implementation, retrying on failure before proceeding to commit.

**When**: After completing task implementation, before `/commit-changes`. Ensures code quality gates are met.

**Implementation**: Load `operations/validate-implementation.md` for detailed steps.

**Quick summary**: Auto-detects test runner and linter from project config files, executes both. Classifies failures as transient (flakes, timeouts) or permanent (code bugs) via `references/error-classification.md`. Transient errors retry with exponential backoff (`AUTO_ADVANCE_TRANSIENT_RETRIES`, default 3). Permanent errors retry with fix attempts (`AUTO_ADVANCE_MAX_RETRIES`, default 2). Pauses for human input if still failing.

### 8. Workspace Closing

Cleanly tears down a workspace: removes worktrees, kills tmux, archives artifacts.

**When**: Task complete, cleaning up workspaces while preserving history.

**Implementation**: Load `operations/close-workspace.md` for detailed steps.

**Quick summary**: Remove git worktrees, kill tmux session, remove symlinks, create tarball archive at `~/src/work/.archive/<epic>/<task>.tar.gz`.

### 9. Finish Workflow

Guided post-completion workflow: commit, PR, review, knowledge capture, metrics, close instructions.

**When**: All tasks in a workspace are complete and the user is ready to wrap up.

**Implementation**: Load `operations/finish.md` for detailed steps.

**Quick summary**: Checks task completion, auto-commits, creates PR, runs review with fix loop, prompts for /compound and /lessons-learned, captures metrics, prints close instructions. Each phase fails gracefully with manual fallback.

### 10. Auto-Advance

Autonomously cycles through the task list: pick next task → implement → validate → commit → repeat.

**When**: Default behavior after task list is created, or when resuming a session with pending tasks.

**Implementation**: Load `operations/auto-advance.md` for detailed steps.

**Quick summary**: Entry guard checks task list state (zero tasks, all blocked, in-progress resume). Loop body: TaskList → pick next unblocked → implement → validate-implementation → git commit → TaskUpdate(completed) → loop. Transient errors at any step are retried with exponential backoff. On all-tasks-complete: commits remaining changes, creates PR, waits for CI checks, and reports status. Pauses on: CI failure, validation failure after retries, ambiguous decision, or commit failure.

### 11. Resume

Re-enters the auto-advance loop after human intervention.

**When**: Auto-advance paused due to validation failure, ambiguous decision, or commit failure. Human has fixed the issue and wants to continue.

**Implementation**: Load `operations/resume.md` for detailed steps.

**Quick summary**: Assesses task state, displays pause context (completed tasks, current task, remaining work), confirms readiness if a task is in-progress, then delegates to auto-advance entry guard.

### 12. Resume Status

Displays auto-advance loop state without resuming. Read-only.

**When**: Human wants to check progress or understand why the loop paused before deciding to `/resume`.

**Implementation**: Load `operations/resume-status.md` for detailed steps.

**Quick summary**: Categorizes tasks by status, infers loop state (complete, paused, ready, blocked, empty), displays progress summary with guidance for next action.

### 13. Fan-Out

Spawns N subagents in parallel via the Task tool, collects all results, handles partial failures, and returns aggregated output.

**When**: Multiple independent work streams need to run concurrently.

**Implementation**: Load `operations/fan-out.md` for detailed steps.

**Quick summary**: Validates agent specs, spawns all in a single message for parallel execution, collects results with success/failure tracking, returns aggregated output for caller synthesis.

### 14. Dispatch Task

Dispatches a single task to a subagent via the Task tool and returns a structured result.

**When**: A task should be offloaded to a subagent for isolated execution.

**Implementation**: Load `operations/dispatch-task.md` for detailed steps.

**Quick summary**: Spawns subagent with caller-assembled prompt, parses structured result (RESULT_START/END markers), retries on failure, signals fallback to inline execution when retries exhausted.

## Common Patterns

**Slug Creation**: Extract 2-3 keywords from headline
- "DWH-DBT Scrape Tags failing" → `scrape-tags-failing`
- "Amazon EC2 Instance Retirement" → `ec2-retirement`

**Metadata Extraction**: Always parse DESIGN.md first line for authoritative task-id and headline

**Task Tracking**: Use Claude's native task tools:
- `TaskList` - View all tasks for workspace
- `TaskCreate` - Add new tasks
- `TaskUpdate(status: in_progress)` - Start a task
- `TaskUpdate(status: completed)` - Finish a task

**Task Purpose**: When you encounter something that needs attention but isn't part of the current task, use `TaskCreate` to add it rather than acting on it immediately. This prevents "side quests" that derail focused work. Complete the current task first, then address queued tasks in order.

**Blocker Signal Recognition**: When encountering annotations like `TODO(BUG)`, `TODO(LATER)`, `FIXME(LATER)`, or similar patterns:
1. **Treat as documentation directive**, not action directive
2. Record via `TaskCreate` or add to PLAN.md as appropriate
3. Continue with the current task
4. Do NOT investigate, debug, or fix the flagged issue

**Status Symbols**: Use status indicators for clarity:
- ✅ Implemented and verified
- ⏸️ Paused or partially complete
- 🔮 Planned but not started
- ❌ Blocked or abandoned

**Tmux Session Creation**:
> **CRITICAL**: NEVER create tmux sessions manually with `tmux new-session`. ALWAYS use the script below.

```bash
~/.claude/skills/task-workflow/scripts/create-tmuxp-session.sh "<session-name>" <workspace-dir>
```

The script:
- Creates 3 windows: nvim (1), zsh (2), claude (9)
- Starts nvim and claude processes automatically
- Sanitizes session names (colons → hyphens)
- Uses tmuxp for reliable session creation

**Wrong**: `tmux new-session -d -s "DO-361"` (creates only 1 window, no processes)
**Right**: `~/.claude/skills/task-workflow/scripts/create-tmuxp-session.sh "DO-361: headline" ~/src/work/epic/task`

**Symlink Resolution**: When editing files referenced by `~/.claude/` paths, always resolve via `realpath` first and edit the worktree copy if one exists.

```bash
# Before editing, resolve the actual path
REAL_PATH=$(realpath ~/.claude/skills/my-skill/SKILL.md)
# If a worktree copy exists, edit there instead
```

## Permissions

The skill requires these bash commands for workspace management:

| Permission | Commands | Purpose |
|------------|----------|---------|
| create tmux sessions | `~/.claude/skills/task-workflow/scripts/create-tmuxp-session.sh` | Create 3-window session via tmuxp |
| list tmux sessions | `tmux list-sessions` | Discover existing sessions |
| check tmux session existence | `tmux has-session -t "<session-name>"` | Verify session before creating |
| kill tmux sessions | `tmux kill-session -t "<session-name>"` | Clean up session on workspace close |
| remove git worktrees | `git worktree remove <path>` | Clean up worktrees on workspace close |
| create archive tarballs | `tar -czf <archive> <dir>` | Archive workspace artifacts |
| extract archive tarballs | `tar -xzf <archive> -C <dir>` | Restore workspace from archive |
| render task dependency graph | `~/.claude/skills/task-workflow/scripts/render_deps.py` | Visualize task blocking relationships |
| run project tests | `pytest`, `go test`, `mix test`, `npm test`, `make test`, `cargo test` | Execute project test suite during validation |
| run lint and format checks | `pre-commit run`, `ruff check`, `npx eslint`, `mix format`, `gofmt`, `make lint` | Execute lint/format checks during validation |
| check existing workspaces | `ls ~/src/work/*/<id>-*/CLAUDE.md` | Detect existing workspace before creation |
| create workspace from script | `~/.claude/skills/task-workflow/scripts/create-workspace.sh` | Bootstrap workspace directory, worktrees, tmux |
| check git status | `git -C <repo> status --porcelain` | Detect uncommitted changes during /finish |
| view GitHub PRs | `gh pr view --json url,state` | Check for existing PR during /finish and auto-advance |
| check GitHub PR CI status | `gh pr checks --watch --fail-fast` | Poll CI checks after auto-advance PR creation |
| create GitHub PRs | `gh pr create` | Create PR during auto-advance completion |
| write metrics log | `mkdir -p`, `jq`, `>> finish.jsonl` | Capture workspace metrics during /finish |
| sleep for backoff between retries | `sleep <seconds>` | Exponential backoff delay during transient error retry |

## Quick Reference

**Create workspace**: Provide task-id, epic, headline, optional repos
**Resume work**: Provide task-id, optional epic for disambiguation; auto-restores from archive if needed
**Finish workspace**: Guided post-completion: commit, PR, review, knowledge capture, metrics, close instructions
**Close workspace**: Removes worktrees, kills tmux, archives to tarball; use `--no-archive` to skip archival
**List workspaces**: Optionally filter by status (in-progress/completed/all)
**Navigate tasks**: Use `TaskList` to find pending tasks
**Auto-advance**: Session-level default — loops through tasks autonomously after init; on completion creates PR and waits for CI; stops on CI failure, validation failure, or ambiguity
**Resume**: Re-enter auto-advance after fixing the issue that caused a pause
**Resume status**: Check auto-advance progress and pause reason without resuming
**Dependency graph**: Visualize task ordering with ASCII or mermaid output

## Progressive Disclosure

Load only what you need:

**Operations** (load on-demand):
- `operations/create-task.md` - Task creation implementation
- `operations/workspace-setup.md` - Workspace setup implementation
- `operations/open-workspace.md` - Workspace opening implementation (includes archive re-hydration)
- `operations/list-workspaces.md` - Workspace listing implementation
- `operations/close-workspace.md` - Workspace closing and archival
- `operations/finish.md` - Post-completion workflow (commit, PR, review, knowledge capture, metrics)
- `operations/dependency-graph.md` - Task dependency visualization
- `operations/validate-implementation.md` - Post-implementation test and lint validation
- `operations/next-task.md` - Task navigation with commit checkpoint
- `operations/auto-advance.md` - Autonomous task loop (pick → implement → validate → commit → repeat)
- `operations/resume.md` - Re-enter auto-advance after human intervention
- `operations/resume-status.md` - Read-only auto-advance state inspection
- `operations/fan-out.md` - Parallel subagent dispatch
- `operations/dispatch-task.md` - Single subagent dispatch with retry

**Reference Documentation**:
- `references/error-classification.md` - Transient vs permanent error taxonomy for retry decisions
- `references/retry-with-backoff.md` - Exponential backoff algorithm with jitter and escalation format
- `references/workspace-structure.md` - Workspace layout and structure
- `references/tmux-sessions.md` - Tmux session management
- `references/solution-search.md` - Grep-first search protocol for solution docs
- `references/subagent-dispatch.md` - Subagent dispatch protocol and template variables

**Supporting Files**:
- `scripts/` - Shell utilities for workspace operations
- `templates/` - File generation templates

## Scripts

All scripts are in `~/.claude/skills/task-workflow/scripts/`:

- `create-tmuxp-session.sh "<session-name>" <workspace-dir>` - **Required** for tmux session creation
- `create-workspace.sh` - Bootstrap workspace directory, worktrees, tmux

## Templates

- `templates/DESIGN.md.tmpl` - Task documentation
- `templates/CLAUDE.md.tmpl` - Workspace context and instructions
- `templates/.envrc.tmpl` - Task list ID and auto-advance configuration
- `templates/settings.json.tmpl` - Claude Code permissions
- `templates/solution.md.tmpl` - Solution documentation with YAML frontmatter
- `templates/subagent-task-prompt.md.tmpl` - Subagent dispatch prompt template
