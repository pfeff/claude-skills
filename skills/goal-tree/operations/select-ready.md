# Select Ready Operation

Queries the coordinator for nodes ready for dispatch — pending with dependencies met. Returns a batch grouped for parallel execution.

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `tree_id` | Yes | Coordinator tree ID |

## Output

```
ready_batch:
  - { node: <node>, independent_group: 1 }
  - { node: <node>, independent_group: 1 }
  - { node: <node>, independent_group: 2 }
```

Nodes in the same `independent_group` have no dependencies between them and can be dispatched in parallel.

## Execution Steps

### 1. Query Ready Nodes

```bash
coord tree ready $TREE_ID
```

The coordinator's `/ready` endpoint returns all nodes that are pending with their dependencies met. This replaces the manual tree-walking and dependency-checking logic.

### 2. Parse Response

**Layer filter**: Only leaf nodes (L0 tasks) should appear in the ready batch. The coordinator's `/ready` endpoint returns pending nodes with dependencies met — filter out any non-leaf nodes (nodes that have children in the tree). Non-leaf nodes are L1 decomposition structure; their readiness is derived from children, not dispatched directly. See `references/layer-model.md`.

The response contains nodes ready for dispatch:

```json
{
  "data": [
    {
      "id": 43,
      "node_id": "A.2",
      "title": "User CRUD",
      "status": "pending",
      "repos": ["api-service"],
      "description": "...",
      "depends_on": ["A.1"]
    },
    {
      "id": 50,
      "node_id": "B.1",
      "title": "Login UI",
      "status": "pending",
      "repos": ["web-app"],
      "description": "...",
      "depends_on": []
    }
  ]
}
```

### 3. Group Independent Nodes

Identify which ready nodes can run in parallel (no dependency path between them):

```
groups = []
current_group = 1

for node in ready_nodes:
  # Check if this node shares a dependency with any node in the current group
  can_parallel = true
  for grouped_node in groups where group == current_group:
    if shares_dependency_path(node, grouped_node):
      can_parallel = false
      break

  if can_parallel:
    groups.append({ node: node, group: current_group })
  else:
    current_group += 1
    groups.append({ node: node, group: current_group })
```

**Dependency path check**: Two nodes share a dependency path if:
- One depends on the other (directly or transitively)
- They share a common dependency that is not yet completed
- They modify the same repo AND have overlapping file scope (conservative: same repo = potentially conflicting)

In practice, the simple heuristic is: nodes under different top-level sub-goals are independent. Nodes under the same sub-goal may conflict if they touch the same repo.

### 4. Return Batch

Return the grouped ready nodes. The caller (execute-tree) decides how many to dispatch in parallel based on the groups.

## Edge Cases

| Condition | Result |
|-----------|--------|
| Empty response, blocked tasks remain | Return empty batch with `reason: "blocked"` |
| Empty response, all done | Return empty batch with `reason: "complete"` |
| Empty response, only skipped remain | Return empty batch with `reason: "all_skipped"` |
| Single ready node | Return batch with one node in group 1 |
| All ready nodes independent | Return batch with all nodes in group 1 (max parallelism) |

To determine the reason when the ready list is empty, query the full tree:

```bash
coord tree show $TREE_ID
```

Check node statuses to determine if all are complete, all blocked, or all skipped.

## Example

### Query

```bash
coord tree ready 1
```

### Response

```json
{
  "data": [
    { "id": 43, "node_id": "A.2", "title": "User CRUD", "repos": ["api-service"] },
    { "id": 50, "node_id": "B.1", "title": "Login UI", "repos": ["web-app"] }
  ]
}
```

### Output

```
ready_batch:
  - { node: A.2, independent_group: 1 }  # api-service
  - { node: B.1, independent_group: 1 }  # web-app (different repo, independent)
```

A.2 and B.1 are in the same group — they can run in parallel (different repos, no shared dependencies).

## Integration Points

- **Called by**: execute-tree (step 1 of each loop iteration)
- **Depends on**: `coord` CLI, COORDINATOR_URL, COORDINATOR_TOKEN
- **Reference**: `references/node-lifecycle.md` for ready check rules
