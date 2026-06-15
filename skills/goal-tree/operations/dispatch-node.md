# Dispatch Node Operation

Executes the chosen dispatch strategy for a node. Handles container dispatch via AC (default), tmux workspace sessions (escape hatch), or escalation to the user.

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `node` | Yes | The node to dispatch (includes db_id, node_id, title, etc.) |
| `decision` | Yes | Output from dispatch-decision (strategy + context) |
| `tree` | Yes | Full parsed goal tree (from coordinator) |
| `tree_id` | Yes | Coordinator tree ID |
| `project_dir` | Yes | Project directory path |
| `project_branch` | Yes | Project branch name |
| `context_depth` | No | Context depth from dispatch-decision: `lean`, `standard` (default), or `full`. Controls how much project context is included in the spec. Passed to `dispatch-container.sh --context-depth`. |
| `prior_failures` | No | List of prior failure telemetry records (populated on retry dispatches). Each entry contains: attempt_number, failure_status, failure_reason, parameter_change_applied. |
| `additional_prompt` | No | Extra context appended to DESIGN.md on retry (error details, approach hints). |

## Output

Dispatch-node returns immediately after initiating dispatch. The output is a `dispatch_initiated` record, not a result:

**Container dispatch** (default):
```
dispatch_initiated:
  node_id: "<node ID>"
  container_id: "<Docker container ID>"
  volume_name: "<Docker volume name>"
  dispatch_method: "container"
```

**Tmux dispatch** (escape hatch):
```
dispatch_initiated:
  node_id: "<node ID>"
  session_name: "<tmux session name>"
  workspace_path: "<path to node workspace>"
  dispatch_method: "tmux"
```

The full `dispatch_result` (status, files_modified, commits, etc.) is populated later by execute-tree's monitoring loop when it detects completion. See execute-tree step 5 for the result schema.

For escalations, the output is immediate:

```
dispatch_result:
  status: "escalated"
  node_id: "<node ID>"
  issues: "<escalation reason>"
  dispatch_method: "escalated"
```

## Layer Precondition

Dispatch-node only operates on **L0 leaf nodes**. If the node has children in the tree, it is L1 structure and should not be dispatched — return an error. See `references/layer-model.md`.

## Spec Content

Both container and tmux strategies need a DESIGN.md spec for the node. Build the spec content as:

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

> **Criteria format**: Write each criterion in canonical form — `- [ ] **AC-N**: <criterion> _(verify: <method>)_`, where `_(verify: <method>)_` is an optional one-line what-to-check hint (e.g. `_(verify: test output)_`, `_(verify: curl the endpoint)_`). Preserve any AC-N ids carried on the node; assign sequential ids only when the node has none. Each criterion must be specific enough for an LLM to judge pass/fail unambiguously. Use observable, verifiable statements (e.g., "endpoint returns 404 when resource not found") not vague directives (e.g., "improve error handling"). Criteria are evaluated post-completion by the parent session — see execute-tree step 4a.

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

If `prior_failures` is provided (retry dispatch), append the failure history — see Prior Failure History section below.

## Node Workspace Setup (Tmux Only)

Host workspace creation applies **only to tmux dispatch**. Container dispatch does not create host workspaces — AC manages Docker volumes (see Volume Lifecycle above).

```bash
skills/goal-tree/scripts/create-node-workspace.sh \
  "$PROJECT_DIR" "$NODE_ID" "$PROJECT_BRANCH" "$OWNER" <repo1> [repo2 ...]
```

The script creates both CLAUDE.md (operational context) and DESIGN.md (placeholder). After workspace creation, populate DESIGN.md with the spec content above.

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

## Permission Pre-Configuration (Tmux Only)

After workspace creation (tmux dispatch), generate `.claude/settings.json` with repo-appropriate permissions. This eliminates >90% of permission prompts that break child session flow.

Key insight: permission patterns must match actual command strings children use, including `cd /path &&` prefixes and `MIX_ENV=test` prefixes.

```bash
SETTINGS_DIR="$WORKSPACE_PATH/.claude"
mkdir -p "$SETTINGS_DIR"

cat > "$SETTINGS_DIR/settings.json" <<'SETTINGS'
{
  "permissions": {
    "allow": [
      "Edit",
      "Write",
      "Bash(mix test:*)",
      "Bash(mix compile:*)",
      "Bash(mix deps*:*)",
      "Bash(mix format:*)",
      "Bash(mix ecto*:*)",
      "Bash(MIX_ENV=* mix:*)",
      "Bash(cd * && mix:*)",
      "Bash(cd * && MIX_ENV=* mix:*)",
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(git push:*)",
      "Bash(git diff:*)",
      "Bash(git log:*)",
      "Bash(git status:*)",
      "Bash(mkdir:*)",
      "Bash(coord:*)",
      "Bash(gh pr:*)",
      "Bash(docker:*)"
    ]
  }
}
SETTINGS
```

The `create-workspace.sh` script (task-workflow) handles this via `settings.json.tmpl` — the template already includes base permissions. For tmux dispatch, the permissions above supplement the template defaults to cover Elixir-specific patterns.

If the workspace was created by `create-node-workspace.sh`, settings.json is already copied from the template. Merge the Elixir-specific patterns into the existing file rather than overwriting:

```bash
# If settings.json already exists (from create-workspace.sh), merge permissions
if [[ -f "$SETTINGS_DIR/settings.json" ]]; then
  # Add Elixir patterns to existing allow list
  jq '.permissions.allow += [
    "Bash(mix test:*)",
    "Bash(mix compile:*)",
    "Bash(mix deps*:*)",
    "Bash(mix format:*)",
    "Bash(mix ecto*:*)",
    "Bash(MIX_ENV=* mix:*)",
    "Bash(cd * && mix:*)",
    "Bash(cd * && MIX_ENV=* mix:*)"
  ] | .permissions.allow |= unique' "$SETTINGS_DIR/settings.json" > "$SETTINGS_DIR/settings.json.tmp" \
    && mv "$SETTINGS_DIR/settings.json.tmp" "$SETTINGS_DIR/settings.json"
fi
```

## Strategy Execution

### Container (Default)

The default execution strategy. Dispatches the node to AC, which manages the entire container lifecycle via Docker volumes. No host-directory workspace is created — all workspace state lives in a Docker volume.

#### Volume Lifecycle

The container dispatch uses a volume-based workspace model:

1. **Volume creation**: AC creates a Docker volume with `ac.*` labels (`ac.managed`, `ac.tree_id`, `ac.node_id`, `ac.role=workspace`) for identity and lifecycle tracking.
2. **Setup container**: A transient `alpine/git` container mounts the volume and performs:
   - Fresh `git clone` of each repo into `/workspace/<repo-name>`
   - Branch checkout (creates branch if it doesn't exist on remote)
   - DESIGN.md (spec content) written to `/workspace/DESIGN.md`
   - CLAUDE.md (operational context) written to `/workspace/CLAUDE.md`
3. **Editor container**: The main execution container (default: `ghcr.io/pfeff/ralph:latest`) mounts the volume at `/workspace` and runs the agent loop.
4. **Result extraction**: When the editor container exits, AC's `ResultExtractor` reads results from the volume — commits, PR URLs, plan completion state — and records them on the node.
5. **Volume cleanup**: After result extraction, the volume is removed. Failed dispatches retain volumes for debugging until explicitly cleaned up.

#### 1. Call `ac_node_update` action=dispatch

Use the AC MCP tool to dispatch the node:

```
ac_node_update:
  action: dispatch
  tree_id: ${TREE_ID}
  node_id: ${NODE_DB_ID}
  repos: [list of repo URLs]
  branch: "${PROJECT_BRANCH}/${NODE_ID}"
  spec_content: <DESIGN.md content built from Spec Content section above>
```

Alternatively, from a bash script, call `dispatch-container.sh` which sends the equivalent JSON-RPC request to `${COORDINATOR_URL}/mcp`:

```bash
skills/goal-tree/scripts/dispatch-container.sh <node-workspace-path> [--context-depth lean|standard|full] [--image <image>] [--dry-run]
```

The script reads DESIGN.md from the workspace, extracts repo remote URLs, and calls `ac_node_update(action="dispatch")` via the MCP endpoint. The `--context-depth` flag (from dispatch-decision's `context_depth` output) controls how much of DESIGN.md is passed as `spec_content`.

#### Output Streaming

Container dispatch automatically sets up incremental output streaming. During execution, `stream-output.sh` (started by `loop.sh`) tails the agent's iteration logs (`.ralph/iteration-*.jsonl`) and POSTs extracted assistant text to AC as heartbeat progress updates every 30 seconds.

This enables the LiveView dashboard to show real-time output for active container nodes without requiring `tmux attach` or manual monitoring. The streaming is best-effort — failures are silently ignored and don't affect the agent's execution.

Env vars required (injected by `dispatch.ex`):
- `AC_TREE_ID` — goal tree ID
- `AC_NODE_ID` — node ID string
- `COORDINATOR_URL` — AC base URL
- `COORDINATOR_TOKEN` — bearer token

Optional tuning:
- `STREAM_INTERVAL` — seconds between posts (default: 30)
- `STREAM_MAX_CHARS` — max characters per chunk (default: 4000)

#### 2. Capture dispatch response

AC returns immediately with container metadata:

```
dispatch_response:
  container_id: "<Docker container ID>"
  volume_name: "<Docker volume name>"
  status: "dispatched"
```

#### 3. Return

Dispatch-node returns immediately. The control session does not wait for the container to complete — monitoring happens in execute-tree's polling loop via `ac_node_query`.

```
dispatch_initiated:
  node_id: "<node ID>"
  container_id: "<Docker container ID>"
  volume_name: "<Docker volume name>"
  dispatch_method: "container"
```

### Tmux (Escape Hatch)

Used only when interactive human collaboration is required, operator explicitly requests tmux, or container dispatch is unavailable. Creates a host workspace, writes the spec, and starts a tmux session.

#### 1. Create Workspace (if not already done)

```bash
skills/goal-tree/scripts/create-node-workspace.sh \
  "$PROJECT_DIR" "$NODE_ID" "$PROJECT_BRANCH" "$OWNER" <repo1> [repo2 ...]
```

#### 2. Write DESIGN.md with Spec

Populate the node workspace's DESIGN.md with the spec content (see Spec Content section above).

#### 3. Configure Inbox Session ID

Append `CLAUDE_INBOX_SESSION_ID` to the workspace `.envrc` so the blocked-signal hook can identify this session:

```bash
echo "export CLAUDE_INBOX_SESSION_ID=\"$NODE_ID\"" >> "$WORKSPACE_PATH/.envrc"
```

This enables `permission-blocked-signal.sh` (wired via settings.json.tmpl) to fire inbox notifications when the session hits a permission prompt.

#### 4. Send Startup Command

Start the child session working on the task:

```bash
tmux send-keys -t "$SESSION_NAME" "claude /init-workspace" Enter
```

The child session picks up CLAUDE.md and DESIGN.md from the workspace, runs `/init-workspace` to decompose into tasks, and autonomously implements them.

#### 5. Return

Dispatch-node returns immediately after sending the startup command. The control session does not wait for the child to complete — monitoring happens in execute-tree's polling loop.

```
dispatch_initiated:
  node_id: "<node ID>"
  session_name: "<tmux session name>"
  workspace_path: "<path to node workspace>"
  dispatch_method: "tmux"
```

### Prior Failure History

If `prior_failures` is provided (retry dispatch), append the failure history to the spec content (DESIGN.md for tmux, spec_content for container):

```markdown
## Prior Failure History

This task has been attempted ${len(prior_failures)} time(s) previously.

### Attempt ${attempt.attempt_number}
- **Failure reason**: ${attempt.failure_reason}
- **Parameter change applied**: ${attempt.parameter_change_applied}

${additional_prompt}
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

Dispatch-node returns failures to execute-tree, which owns the retry loop (step 4). Since dispatched nodes run asynchronously, failures are detected during execute-tree's monitoring loop, not at dispatch time.

### Failure Detection

Failures are detected by execute-tree monitoring via:

**Container nodes**:
1. **Container exit**: `ac_node_query` action=active no longer lists the container — exited or crashed
2. **Coordinator status**: Node status updated to `blocked` or `failed` by the child agent
3. **Stall detection**: No progress observed across multiple monitoring cycles (via `ac_node_query`)

**Tmux nodes**:
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

```
ac_node_update(
  action="progress",
  tree_id=$TREE_ID,
  node_id="$NODE_ID",
  message="Deliverable: <PR URL or artifact path>. Advances: <parent goal title> → <root objective>.",
  artifacts=["<PR URL or artifact path>"]
)
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
- **Depends on**: dispatch-decision output, `ac_node_update` MCP tool (agent-coordinator MCP server), tmux (escape hatch only)
- **References**:
  - `task-workflow/references/error-classification.md` — error taxonomy
  - `task-workflow/references/retry-with-backoff.md` — backoff algorithm
  - `operations/branch-management.md` — node workspace creation
  - `operations/discuss-dispatch.md` — conversation-first dispatch pattern
  - Project-level `nodes/C.3/l1-review-process.md` — L1 review procedure that evaluates dispatch output
