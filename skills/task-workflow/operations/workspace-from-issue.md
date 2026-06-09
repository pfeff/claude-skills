# Workspace From Issue Operation

Creates a workspace by inferring parameters and delegating to `create-workspace.sh`. Supports two entry modes:

1. **Issue mode**: GitHub issue reference provided → infer from issue metadata
2. **PWD mode**: No issue reference → infer from current working directory context

**Requirements**: Runs in the control session. The work session runs `/init-workspace` separately.

## Purpose

Eliminates manual parameter entry when creating workspaces. Accepts an optional GitHub issue reference; when provided, infers epic and repos from issue metadata and project board. When no issue is provided, infers epic from PWD context (goal-tree projects, workspace paths) and prompts for remaining parameters.

## Input Formats

### Issue Mode

Accept any of these issue reference formats (R1):

| Format | Example | Parse |
|--------|---------|-------|
| Short form | `<owner>/<repo>#78` | owner, repo, number=`78` |
| URL | `https://github.com/<owner>/<repo>/issues/78` | Extract from URL path segments |
| Number + repo | `78` (with repo context) | Requires owner/repo from context |

### PWD Mode

When no issue reference provided, the operation switches to PWD inference mode. No input required — context is derived from the current working directory.

## Execution Steps

### 0. Determine Mode

Check if an issue reference was provided:
- **Issue reference present**: Proceed to step 1 (Issue Mode)
- **No issue reference**: Jump to step 8 (PWD Mode)

---

## Issue Mode (steps 1-7)

### 1. Parse Issue Reference

Extract owner, repo, and issue number from the input.

**Short form** (`owner/repo#number`):
```
owner = segment before "/"
repo = segment between "/" and "#"
number = segment after "#"
```

**URL** (`https://github.com/owner/repo/issues/number`):
```
owner = path segment 1
repo = path segment 2
number = path segment 4
```

If parsing fails, ask the user for the reference in `owner/repo#number` format.

### 2. Fetch Issue Metadata

The script derives task-id and headline from `--issue` automatically. The agent fetches additional metadata only for epic and repo inference:

```bash
gh issue view <number> --repo <owner>/<repo> --json title,body,labels,assignees,milestone
```

Extract:
- `title` → used for confirmation display (script derives headline independently)
- `body` → scan for repo mentions (step 4)
- `milestone`, `labels` → used for epic inference (step 3)

#### Error Handling

| Error | Response |
|-------|----------|
| `gh` not installed | Error: "gh CLI is required" |
| Auth failure | Suggest: `gh auth login` |
| Issue not found | Error with issue reference, ask user to verify |

### 3. Infer Epic from Project Board

Query the owner's project boards to find which project contains this issue, then extract the sprint field.

```bash
# List projects
gh project list --owner <owner> --format json

# For each project, fetch items and find our issue
gh project item-list <project-number> --owner <owner> --format json --limit 200
```

Find the item matching our issue number and repository. Extract the `sprint` field.

**Sprint → Epic slug mapping**:
- `"Sprint 1 (Feb 17-21)"` → `sprint-1`
- `"Sprint 2 (Feb 24-28)"` → `sprint-2`
- Pattern: extract sprint number, format as `sprint-<N>`
- If sprint field is empty/null or item not found on any board → cannot infer

**If epic cannot be inferred**: Prompt the user via AskUserQuestion:
```
question: "What epic/project slug should this workspace use?"
options:
  - label: "ad-hoc"
    description: "No specific epic"
  - label: "sprint-1"
    description: "Current sprint"
  - label: "<other suggestion based on labels>"
    description: "<context>"
```

### 4. Infer Repos

Pass repos to `create-workspace.sh` in **owner-qualified form** `owner/repo`. The bootstrap script will resolve `~/src/github/<owner>/<repo>` directly and not fall back to alphabetical globs. Qualifying disambiguates when the same repo name exists under multiple owners (e.g. `pfeff/claude-skills` vs `Tcetra/claude-skills`) — the operation is the layer that knows the owner from the issue reference, so it is the layer that should qualify.

**Primary repo**: `<owner>/<repo>` from the issue reference (e.g., `acme/webapp` from `acme/webapp#78`).

**Additional repos**: Scan issue body for repo references:
- `other-owner/other-repo` patterns → pass through qualified
- Bare repo names mentioned in code blocks or file paths → default to the issue's owner and pass `<issue-owner>/<repo>`

**If unclear from context**: Prompt the user:
```
question: "Which repositories should be included?"
options:
  - label: "<owner>/<primary-repo> only"
    description: "Just the issue's repository"
  - label: "<owner>/<primary-repo>, <owner>/<detected-repo>"
    description: "Include referenced repository"
```

If no additional repos detected, default to primary repo only — no prompt needed.

### 5. Confirm Parameters

Before calling the bootstrap script, display inferred parameters and ask for confirmation:

```
Inferred parameters:
  task-id:  <number>
  epic:     <epic>
  headline: <title>
  repos:    <repo-list>
  issue:    <owner>/<repo>#<number>

Proceed with workspace creation?
```

Use AskUserQuestion with options: "Yes, create workspace" / "Let me adjust".

If the user wants to adjust, ask which parameter to change.

### 6. Run Bootstrap Script

Call `create-workspace.sh` with `--issue` and agent-derived params. The script auto-derives `--task-id` and `--headline` from the issue reference. `--repos` should use the owner-qualified form assembled in step 4:

```bash
${CLAUDE_PLUGIN_ROOT}/skills/task-workflow/scripts/create-workspace.sh \
  --epic <epic> \
  --repos <owner>/<primary-repo>[,<owner>/<other-repo>...] \
  --issue <owner>/<repo>#<number>
```

Example: `--repos acme/webapp,acme/shared-lib`.

Explicit `--task-id` or `--headline` can be passed if the user overrode them during confirmation (step 5).

The script handles:
- Issue metadata fetch (task-id, headline derivation)
- Directory creation
- Template rendering (DESIGN.md, CLAUDE.md, .envrc)
- Git worktree creation with feature branches
- Tmux session creation
- Verification checks

**Exit code 8** (derivation failed): The script could not fetch or parse issue metadata. Display the error and do not retry.

### 7. Display Next Steps

After successful creation, display:

```
Workspace created from <owner>/<repo>#<number>

  Path: ~/src/work/<epic>/<task-id>-<slug>/
  Session: <session-name>

Next steps:
  1. Attach: tmux attach -t "<sanitized-session-name>"
  2. In the work session: /init-workspace
```

## Error Handling

| Error | Response |
|-------|----------|
| Issue reference unparseable | Ask user for `owner/repo#number` format |
| `gh` CLI missing | Error with install instructions |
| Issue not found | Show reference, ask user to verify |
| Project board not found | Prompt for epic instead of inferring |
| Sprint field empty | Prompt for epic |
| `create-workspace.sh` exit 8 | Issue derivation failed — display error, do not retry |
| `create-workspace.sh` other failure | Show exit code and error, do not retry |

## Examples

### From /claude-skills:pull-task handoff

```
Input: acme/webapp#78

Fetching issue acme/webapp#78...
  Title: Unified workspace setup from GitHub issue reference
  Labels: enhancement, process-improvement

Checking project board for sprint...
  Project: Acme Development
  Sprint: Sprint 1 (Feb 17-21)
  Epic: sprint-1

Scanning for repo references...
  Primary: acme/webapp
  Also found: pfeff/cursor-rules (mentioned in issue body)

Inferred parameters:
  task-id:  78
  epic:     sprint-1
  headline: Unified workspace setup from GitHub issue reference
  repos:    acme/webapp,acme/shared-lib
  issue:    acme/webapp#78

Proceed? → Yes

Running create-workspace.sh...
  (script output)

Workspace created from acme/webapp#78
  Path: ~/src/work/sprint-1/78-unified-workspace-setup/
  Session: 78- Unified workspace setup from GitHub issue reference

Next steps:
  1. Attach: tmux attach -t "78- Unified workspace setup from GitHub issue reference"
  2. In the work session: /init-workspace
```

### With missing epic (prompt fallback)

```
Input: acme/webapp#99

Fetching issue acme/webapp#99...
  Title: Add retry logic to webhook delivery

Checking project board for sprint...
  Item not found on project board.

? What epic/project slug should this workspace use?
  → ad-hoc

Inferred parameters:
  task-id:  99
  epic:     ad-hoc
  headline: Add retry logic to webhook delivery
  repos:    acme/webapp
  issue:    acme/webapp#99

Proceed? → Yes
```

### URL input

```
Input: https://github.com/acme/webapp/issues/78

Parsed: acme/webapp#78
(continues as above)
```

---

## PWD Mode (steps 8-12)

When no issue reference is provided, infer parameters from the current working directory and project context.

### 8. Detect Project Context

Search for goal-tree or workspace markers starting from PWD, traversing upward:

```bash
# Check for GOAL.md (goal-tree project root)
GOAL_FILE=$(find_upward "GOAL.md")

# Check for CLAUDE.md with project context
CLAUDE_FILE=$(find_upward "CLAUDE.md")
```

**Find upward algorithm**:
```
current_dir = PWD
while current_dir != "/" and current_dir != $HOME:
    if file exists in current_dir:
        return current_dir/file
    current_dir = parent(current_dir)
return null
```

### 9. Infer Epic from Context

Apply heuristics in order (stop at first success):

**9a. From GOAL.md frontmatter**:
```
Read GOAL.md, parse YAML frontmatter
Extract: title field → generate slug (2-3 keywords, lowercase-hyphen)
Example: "DevOps/CloudEng Strategic Execution" → "devops-cloudeng-strategic"
```

**9b. From CLAUDE.md Epic reference**:
```
Read CLAUDE.md, look for "Epic:" line
Extract epic slug if present
```

**9c. From PWD path pattern**:
```
If PWD matches ~/src/work/<epic>/<task>/:
    Extract <epic> segment
Example: ~/src/work/sprint-1/42-feature/ → epic = "sprint-1"
```

**9d. Prompt user**:
If all heuristics fail, prompt via AskUserQuestion:
```
question: "What epic/project slug should this workspace use?"
options:
  - label: "ad-hoc"
    description: "No specific epic"
  - label: "experiments"
    description: "Experimental work"
```

### 10. Prompt for Task ID and Headline

Since there's no issue to derive from, prompt the user:

```
AskUserQuestion:
  question: "What task ID should this workspace use?"
  options:
    - label: "<suggested-id>"
      description: "Based on existing workspace numbering"
    - label: "Enter manually"
      description: "I'll type a custom ID"
```

For headline:
```
AskUserQuestion:
  question: "What headline/title describes this task?"
  options:
    - label: "Enter headline"
      description: "I'll type the task title"
```

### 11. Prompt for Repos (Optional)

```
AskUserQuestion:
  question: "Which repositories should be included?"
  options:
    - label: "None"
      description: "No git worktrees needed"
    - label: "Specify repos"
      description: "I'll list the repositories"
```

If "Specify repos", ask for a comma-separated list. Users can enter either bare names (`some-repo`) or owner-qualified names (`pfeff/some-repo`). The qualified form is recommended when the repo name exists under multiple owners on the local filesystem; the bootstrap script's `resolve_repo_path` will otherwise pick whichever owner sorts first alphabetically.

### 12. Run Bootstrap Script (PWD Mode)

Call `create-workspace.sh` with gathered parameters:

```bash
${CLAUDE_PLUGIN_ROOT}/skills/task-workflow/scripts/create-workspace.sh \
  --task-id <task-id> \
  --epic <epic> \
  --headline "<headline>" \
  [--repos <repo-list>]
```

Note: No `--issue` flag since this is PWD mode.

### 13. Display Next Steps (PWD Mode)

After successful creation, display:

```
Workspace created:
  Path: ~/src/work/<epic>/<task-id>-<slug>/
  Session: <session-name>

Next steps:
  1. Attach: tmux attach -t "<sanitized-session-name>"
  2. In the work session: /init-workspace
```

---

## Error Handling

| Error | Response |
|-------|----------|
| Issue reference unparseable | Ask user for `owner/repo#number` format |
| `gh` CLI missing | Error with install instructions |
| Issue not found | Show reference, ask user to verify |
| Project board not found | Prompt for epic instead of inferring |
| Sprint field empty | Prompt for epic |
| `create-workspace.sh` exit 8 | Issue derivation failed — display error, do not retry |
| `create-workspace.sh` other failure | Show exit code and error, do not retry |
| PWD not in recognized workspace path | Fall back to prompting for all parameters |
| GOAL.md/CLAUDE.md not parseable | Fall back to path-based inference or prompt |

## Examples

### Issue Mode: From /claude-skills:pull-task handoff

```
Input: acme/webapp#78

Fetching issue acme/webapp#78...
  Title: Unified workspace setup from GitHub issue reference
  Labels: enhancement, process-improvement

Checking project board for sprint...
  Project: Acme Development
  Sprint: Sprint 1 (Feb 17-21)
  Epic: sprint-1

Scanning for repo references...
  Primary: acme/webapp
  Also found: pfeff/cursor-rules (mentioned in issue body)

Inferred parameters:
  task-id:  78
  epic:     sprint-1
  headline: Unified workspace setup from GitHub issue reference
  repos:    acme/webapp,acme/shared-lib
  issue:    acme/webapp#78

Proceed? → Yes

Running create-workspace.sh...
  (script output)

Workspace created from acme/webapp#78
  Path: ~/src/work/sprint-1/78-unified-workspace-setup/
  Session: 78- Unified workspace setup from GitHub issue reference

Next steps:
  1. Attach: tmux attach -t "78- Unified workspace setup from GitHub issue reference"
  2. In the work session: /init-workspace
```

### Issue Mode: With missing epic (prompt fallback)

```
Input: acme/webapp#99

Fetching issue acme/webapp#99...
  Title: Add retry logic to webhook delivery

Checking project board for sprint...
  Item not found on project board.

? What epic/project slug should this workspace use?
  → ad-hoc

Inferred parameters:
  task-id:  99
  epic:     ad-hoc
  headline: Add retry logic to webhook delivery
  repos:    acme/webapp
  issue:    acme/webapp#99

Proceed? → Yes
```

### Issue Mode: URL input

```
Input: https://github.com/acme/webapp/issues/78

Parsed: acme/webapp#78
(continues as issue mode above)
```

### PWD Mode: From goal-tree project directory

```
PWD: ~/src/work/experiments/start-project-openended-goal-tree/

No issue reference provided. Detecting context...

Found: GOAL.md
  Title: DevOps/CloudEng Strategic Execution
  Epic: experiments

? What task ID should this workspace use?
  → G3

? What headline/title describes this task?
  → Background agent permission model

? Which repositories should be included?
  → dotfiles

Assembled parameters:
  task-id:  G3
  epic:     experiments
  headline: Background agent permission model
  repos:    dotfiles

Creating workspace...
  (script output)

Workspace created:
  Path: ~/src/work/experiments/G3-background-agent/
  Session: G3: Background agent permission model

Next steps:
  1. Attach: tmux attach -t "G3- Background agent permission model"
  2. In the work session: /init-workspace
```

### PWD Mode: No project context found

```
PWD: ~/src/github/pfeff/some-repo/

No issue reference provided. Detecting context...
  No GOAL.md found
  No workspace path pattern matched

? What epic/project slug should this workspace use?
  → ad-hoc

? What task ID should this workspace use?
  → fix-123

? What headline/title describes this task?
  → Fix broken authentication flow

? Which repositories should be included?
  → some-repo

Assembled parameters:
  task-id:  fix-123
  epic:     ad-hoc
  headline: Fix broken authentication flow
  repos:    some-repo

Creating workspace...
```

## Integration Points

- **Called by**: `/setup-workspace` command, `/claude-skills:pull-task` (after selection)
- **Delegates to**: `create-workspace.sh` (bootstrap script)
- **Succeeded by**: `/init-workspace` (in work session)
- **Issue data**: `gh` CLI for issue metadata and project board queries (Issue Mode only)
- **Context detection**: File system traversal and pattern matching (PWD Mode)
