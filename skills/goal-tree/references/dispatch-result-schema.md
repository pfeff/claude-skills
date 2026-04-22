# Dispatch Result Schema

Structured format returned by L0 agents upon task completion. Used by execute-tree (L1) to process outcomes, capture gaps, and advance the goal tree.

## Schema

```json
{
  "status": "completed | failed | blocked",
  "summary": "Human-readable summary of what was accomplished",
  "pr_url": "https://github.com/org/repo/pull/123",
  "files_modified": ["path/to/file1.md", "path/to/file2.md"],
  "test_result": "pass | fail | no_tests | skipped",
  "gaps": [
    {
      "title": "Short description of the gap",
      "description": "Detailed explanation of what was deferred or left incomplete",
      "severity": "minor | moderate | major",
      "suggested_parent": "D.3.6"
    }
  ]
}
```

## Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `status` | string | Yes | Completion status: `completed`, `failed`, or `blocked` |
| `summary` | string | Yes | What was accomplished or why it failed |
| `pr_url` | string | No | URL of the PR created by the agent |
| `files_modified` | array[string] | No | List of files changed |
| `test_result` | string | No | Test outcome: `pass`, `fail`, `no_tests`, `skipped` |
| `gaps` | array[gap] | No | Known gaps or deferred items discovered during execution |

## Gap Object

Each entry in the `gaps` array represents a known gap — work that was identified during execution but intentionally deferred.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | string | Yes | Imperative-form title for the gap (becomes the new node title) |
| `description` | string | Yes | What the gap is and why it was deferred |
| `severity` | string | Yes | Impact level: `minor`, `moderate`, or `major` |
| `suggested_parent` | string | No | Node ID under which to register the new node. Defaults to the completed node's parent. |

### Severity Levels

| Level | Meaning | Example |
|-------|---------|---------|
| `minor` | Cosmetic or low-impact deferral | "Docs not updated for new flag" |
| `moderate` | Functional gap with a workaround | "Edge case X throws unhandled error but happy path works" |
| `major` | Significant missing functionality | "Authentication bypass not addressed" |

## Where It's Produced

- **`/finish` skill** (step 3a): Prompts the agent for gaps before cutting the PR. Writes `dispatch_result.json` to the workspace root.
- **L0 agent completion**: Agent writes structured results to coordinator via `ac_node_update`.

## Where It's Consumed

- **`execute-tree.md` (step 5f)**: After a node completes and passes evaluation, checks for gaps in the dispatch result. Each gap is registered as a new pending node in the goal tree.
- **`finish.md` metrics**: Gap count is included in completion telemetry.

## Example

```json
{
  "status": "completed",
  "summary": "Implemented OAuth flow with Google and GitHub providers",
  "pr_url": "https://github.com/org/repo/pull/42",
  "files_modified": [
    "src/auth/oauth.ts",
    "src/auth/providers/google.ts",
    "src/auth/providers/github.ts",
    "tests/auth/oauth.test.ts"
  ],
  "test_result": "pass",
  "gaps": [
    {
      "title": "Add Microsoft OAuth provider",
      "description": "Microsoft provider was in scope but deferred due to complexity of their token refresh flow. Google and GitHub work end-to-end.",
      "severity": "moderate",
      "suggested_parent": "B.1"
    },
    {
      "title": "Update API docs for OAuth endpoints",
      "description": "New /auth/callback endpoints are functional but not documented in the API reference.",
      "severity": "minor"
    }
  ]
}
```
