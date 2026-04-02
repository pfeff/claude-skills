# Task Workflow Examples

Concrete usage scenarios for task workspace management.

## Quick Reference

| Operation | Command | Use Case |
|-----------|---------|----------|
| Create task docs | `/create-task` | Document new work before starting |
| Setup workspace | `/create-workspace` | Initialize environment for active development |
| Resume workspace | `/open-workspace` | Return to existing work |
| List tasks | `/list-workspaces` | View progress across all tasks |
| Find next task | `TaskList` | View pending tasks in current workspace |

---

## Scenario 1: GitHub Issue → Workspace

**Context**: Team member assigned a GitHub issue, needs to start work immediately.

### Steps

```bash
# 1. Create task documentation from issue
/create-task --issue org/repo#123

# User answers prompts:
# - Epic: platform
# - Mode: progressive

# 2. Setup complete workspace
/create-workspace --task-id DO-123 --epic platform --repos api,frontend

# Result: Ready-to-code environment with:
# - ~/src/work/platform/DO-123-fix-auth/
# - Git worktrees for api and frontend repos
# - Tmux session "DO-123: Fix authentication timeout"
# - DESIGN.md populated from issue body
# - PLAN.md with TODO checklist
```

### Timeline
- Task creation: 2 minutes
- Workspace setup: 30 seconds
- **Total time to code**: < 3 minutes

---

## Scenario 2: Ad-Hoc Investigation

**Context**: Quick debugging task, no GitHub issue, single repository.

### Steps

```bash
# 1. Quick task creation
/create-task

# User answers (quick mode - 5 questions):
# - Task ID: cache-debug
# - Headline: Debug Redis cache misses
# - Epic: ad-hoc
# - Description: Cache hit rate dropped to 60%, investigate
# - Priority: high

# 2. Setup workspace
/create-workspace --task-id cache-debug --epic ad-hoc --repos api

# 3. Do investigation work...

# 4. Resume next day
/open-workspace cache-debug ad-hoc
```

### Notes
- No GitHub integration needed
- Single repository (api)
- Fast setup for time-sensitive work

---

## Scenario 3: Multi-Repo Feature

**Context**: Complex feature spanning 3 repositories with detailed planning.

### Steps

```bash
# 1. Comprehensive task creation
/create-task

# User answers (full mode - 15-20 questions):
# - Task ID: user-auth-v2
# - Headline: Implement OAuth 2.0 authentication
# - Epic: platform
# - Mode: full
# - Related tasks: session-mgmt, api-keys
# - Estimated effort: 5 days
# - Milestones: Design, Backend, Frontend, Testing
# - Repositories: api, frontend, docs

# 2. Setup workspace with all repos
/create-workspace --task-id user-auth-v2 --epic platform \
  --repos api,frontend,docs

# Result:
# ~/src/work/platform/user-auth-v2-oauth/
# ├── DESIGN.md          # Detailed architecture
# ├── PLAN.md            # Broken down by milestone
# ├── api/               # Backend worktree
# ├── frontend/          # UI worktree
# └── docs/              # Docs worktree
```

### Workflow
1. Work in `api/` worktree for backend
2. Switch to `frontend/` for UI changes
3. Update `docs/` with API documentation
4. All within single tmux session

---

## Scenario 4: Resuming After Break

**Context**: Developer worked on 5 tasks last week, returning Monday.

### Steps

```bash
# 1. See what's in progress
/list-workspaces in-progress

# Output:
# user-auth-v2 • platform
#   Implement OAuth 2.0 authentication
#   Progress: 12/25 tasks
#   ~/src/work/platform/user-auth-v2-oauth
#
# cache-debug • ad-hoc
#   Debug Redis cache misses
#   Progress: 3/5 tasks
#   ~/src/work/ad-hoc/cache-debug
#
# docs-update • tooling
#   Update workflow documentation
#   Progress: 2/8 tasks
#   ~/src/work/tooling/docs-update

# 2. Resume highest priority task
/open-workspace user-auth-v2 platform

# 3. Check what's next using native task tools
TaskList
# Shows pending tasks in current workspace
```

### Benefits
- Quick visibility into active work
- One command to restore full environment
- No manual directory navigation

---

## Scenario 5: Daily Planning

**Context**: Start of day, need to organize work.

### Steps

```bash
# 1. Review all tasks
/list-workspaces all

# 2. Check completed work
/list-workspaces completed

# Output:
# DO-119 • platform
#   Fix database connection pool
#   Progress: 8/8 tasks (completed)
#   ~/src/work/platform/DO-119-db-pool

# 3. Resume main task
/open-workspace skills-workflow tooling

# 4. Find next action using native task tools
TaskList
# Shows pending tasks in current workspace
```

### Planning Workflow
- Morning: Review progress with `/list-workspaces`
- Choose task: Resume with `/open-workspace`
- Stay focused: Use `TaskList` for pending tasks

---

## Scenario 6: Bug Fix Preset

**Context**: Production bug needs quick fix.

### Steps

```bash
# 1. Create bug task
/create-task

# User answers:
# - Task ID: DO-456
# - Headline: Fix memory leak in worker process
# - Epic: platform
# - Mode: bug
#
# Bug-specific prompts:
# - Priority: critical
# - Severity: high
# - Reproduction: 100% after 24h uptime
# - Impact: Worker crashes, queue backup
# - Root cause: Unclosed connections

# 2. Quick workspace setup
/create-workspace --task-id DO-456 --epic platform --repos worker

# 3. Work on fix...

# 4. Verify completion using native task tools
TaskList
# Shows all tasks completed
# Suggested next steps:
# - Run tests
# - Create pull request
# - Close issue
```

### Bug Workflow Benefits
- Preset captures all debugging context
- Quick iteration from discovery to fix
- Documentation for future reference

---

## Scenario 7: Refactoring Project

**Context**: Large codebase refactor with subtasks.

### PLAN.md Structure

```markdown
## Phase 1: Analysis
- [x] Map current architecture
- [x] Identify dependencies
- [ ] Document breaking changes

## Phase 2: Implementation
- [ ] Refactor core module
  - [ ] Update interfaces
  - [ ] Migrate tests
  - [ ] Update consumers
- [ ] Refactor API layer
- [ ] Update documentation
```

### Navigation Workflow

```bash
# Start workspace
/open-workspace refactor-core tooling

# Check pending tasks
TaskList
# Shows pending tasks in current workspace

# ... complete task ...
TaskUpdate(taskId: "1", status: "completed")

# Check remaining tasks
TaskList
# Shows updated task list
```

### Benefits
- Native task tracking with TaskList/TaskUpdate
- Persistent progress across sessions
- Clear progress visibility

---

## Scenario 8: Workspace Without Git

**Context**: Documentation-only task, no code changes needed.

### Steps

```bash
# 1. Create task
/create-task

# Task: docs-review
# Epic: tooling
# Description: Review and update API documentation

# 2. Setup workspace without repos
/create-workspace --task-id docs-review --epic tooling

# No --repos flag = no worktrees created

# Result:
# ~/src/work/tooling/docs-review/
# ├── DESIGN.md
# ├── PLAN.md
# └── Obsidian -> (vault symlink)

# 3. Access docs through Obsidian symlink
cd ~/src/work/tooling/docs-review
ls Obsidian/Documentation/API/
```

### Use Cases
- Documentation reviews
- Planning tasks
- Research and analysis

---

## Scenario 9: Issue Sync

**Context**: Update GitHub issue with local design decisions.

### Steps

```bash
# 1. Working in task workspace
cd ~/src/work/platform/user-auth-v2-oauth

# 2. Made design decisions, updated DESIGN.md
nvim DESIGN.md
# ... add architecture section ...

# 3. Sync to GitHub
gh issue edit org/repo#123 --body "$(cat DESIGN.md)"

# 4. Team can now see design in issue
# Issue body updated with full DESIGN.md content
```

### Sync Strategy
- Local DESIGN.md is source of truth
- Sync to GitHub for team visibility
- Optional, doesn't block local work

---

## Scenario 10: Disambiguation

**Context**: Multiple workspaces with similar task IDs.

### Steps

```bash
# 1. Resume without epic
/open-workspace auth-fix

# Output:
# Multiple workspaces found for task-id 'auth-fix':
#
# 1. ad-hoc/auth-fix-timeout
#    auth-fix: Fix authentication timeout
#    ~/src/work/ad-hoc/auth-fix-timeout
#
# 2. platform/DO-242-auth-fix
#    DO-242: Fix auth service connection
#    ~/src/work/platform/DO-242-auth-fix
#
# Please specify epic to disambiguate:
# /open-workspace auth-fix <epic>

# 2. Resume with epic
/open-workspace auth-fix ad-hoc

# Success: Resumed ad-hoc/auth-fix-timeout
```

### Disambiguation Rules
- Always show all matches
- Display: epic, task-id, headline, path
- Prompt for epic to narrow down

---

## Scenario 11: Parallel Tasks

**Context**: Context switching between multiple active tasks.

### Morning Workflow

```bash
# Check what's in progress
/list-workspaces in-progress

# 3 tasks shown:
# - api-migration (platform)
# - perf-tuning (platform)
# - docs-update (tooling)

# Work on API migration
/open-workspace api-migration platform

# ... work for 2 hours ...

# Switch to urgent performance issue
/open-workspace perf-tuning platform

# ... quick fix ...

# Back to API migration
/open-workspace api-migration platform
```

### Benefits
- Fast context switching
- Each task has isolated environment
- Tmux session preserves state

---

## Scenario 12: Subtask Creation

**Context**: Large task needs breakdown into subtasks.

### Workflow

```bash
# Working on large feature
cd ~/src/work/platform/user-auth-v2-oauth

# Check current tasks
TaskList
# Shows: Implement OAuth providers

# Too big, break into subtasks
TaskCreate(subject: "Google provider", description: "Implement Google OAuth")
TaskCreate(subject: "GitHub provider", description: "Implement GitHub OAuth")
TaskCreate(subject: "Microsoft provider", description: "Implement Microsoft OAuth")

# Set dependencies
TaskUpdate(taskId: "2", addBlockedBy: ["1"])
TaskUpdate(taskId: "3", addBlockedBy: ["1"])

# Check pending tasks
TaskList
# Shows: Google provider (next available)
```

### Subtask Pattern
- Use TaskCreate for subtasks
- Use TaskUpdate with addBlockedBy for dependencies
- TaskList shows available (unblocked) tasks

---

## Common Patterns

### Pattern 1: Issue → Code → PR

```bash
/create-task --issue org/repo#123
/create-workspace --task-id DO-123 --epic platform --repos api
# ... implement feature ...
git commit -m "feat: implement feature"
git push origin DO-123/mbp/feature-name
/gh-pr-create
# Reads .github/PULL_REQUEST_TEMPLATE.md, populates sections from
# DESIGN.md/CLAUDE.md context, previews, and creates PR
```

### Pattern 2: Daily Standup Prep

```bash
/list-workspaces in-progress
# Review each task's progress
# Communicate TODO counts to team
```

### Pattern 3: Week End Review

```bash
/list-workspaces completed
# Review what was accomplished
# Archive or clean up workspaces
```

### Pattern 4: Context Recovery

```bash
# What was I working on?
/list-workspaces in-progress

# Which task specifically?
/open-workspace <task-id> <epic>

# What was next?
TaskList
```

---

## Error Recovery

### Workspace Already Exists

```bash
/create-workspace --task-id DO-123 --epic platform --repos api

# Error: Workspace already exists at ~/src/work/platform/DO-123-...
# Options:
# 1. Resume existing workspace: /open-workspace DO-123 platform
# 2. Delete and recreate: rm -rf ~/src/work/platform/DO-123-*
```

### Repository Not Found

```bash
/create-workspace --task-id DO-123 --epic platform --repos unknown-repo

# Error: Repository 'unknown-repo' not found
# Searched:
# - ~/src/github/*/unknown-repo
# - ~/src/azdevops/*/unknown-repo
#
# Options:
# 1. Add to mapping table in structure.yaml
# 2. Clone manually and retry
# 3. Skip repo and continue
```

---

## Tips and Tricks

### Tip 1: Lazy Epic Discovery

```bash
# Don't remember epic? Omit it:
/open-workspace skills-workflow

# Works if only one match found
# Prompts for disambiguation if multiple matches
```

### Tip 2: Quick Status Check

```bash
# In any workspace directory
TaskList

# Shows pending tasks in current workspace
```

### Tip 3: Minimal Task Creation

```bash
# Skip interactive prompts
/create-task \
  --task-id quick-fix \
  --headline "Fix typo in README" \
  --epic ad-hoc \
  --description "Correct spelling errors" \
  --priority low
```

### Tip 4: Obsidian Integration

```bash
# From workspace
cd ~/src/work/platform/DO-123-auth
cd Obsidian/Notes

# Create task-specific note
nvim 2025/11/DO-123-auth-investigation.md

# Link from DESIGN.md
echo "See Obsidian note: Notes/2025/11/DO-123-auth-investigation.md" >> DESIGN.md
```

### Tip 5: Task Archival

```bash
# After task completion
/list-workspaces completed

# Archive old tasks
mv ~/src/work/platform/DO-123-auth ~/src/archive/2025-11/

# Clean up worktrees
cd ~/src/github/org/repo
git worktree prune
```

---

## Advanced Usage

### Custom Epic Categories

Add to `~/.claude/workflows/config/structure.yaml`:

```yaml
workspace:
  epics:
    - ad-hoc
    - tooling
    - platform
    - dwh
    - security      # Custom
    - performance   # Custom
```

### Custom Templates

Create `${CLAUDE_PLUGIN_ROOT}/skills/task-workflow/templates/custom-DESIGN.md.tmpl`:

```markdown
# {{TASK_ID}}: {{HEADLINE}}

## Context
{{DESCRIPTION}}

## Security Considerations
- [ ] Input validation
- [ ] Authentication
- [ ] Authorization
- [ ] Data encryption

## Performance Impact
- [ ] Load testing
- [ ] Database query optimization
- [ ] Caching strategy
```

Use with:
```bash
/create-workspace --template custom-DESIGN.md.tmpl
```

### Integration with Other Tools

**Jira Integration**:
```bash
# Fetch Jira issue
jira issue view PROJ-123 > /tmp/jira-issue.txt

# Create task from Jira
/create-task
# Paste Jira details when prompted
```

**Slack Integration**:
```bash
# After completing task
/list-workspaces completed | tail -1 | \
  slack-cli send "#team-updates" \
  "Completed: $(cat -)"
```

---

## Summary

The task workflow skill provides a complete lifecycle for development tasks:

1. **Create**: Document requirements and plan
2. **Setup**: Initialize workspace with repos and tools
3. **Resume**: Return to work with full context
4. **Track**: Monitor progress across all tasks
5. **Navigate**: Stay focused with next-action guidance

All operations work together to maintain a consistent, productive workflow while minimizing context-switching overhead.
