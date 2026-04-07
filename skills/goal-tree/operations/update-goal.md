# Update Goal Operation

Updates node state via the coordinator API. Handles status transitions, result recording, and acceptance criteria updates.

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `tree_id` | Yes | Coordinator tree ID |
| `node_db_id` | Yes | Node database ID (from coordinator) |
| `node_id` | Yes | Human-readable node ID (e.g., `A.1`) for logging |
| `updates` | Yes | Dictionary of fields to update (see below) |

### Update Fields

| Field | Type | Description |
|-------|------|-------------|
| `status` | string | New status value |
| `result` | string | Outcome summary (on completion) |
| `description` | string | Updated description |
| `criteria` | JSON array | Updated acceptance criteria |

## Execution Steps

### 1. Build Update Command

Construct the `coord node update` command with the fields to change:

```bash
coord node update $TREE_ID $NODE_DB_ID \
  --status <status> \
  --result "<result summary>"
```

### 2. Update Node Status

If `updates.status` is provided:

```bash
coord node update $TREE_ID $NODE_DB_ID --status <new_status>
```

### 3. Record Result

If `updates.result` is provided (typically on completion):

```bash
coord node update $TREE_ID $NODE_DB_ID --result "<outcome summary>"
```

Status and result can be combined in a single call:

```bash
coord node update $TREE_ID $NODE_DB_ID \
  --status completed \
  --result "Added JWTAuthMiddleware with full validation."
```

### 4. Update Acceptance Criteria

If `updates.criteria` is provided:

```bash
coord node update $TREE_ID $NODE_DB_ID \
  --criteria '[\"criterion 1\", \"criterion 2\"]'
```

### 5. Add Detailed Result Record

For structured result recording (dispatch method, files, commit):

```bash
coord node add-result $TREE_ID $NODE_DB_ID \
  --status completed \
  --dispatch subagent \
  --files "path/to/file1.md,path/to/file2.md" \
  --summary "Added JWT validation middleware with signature and expiry checks." \
  --commit "abc1234"
```

### 6. Parent Status Propagation

The coordinator handles parent goal status propagation automatically. When a node is marked completed, the coordinator checks if all sibling nodes are complete and updates the parent accordingly.

No manual parent checking is needed — this was previously done by walking GOAL.md headers.

### 7. Verify Update

After the update, optionally verify by querying the node state:

```bash
coord tree show $TREE_ID | jq ".data.nodes[] | select(.node_id == \"$NODE_ID\")"
```

## Batch Update

For updating multiple nodes at once (e.g., after parallel dispatch completes):

```
for each (node_db_id, updates) in batch:
  coord node update $TREE_ID $node_db_id --status <status> --result "<result>"
```

Each `coord node update` call is independent — no file-level concurrency concerns.

## Error Handling

| Error | Response |
|-------|----------|
| Node not found (404) | Return error with node ID and db ID |
| Invalid status transition | Warn but allow (coordinator validates) |
| Connection failure | Retry with backoff, report if persistent |
| Invalid JSON in criteria | Report formatting error |

## Example

### Update: Mark task completed with result

**Input**:
```
tree_id: 1
node_db_id: 42
node_id: "A.1"
updates:
  status: "completed"
  result: "Added JWTAuthMiddleware with full validation."
```

**Commands executed**:

```bash
# Update status and result
coord node update 1 42 --status completed --result "Added JWTAuthMiddleware with full validation."

# Record detailed result
coord node add-result 1 42 \
  --status completed \
  --dispatch subagent \
  --files "middleware/auth.go,middleware/auth_test.go" \
  --summary "Added JWT validation middleware with signature and expiry checks." \
  --commit "abc1234"
```

The coordinator automatically propagates parent status — if A's other children are all done, A is marked completed.

## Integration Points

- **Called by**: execute-tree (after dispatch), resume-project (reset in_progress)
- **Depends on**: `coord` CLI, COORDINATOR_URL, COORDINATOR_TOKEN
- **Reference**: `references/node-lifecycle.md` for transition rules
