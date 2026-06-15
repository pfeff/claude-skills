# Dispatch Task Command Operation

User-facing command that dispatches a GOAL.md node to a workspace. Parses GOAL.md, presents ready nodes for selection, creates the node workspace, populates DESIGN.md with node content, updates GOAL.md status, and outputs attach instructions.

**Mode**: Bootstrap (GOAL.md-based). For coordinator mode, use `dispatch-node.md` within the execute-tree loop.

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `project_dir` | No | Project directory containing GOAL.md. Defaults to current working directory. |

## Output

Attach instructions for the created workspace:
- Workspace path
- Tmux session name
- Next steps (attach command, init-workspace reminder)

## Execution Steps

### 1. Locate GOAL.md

```
If project_dir provided:
  goal_path = project_dir/GOAL.md
Else:
  goal_path = ./GOAL.md

If GOAL.md does not exist:
  Error: "No GOAL.md found in <path>. This command requires a goal-tree project."
  Stop.
```

### 2. Parse GOAL.md

Read and parse GOAL.md using the format specification in `references/goal-md-format.md`.

```
Read: GOAL.md

Extract:
  - Frontmatter: title, repos, guardian_issue, status
  - Nodes: ID, title, status, repos, depends_on, description, acceptance_criteria
  - Results Log (for dependency context)
```

Use the parsing algorithm from goal-md-format.md:
1. Extract YAML frontmatter
2. Parse node headings with `[status: <value>]` tags
3. Parse node body properties (`**repos**:`, `**depends_on**:`, acceptance criteria checkboxes)
4. Build tree structure from heading levels
5. Resolve repos inheritance

### 3. Identify Ready Nodes

A node is ready when:
- `status` = `pending`
- All nodes in `depends_on` have `status` = `completed`

```
ready_nodes = []

for node in all_nodes:
  if node.status == "pending":
    deps_met = true
    for dep_id in node.depends_on:
      dep_node = find_node_by_id(dep_id)
      if dep_node.status != "completed":
        deps_met = false
        break
    if deps_met:
      ready_nodes.append(node)
```

### 4. Handle Edge Cases

| Condition | Action |
|-----------|--------|
| No ready nodes, some pending | "No ready nodes. All pending nodes have unmet dependencies." |
| No ready nodes, all complete | "All nodes complete. Nothing to dispatch." |
| No ready nodes, some blocked | "No ready nodes. Some nodes are blocked." |

If no ready nodes, stop and display the appropriate message.

### 5. Present Node Selection

Use AskUserQuestion to present ready nodes:

```
AskUserQuestion:
  question: "Select a node to dispatch:"
  header: "Node"
  options:
    - label: "<node.id>. <node.title>"
      description: "<parent goal> | repos: <node.repos>"
    - ...
```

If only one ready node, skip selection and use it directly.

### 6. Check for Existing Workspace

Before creating a workspace, check if one already exists:

```
workspace_path = <project_dir>/<node.id>-<slug>/

If directory exists:
  Skip workspace creation
  Go to step 9 (output attach instructions)
```

### 7. Create Node Workspace

Call the workspace creation script:

```bash
${CLAUDE_PLUGIN_ROOT}/skills/task-workflow/scripts/create-workspace.sh \
  --node \
  --node-id "<node.id>" \
  --headline "<node.title>" \
  --project-dir "<project_dir>" \
  --project-branch "<project_branch>" \
  --repos "<comma-separated repos>"
```

Extract `project_branch` from project `.envrc` (`PROJECT_BRANCH` variable) or derive from project directory name.

If the script fails, report the error and stop.

### 8. Populate DESIGN.md

After workspace creation, populate DESIGN.md with actual node content:

```
Edit: <workspace_path>/DESIGN.md

Replace placeholder sections with:

## Requirements

<node.description>

## Acceptance Criteria

<node.acceptance_criteria as canonical checkbox list>

Write each criterion in canonical form:
  - [ ] **AC-N**: <criterion> _(verify: <method>)_
where `_(verify: <method>)_` is an optional one-line what-to-check hint.
PRESERVE any existing AC-N ids carried on the GOAL.md node — reuse them
verbatim. Assign sequential ids (AC-1, AC-2, …) only when the node has none.
This step is idempotent: re-running must not renumber or rewrite existing ids.

## Project Context

- **Parent goal**: <parent_goal.title>
- **Root objective**: <frontmatter.title>
- **Integration branch**: <project_branch>
```

### 8a. Warn on Empty Acceptance Criteria (Provisional)

After seeding the node's AC into DESIGN.md, check that at least one checkable criterion landed. A node dispatched with an empty AC section should warn, not silently proceed. Count the total ACs in BOTH formats with the shared parser:

```bash
${CLAUDE_PLUGIN_ROOT}/skills/task-workflow/scripts/ac-count "<workspace_path>/DESIGN.md"
```

`ac-count` prints `<met> <total>`. If `<total>` is `0`, **WARN** the operator (recommend the node carry ≥1 checkable acceptance criterion) and **continue**. Do not block: an empty AC section must not halt or fail dispatch.

```
ACCEPTANCE CRITERIA WARNING: dispatched node has no checkable acceptance criteria.
Recommend capturing ≥1 checkable AC on the GOAL.md node.
Continuing — dispatch is not blocked.
```

**Provisional (DESIGN.md DD-6)** — warn-first by deliberate doctrine: preserving the dispatch flow (fleet-safety) wins over a hard refusal that is unvalidated in use. The upgrade-to-refuse criteria live in DD-6; do not promote this to a hard gate here.

### 9. Update GOAL.md

Update the node in GOAL.md:

1. Change status tag from `[status: pending]` to `[status: in_progress]`
2. Add `**workspace**: <workspace_path>` to node body

Use the Edit tool for surgical updates:

```
Edit: GOAL.md
  old_string: "## <node.id>. <node.title> [status: pending]"
  new_string: "## <node.id>. <node.title> [status: in_progress]"

Edit: GOAL.md
  old_string: "<end of node body before next heading>"
  new_string: "**workspace**: <workspace_path>\n\n<end of node body>"
```

### 10. Output Attach Instructions

```
Node dispatched: <node.id>. <node.title>

  Workspace: <workspace_path>
  Session:   <sanitized_session_name>

Next steps:
  1. tmux attach -t "<session_name>"
  2. Run /init-workspace in the work session
```

## Error Handling

| Error | Response |
|-------|----------|
| GOAL.md not found | "No GOAL.md found in <path>. This command requires a goal-tree project." |
| GOAL.md parse error | "Failed to parse GOAL.md: <error>. Check format against references/goal-md-format.md." |
| No ready nodes | Display appropriate message based on tree state (blocked, complete, dependencies) |
| create-workspace.sh fails | "Workspace creation failed (exit <code>): <stderr>. Check script output above." |
| Workspace already exists | Skip creation, show attach instructions |
| Edit fails | "Failed to update GOAL.md: <error>. Manual update may be needed." |

## Example

### Happy Path

```
User: /dispatch-task

Reading GOAL.md...
  Title: Add OAuth Authentication
  Nodes: 6 total, 2 ready

Select a node to dispatch:
  A.2. OAuth endpoints (Backend API | repos: api-service)
  B.1. Login page (Frontend Integration | repos: web-frontend)

User selects: A.2. OAuth endpoints

Creating workspace...
  Path: /home/user/project/A.2-oauth-endpoints/
  Branch: project-branch/A.2
  Session: A.2- OAuth endpoints

Populating DESIGN.md...
  Requirements: updated
  Acceptance Criteria: 3 items

Updating GOAL.md...
  Status: pending → in_progress
  Workspace: added

Node dispatched: A.2. OAuth endpoints

  Workspace: /home/user/project/A.2-oauth-endpoints/
  Session:   A2- OAuth endpoints

Next steps:
  1. tmux attach -t "A2- OAuth endpoints"
  2. Run /init-workspace in the work session
```

### Existing Workspace

```
User: /dispatch-task

Reading GOAL.md...
  Title: Add OAuth Authentication
  Ready: A.2. OAuth endpoints

Workspace already exists: /home/user/project/A.2-oauth-endpoints/

Attach instructions:
  tmux attach -t "A2- OAuth endpoints"
```

## Integration Points

- **Invoked by**: `/dispatch-task` command
- **Depends on**:
  - `references/goal-md-format.md` (parsing spec)
  - `task-workflow/scripts/create-workspace.sh` (workspace creation)
- **Related**:
  - `dispatch-node.md` (coordinator mode dispatch with subagent/session support)
  - `start-task.md` (analogous pattern for GitHub issues)
