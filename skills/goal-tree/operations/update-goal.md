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

### 1. Build Update Call

Construct the `ac_node_update` MCP tool call with the fields to change:

```
ac_node_update(
  action=<"complete"|"blocked"|"failed"|"progress">,
  tree_id=$TREE_ID,
  node_id="$NODE_ID",
  message="<result summary>",
  artifacts=[<optional artifact list>]
)
```

### 2. Update Node Status

If `updates.status` is provided, use the corresponding action:

```
ac_node_update(action="complete", tree_id=$TREE_ID, node_id="$NODE_ID")
```

### 3. Record Result

If `updates.result` is provided (typically on completion), include it as `message`:

```
ac_node_update(
  action="complete",
  tree_id=$TREE_ID,
  node_id="$NODE_ID",
  message="Added JWTAuthMiddleware with full validation."
)
```

Status and result are combined in the same call — the `action` sets the status and `message` records the result.

### 4. Update Acceptance Criteria

Acceptance criteria updates are not directly supported by `ac_node_update`. Use the coordinator REST API or update criteria through the node description if needed.

### 5. Add Detailed Result Record

For structured result recording (dispatch method, files, commit), use `action="progress"` with artifacts:

```
ac_node_update(
  action="progress",
  tree_id=$TREE_ID,
  node_id="$NODE_ID",
  message="Added JWT validation middleware with signature and expiry checks.",
  artifacts=["path/to/file1.md", "path/to/file2.md", "abc1234"]
)
```

### 6. Parent Status Propagation

The coordinator handles parent goal status propagation automatically. When a node is marked completed, the coordinator checks if all sibling nodes are complete and updates the parent accordingly.

No manual parent checking is needed — this was previously done by walking GOAL.md headers.

### 7. Verify Update

After the update, optionally verify by querying the node state:

```
ac_node_query(action="get", tree_id=$TREE_ID, node_id="$NODE_ID")
```

## Batch Update

For updating multiple nodes at once (e.g., after parallel dispatch completes):

```
for each (node_id, updates) in batch:
  ac_node_update(action=<status_action>, tree_id=$TREE_ID, node_id=node_id, message="<result>")
```

Each `ac_node_update` call is independent — no concurrency concerns.

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

**Calls executed**:

```
# Update status and result
ac_node_update(
  action="complete",
  tree_id=1,
  node_id="A.1",
  message="Added JWTAuthMiddleware with full validation."
)

# Record detailed result with artifacts
ac_node_update(
  action="progress",
  tree_id=1,
  node_id="A.1",
  message="Added JWT validation middleware with signature and expiry checks.",
  artifacts=["middleware/auth.go", "middleware/auth_test.go", "abc1234"]
)
```

The coordinator automatically propagates parent status — if A's other children are all done, A is marked completed.

## Integration Points

- **Called by**: execute-tree (after dispatch), resume-project (reset in_progress)
- **Depends on**: `ac_node_query` and `ac_node_update` MCP tools (agent-coordinator MCP server), COORDINATOR_TOKEN
- **Reference**: `references/node-lifecycle.md` for transition rules
