---
name: task-workflow
description: Manage development task workspaces with standardized structure including workspace creation, git worktree management, tmux session orchestration, GitHub issue integration, and progress tracking. Use when creating tasks, setting up workspaces, resuming work, listing tasks by status, navigating task plans, or finishing a workspace. Supports multi-repository projects with automated environment setup.
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
    prompt: fetch GitHub issues
  - tool: Bash
    prompt: fetch Jira tickets
  - tool: Bash
    prompt: run project tests
  - tool: Bash
    prompt: run lint and format checks
  - tool: Bash
    prompt: list GitHub projects
  - tool: Bash
    prompt: list GitHub project fields
  - tool: Bash
    prompt: list GitHub project items
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
version: 1.6.0
---

# Task Workflow Skill

Manages development task workspaces with standardized structure, git worktree management, tmux session orchestration, and GitHub integration.

## Public/Private Split

Generic execution mechanics (auto-advance, validate-implementation, finish, fan-out, dispatch, workspace create/open/close/list) are maintained in the public `claude-skills` plugin under `skills/task-workflow/`. This repository extends the public skill with private integrations:

- **GitHub issue/board integration**: workspace-from-issue, init-workspace, start-task, pull-task
- **Jira integration**: Jira ticket fetching in init-workspace
- **Org-specific workspace setup**: org detection, secret fetching, Azure PAT, employer env vars
- **Repository-specific skills**: Dev-Stacks, Octopus detection in open-workspace

Operations in this repo may reference public operations from `claude-skills` for shared mechanics.

## Core Concepts

**Workspace Structure**: `~/src/work/<epic-slug>/<task-id>-<task-slug>/`

Each workspace contains:
- **.envrc**: direnv config with Azure PAT and `CLAUDE_CODE_TASK_LIST_ID` for native task tracking
- **DESIGN.md**: Task overview with format `# TASK-ID: Headline` on first line
- **Obsidian/**: Symlink to Obsidian vault
- **Git worktrees**: Per repository specified
- **Tmux session**: Named `"<task-id>: <headline>"`
- **FEEDBACK.md** (optional): Session friction log — agents append entries when encountering complex commands, missing tool flags, or repeated patterns. See `templates/FEEDBACK.md.tmpl`.

**Metadata Format**:
- Task ID: Short identifier (e.g., `DO-242`, `skills-workflow`)
- Epic: Category slug (e.g., `ad-hoc`, `tooling`, `platform`)
- Slug: 2-3 word concise identifier from headline

## Operations

### 1. Task Creation

Creates task documentation in `docs/tasks/` with interactive Q&A.

**When**: User requests task documentation, mentions GitHub issue, or needs planning.

**Implementation**: Load `operations/create-task.md` for detailed steps.

**Quick summary**: Mode-based questioning (quick/progressive/full), GitHub issue integration, outputs task file.

### 2. Workspace Setup

Creates complete development environment for a task.

**When**: User needs to start active work on a task.

**Implementation**: Load `operations/workspace-setup.md` for detailed steps.

**Quick summary**: Creates directory, DESIGN.md, .envrc (with task list ID), git worktrees, Obsidian link, tmux session.

### 3. Workspace From Issue

Creates a workspace by inferring parameters and delegating to `create-workspace.sh`. Supports two modes: Issue Mode (GitHub issue reference provided) and PWD Mode (no reference, infers from current directory).

**When**: User wants to create a workspace — either from a GitHub issue reference or by inferring context from the current working directory (goal-tree projects, workspace paths).

**Implementation**: Load `operations/workspace-from-issue.md` for detailed steps.

**Quick summary**: Issue Mode: parses issue reference, fetches metadata via `gh`, infers epic from project board sprint. PWD Mode: detects GOAL.md or workspace path pattern, extracts epic, prompts for task-id/headline. Both modes delegate to `create-workspace.sh`.

### 4. Workspace Initialization

Populates workspace with issue/ticket content, enriches CLAUDE.md and DESIGN.md, and creates implementation task list.

**When**: After `/create-workspace`, before starting implementation. Workspace exists but docs have placeholder content.

**Implementation**: Load `operations/init-workspace.md` for detailed steps.

**Quick summary**: Auto-detects issue source (GitHub/Jira) from workspace files, fetches issue content, enriches CLAUDE.md and DESIGN.md with requirements, interviews user only when gaps exist, creates task list from DESIGN.md. Idempotent — safe to re-run.

### 5. Workspace Opening

Discovers and opens existing workspace.

**When**: User returns to previous work or switches workspaces.

**Implementation**: Load `operations/open-workspace.md` for detailed steps.

**Quick summary**: Locate workspace, extract metadata, restore tmux session. Use `--verify` to check linked GitHub issue status.

### 6. Workspace Listing

Shows all workspaces filtered by status with progress.

**When**: User needs overview of active/completed work.

**Implementation**: Load `operations/list-workspaces.md` for detailed steps.

**Quick summary**: Scan workspaces, parse TODO progress, format by status.

### 7. Task Navigation

Finds the next pending task and transitions to it, with a commit checkpoint to prevent losing uncommitted work.

**When**: User needs to know what to work on next, or is transitioning between tasks.

**Implementation**: Load `operations/next-task.md` for detailed steps.

**Quick summary**: Checks for uncommitted changes in workspace repos before transitioning. If dirty, prompts user to commit or skip. Then displays next pending task and marks it in_progress.

### 8. Dependency Graph

Renders task dependency relationships as an ASCII diagram or mermaid flowchart.

**When**: User wants to visualize task ordering, blocking relationships, or dependency chains.

**Implementation**: Load `operations/dependency-graph.md` for detailed steps.

**Quick summary**: Runs `render_deps.py` against current workspace's task list. Outputs layered ASCII graph with status icons, or mermaid flowchart with `--mermaid`.

### 9. Validate Implementation

Runs tests and lint checks after task implementation, retrying on failure before proceeding to commit.

**When**: After completing task implementation, before `/commit-changes`. Ensures code quality gates are met.

**Implementation**: Load `operations/validate-implementation.md` for detailed steps.

**Quick summary**: Auto-detects test runner and linter from project config files, executes both. Classifies failures as transient (flakes, timeouts) or permanent (code bugs) via `references/error-classification.md`. Transient errors retry with exponential backoff (`AUTO_ADVANCE_TRANSIENT_RETRIES`, default 3). Permanent errors retry with fix attempts (`AUTO_ADVANCE_MAX_RETRIES`, default 2). Pauses for human input if still failing.

### 10. Workspace Closing

Cleanly tears down a workspace: removes worktrees, kills tmux, archives artifacts.

**When**: Task complete, cleaning up workspaces while preserving history.

**Implementation**: Load `operations/close-workspace.md` for detailed steps.

**Quick summary**: Remove git worktrees, kill tmux session, remove symlinks, create tarball archive at `~/src/work/.archive/<epic>/<task>.tar.gz`.

### 11. Start Task

Chains pull-task → workspace-from-issue into a single control-session command.

**When**: User wants to pick an issue from the project board and immediately set up a workspace.

**Implementation**: Load `operations/start-task.md` for detailed steps.

**Quick summary**: Invokes pull-task for issue selection, checks for existing workspace, infers parameters, creates workspace via `create-workspace.sh`, displays attach instructions. User runs `/init-workspace` in the work session.

**Depends on**: `pull-task` skill (issue selection phase). Loads `${CLAUDE_PLUGIN_ROOT}/skills/pull-task/operations/pull-task.md` at runtime.

### 12. Finish Workflow

Guided post-completion workflow: commit, PR, knowledge capture, metrics, close instructions.

**When**: All tasks in a workspace are complete and the user is ready to wrap up.

**Implementation**: Load `operations/finish.md` for detailed steps.

**Quick summary**: Checks task completion, auto-commits, creates PR, prompts for /claude-skills:compound and /claude-skills:lessons-learned, captures metrics, prints close instructions. Each phase fails gracefully with manual fallback.

### 13. Auto-Advance

Autonomously cycles through the task list: pick next task → implement → validate → commit → repeat.

**When**: Default behavior after `/init-workspace` creates the task list, or when resuming a session with pending tasks.

**Implementation**: Load `operations/auto-advance.md` for detailed steps.

**Quick summary**: Entry guard checks task list state (zero tasks, all blocked, in-progress resume). Loop body: TaskList → pick next unblocked → implement → validate-implementation → git commit → TaskUpdate(completed) → loop. Transient errors (rate limits, timeouts, 5xx) at any step are retried with exponential backoff via `references/error-classification.md` and `references/retry-with-backoff.md`. On all-tasks-complete: commits remaining changes, creates PR via `/gh-pr-create` (with `Closes #N` issue linking), waits for CI checks, and reports status. Pauses on: CI failure, validation failure after retries, transient retries exhausted, ambiguous decision, or commit failure. Pause messages include retry history when applicable. No PR created when blocked tasks remain.

### 14. Resume

Re-enters the auto-advance loop after human intervention.

**When**: Auto-advance paused due to validation failure, ambiguous decision, or commit failure. Human has fixed the issue and wants to continue.

**Implementation**: Load `operations/resume.md` for detailed steps.

**Quick summary**: Assesses task state, displays pause context (completed tasks, current task, remaining work), confirms readiness if a task is in-progress, then delegates to auto-advance entry guard.

### 15. Resume Status

Displays auto-advance loop state without resuming. Read-only.

**When**: Human wants to check progress or understand why the loop paused before deciding to `/resume`.

**Implementation**: Load `operations/resume-status.md` for detailed steps.

**Quick summary**: Categorizes tasks by status, infers loop state (complete, paused, ready, blocked, empty), displays progress summary with guidance for next action.

## Common Patterns

**Slug Creation**: Extract 2-3 keywords from headline
- "DWH-DBT Scrape Tags failing" → `scrape-tags-failing`
- "Amazon EC2 Instance Retirement" → `ec2-retirement`

**Metadata Extraction**: Always parse DESIGN.md first line for authoritative task-id and headline

**Repository Mapping**: Resolve repo names to paths using `~/.claude/workflows/config/structure.yaml`

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

These signals indicate the user wants the issue recorded for later, not addressed now.

**Status Symbols**: Use status indicators for clarity:
- ✅ Implemented and verified
- ⏸️ Paused or partially complete
- 🔮 Planned but not started
- ❌ Blocked or abandoned

**Tmux Session Creation**:
> **CRITICAL**: NEVER create tmux sessions manually with `tmux new-session`. ALWAYS use the script below.

```bash
${CLAUDE_PLUGIN_ROOT}/skills/task-workflow/scripts/create-tmuxp-session.sh "<session-name>" <workspace-dir>
```

The script:
- Creates 3 windows: nvim (1), zsh (2), claude (9)
- Starts nvim and claude processes automatically
- Sanitizes session names (colons → hyphens)
- Uses tmuxp for reliable session creation

**Wrong**: `tmux new-session -d -s "DO-361"` (creates only 1 window, no processes)
**Right**: `${CLAUDE_PLUGIN_ROOT}/skills/task-workflow/scripts/create-tmuxp-session.sh "DO-361: headline" ~/src/work/epic/task`

**Repository-Specific Setup**: Some repositories require additional configuration:
- **Dev-Stacks**: Symlink `~/src/{dev.env,testing.tfvars}` into worktree root (required for `task` commands)

See `references/configuration.md` for structure.yaml details.

**Symlink Resolution**: When editing files referenced by `~/.claude/` paths, always resolve via `realpath` first and edit the worktree copy if one exists. This prevents editing the shared symlink target instead of the worktree-specific version.

```bash
# Before editing, resolve the actual path
REAL_PATH=$(realpath ${CLAUDE_PLUGIN_ROOT}/skills/my-skill/SKILL.md)
# If a worktree copy exists, edit there instead
```

See `skills/git/operations/commit.md` for the full symlink resolution pattern.

**Submodule Management**: Repositories with submodules (historically, dotfiles included a cursor-rules submodule) require sync before work:
```bash
git -C <submodule> checkout main && git -C <submodule> pull origin main
```
Risk: Detached HEAD state hides main branch content, causing duplicate work. See `references/workspace-structure.md` for details.

## Permissions

The skill requires these bash commands for workspace management:

| Permission | Commands | Purpose |
|------------|----------|---------|
| create tmux sessions | `${CLAUDE_PLUGIN_ROOT}/skills/task-workflow/scripts/create-tmuxp-session.sh` | Create 3-window session via tmuxp |
| list tmux sessions | `tmux list-sessions` | Discover existing sessions |
| check tmux session existence | `tmux has-session -t "<session-name>"` | Verify session before creating |
| kill tmux sessions | `tmux kill-session -t "<session-name>"` | Clean up session on workspace close |
| remove git worktrees | `git worktree remove <path>` | Clean up worktrees on workspace close |
| create archive tarballs | `tar -czf <archive> <dir>` | Archive workspace artifacts |
| extract archive tarballs | `tar -xzf <archive> -C <dir>` | Restore workspace from archive |
| render task dependency graph | `${CLAUDE_PLUGIN_ROOT}/skills/task-workflow/scripts/render_deps.py` | Visualize task blocking relationships |
| fetch GitHub issues | `gh issue view <ref>` | Fetch issue content for workspace initialization |
| fetch Jira tickets | `acli jira --action getIssue` | Fetch Jira ticket content for workspace initialization |
| run project tests | `pytest`, `go test`, `mix test`, `npm test`, `make test`, `cargo test` | Execute project test suite during validation |
| run lint and format checks | `pre-commit run`, `ruff check`, `npx eslint`, `mix format`, `gofmt`, `make lint` | Execute lint/format checks during validation |
| list GitHub projects | `gh project list --owner <owner>` | Discover project boards for pull-task |
| list GitHub project fields | `gh project field-list <number> --owner <owner>` | Fetch field definitions for filtering |
| list GitHub project items | `gh project item-list <number> --owner <owner>` | Fetch board items for ranking |
| check existing workspaces | `ls ~/src/work/*/<id>-*/CLAUDE.md` | Detect existing workspace before creation |
| create workspace from script | `${CLAUDE_PLUGIN_ROOT}/skills/task-workflow/scripts/create-workspace.sh` | Bootstrap workspace directory, worktrees, tmux |
| check git status | `git -C <repo> status --porcelain` | Detect uncommitted changes during /finish |
| view GitHub PRs | `gh pr view --json url,state` | Check for existing PR during /finish and auto-advance |
| check GitHub PR CI status | `gh pr checks --watch --fail-fast` | Poll CI checks after auto-advance PR creation |
| create GitHub PRs | `gh pr create` | Create PR via /gh-pr-create during auto-advance completion |
| write metrics log | `mkdir -p`, `jq`, `>> finish.jsonl` | Capture workspace metrics during /finish |
| sleep for backoff between retries | `sleep <seconds>` | Exponential backoff delay during transient error retry |

## Quick Reference

**Create workspace**: Provide task-id, epic, headline, optional repos and GitHub issue
**Setup workspace**: Provide GitHub issue reference; infers parameters, delegates to create-workspace
**Init workspace**: Auto-detects issue source, enriches docs, creates task list; idempotent
**Resume work**: Provide task-id, optional epic for disambiguation; auto-restores from archive if needed; use `--verify` to check GitHub issue status
**Finish workspace**: Guided post-completion: commit, PR, knowledge capture, metrics, close instructions
**Close workspace**: Removes worktrees, kills tmux, archives to tarball; use `--no-archive` to skip archival
**List workspaces**: Optionally filter by status (in-progress/completed/all)
**Navigate tasks**: Use `TaskList` to find pending tasks
**Auto-advance**: Session-level default — loops through tasks autonomously after init; on completion creates PR with issue linking and waits for CI; stops on CI failure, validation failure, or ambiguity
**Resume**: Re-enter auto-advance after fixing the issue that caused a pause
**Resume status**: Check auto-advance progress and pause reason without resuming
**Dependency graph**: Visualize task ordering with ASCII or mermaid output

## Commands

Commands that invoke this skill live in `~/.claude/commands/` (symlinked from `dotfiles/claude/commands/`; previously also from `cursor-rules/commands/`).

| Command | Operation |
|---------|-----------|
| `/create-workspace` | workspace-setup |
| `/setup-workspace` | workspace-from-issue |
| `/init-workspace` | init-workspace |
| `/open-workspace` | open-workspace |
| `/close-workspace` | close-workspace |
| `/finish` | finish |
| `/list-workspaces` | list-workspaces |
| `/next-task` | next-task |
| `/start-task` | start-task |
| `/resume` | resume |
| `/resume-status` | resume-status |

Commands are thin wrappers that invoke this skill with context. The skill's operations contain the implementation details.

## Progressive Disclosure

Load only what you need:

**Operations** (load on-demand):
- `operations/create-task.md` - Task creation implementation
- `operations/workspace-setup.md` - Workspace setup implementation
- `operations/workspace-from-issue.md` - Workspace creation with parameter inference (Issue Mode or PWD Mode)
- `operations/init-workspace.md` - Workspace initialization (issue fetch, doc enrichment, task creation)
- `operations/open-workspace.md` - Workspace opening implementation (includes archive re-hydration)
- `operations/list-workspaces.md` - Workspace listing implementation
- `operations/close-workspace.md` - Workspace closing and archival
- `operations/finish.md` - Post-completion workflow (commit, PR, knowledge capture, metrics)
- `operations/dependency-graph.md` - Task dependency visualization
- `operations/validate-implementation.md` - Post-implementation test and lint validation
- `operations/next-task.md` - Task navigation with commit checkpoint
- `operations/start-task.md` - Chain pull-task → workspace-from-issue into single command
- `operations/auto-advance.md` - Autonomous task loop (pick → implement → validate → commit → repeat)
- `operations/resume.md` - Re-enter auto-advance after human intervention
- `operations/resume-status.md` - Read-only auto-advance state inspection
- `operations/session-review.md` - Post-session FEEDBACK.md triage into skill updates, scripts, and tool gaps

**Reference Documentation**:
- `reference.md` - Complete technical reference (all operations)
- `examples.md` - Concrete usage scenarios
- `references/workspace-structure.md` - Workspace layout, .envrc, submodule management
- `references/solution-search.md` - QMD hybrid-search protocol over the Obsidian vault (replaces grep over `docs/solutions/`)
- `references/error-classification.md` - Transient vs permanent error taxonomy for retry decisions
- `references/retry-with-backoff.md` - Exponential backoff algorithm with jitter and escalation format

**Supporting Files**:
- `scripts/` - Shell utilities for workspace operations
- `templates/` - File generation templates

## Scripts

All scripts are in `${CLAUDE_PLUGIN_ROOT}/skills/task-workflow/scripts/`:

- `create-tmuxp-session.sh "<session-name>" <workspace-dir>` - **Required** for tmux session creation
- `list-tasks.sh` - Task discovery and status
- `workspace-locator.sh` - Find workspace by task-id
- `metadata-parser.sh` - Extract DESIGN.md metadata
- `render_deps.py --task-list-id ID [--mermaid]` - Task dependency graph visualization
- `scan-feedback.sh <work_dir> [--verbose]` - Scan workspaces for FEEDBACK.md entries

## Templates

- `templates/DESIGN.md.tmpl` - Task documentation
- `templates/.envrc.tmpl` - Azure PAT and task list ID configuration
- `templates/solution.md.tmpl` - Solution documentation with YAML frontmatter
- `templates/FEEDBACK.md.tmpl` - Session friction log for command simplification feedback loop
