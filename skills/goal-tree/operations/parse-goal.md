# Parse Goal Operation

Queries the coordinator API for the goal tree and returns a structured tree representation. Foundation for all operations that need to understand tree state.

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `tree_id` | Yes | Coordinator tree ID (from project CLAUDE.md or environment) |

## Output

A structured tree with these fields per node:

```
node:
  db_id: 42              # coordinator database ID
  id: "A.1"              # human-readable node ID
  title: "Implement auth middleware"
  status: "pending"
  description: "Add JWT validation..."
  acceptance_criteria:
    - { text: "Validates JWT signature", checked: false }
    - { text: "Invalid tokens return 401", checked: true }
  depends_on: ["A.0"]
  result: null
  repos: ["api-gateway"]
  children: [...]  # nested nodes
```

Plus document-level fields:

```
goal:
  tree_id: 1
  title: "Root goal title"
  context: "Problem statement..."
  guardian_issue: "owner/repo#123"
  status: "active"
  tree: [top-level nodes]
```

## Execution Steps

### 1. Query Coordinator API

```bash
coord tree show $TREE_ID
```

This returns JSON with the tree metadata and all nodes.

### 2. Parse JSON Response

The response from `coord tree show` contains:

```json
{
  "data": {
    "id": 1,
    "title": "Root goal title",
    "context": "Problem statement...",
    "guardian_issue_ref": "owner/repo#123",
    "status": "active",
    "nodes": [
      {
        "id": 42,
        "node_id": "A",
        "title": "Sub-goal A",
        "description": "...",
        "status": "pending",
        "repos": ["repo-1"],
        "result": null,
        "parent_id": null,
        "position": 0,
        "children": [
          {
            "id": 43,
            "node_id": "A.1",
            "title": "Task A.1",
            "status": "completed",
            "result": "Summary of what was done",
            ...
          }
        ]
      }
    ]
  }
}
```

Parse with `jq` or process the JSON directly.

### 3. Build Structured Tree

Map the JSON response to the standard tree structure:

```
For each node in response.data.nodes:
  Extract:
    db_id = node.id (database ID for API calls)
    id = node.node_id (human-readable ID like "A.1")
    title = node.title
    status = node.status
    description = node.description
    repos = node.repos (array)
    result = node.result
    children = node.children (recursively parsed)
    depends_on = node.dependencies (list of node_ids)
```

### 4. Resolve Repos Inheritance

Walk the tree and resolve repos inheritance:

```
function resolve_repos(node, parent_repos):
  if node.repos is empty:
    node.repos = parent_repos
  for child in node.children:
    resolve_repos(child, node.repos)
```

### 5. Return Structured Result

Return the complete parsed tree with all fields populated.

## Error Handling

| Error | Response |
|-------|----------|
| Tree not found (404) | Return error: "Tree $TREE_ID not found in coordinator" |
| Connection failure | Return error: "Cannot connect to coordinator at $COORDINATOR_URL" |
| Invalid JSON response | Return error with raw response for debugging |
| Missing COORDINATOR_TOKEN | Return error: "COORDINATOR_TOKEN is required" |
| Empty tree (no nodes) | Return empty tree (valid for new trees) |

## Example

### Query

```bash
coord tree show 1
```

### Parsed Output

```
goal.tree_id = 1
goal.title = "Add OAuth Authentication"
goal.tree = [
  {
    db_id: 10,
    id: "A",
    title: "Backend API",
    status: "in_progress",
    description: "Add REST endpoints for user management.",
    repos: ["api-service"],
    children: [
      {
        db_id: 11,
        id: "A.1",
        title: "Auth middleware",
        status: "completed",
        depends_on: [],
        result: "Added JWTAuthMiddleware with full validation.",
        repos: ["api-service"],
        children: []
      },
      {
        db_id: 12,
        id: "A.2",
        title: "User CRUD",
        status: "pending",
        depends_on: ["A.1"],
        repos: ["api-service"],
        children: []
      }
    ]
  }
]
```

## Integration Points

- **Called by**: All goal-tree operations that need tree state
- **Depends on**: `coord` CLI, COORDINATOR_URL, COORDINATOR_TOKEN
