# Task Workflow Reference

Detailed implementation guide for task workspace management operations.

## Table of Contents

1. [Workspace Structure](#workspace-structure)
2. [Task Creation](#task-creation)
3. [Workspace Setup](#workspace-setup)
4. [Workspace Opening](#workspace-opening)
5. [Workspace Listing](#workspace-listing)
6. [Task Navigation](#task-navigation)
7. [GitHub Integration](#github-integration)
8. [Tmux Sessions](#tmux-sessions)
9. [Repository Mapping](#repository-mapping)
10. [Configuration](#configuration)

---

## Workspace Structure

**Standard Layout**: `~/src/work/<epic-slug>/<task-id>-<task-slug>/`

### Directory Contents

```
~/src/work/<epic>/<task-id>-<slug>/
├── DESIGN.md              # Task overview and architecture
├── PLAN.md                # TODO tracking with checkboxes
├── <repo-1>/              # Git worktree for repository 1
├── <repo-2>/              # Git worktree for repository 2
└── .tmuxp.yaml            # Tmux session configuration
```

Obsidian access is provided by the `obsidian-notes` skill — no per-workspace symlink is created.

### Metadata Format

**DESIGN.md First Line**: Must follow format `# TASK-ID: Headline`

Examples:
- `# DO-242: Fix authentication timeout`
- `# skills-workflow: Refactor workflow system using skills`
- `# ec2-retirement: Amazon EC2 Instance Retirement`

**Task ID Formats**:
- Ticket reference: `DO-242`, `DWH-123`, `PROJ-456`
- Slug identifier: `skills-workflow`, `auth-fix`, `api-migration`

**Epic Categories**: Short lowercase slug identifying project area
- `ad-hoc`: One-off tasks and investigations
- `tooling`: Development tools and workflows
- `platform`: Infrastructure and platform work
- `dwh`: Data warehouse tasks
- Custom: Project-specific epics

**Slug Rules**:
- 2-3 keywords from headline
- Lowercase with hyphens
- Descriptive and unique within epic
- Algorithm: Extract nouns/verbs, remove articles/prepositions, join with hyphens

---

## Task Creation

Interactive workflow for creating task documentation in `docs/tasks/` directory.

### Execution Modes

#### Quick Mode (5 questions)
- Task ID
- Headline
- Epic
- Description (brief)
- Priority (low/medium/high)

**Use when**: Simple tasks, clear requirements, time-sensitive

#### Progressive Mode (adaptive, 8-12 questions)
Adds to quick mode:
- Related tasks/dependencies
- Context from existing docs
- Estimated effort
- Acceptance criteria

**Use when**: Standard tasks with moderate complexity

#### Full Mode (comprehensive, 15-20 questions)
Adds to progressive mode:
- Detailed requirements gathering
- Milestone breakdown
- Subtask identification
- Risk assessment
- Testing strategy

**Use when**: Complex tasks requiring detailed planning

#### Preset Modes
- `bug`: Bug fix workflow (priority, reproduction, impact)
- `feature`: Feature development (user stories, acceptance criteria)
- `refactor`: Code improvement (scope, backward compatibility)
- `docs`: Documentation (audience, scope, format)
- `infrastructure`: Infrastructure work (impact, rollback plan)

### GitHub Integration

**Issue Pre-population**:
```bash
# Fetch issue details
gh issue view <ref> --json title,body,labels,milestone
```

**Reference Formats**:
- Issue number: `123` (in current repo)
- Full reference: `org/repo#123`
- URL: `https://github.com/org/repo/issues/123`

**Extracted Fields**:
- `title` → Headline
- `body` → Description
- `labels` → Tags/categories
- `milestone` → Project phase

### Output Location

**Default**: `docs/tasks/task-{slug}-{date}.md`

**Filename Format**:
- Slug: First 3-4 keywords from headline
- Date: `YYYY-MM-DD` format
- Example: `task-refactor-workflow-system-2025-11-09.md`

### Non-Interactive Mode

**Command-line Parameters**:
- `--task-id <id>`: Task identifier
- `--headline <text>`: Task title
- `--epic <slug>`: Epic category
- `--description <text>`: Task description
- `--priority <level>`: Priority (low/medium/high)
- `--issue <ref>`: GitHub issue reference

**Use case**: Automation, scripting, batch task creation

---

## Workspace Setup

Complete environment setup for task workspace.

### Prerequisites

1. **DESIGN.md**: Must exist with task-id and headline
2. **Git repositories**: Must be cloned in standard locations
3. **GitHub CLI**: Optional, for issue integration

### Setup Process

#### 1. Directory Creation

```bash
mkdir -p ~/src/work/<epic>/<task-id>-<slug>
cd ~/src/work/<epic>/<task-id>-<slug>
```

#### 2. Documentation Setup

**DESIGN.md Generation**:
- From template if no GitHub issue
- From issue body if `--issue` provided
- Must include: Task ID, headline, requirements, architecture

**PLAN.md Generation**:
- Default: Create from template with TODO checklist
- GitHub mode: Skip file, use issue for tracking
- Format: Markdown with checkbox items
- Purpose: Capture work items to address later, preventing "side quests" during focused task execution

**Template Locations**:
- `templates/DESIGN.md.tmpl`: Task documentation template
- `templates/PLAN.md.tmpl`: TODO tracking template

#### 3. Git Worktree Management

**Branch Naming**: `<task-id>/mbp/<task-slug>`

Examples:
- `DO-242/mbp/auth-timeout`
- `skills-workflow/mbp/refactor-system`

**Worktree Creation**:
```bash
# For each repo in --repos list
cd ~/src/github/<org>/<repo>
git worktree add ~/src/work/<epic>/<task-id>-<slug>/<repo> -b <branch>
```

**Multi-Repository Support**:
- Comma-separated list: `--repos repo1,repo2,repo3`
- Path resolution via mapping table
- Automatic clone if repo not found locally

**Repository-Specific Setup**:
After worktree creation, apply repo-specific configuration:

| Repository | Setup Required |
|------------|----------------|
| Dev-Stacks | `ln -sf ~/src/{dev.env,testing.tfvars} <worktree>/` |

These symlinks are required for `task` commands to work properly in Dev-Stacks.

#### 4. Tmux Session Creation

**IMPORTANT**: Always use the tmuxp script - never create tmux sessions manually.

**Invocation**:
```bash
${CLAUDE_PLUGIN_ROOT}/skills/task-workflow/scripts/create-tmuxp-session.sh \
  "<task-id>: <headline>" \
  ~/src/work/<epic>/<task-id>-<slug>
```

**Session Configuration**:
- 3 windows: nvim, zsh, claude (window 9)
- Working directory: Workspace root
- Creates `.tmuxp.yaml` config in workspace
- Session name sanitized (colons → hyphens)

### Parameters

**Required**:
- `--task-id`: Task identifier
- `--epic`: Epic slug
- `--headline`: Task title

**Optional**:
- `--repos`: Comma-separated repository list
- `--issue`: GitHub issue reference for sync

### Error Handling

**Repository not found**:
1. Check mapping table
2. Search known locations (`~/src/github`, `~/src/azdevops`)
3. Prompt user for path
4. Offer to clone if not local

**Workspace exists**: Prompt to resume or recreate

**Missing prerequisites**: Validate and guide user to fix

---

## Workspace Opening

Discover and open existing workspace.

### Discovery Algorithm

**With Epic**:
```bash
find ~/src/work/<epic> -maxdepth 1 -type d -name "<task-id>-*"
```

**Without Epic**:
```bash
find ~/src/work -maxdepth 2 -type d -name "<task-id>-*"
```

**Utility Script**: `scripts/workspace-locator.sh <task-id> [epic]`

### Metadata Extraction

**Parser Script**: `scripts/metadata-parser.sh <workspace>/DESIGN.md`

**Algorithm**:
1. Read first line of DESIGN.md
2. Match pattern: `# ([^:]+): (.+)`
3. Extract: Group 1 = task-id, Group 2 = headline
4. Fallback: Use task-id from directory name if parse fails

**Output Format**: `<task-id>|<headline>`

### Session Restoration

**Process**:
1. Kill existing tmux session with same name (if running)
2. Invoke `create-tmuxp-session.sh` with extracted metadata
3. Attach to new session

**Session Name**: `"<task-id>: <headline>"`
- Sanitize special characters (quotes, backticks)
- Truncate if exceeds tmux limits

### Disambiguation

**Multiple Matches**:
1. List all found workspaces
2. Show: Epic, task-id, headline, path
3. Prompt user to specify epic
4. Re-run with epic filter

**No Matches**:
- Show search paths
- Suggest running `/list-workspaces all`
- Offer to create workspace

### Validation

**Required**:
- DESIGN.md must exist
- First line must parse correctly
- Workspace directory readable

**Optional**:
- PLAN.md (may use GitHub issues)
- Git worktrees (may be deleted)
- Tmux session (will recreate)

---

## Workspace Listing

Status-based discovery of workspaces.

### Script Invocation

```bash
${CLAUDE_PLUGIN_ROOT}/skills/task-workflow/scripts/list-tasks.sh
```

**No parameters needed**: Script outputs all tasks with status information.

**Status Values**:
- `in-progress`: Tasks with unchecked TODOs
- `completed`: All TODOs checked
- `no-plan`: No PLAN.md file
- `no-todos`: PLAN.md exists but no TODO items

### Output Format

**Pipe-delimited**: `status|epic|task_id|headline|checked|total|workspace`

Example:
```
in-progress|tooling|skills-workflow|Refactor workflow system|8|15|~/src/work/tooling/skills-workflow
completed|ad-hoc|auth-fix|Fix authentication timeout|5|5|~/src/work/ad-hoc/DO-242-auth-timeout
```

### Status Classification

**Algorithm**:
1. Check if PLAN.md exists
2. Count top-level TODO items (pattern: `^- \[ \]` and `^- \[x\]`)
3. Classify based on counts

**States**:
- `in-progress`: Has unchecked items (`^- \[ \]`)
- `completed`: All items checked, total > 0
- `no-plan`: PLAN.md missing
- `no-todos`: PLAN.md exists but no TODO items

**Important**: Only top-level items count (no indentation before `-`)

### Display Formatting

**Format**:
```
TASK-ID • epic
  Headline
  Progress: X/Y tasks
  ~/path/to/workspace
```

**Example**:
```
skills-workflow • tooling
  Refactor workflow system using skills
  Progress: 8/15 tasks
  ~/src/work/tooling/skills-workflow

DO-242 • ad-hoc
  Fix authentication timeout
  Progress: 5/5 tasks (completed)
  ~/src/work/ad-hoc/DO-242-auth-timeout
```

### Workspace Discovery

**Search Path**: `~/src/work/*/*/`

**Validation**:
1. Must have DESIGN.md
2. First line must parse as `# TASK-ID: Headline`
3. Directory name must match pattern `<task-id>-<slug>`

### Performance

**Optimization**:
- Shell script handles file I/O
- Parallel processing for multiple workspaces
- Cache-friendly (read once per workspace)

**Typical Time**: < 100ms for 50 workspaces

---

## GitHub Integration

### Issue Fetching

**Command**: `gh issue view <ref> --json <fields>`

**Supported References**:
- Issue number in current repo: `123`
- Full reference: `org/repo#123`
- URL: `https://github.com/org/repo/issues/123`

**Fields**:
- `title`: Issue title
- `body`: Issue description
- `labels`: Array of label names
- `milestone`: Milestone object (title, dueOn)
- `state`: open/closed
- `assignees`: Array of assignee logins

### Issue Updates

**Update DESIGN.md to Issue**:
```bash
gh issue edit <ref> --body "$(cat DESIGN.md)"
```

**Use Cases**:
- Sync local documentation to GitHub
- Update issue description with architecture details
- Share design decisions with team

### Sub-Issue Creation

**Pattern**: Create checklist in main issue, optionally convert to sub-issues

**Command**:
```bash
gh issue create \
  --title "<subtask title>" \
  --body "Part of #<parent-issue>" \
  --label "subtask"
```

**Use Cases**:
- Break down large tasks
- Assign sub-tasks to team members
- Track parallel work streams

### Graceful Fallback

**GitHub Unavailable**:
1. Network error → Continue with local files
2. Auth error → Prompt for `gh auth login`
3. Rate limit → Cache and retry later

**Local-First**:
- DESIGN.md is source of truth
- PLAN.md for TODO tracking
- Sync to GitHub is enhancement, not requirement

---

## Tmux Sessions

### Session Creation Script

**Location**: `scripts/create-tmuxp-session.sh`

**Parameters**:
1. Session name (required): `"<task-id>: <headline>"`
2. Working directory (required): Workspace root path

**Usage**:
```bash
${CLAUDE_PLUGIN_ROOT}/skills/task-workflow/scripts/create-tmuxp-session.sh \
  "skills-workflow: Refactor workflow system" \
  ~/src/work/tooling/skills-workflow
```

### Session Configuration

**Windows** (3 total):
1. **nvim**: Text editor for code/docs
2. **zsh**: Shell for git, builds, testing
3. **claude**: AI assistant for development

**Layout**:
- All windows in workspace directory
- Auto-attach on creation
- Session name visible in tmux status bar

### Session Naming

**Format**: `"<task-id>: <headline>"`

**Sanitization**:
- Remove backticks, quotes
- Escape special characters
- Truncate if > 100 chars

**Examples**:
- `DO-242: Fix authentication timeout`
- `skills-workflow: Refactor workflow system`

### Session Management

**Resume Existing**:
1. Kill session if running: `tmux kill-session -t "<name>"`
2. Create new session with same name
3. Attach automatically

**Rationale**: Fresh environment, no stale state

---

## Repository Mapping

### Mapping Table

**Source**: Embedded in `/create-workspace` command (will move to `structure.yaml`)

**Format**:
```yaml
repositories:
  - name: cursor-rules
    path: ~/src/github/pfeff/cursor-rules
  - name: dotfiles
    path: ~/src/github/pfeff/dotfiles
  - name: knowledge-api
    path: ~/src/work/knowledge-api
```

### Resolution Algorithm

**Input**: Repository name (e.g., `cursor-rules`, `Project/Repo`)

**Steps**:
1. **Direct match**: Check if name exists in mapping table
2. **Pattern match**: Handle "Project/Repo" format, extract repo name
3. **Filesystem search**: Look in `~/src/github/*` and `~/src/azdevops/*`
4. **User prompt**: Show options, request confirmation or custom path

**Output**: Absolute path to repository

### Known Locations

**GitHub**: `~/src/github/<org>/<repo>`
- Personal: `~/src/github/pfeff/*`
- Organizations: `~/src/github/<org>/*`

**Azure DevOps**: `~/src/azdevops/<org>/<project>/<repo>`
- Work repos: `~/src/azdevops/tcetra/*`

**Worktrees**: `~/src/work/<epic>/<task-id>-<slug>/<repo>`

### Path Validation

**Checks**:
1. Directory exists
2. Is a git repository (`.git/` or worktree)
3. Has remote configured
4. Is readable/writable

**Fallback**:
- Offer to clone if remote URL known
- Suggest manual clone with instructions
- Skip repository if critical error

---

## Configuration

### structure.yaml

**Location**: `~/.claude/workflows/config/structure.yaml`

**Purpose**: Central configuration for workspace structure, coordinators, and repository mappings

**Sections**:

#### 1. Workspace Settings
```yaml
workspace:
  base_path: ~/src/work
  epic_required: true
  slug_format: "{task_id}-{slug}"
```

#### 2. Repository Mappings
```yaml
repositories:
  - name: cursor-rules
    path: ~/src/github/pfeff/cursor-rules
    worktree_parent: ~/src/github/pfeff/cursor-rules
  - name: dotfiles
    path: ~/src/github/pfeff/dotfiles
    worktree_parent: ~/src/github/pfeff/dotfiles
```

#### 3. Coordinator Definitions
```yaml
coordinators:
  - name: task-workspace
    role: Workspace creation and management
    capabilities:
      - directory_creation
      - git_worktree
      - tmux_session
```

#### 4. Template Paths
```yaml
templates:
  design: templates/DESIGN.md.tmpl
  plan: templates/PLAN.md.tmpl
```

### Epic Categories

**Predefined**:
- `ad-hoc`: Quick tasks, investigations
- `tooling`: Development tools
- `platform`: Infrastructure work

**Custom**: Add project-specific epics as needed

### Task Presets

**Bug Fix**:
```yaml
presets:
  bug:
    questions: [priority, severity, reproduction, impact, root_cause]
    templates: bug-template.md
```

**Feature**:
```yaml
presets:
  feature:
    questions: [user_story, acceptance_criteria, dependencies, effort]
    templates: feature-template.md
```
