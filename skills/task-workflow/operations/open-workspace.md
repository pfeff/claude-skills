# Workspace Opening Operation

Discovers and opens existing workspace.

## Purpose

Opens an existing task workspace by locating the directory, extracting metadata, and recreating the tmux session.

## Inputs

- **task-id** or **path** (required): Either a task identifier (e.g., `TOOS-24`, `DO-242`, `skills-workflow`) or a full path to a workspace directory
- **epic-slug** (optional): Epic slug to narrow search when using task-id (e.g., `ad-hoc`, `tooling`, `DO-202-outsource`)
- **--verify** (optional): Check GitHub issue status via `gh issue view`

## Implementation Steps

### 1. Parse User Request

Extract task-id/path and optional epic-slug from user input.

**Valid formats**:
- `/open-workspace TOOS-24`
- `/open-workspace TOOS-24 ad-hoc`
- `/open-workspace ~/src/work/tooling/TOOS-24-fix-auth/`
- `/open-workspace .`
- `Resume task DO-242`
- `Continue work on skills-workflow`

### 2. Detect Argument Type

Determine if the first argument is a path or a task-id.

**Path detection**:
```bash
arg="$1"
if [[ "$arg" == *"/"* ]] || [[ "$arg" == "~"* ]] || [[ "$arg" == "."* ]]; then
  is_path=true
else
  is_path=false
fi
```

**If path provided**:
```bash
if [ "$is_path" = true ]; then
  # Expand ~ and resolve relative paths
  workspace_path=$(eval echo "$arg")
  workspace_path=$(cd "$workspace_path" 2>/dev/null && pwd)

  if [ ! -d "$workspace_path" ]; then
    echo "Error: Path not found: $arg"
    exit 1
  fi

  # Skip to step 3 (Validate Workspace)
fi
```

### 3. Locate Workspace (task-id mode only)

Use shell commands to find the workspace directory.

**If epic provided**:
```bash
find ~/src/work/$epic_slug -maxdepth 1 -type d -name "$task_id-*" 2>/dev/null | head -1
```

**If no epic provided**:
```bash
find ~/src/work -maxdepth 2 -type d -name "$task_id-*" 2>/dev/null
```

**Handle multiple matches**:
```bash
matches=$(find ~/src/work -maxdepth 2 -type d -name "$task_id-*" 2>/dev/null)
match_count=$(echo "$matches" | wc -l | tr -d ' ')

if [ "$match_count" -gt 1 ]; then
  echo "Multiple workspaces found for $task_id:"
  echo "$matches"
  echo ""
  echo "Please specify epic slug to narrow search:"
  echo "/open-workspace $task_id <epic-slug>"
  exit 1
fi
```

**If not found, check archive**:
```bash
if [ -z "$workspace_path" ] || [ ! -d "$workspace_path" ]; then
  # Search archive for matching tarball
  if [ -n "$epic_slug" ]; then
    archive_match=$(find ~/src/work/.archive/$epic_slug -maxdepth 1 -name "$task_id-*.tar.gz" 2>/dev/null | head -1)
  else
    archive_match=$(find ~/src/work/.archive -maxdepth 2 -name "$task_id-*.tar.gz" 2>/dev/null | head -1)
  fi

  if [ -n "$archive_match" ]; then
    echo "Workspace not found in active workspaces"
    echo "Found archived workspace: $archive_match"
    # Proceed to re-hydration (step 3a)
  fi
fi
```

### 3a. Re-hydrate from Archive (if found)

Extract archived workspace back to active location:
```bash
archive_path="$archive_match"
archive_epic=$(basename "$(dirname "$archive_path")")
archive_name=$(basename "$archive_path" .tar.gz)

# Determine target directory
target_dir="$HOME/src/work/$archive_epic"
mkdir -p "$target_dir"

echo "Re-hydrating to $target_dir/$archive_name/"

# Extract tarball
tar -xzf "$archive_path" -C "$target_dir"

workspace_path="$target_dir/$archive_name"

echo "Workspace restored from archive"
```

**Error if not found anywhere**:
```bash
if [ -z "$workspace_path" ] || [ ! -d "$workspace_path" ]; then
  echo "Error: No workspace found for task $task_id"
  if [ -n "$epic_slug" ]; then
    echo "Searched in: ~/src/work/$epic_slug/"
    echo "Searched archive: ~/src/work/.archive/$epic_slug/"
  else
    echo "Searched in: ~/src/work/*/"
    echo "Searched archive: ~/src/work/.archive/*/"
  fi
  echo "Expected pattern: ~/src/work/<epic>/$task_id-<slug>/"
  exit 1
fi
```

### 4. Validate Workspace

Verify workspace contains DESIGN.md:
```bash
if [ ! -f "$workspace_path/DESIGN.md" ]; then
  echo "Error: Found directory but missing DESIGN.md: $workspace_path"
  echo "This may not be a valid task workspace."
  exit 1
fi
```

### 5. Extract Metadata

Read DESIGN.md first line to extract task-id and headline:
```bash
first_line=$(head -n 1 "$workspace_path/DESIGN.md")
task_id_extracted=$(echo "$first_line" | sed 's/^# \([^:]*\):.*/\1/')
headline=$(echo "$first_line" | sed 's/^# [^:]*: \(.*\)/\1/')
```

**Format validation**:
- Expected format: `# TASK-ID: Headline text`
- If extraction fails, use provided task-id as fallback

```bash
if [ -z "$headline" ]; then
  echo "Warning: Could not extract headline from DESIGN.md"
  headline="$task_id"
fi
```

### 6. Recreate Tmux Session

Format session name:
```bash
session_name="$task_id_extracted: $headline"
```

Create session using script:
```bash
${CLAUDE_PLUGIN_ROOT}/skills/task-workflow/scripts/create-tmuxp-session.sh "$session_name" "$workspace_path"
```

**Session creation does**:
- Kills existing session with same name (if any)
- Creates `.tmuxp.yaml` with three windows:
  - `nvim`: Editor window
  - `zsh`: Shell window
  - `claude`: Claude CLI window
- Launches session in detached mode

### 7. Display Summary

Show task information to user:
```
Task resumed: $task_id_extracted - $headline
Workspace: $workspace_path
Tmux session: "$session_name"

Attach with: tmux attach -t "$session_name"
```

### 8. Detect and Suggest Skills

Scan workspace for known repositories and suggest relevant skills.

**Repository-to-skill mapping**:

| Repository | Skill | Trigger |
|------------|-------|---------|
| Octopus | octopus | Directory named `Octopus` exists |
| GitHub | - | Directory named `GitHub` exists |

> **Note**: Dev-Stacks operational knowledge is now in `Dev-Stacks/CLAUDE.md` and `Dev-Stacks/docs/`. No skill loading needed — the repo's CLAUDE.md is loaded automatically when working within the repo directory.

**Detection logic**:
```bash
detected_skills=""

if [ -d "$workspace_path/Octopus" ]; then
  detected_skills="$detected_skills octopus"
fi
```

**Implementation note**: After displaying suggestions, the Claude instance should use the Skill tool to invoke each detected skill. For Dev-Stacks, read the repo's CLAUDE.md directly instead.

### 9. Verify GitHub Issue (if --verify flag)

If `--verify` flag is provided, check GitHub issue status.

**Extract issue reference from DESIGN.md**:
```bash
issue_ref=$(grep "^- GitHub Issue:" "$workspace_path/DESIGN.md" | sed 's/^- GitHub Issue: *//')
```

**Skip if no issue reference**:
```bash
if [ -z "$issue_ref" ] || [ "$issue_ref" = "\$ISSUE" ]; then
  echo "No GitHub issue linked to this workspace"
  exit 0
fi
```

**Fetch issue status**:
```bash
gh issue view "$issue_ref" --json state,title,assignees,labels,milestone
```

**Display issue status**:
```
GitHub Issue Status:
  Issue: $issue_ref
  Title: $title
  State: $state
  Assignees: $assignees
  Labels: $labels
  Milestone: $milestone
```

**Handle errors**:
```bash
if ! gh issue view "$issue_ref" --json state 2>/dev/null; then
  echo "Warning: Could not fetch GitHub issue: $issue_ref"
  echo "Check that the issue exists and you have access"
fi
```

## Error Handling

| Error | Response |
|-------|----------|
| Task not found | Search archive, then show searched paths (active and archive) |
| Multiple matches | List all matches (active and archived), prompt for epic slug |
| Path not found | Show error with provided path |
| Missing DESIGN.md | Warn that directory may not be valid workspace |
| Cannot parse DESIGN.md | Use task-id as fallback for session name |
| Tmux creation fails | Report error from script |
| Archive extraction fails | Report error with tarball path |
| No GitHub issue linked | Show message that no issue is linked (--verify) |
| GitHub issue fetch fails | Show warning with issue ref and access hint (--verify) |

## Examples

### Resume by task ID only
```
User: /open-workspace TOOS-24
Searches: ~/src/work/*/TOOS-24-*/
Output: Task resumed: TOOS-24 - Fix authentication bug
        Workspace: ~/src/work/platform/TOOS-24-fix-auth-bug/
        Tmux session: "TOOS-24: Fix authentication bug"
```

### Resume by task ID and epic
```
User: /open-workspace TOOS-24 platform
Searches: ~/src/work/platform/TOOS-24-*/
Output: Same as above
```

### Resume by full path
```
User: /open-workspace ~/src/work/tooling/TOOS-24-fix-auth/
Path detected, skips search
Output: Task resumed: TOOS-24 - Fix authentication bug
        Workspace: ~/src/work/tooling/TOOS-24-fix-auth/
        Tmux session: "TOOS-24: Fix authentication bug"
```

### Resume from current directory
```
User: /open-workspace .
Path detected (starts with .)
Output: Task resumed: TOOS-24 - Fix authentication bug
        Workspace: /current/working/directory/
        Tmux session: "TOOS-24: Fix authentication bug"
```

### Handle multiple matches
```
User: /open-workspace DO-242
Output: Multiple workspaces found for DO-242:
        ~/src/work/ad-hoc/DO-242-first-task/
        ~/src/work/platform/DO-242-second-task/

        Please specify epic slug to narrow search:
        /open-workspace DO-242 <epic-slug>

User: /open-workspace DO-242 ad-hoc
Output: Task resumed: DO-242 - First task
        Workspace: ~/src/work/ad-hoc/DO-242-first-task/
```

### Re-hydrate from archive
```
User: /open-workspace TOOS-24
Output: Workspace not found in active workspaces
        Found archived workspace: ~/src/work/.archive/platform/TOOS-24-fix-auth.tar.gz
        Re-hydrating to ~/src/work/platform/TOOS-24-fix-auth/
        Workspace restored from archive

        Task resumed: TOOS-24 - Fix authentication bug
        Workspace: ~/src/work/platform/TOOS-24-fix-auth/
        Tmux session: "TOOS-24: Fix authentication bug"

        Attach with: tmux attach -t "TOOS-24: Fix authentication bug"
```

### Verify GitHub issue status
```
User: /open-workspace TOOS-24 --verify
Output: Task resumed: TOOS-24 - Fix authentication bug
        Workspace: ~/src/work/platform/TOOS-24-fix-auth-bug/
        Tmux session: "TOOS-24: Fix authentication bug"

        GitHub Issue Status:
          Issue: pfeff/project#24
          Title: Fix authentication bug
          State: open
          Assignees: pfeff
          Labels: bug, priority:high
          Milestone: v2.0

        Attach with: tmux attach -t "TOOS-24: Fix authentication bug"
```

### Verify with no linked issue
```
User: /open-workspace skills-workflow --verify
Output: Task resumed: skills-workflow - Refactor workflow system
        Workspace: ~/src/work/tooling/skills-workflow/
        Tmux session: "skills-workflow: Refactor workflow system"

        No GitHub issue linked to this workspace

        Attach with: tmux attach -t "skills-workflow: Refactor workflow system"
```

## Integration Points

- **Workspace structure**: Uses standard `~/src/work/<epic>/<task-id>-<slug>/` layout
- **DESIGN.md format**: Parses first line `# TASK-ID: Headline`
- **Tmux session**: Delegates to `scripts/create-tmuxp-session.sh`
- **Created by**: `/create-workspace` command

## Implementation Checklist

When implementing this operation:

1. Parse user request for task-id/path, optional epic-slug, and --verify flag
2. Detect if argument is path (contains `/`, starts with `~` or `.`) or task-id
3. If path: validate it exists, resolve to absolute path
4. If task-id: use Bash tool to find workspace with `find` command
5. If not found in active workspaces: search `~/src/work/.archive/` for matching tarball
6. If found in archive: extract tarball to restore workspace, then continue
7. Handle edge cases: not found anywhere, multiple matches, path not found
8. Use Read tool to validate DESIGN.md exists
9. Use Bash tool to extract metadata from DESIGN.md
10. Use Bash tool to invoke `scripts/create-tmuxp-session.sh`
11. Display summary with workspace path and attach command
12. **Detect relevant skills**: Scan workspace for known repository directories (Dev-Stacks, DWH-TF, DevExtTFEnv, Octopus, etc.) and invoke corresponding skills using the Skill tool
13. If --verify flag: extract GitHub issue ref from DESIGN.md and run `gh issue view`
