# Dispatch Node Operation

Executes the chosen dispatch strategy for a node. Handles workspace session creation and startup via tmux, or escalation to the user.

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `node` | Yes | The node to dispatch (includes db_id, node_id, title, etc.) |
| `decision` | Yes | Output from dispatch-decision (strategy + context) |
| `tree` | Yes | Full parsed goal tree (from coordinator) |
| `tree_id` | Yes | Coordinator tree ID |
| `project_dir` | Yes | Project directory path |
| `project_branch` | Yes | Project branch name |
| `prior_failures` | No | List of prior failure telemetry records (populated on retry dispatches). Each entry contains: attempt_number, failure_status, failure_reason, parameter_change_applied. |
| `additional_prompt` | No | Extra context appended to DESIGN.md on retry (error details, approach hints). |

## Output

Dispatch-node returns immediately after sending the startup command. The output is a `dispatch_initiated` record, not a result:

```
dispatch_initiated:
  node_id: "<node ID>"
  session_name: "<tmux session name>"
  workspace_path: "<path to node workspace>"
  dispatch_method: "workspace-session"
```

The full `dispatch_result` (status, files_modified, commits, etc.) is populated later by execute-tree's monitoring loop when it detects session completion. See execute-tree step 5 for the result schema.

For escalations, the output is immediate:

```
dispatch_result:
  status: "escalated"
  node_id: "<node ID>"
  issues: "<escalation reason>"
  dispatch_method: "escalated"
```

## Node Workspace Setup

**Before any dispatch strategy**, create a node workspace with repo worktrees. This applies to all strategies.

```bash
skills/goal-tree/scripts/create-node-workspace.sh \
  "$PROJECT_DIR" "$NODE_ID" "$PROJECT_BRANCH" "$OWNER" <repo1> [repo2 ...]
```

The script creates both CLAUDE.md (operational context) and DESIGN.md (placeholder). After workspace creation, populate DESIGN.md with actual node content using the Edit tool:

```markdown
# ${NODE_ID}: ${NODE_TITLE}

## Task Information

- **Node ID**: ${NODE_ID}
- **Project**: ${ROOT_GOAL_TITLE}
- **Branch**: ${PROJECT_BRANCH}/${NODE_ID}

## Requirements

${NODE_DESCRIPTION}

## Acceptance Criteria

${ACCEPTANCE_CRITERIA_AS_CHECKLIST}

> **Criteria format**: Each criterion must be specific enough for an LLM to judge pass/fail unambiguously. Use observable, verifiable statements (e.g., "endpoint returns 404 when resource not found") not vague directives (e.g., "improve error handling"). Criteria are evaluated post-completion by the parent session — see execute-tree step 4a.

## Project Context

- **Parent goal**: ${PARENT_GOAL_TITLE}
- **Root objective**: ${ROOT_GOAL_TITLE}
- **Integration branch**: ${PROJECT_BRANCH}

## Coordinator

- **Tree ID**: ${TREE_ID}
- **Node DB ID**: ${NODE_DB_ID}
- **API**: ${COORDINATOR_URL}

## Design Decisions

[To be documented during implementation]
```

The workspace creation script automatically configures **GitHub App authentication** for child sessions:
- Worktree remotes are switched from SSH to HTTPS
- Git credential helper uses `generate-app-token.sh` for push auth
- `GH_TOKEN` is set in `.envrc` via the same token script
- Child sessions authenticate as the GitHub App — they can push and create PRs but **cannot approve or merge**

**Token refresh**: GitHub App tokens expire after ~1 hour. When `gh` CLI returns auth errors, run:

```bash
refresh-gh-token
```

This shell function is defined in `.envrc` by `configure-child-auth.sh` and available in any direnv-loaded session. If the function is unavailable, source the script directly:

```bash
. /path/to/skills/goal-tree/scripts/refresh-gh-token.sh
```

See `operations/branch-management.md` for the canonical workspace creation operation.

## Assumption Boundary Protocol (DD-22)

During dispatch, the agent may encounter something unexpected — a missing API, a contradictory schema, an ambiguous requirement. These are **assumption boundaries**: moments where the agent is about to act on an uncertain belief.

**Recognition heuristic** — surface to the user when:
1. **Something expected is missing**: An endpoint, table, config, or interface that the task spec implies should exist but doesn't
2. **Something contradicts the spec**: Code behavior differs from what the acceptance criteria or design decisions describe
3. **A design decision is being made implicitly**: Adding a new schema, choosing a data format, selecting an integration pattern — anything that constrains future work

**How to surface:**

```
## Assumption Check

**Node**: <id>. <title>
**Observation**: <what was found/not found>
**Assumption**: <what the agent is about to do>
**Risk if wrong**: <what rework or momentum cost this creates>

Proceed with this assumption, or redirect?
```

**When to skip**: If the assumption is low-risk (cosmetic, easily reversible, local to one file) and doesn't constrain other nodes, proceed without surfacing. The heuristic is: **would the human want to know this before I build on top of it?**

## Strategy Execution

### Workspace Session

The default execution strategy. Creates a workspace, writes the spec, and starts a tmux session that runs autonomously.

#### 1. Create Workspace (if not already done)

```bash
skills/goal-tree/scripts/create-node-workspace.sh \
  "$PROJECT_DIR" "$NODE_ID" "$PROJECT_BRANCH" "$OWNER" <repo1> [repo2 ...]
```

#### 2. Write DESIGN.md with Spec

Populate the node workspace's DESIGN.md with the full task spec (see Node Workspace Setup above).

If `prior_failures` is provided (retry dispatch), append the failure history to DESIGN.md:

```markdown
## Prior Failure History

This task has been attempted ${len(prior_failures)} time(s) previously.

### Attempt ${attempt.attempt_number}
- **Failure reason**: ${attempt.failure_reason}
- **Parameter change applied**: ${attempt.parameter_change_applied}

${additional_prompt}
```

#### 3. Send Startup Command

Start the child session working on the task:

```bash
tmux send-keys -t "$SESSION_NAME" "claude /init-workspace" Enter
```

The child session picks up CLAUDE.md and DESIGN.md from the workspace, runs `/init-workspace` to decompose into tasks, and autonomously implements them.

#### 4. Return

Dispatch-node returns immediately after sending the startup command. The control session does not wait for the child to complete — monitoring happens in execute-tree's polling loop.

```
dispatch_initiated:
  node_id: "<node ID>"
  session_name: "<tmux session name>"
  workspace_path: "<path to node workspace>"
  dispatch_method: "workspace-session"
```

### Escalate

Pause execution and surface the decision to the user.

```
## Escalation Required

**Node**: ${NODE_ID}. ${NODE_TITLE}
**Reason**: ${DECISION.CONTEXT.QUESTION}

${DECISION.CONTEXT.OPTIONS if present}

Please provide guidance. The goal tree execution will resume after your input.
```

Return:
```
dispatch_result:
  status: "escalated"
  node_id: "<node ID>"
  issues: "<escalation reason>"
  dispatch_method: "escalated"
```

## tmux Control Patterns

These are the primary interface for interacting with child sessions.

**Session name sanitization**: `$SESSION_NAME` is derived from node IDs and titles. Before use in any tmux command, sanitize to `[a-zA-Z0-9_-]` only — strip or replace shell metacharacters, spaces, and tmux special characters. This prevents command injection via crafted node titles.

```bash
# Send command to child session
tmux send-keys -t "$SESSION_NAME" "command here" Enter

# Send literal text (no key interpretation — use for content from external sources)
tmux send-keys -l -t "$SESSION_NAME" "literal text here"

# Read child session output (recent screen)
tmux capture-pane -t "$SESSION_NAME" -p

# Read scrollback (more history)
tmux capture-pane -t "$SESSION_NAME" -p -S -100

# Check if session is alive
tmux has-session -t "$SESSION_NAME" 2>/dev/null
```

**When to use `-l` (literal mode)**: Use `send-keys -l` when the content originates from external data (coordinator fields, error messages, evaluation feedback). Use plain `send-keys` only for known command strings like `"claude /init-workspace" Enter`.

## Failure Handling

Dispatch-node returns failures to execute-tree, which owns the retry loop (step 4). Since workspace sessions run asynchronously, failures are detected during execute-tree's monitoring loop, not at dispatch time.

### Failure Detection

Failures are detected by execute-tree monitoring via:
1. **Session death**: `tmux has-session` returns non-zero — session crashed or exited
2. **Coordinator status**: Node status updated to `blocked` or `failed` by the child session
3. **Stall detection**: No progress observed across multiple monitoring cycles

### Failure Telemetry

Each dispatch failure emits a structured telemetry record (see execute-tree step 4 "Failure Telemetry Record" for schema). Dispatch-node populates the `dispatch_method` field; execute-tree adds the retry-loop fields (`attempt_number`, `parameter_change_applied`, `parameter_change_strategy`).

### Error Classification

For transient errors during dispatch setup (workspace creation, tmux issues):

1. Load `task-workflow/references/error-classification.md`
2. Classify the error
3. If transient: retry with backoff per `task-workflow/references/retry-with-backoff.md`
4. If permanent: return failure immediately

## Post-Implementation Lifecycle

After a node's implementation is complete (detected by execute-tree monitoring), the control session drives the full landing sequence. Do not stop after committing — continue through the entire pipeline:

### 1. Commit
Stage and commit changes in the node workspace using the git skill.

### 2. Push
Push the node branch to the remote.

### 3. Create PR
Read `.github/PULL_REQUEST_TEMPLATE.md` from the repo, then create the PR. Include the goal-tree node reference on the `**Issue:**` line (e.g., `AC tree 3 node D` or `Closes owner/repo#N` if a GitHub issue exists).

### 4. Request Review
Request review from the operator. Child sessions **do not** self-review or approve PRs.

```bash
gh pr edit <PR_NUMBER> --repo <REPO> --add-reviewer <OPERATOR_GITHUB_USERNAME>
```

For feature, refactor, or multi-file changes, also run `/review <PR_NUMBER>` to post automated review comments on the PR.

### 5. Traceability Update
Link the deliverable back to the strategic objective. Record traceability context alongside the node result (execute-tree step 4 handles the primary `add-result` with status; this appends the strategic link):

```bash
coord node add-result $TREE_ID $NODE_DB_ID \
  --summary "Deliverable: <PR URL or artifact path>. Advances: <parent goal title> → <root objective>."
```

Include the traceability chain: what was delivered, which goal it serves, and how it connects to the mission. For non-code deliverables (research, documents, applications), record the artifact location and its strategic link.

### 6. Lessons-Learned Capture
Review child session output for lessons worth capturing. Look for:

- **Process friction**: steps that took longer than expected, tooling gaps, unclear specs
- **Reusable patterns**: approaches that worked well and should be repeated
- **Assumption mismatches**: places where the plan diverged from reality

If any lessons are worth preserving, save them to the project's memory:

```
Write: ${PROJECT_DIR}/memory/lessons_<NODE_ID>.md
---
name: lessons-<NODE_ID>
description: Lessons from implementing <NODE_TITLE>
type: project
---

<lesson content>

**Why:** <what caused this>
**How to apply:** <when this lesson is relevant>
```

If nothing notable occurred, skip — do not generate boilerplate lessons.

### 7. Notify and Stop
Child sessions **stop here**. Do not merge, do not enable auto-merge. The operator reviews, approves, and merges.

If running as a child workspace session, notify the parent's inbox:
```bash
~/.claude/hooks/inbox-write.sh workspace-session "<node_id>" "<node_title>: PR ready for review"
```

> **Review gate**: The `PR Review` CI check requires `APPROVED` state. Child sessions (GitHub App) cannot self-approve. The operator must `gh pr review --approve` before the PR can merge.

### 8. Post-Merge (operator or parent session only)
After the operator approves and merges:

- **Deploy** (when applicable): If the node targets a running service (e.g., AC), upgrade the service after merge.
- **Update Coordinator**: Report the result to the coordinator and mark the node complete. This happens in execute-tree step 4.

**Key principle**: Child sessions drive the pipeline up to PR creation and review request, then yield control. The operator holds the merge gate.

## Integration Points

- **Called by**: execute-tree (step 3)
- **Depends on**: dispatch-decision output, `coord` CLI, tmux
- **References**:
  - `task-workflow/references/error-classification.md` — error taxonomy
  - `task-workflow/references/retry-with-backoff.md` — backoff algorithm
  - `operations/branch-management.md` — node workspace creation
  - `operations/discuss-dispatch.md` — conversation-first dispatch pattern
