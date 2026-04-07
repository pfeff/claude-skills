# GOAL.md Format Specification

File-based persistence format for goal trees. Provides human-readable AND machine-parseable representation equivalent to the coordinator data model.

## Document Structure

```
---
YAML frontmatter (tree metadata)
---

# Title (root goal)

Context paragraph

## A. First top-level goal
### A.1 First sub-task
### A.2 Second sub-task

## B. Second top-level goal
...

---
## Results Log
```

## YAML Frontmatter

Required tree-level metadata at document start:

```yaml
---
title: "Project title"
guardian_issue: "owner/repo#123"
repos:
  - repo-1
  - repo-2
status: active
---
```

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `title` | Yes | string | Root goal title |
| `guardian_issue` | No | string | Issue reference (owner/repo#123) |
| `repos` | Yes | array | Default repositories for all nodes |
| `status` | Yes | string | Tree status: `active`, `completed`, `archived` |

## Node Structure

Each node is a markdown heading with structured content.

### Heading Format

```markdown
## A. Goal title [status: pending]
```

Components:
1. **Heading level**: Depth indicates hierarchy (## = top-level, ### = child, etc.)
2. **Node ID**: Letter or dotted notation (A, A.1, A.1.2)
3. **Title**: Short description
4. **Status tag**: `[status: <value>]` at end of heading

### Node Body

```markdown
## A. Implement authentication [status: in_progress]

**repos**: api-gateway, user-service
**depends_on**: B.1

Description paragraph explaining the goal or task.
Can span multiple lines.

**Acceptance Criteria**:
- [ ] Criterion one
- [x] Criterion two (completed)
- [ ] Criterion three

**result**: Summary of what was accomplished (only present when completed)
```

### Node Properties

| Property | Location | Format | Description |
|----------|----------|--------|-------------|
| `id` | Heading | Before title | Dotted hierarchy (A, A.1, A.1.2) |
| `title` | Heading | After ID | Short description |
| `status` | Heading | `[status: value]` | Node state |
| `repos` | Body | `**repos**: a, b` | Comma-separated list |
| `depends_on` | Body | `**depends_on**: A.1, A.2` | Sibling dependencies |
| `jira_ref` | Body | `**jira_ref**: PROJ-123` | Linked Jira issue key (optional) |
| `description` | Body | Paragraph text | Detailed description |
| `criteria` | Body | Checkbox list | Acceptance criteria |
| `result` | Body | `**result**: text` | Outcome summary |

### Status Values

| Status | Meaning |
|--------|---------|
| `pending` | Not yet started, waiting for dispatch |
| `in_progress` | Currently being worked on |
| `completed` | All criteria met / all children done |
| `blocked` | External dependency prevents progress |
| `skipped` | Stuck detection triggered, deferred |

## Hierarchy Rules

1. **Heading levels map to tree depth**:
   - `##` → Top-level goals (A, B, C)
   - `###` → First-level children (A.1, B.2)
   - `####` → Second-level children (A.1.1, B.2.3)

2. **Parent-child relationship** is determined by:
   - Consecutive headings where child level = parent level + 1
   - Child ID prefix matches parent ID

3. **Node type** is structural:
   - **Goal**: Has child headings (non-leaf)
   - **Task**: No child headings (leaf)

## Dependencies

Dependencies use `**depends_on**` with comma-separated sibling node IDs:

```markdown
### A.2 User CRUD [status: pending]

**depends_on**: A.1

Create user management endpoints.
```

Rules:
- Dependencies must be siblings (same parent)
- Use human-readable IDs, not database IDs
- Multiple dependencies: `**depends_on**: A.1, A.3`

## Repos Inheritance

If a node omits `**repos**`, it inherits from its parent:

```markdown
## A. Backend API [status: pending]

**repos**: api-service

### A.1 Auth middleware [status: pending]

(inherits repos: api-service)

### A.2 Database layer [status: pending]

**repos**: api-service, db-migrations

(overrides with explicit list)
```

## Results Log

Append-only log at document end, separated by horizontal rule:

```markdown
---
## Results Log

### A.1 Auth middleware
- **Status**: completed
- **Dispatch**: subagent
- **Files**: middleware/auth.go, middleware/auth_test.go
- **Commit**: abc1234
- **Summary**: Added JWT validation middleware with signature and expiry checks.
- **Completed**: 2024-01-15T10:30:00Z

### A.2 User CRUD
- **Status**: skipped
- **Dispatch**: inline
- **Reason**: Turn budget exceeded after 3 attempts
- **Skipped**: 2024-01-15T11:45:00Z
```

Results Log entries are immutable — new entries are appended, never modified.

## Complete Example

```markdown
---
title: "Add OAuth Authentication"
guardian_issue: "acme/api#42"
repos:
  - api-service
  - web-frontend
status: active
---

# Add OAuth Authentication

Enable users to sign in with Google and GitHub OAuth providers.
This replaces the legacy username/password system.

## A. Backend API [status: in_progress]

**repos**: api-service

Implement OAuth endpoints and token management.

### A.1 Auth middleware [status: completed]

Add JWT validation middleware for protected routes.

**Acceptance Criteria**:
- [x] Validates JWT signature
- [x] Checks token expiry
- [x] Returns 401 for invalid tokens

**result**: Added JWTAuthMiddleware with full RS256 validation.

### A.2 OAuth endpoints [status: pending]

**depends_on**: A.1

Implement /auth/google and /auth/github callback handlers.

**Acceptance Criteria**:
- [ ] Google OAuth flow works end-to-end
- [ ] GitHub OAuth flow works end-to-end
- [ ] Tokens stored securely in database

### A.3 Token refresh [status: pending]

**depends_on**: A.1

Implement refresh token rotation.

**Acceptance Criteria**:
- [ ] Refresh endpoint issues new access token
- [ ] Old refresh tokens are invalidated

## B. Frontend Integration [status: pending]

**repos**: web-frontend
**depends_on**: A

Add OAuth buttons and handle authentication state.

### B.1 Login page [status: pending]

Add Google and GitHub sign-in buttons.

**Acceptance Criteria**:
- [ ] Buttons redirect to OAuth provider
- [ ] Callback updates auth state

### B.2 Auth state management [status: pending]

**depends_on**: B.1

Store and refresh tokens in frontend.

**Acceptance Criteria**:
- [ ] Token stored in secure cookie
- [ ] Auto-refresh before expiry

---
## Results Log

### A.1 Auth middleware
- **Status**: completed
- **Dispatch**: subagent
- **Files**: middleware/auth.go, middleware/auth_test.go
- **Commit**: abc1234
- **Summary**: Added JWT validation middleware with RS256 signature verification, expiry checking, and proper 401 responses.
- **Completed**: 2024-01-15T10:30:00Z
```

## Parsing Algorithm

### 1. Extract Frontmatter

```
Match: /^---\n(.*?)\n---/s
Parse: YAML content
Result: tree metadata (title, guardian_issue, repos, status)
```

### 2. Parse Node Headings

```
Pattern: /^(#{2,6})\s+([A-Z](?:\.\d+)*)\.\s+(.+?)\s+\[status:\s*(\w+)\]/

Groups:
  1: Heading markers (## = level 2)
  2: Node ID (A, A.1, A.1.2)
  3: Title
  4: Status

Level mapping:
  ## (2) → depth 0 (top-level)
  ### (3) → depth 1
  #### (4) → depth 2
```

### 3. Parse Node Body

For each node, extract body content until next heading or document end:

```
repos:      /^\*\*repos\*\*:\s*(.+)$/m → split by comma, trim
depends_on: /^\*\*depends_on\*\*:\s*(.+)$/m → split by comma, trim
jira_ref:   /^\*\*jira_ref\*\*:\s*(\S+)$/m → capture issue key
result:     /^\*\*result\*\*:\s*(.+)$/m → capture text
criteria:   /^- \[([ x])\] (.+)$/gm → list of {checked, text}
description: remaining paragraph text (not matching above patterns)
```

### 4. Build Tree Structure

```python
def build_tree(nodes):
    root = []
    stack = [(root, -1)]  # (children list, depth)

    for node in nodes:
        # Pop stack until we find the parent level
        while stack[-1][1] >= node.depth:
            stack.pop()

        # Add node to current parent's children
        stack[-1][0].append(node)

        # Push this node as potential parent
        stack.append((node.children, node.depth))

    return root
```

### 5. Resolve Repos Inheritance

```python
def resolve_repos(node, parent_repos):
    if not node.repos:
        node.repos = parent_repos
    for child in node.children:
        resolve_repos(child, node.repos)
```

## Serialization Algorithm

### 1. Write Frontmatter

```yaml
---
title: "{tree.title}"
guardian_issue: "{tree.guardian_issue}"
repos:
{for repo in tree.repos}
  - {repo}
{endfor}
status: {tree.status}
---
```

### 2. Write Root Context

```markdown
# {tree.title}

{tree.context}
```

### 3. Write Nodes Recursively

```python
def write_node(node, depth):
    level = '#' * (depth + 2)  # ## for depth 0

    # Heading
    print(f"{level} {node.id}. {node.title} [status: {node.status}]")
    print()

    # Optional properties
    if node.repos and node.repos != parent_repos:
        print(f"**repos**: {', '.join(node.repos)}")
    if node.depends_on:
        print(f"**depends_on**: {', '.join(node.depends_on)}")
    if node.jira_ref:
        print(f"**jira_ref**: {node.jira_ref}")
    print()

    # Description
    if node.description:
        print(node.description)
        print()

    # Acceptance criteria
    if node.criteria:
        print("**Acceptance Criteria**:")
        for c in node.criteria:
            mark = 'x' if c.checked else ' '
            print(f"- [{mark}] {c.text}")
        print()

    # Result
    if node.result:
        print(f"**result**: {node.result}")
        print()

    # Children
    for child in node.children:
        write_node(child, depth + 1)
```

### 4. Write Results Log

```markdown
---
## Results Log

{for entry in results_log}
### {entry.node_id} {entry.title}
- **Status**: {entry.status}
- **Dispatch**: {entry.dispatch_method}
{if entry.files}
- **Files**: {', '.join(entry.files)}
{endif}
{if entry.commit}
- **Commit**: {entry.commit}
{endif}
- **Summary**: {entry.summary}
- **{entry.status.title()}**: {entry.timestamp}

{endfor}
```

## Validation Rules

1. **Unique node IDs**: No duplicate IDs in document
2. **Valid ID format**: Must match `/^[A-Z](\.\d+)*$/`
3. **Parent existence**: Child ID prefix must match existing parent
4. **Sibling dependencies**: depends_on references must be siblings
5. **Valid status**: Must be one of: pending, in_progress, completed, blocked, skipped
6. **Frontmatter required**: Document must start with valid YAML frontmatter

## Compatibility Notes

### Coordinator Mapping

| GOAL.md | Coordinator API |
|---------|-----------------|
| YAML `title` | `tree.title` |
| YAML `guardian_issue` | `tree.guardian_issue_ref` |
| YAML `repos` | Default for root nodes |
| Heading node ID | `node.node_id` |
| `[status: x]` | `node.status` |
| `**repos**` | `node.repos` |
| `**depends_on**` | `node.dependencies` |
| `**jira_ref**` | `node.jira_ref` (external tracker link) |
| `**result**` | `node.result` |
| Criteria checkboxes | `node.criteria` |
| Results Log entries | `node_result` records |

### Migration

To migrate from coordinator to GOAL.md:
1. Query `coord tree show <tree-id>`
2. Serialize using the algorithm above
3. Write to GOAL.md in project workspace

To migrate from GOAL.md to coordinator:
1. Parse GOAL.md using the algorithm above
2. Create tree: `coord tree create`
3. Create nodes: `coord node create` for each parsed node
4. Add dependencies: `coord node add-dependency` for each depends_on

## Integration Points

- **parse-goal.md**: Implements the parsing algorithm
- **update-goal.md**: Implements atomic updates to GOAL.md
- **node-lifecycle.md**: Status transition rules apply to `[status: x]` tags
- **select-ready.md**: Uses parsed tree for ready node selection
