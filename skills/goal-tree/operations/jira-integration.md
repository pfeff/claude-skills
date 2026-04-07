# Jira Integration for Goal Trees

Integration approach for linking goal tree nodes to Jira items using the Atlassian CLI (acli).

## Permission Model

| Operation Type | Permission | Notes |
|---------------|------------|-------|
| Read | Automatic | Query issues, view details, list sprints |
| Write | User-directed | Status changes, comments require explicit request |

**Principle**: Reads are safe and autonomous. Writes require explicit user direction because they affect external state visible to the team.

## Node Property: jira_ref

Link a goal tree node to a Jira issue using the `jira_ref` property:

```markdown
### A.1 Implement auth middleware [status: pending]

**jira_ref**: DO-422
**repos**: api-service

Add JWT validation middleware for protected routes.
```

The `jira_ref` value is the Jira issue key (e.g., `DO-422`, `PROJ-123`).

## Read Operations (Automatic)

### Fetch Issue Details

```bash
# View issue with full details
acli jira workitem view DO-422

# View multiple issues
acli jira workitem view DO-422 DO-423 DO-424
```

Use when:
- Starting work on a node with `jira_ref`
- Syncing acceptance criteria from Jira
- Checking current status before updating

### Search Related Issues

```bash
# Find issues in a sprint
acli jira workitem search --jql "sprint = 'Sprint 10' AND project = DO"

# Find issues by epic
acli jira workitem search --jql "parent = DO-100"

# Find issues with specific status
acli jira workitem search --jql "project = DO AND status = 'In Progress'"
```

Use when:
- Populating a goal tree from sprint backlog
- Finding related work items
- Checking sprint progress

### List Sprint Items

```bash
# List sprints on a board
acli jira sprint list --board-id 123

# View sprint details
acli jira sprint view 456
```

Use when:
- Planning goal tree structure from sprint
- Checking sprint timeline

### View Comments

```bash
acli jira workitem comment list DO-422
```

Use when:
- Checking for context or decisions
- Reviewing discussion before starting work

## Write Operations (User-Directed Only)

### Update Issue Status

```bash
# Transition to new status
acli jira workitem transition --key DO-422 --status "In Progress"
acli jira workitem transition --key DO-422 --status "Done"
```

**Trigger**: Only when user explicitly requests status sync or says "update Jira".

**Status Mapping** (example):

| Goal Tree Status | Jira Status |
|-----------------|-------------|
| pending | To Do |
| in_progress | In Progress |
| completed | Done |
| blocked | Blocked |
| skipped | Won't Do |

**Note**: Status names vary by project workflow. Check the issue's current status first:
```bash
acli jira workitem view DO-422
```

### Add Work Log Comment

```bash
acli jira workitem comment create --key DO-422 --body "Completed auth middleware implementation. See commit abc1234."
```

**Trigger**: Only when user explicitly requests, e.g., "add a comment to Jira" or "log this to Jira".

**Comment Template** (when completing a node):
```
[Goal Tree] Node A.1 completed

Summary: {node.result}
Commit: {commit_sha}
Files: {files_changed}
```

### Link Issues

```bash
# Link two issues
acli jira workitem link add DO-422 DO-423 --type "blocks"
```

**Trigger**: Only when user requests linking.

## Integration Patterns

### Pattern 1: Start Work on Node

When beginning work on a node with `jira_ref`:

1. **Read** issue details (automatic)
2. Show user current Jira status
3. **If user requests**: Update Jira status to "In Progress"

```
Starting node A.1 (jira_ref: DO-422)
Jira status: "To Do" | Assignee: mpfefferle | Sprint: Sprint 10

Would you like me to update the Jira status to "In Progress"?
```

### Pattern 2: Complete Node

When completing a node with `jira_ref`:

1. Mark node completed in GOAL.md
2. Show user the completion summary
3. **If user requests**: Update Jira and/or add comment

```
Node A.1 completed.

Jira issue DO-422 is currently "In Progress".
Would you like me to:
- Transition to "Done"
- Add a completion comment
```

### Pattern 3: Sync from Sprint

When populating goal tree from Jira sprint:

1. **Read** sprint items (automatic)
2. Present items to user
3. User selects which items become goal tree nodes
4. Create nodes with `jira_ref` property

### Pattern 4: Blocked Node

When a node becomes blocked:

1. Mark node blocked in GOAL.md
2. **If user requests**: Update Jira to "Blocked" with comment

## Error Handling

### Authentication Issues

```bash
# Check auth status
acli jira auth status

# Re-authenticate if needed
acli jira auth login --web
```

### Transition Failures

If transition fails with "No allowed transitions found":
1. The status name may differ from expected
2. Check current status: `acli jira workitem view DO-422`
3. Report exact status names to user
4. Ask user for correct target status

### Rate Limits

For bulk operations:
- Process items in small batches
- Add delays between API calls
- Report progress to user

## Configuration

No additional configuration required beyond standard acli setup:

```bash
# Verify acli is configured
acli jira auth status
```

Environment variables (optional, for scripts):
- `JIRA_SITE`: Jira instance (e.g., `tcetra.atlassian.net`)
- `JIRA_EMAIL`: User email
- `JIRA_API_TOKEN`: API token (or use `~/.acli/token.txt`)

## References

- `/atlassian-cli` skill: Full acli command reference
- `goal-md-format.md`: GOAL.md specification including `jira_ref` property
- `node-lifecycle.md`: Status transition rules for goal tree nodes
