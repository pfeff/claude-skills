# Coordinator Data Model Reference

The goal tree is persisted via the coordinator API (`agent-coordinator`). The coordinator is the single source of truth for tree structure, status, and results. All reads and writes go through the `coord` CLI.

## Data Model

### Goal Tree

| Field | Type | Description |
|-------|------|-------------|
| `id` | integer | Database ID (used in all API calls) |
| `title` | string | Root goal title |
| `context` | string | Problem statement, motivation, scope |
| `guardian_issue_ref` | string | Guardian issue reference (e.g., `owner/repo#123`) |
| `status` | string | Tree status: `active`, `completed`, `archived` |

### Goal Node

| Field | Type | Description |
|-------|------|-------------|
| `id` | integer | Database ID (used in API calls as `node-db-id`) |
| `node_id` | string | Human-readable ID (e.g., `A`, `A.1`, `B.1.2`) |
| `title` | string | Short description |
| `description` | string | Detailed description |
| `status` | string | Node status (see below) |
| `repos` | array | Repository names this node targets |
| `result` | string | Outcome summary (set on completion) |
| `parent_id` | integer | Database ID of parent node (null for top-level) |
| `position` | integer | Ordering within parent |
| `criteria` | array | Acceptance criteria (JSON array of strings) |

### Node Result

| Field | Type | Description |
|-------|------|-------------|
| `id` | integer | Database ID |
| `goal_node_id` | integer | Database ID of the node |
| `status` | string | Result status: `completed`, `partial`, `failed` |
| `dispatch_method` | string | How the node was executed: `subagent`, `inline`, `sub-session` |
| `files_modified` | array | List of file paths changed |
| `changes_summary` | string | Description of changes |
| `commit_hash` | string | Git commit hash |

### Dependency

| Field | Type | Description |
|-------|------|-------------|
| `goal_node_id` | integer | Database ID of the dependent node |
| `depends_on_node_id` | integer | Database ID of the dependency |

## Node Properties

### ID Format

IDs use dotted hierarchical notation:

| Level | ID Pattern | Example |
|-------|------------|---------|
| Top-level goal | Single letter | `A`, `B`, `C` |
| Sub-task | Letter.number | `A.1`, `B.2` |
| Sub-sub-task | Letter.number.number | `A.1.1`, `B.2.3` |

### Status Values

| Status | Meaning |
|--------|---------|
| `pending` | Not yet started, waiting for dispatch |
| `in_progress` | Currently being worked on |
| `completed` | All criteria met / all children done |
| `blocked` | External dependency prevents progress |
| `skipped` | Stuck detection triggered, deferred |

### Node Type Distinction

- **Goal**: Has children. Not directly implementable. Description is outcome-oriented.
- **Task**: Leaf node (no children). Directly implementable. Has acceptance criteria.

Any node can be either type — the distinction is structural (presence of children), not declared.

## CLI Reference

### Tree Operations

```bash
# Create a new goal tree
coord tree create --title "Project Title" --context "Description" --guardian-issue "owner/repo#123"

# List all trees
coord tree list

# Show tree with all nodes
coord tree show <tree-id>

# Get nodes ready for dispatch
coord tree ready <tree-id>
```

### Node Operations

```bash
# Create a node
coord node create <tree-id> \
  --node-id "A.1" \
  --title "Task title" \
  --description "Task description" \
  --status pending \
  --repos "repo1,repo2" \
  --parent-id <parent-db-id>

# Update a node
coord node update <tree-id> <node-db-id> \
  --status completed \
  --result "What was accomplished"

# Add a dependency
coord node add-dependency <tree-id> <node-db-id> --depends-on <other-db-id>

# Record a detailed result
coord node add-result <tree-id> <node-db-id> \
  --status completed \
  --dispatch subagent \
  --files "file1.go,file2.go" \
  --summary "What changed" \
  --commit "abc1234"
```

## Environment

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `COORDINATOR_URL` | No | `http://localhost:4000` | Coordinator API base URL |
| `COORDINATOR_TOKEN` | Yes | — | Bearer token for authentication |

## Repos Inheritance

If a node does not specify `repos`, it inherits from its parent. The root goal's repos are the union of all repos across the tree. This allows cross-repo projects to specify repos at the appropriate level.

## Dependencies

- Only between siblings (same parent) to maintain tree structure
- Use database IDs (`id` field) when creating dependencies, not human-readable IDs
- The `/ready` endpoint handles dependency resolution automatically

## GitHub Sync

The coordinator manages GitHub sync automatically. When tree or node state changes, the coordinator updates the guardian issue's progress section. No manual sync operation is needed from the goal-tree workflow.
