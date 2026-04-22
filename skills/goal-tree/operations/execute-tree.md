# Execute Tree Operation

Main orchestration loop for goal tree execution. Iterates: select ready nodes → decide dispatch strategy → dispatch (container or tmux) → monitor active nodes → collect results → update coordinator → repeat.

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `tree_id` | Yes | Coordinator tree ID |
| `project_dir` | Yes | Project directory path |
| `project_branch` | Yes | Project branch name |

## Purpose

Drives the goal tree from pending to complete. Handles parallel dispatch of independent nodes via containers (default) or tmux (escape hatch), asynchronous monitoring via AC MCP and/or tmux, result collection, failure recovery, and stuck detection. Stops when all nodes are complete, all remaining are blocked/skipped, or an unrecoverable error occurs.

## Layer Context

Execute-tree operates as the **L1 control loop**. It dispatches **L0 leaf nodes** to containers (default) or tmux sessions (escape hatch) and evaluates their outputs. Non-leaf nodes (L1 structure) are never dispatched — their status is derived from children. See `references/layer-model.md` for the full layer model.

## Protocol Requirements

These are mandatory — do not shortcut the pipeline.

1. **Every node goes through the full pipeline.** You MUST run select-ready → dispatch-decision → dispatch-node for each node. Do not implement tasks directly without going through dispatch-decision first.
2. **Parallel dispatch is the default.** When select-ready returns multiple independent nodes, dispatch all of them (container or tmux) in a single pass. Sequential dispatch of independent nodes is a protocol violation.
3. **Planning-workflow is a gate, not a suggestion.** Every dispatched node must run planning-workflow before implementation. Child sessions handle this via `/init-workspace` which triggers the planning pipeline.

## Entry Guard

Before entering the loop:

### 1. Query Goal Tree

```
ac_node_query(action="get", tree_id=$TREE_ID)
```

Parse the response to get the full tree state.

### 2. Check Preconditions

| Condition | Action |
|-----------|--------|
| No nodes in tree | Output "Empty goal tree — nothing to execute." and stop |
| All nodes completed | Output completion summary and hand off to synthesize |
| Any node in_progress | Resume: treat in_progress as ready (it wasn't completed last session) |
| Pending nodes exist | Enter loop |
| All remaining nodes blocked/skipped | Output "All remaining nodes are blocked or skipped." and stop |

### 3. Initialize State

```
skipped_set = {}           # node IDs skipped by stuck detection
completed_nodes = []       # list of {id, title, commits}
active_nodes = {}          # node_id → {node, dispatch_method, dispatch_time, ...strategy-specific fields}
                           #   container: {container_id, volume_name}
                           #   tmux: {session_name, workspace_path}
total_dispatches = 0       # total dispatch attempts
max_retries = 3            # max retry attempts per node before escalation
failure_telemetry = {}     # node_id → [list of attempt records]
```

## Loop Body

Repeat steps 1-6 until termination.

### 1. Select Ready Nodes

```
ac_node_query(action="ready", tree_id=$TREE_ID)
```

Parse the response to get ready nodes, then group for parallel dispatch per `operations/select-ready.md`.

| Batch Result | Action |
|-------------|--------|
| Non-empty batch | Proceed to step 2 |
| Empty, reason: "complete", **bounded** | Go to Termination (step 7) |
| Empty, reason: "complete", **open-ended** | Auto-continue via `operations/next-cycle.md` |
| Empty, reason: "blocked" | Go to Termination with blocked summary |
| Empty, reason: "all_skipped" | Go to Termination with skipped summary |

### 2. Dispatch Decisions

For each node in the ready batch:

```
Load: operations/dispatch-decision.md

decisions = []
for node in ready_batch:
  decision = dispatch_decision(node, tree, results_log)
  decisions.append((node, decision))
```

### 2b. Dispatch Checkpoint

Checkpoint behavior is determined by autonomy tier (see `dispatch-decision.md`):

| Batch composition | Checkpoint |
|-------------------|------------|
| All Tier 1 (read-only) | **Skip** — auto-dispatch silently |
| All Tier 2 (code with spec) | **Skip** — auto-dispatch, checkpoint comes post-completion |
| Any Tier 3 (strategic/ambiguous) | **Present** escalations to user before dispatching |
| Mixed Tier 1+2 | **Skip** — auto-dispatch all |

When presenting a checkpoint (Tier 3 in batch):

```
## Dispatch Round <N>

| Node | Strategy | Tier | Reason |
|------|----------|------|--------|
| <id>. <title> | escalate | 3 | <question for user> |
| <id>. <title> | container | 1 | <rationale> (auto) |

Tier 1/2 nodes will auto-dispatch. Need your input on the Tier 3 items above.
```

Tier 1 and 2 nodes in a mixed batch dispatch immediately — don't hold them waiting for Tier 3 resolution.

### 3. Dispatch Nodes

Group decisions by strategy and dispatch:

```
Load: operations/dispatch-node.md

# Separate by dispatch type
container_nodes = [(n, d) for n, d in decisions if d.strategy == "container"]
tmux_nodes = [(n, d) for n, d in decisions if d.strategy == "tmux"]
escalate_nodes = [(n, d) for n, d in decisions if d.strategy == "escalate"]
discuss_nodes = [(n, d) for n, d in decisions if d.strategy == "discuss-dispatch"]
```

#### 3a. Handle Escalations First

If any nodes need escalation, present them to the user before dispatching others:

```
for node, decision in escalate_nodes:
  ac_node_update(action="blocked", tree_id=$TREE_ID, node_id="$NODE_ID", message="Escalated to user")
  present escalation to user
```

If **all** nodes in the batch are escalations, pause the loop.

#### 3b. Dispatch Container Nodes (Default)

For each container node:

1. Call `ac_node_update` action=dispatch (AC handles volume, clone, spec, container)
2. Track in `active_nodes`

```
for node, decision in container_nodes:
  ac_node_update(action="progress", tree_id=$TREE_ID, node_id="$NODE_ID", message="Dispatching")

  # dispatch-node calls ac_node_update action=dispatch
  dispatch_result = dispatch_node(node, decision)

  active_nodes[node.id] = {
    node: node,
    dispatch_method: "container",
    container_id: dispatch_result.container_id,
    volume_name: dispatch_result.volume_name,
    dispatch_time: now(),
    monitoring_cycles: 0
  }

total_dispatches += len(container_nodes)
```

All container dispatches happen in parallel — AC handles each independently.

#### 3b-alt. Dispatch Tmux Nodes (Escape Hatch)

For each tmux node:

1. Create host workspace (if not already created)
2. Write DESIGN.md with spec
3. Send startup command to tmux session
4. Track in `active_nodes`

```
for node, decision in tmux_nodes:
  ac_node_update(action="progress", tree_id=$TREE_ID, node_id="$NODE_ID", message="Dispatching")

  # dispatch-node handles workspace creation + DESIGN.md + tmux send-keys
  dispatch_result = dispatch_node(node, decision)

  active_nodes[node.id] = {
    node: node,
    dispatch_method: "tmux",
    session_name: dispatch_result.session_name,
    workspace_path: dispatch_result.workspace_path,
    dispatch_time: now(),
    monitoring_cycles: 0
  }

total_dispatches += len(tmux_nodes)
```

#### 3c. Handle Discuss-Dispatch Nodes

For nodes that need conversation before dispatch:

```
for node, decision in discuss_nodes:
  Load: operations/discuss-dispatch.md
  # Follow the discuss-dispatch lifecycle
```

### 4. Monitor Active Nodes

Active monitoring loop for dispatched nodes. Each poll cycle performs four substeps: status check, permission servicing, PR detection with auto-review, and stuck detection.

#### Monitoring Loop

```
while active_nodes is not empty:
  for node_id, node_info in active_nodes:

    # Branch on dispatch method
    if node_info.dispatch_method == "container":
      monitor_container_node(node_id, node_info)
    elif node_info.dispatch_method == "tmux":
      monitor_tmux_node(node_id, node_info)

  # Wait before next poll cycle
  sleep 30  # adjust based on expected task duration
```

#### 4a. Monitor Active Nodes (Status Check)

For each active node, check current status:

**Container dispatch**: Query AC for node heartbeats, check container status.

```
function monitor_container_node(node_id, node_info):
  # 1. Query AC for active containers
  active = ac_node_query(action="active", tree_id=TREE_ID)

  container_alive = node_info.container_id in active.containers

  if not container_alive:
    handle_container_exit(node_id, node_info)
    return

  # 2. Check coordinator for status updates
  node_status = ac_node_query(action="get", tree_id=$TREE_ID, node_id="$NODE_ID")

  # 3. Detect completion
  if node_status == "completed":
    collect_result(node_id, node_info)
    active_nodes.remove(node_id)
    return

  # 4. Check for PR (step 4c)
  check_for_pr(node_id, node_info)

  # 5. Detect stall (step 4d)
  node_info.monitoring_cycles += 1
  if node_info.monitoring_cycles > STALL_THRESHOLD:
    handle_stall(node_id, node_info)
```

**Tmux dispatch**: Capture pane output, check for permission prompts and completion signals.

```
function monitor_tmux_node(node_id, node_info):
  session_name = node_info.session_name

  # 1. Check if session is alive
  tmux has-session -t "$SESSION_NAME" 2>/dev/null
  if not alive:
    handle_session_death(node_id, node_info)
    return

  # 2. Read recent output
  output = tmux capture-pane -t "$SESSION_NAME" -p -S -50

  # 3. Check coordinator for status updates
  node_status = ac_node_query(action="get", tree_id=$TREE_ID, node_id="$NODE_ID")

  # 4. Detect completion
  if node_status == "completed":
    collect_result(node_id, node_info)
    active_nodes.remove(node_id)
    return

  # 5. Service permission prompts (step 4b)
  service_permission_prompts(node_id, node_info, output)

  # 6. Detect need for intervention
  if output contains "Assumption Check" or "Escalation Required" or "blocked":
    intervene(node_id, node_info, output)

  # 7. Check for PR (step 4c)
  check_for_pr(node_id, node_info)

  # 8. Detect stall (step 4d)
  node_info.monitoring_cycles += 1
  if node_info.monitoring_cycles > STALL_THRESHOLD:
    handle_stall(node_id, node_info)
```

**MCP notifications**: When available, the `node_updated` SSE stream from AC supplements polling. The control session holds the stream open and receives push notifications when node status changes. This reduces polling latency for container nodes but does not replace the polling loop (SSE connections can drop).

```
# SSE notification handler (supplements polling, does not replace it)
on node_updated(event):
  if event.node_id in active_nodes:
    if event.status == "completed":
      collect_result(event.node_id, active_nodes[event.node_id])
      active_nodes.remove(event.node_id)
```

#### 4b. Service Permission Prompts (Tmux Only)

If a child session is blocked on a permission prompt, the L1 control session can unblock it:

```
function service_permission_prompts(node_id, node_info, output):
  # Detect permission prompt patterns in pane output
  if output contains "Allow" or "permission" or "approve":
    # Read the command being requested
    command_requested = extract_permission_command(output)

    # Evaluate safety: is this command aligned with the node's objective?
    if command_is_safe(command_requested, node_info.node):
      # Approve by pressing 'y' or sending the approval key
      tmux send-keys -t "$SESSION_NAME" "y" Enter
      log("Approved permission for $NODE_ID: $command_requested")
    else:
      # Reject and send corrective guidance
      tmux send-keys -t "$SESSION_NAME" "n" Enter
      tmux send-keys -l -t "$SESSION_NAME" "Command rejected: $command_requested is not aligned with task objective."
      tmux send-keys -t "$SESSION_NAME" Enter
      log("Rejected permission for $NODE_ID: $command_requested")
```

Safe command heuristics:
- **Allow**: `mix test`, `mix compile`, `mix deps.get`, `mix format`, `git add/commit/push/diff/log/status`, `mkdir`, `docker`, `gh pr`, `coord`, file reads/writes within the workspace
- **Reject**: `rm -rf /`, `sudo`, commands targeting directories outside the workspace, network calls to unknown hosts
- **Escalate**: Ambiguous commands — log and skip (child retries or uses a different approach)

#### 4c. Detect PR Push

Check if the child has pushed commits or created a PR:

```
function check_for_pr(node_id, node_info):
  node = node_info.node
  branch = node.branch  # e.g., "autoresearch/C.3.27/D.1"

  # Check for open PRs on this branch
  pr_json = gh pr list --repo $REPO --head $BRANCH --json number,state --jq '.[0]'

  if pr_json is not empty and pr_json.state == "OPEN":
    pr_number = pr_json.number

    # Load and execute the L1 review protocol
    Load: operations/l1-review.md

    review_result = l1_review(
      pr_number=pr_number,
      repo=$REPO,
      node_id=node_id,
      tree_id=$TREE_ID,
      workspace_path=node_info.workspace_path
    )

    if review_result.verdict == "APPROVE":
      # Merge, deploy if needed, mark complete
      # l1-review.md handles merge + deploy + coordinator update
      active_nodes.remove(node_id)
      completed_nodes.append(node)

      # Auto-continue: go to step 1 (select next ready nodes)
      break  # exit monitoring loop to re-enter main loop

    elif review_result.verdict == "REJECT":
      # l1-review.md handles PR comment + coordinator blocked status
      # Child session should pick up feedback and retry
      log("PR #$pr_number rejected for $NODE_ID — child should address feedback")
```

#### 4d. Stuck Detection

If a node has been active for an extended period with no heartbeat or pane activity:

```
STUCK_MINUTES = 30
STUCK_RESPONSE_MINUTES = 5

function check_stuck(node_id, node_info):
  elapsed = now() - node_info.dispatch_time

  if elapsed > STUCK_MINUTES * 60 and node_info.stall_count >= STALL_THRESHOLD:
    if node_info.dispatch_method == "tmux":
      # Send a status check to the child
      tmux send-keys -l -t "$SESSION_NAME" "What is your current status? Are you blocked?"
      tmux send-keys -t "$SESSION_NAME" Enter
      node_info.stuck_check_sent = now()

    # If no response after 5 more minutes, escalate
    if node_info.stuck_check_sent and (now() - node_info.stuck_check_sent) > STUCK_RESPONSE_MINUTES * 60:
      handle_stuck(node, "no_response", "No response to status check after ${STUCK_RESPONSE_MINUTES} minutes")
```

#### Completion Detection

A node is complete when:

**Container nodes**:
- The coordinator node status is `completed` (child agent updated it via AC MCP)
- The `node_updated` SSE event arrives with status `completed`
- The container has exited and coordinator shows `completed`

**Tmux nodes**:
- The coordinator node status is `completed` (child session updated it)
- The tmux session has exited cleanly (check `tmux has-session`)
- The child session's inbox notification arrived

#### Intervention

**Tmux nodes**: The control session can send commands to child sessions. Use `send-keys -l` (literal mode) for all content derived from external data to prevent injection:

```bash
# Course correction (literal mode — content may contain special characters)
tmux send-keys -l -t "$SESSION_NAME" "The acceptance criteria require X, not Y. Adjust your approach."
tmux send-keys -t "$SESSION_NAME" Enter

# Provide missing context
tmux send-keys -l -t "$SESSION_NAME" "The API endpoint you need is at /api/v2/users, not /api/users."
tmux send-keys -t "$SESSION_NAME" Enter

# Answer a question the child session asked
tmux send-keys -l -t "$SESSION_NAME" "Use Redis, not Memcached."
tmux send-keys -t "$SESSION_NAME" Enter
```

**Container nodes**: Direct intervention is not available. Container agents are autonomous. If a container node needs course correction, the control session updates the coordinator node with feedback — the child agent reads it on its next AC query. For critical issues, the container can be killed and re-dispatched with an adjusted spec.

Intervention triggers:
- Child session output contains "Assumption Check" or "Escalation Required" (tmux only)
- Child session output contains repeated error patterns across monitoring cycles (tmux only)
- Coordinator node status changes to `blocked` (both container and tmux)
- Control session has new context relevant to the child's work

#### Container Exit Handling

When a container exits:

```
function handle_container_exit(node_id, node_info):
  node = node_info.node

  # Check if the node actually completed before the container exited
  node_status = ac_node_query(action="get", tree_id=$TREE_ID, node_id="$NODE_ID")

  if node_status == "completed":
    collect_result(node_id, node_info)
    return

  # Container exited without completing — treat as failure
  record_failure(node, "container_exit", "Container exited unexpectedly")
  active_nodes.remove(node_id)
```

#### Session Death Handling (Tmux)

When a tmux session dies unexpectedly:

```
function handle_session_death(node_id, node_info):
  node = node_info.node

  # Check if the node actually completed before the session died
  node_status = ac_node_query(action="get", tree_id=$TREE_ID, node_id="$NODE_ID")

  if node_status == "completed":
    collect_result(node_id, node_info)
    return

  # Session died without completing — treat as failure
  record_failure(node, "session_death", "tmux session exited unexpectedly")
  active_nodes.remove(node_id)
```

### 5. Process Results

For each completed session's results:

```
if result.status == "success":
  ac_node_update(
    action="complete",
    tree_id=$TREE_ID,
    node_id="$NODE_ID",
    message="<changes summary>",
    artifacts=["<file1>", "<file2>", "<commit hash>"]
  )

  completed_nodes.append(node)

elif result.status == "failure":
  retry_node(node, result)

elif result.status == "blocked":
  ac_node_update(action="blocked", tree_id=$TREE_ID, node_id="$NODE_ID")

elif result.status == "escalated":
  # Already handled in step 3a
  pass
```

#### Retry Loop (`retry_node`)

When a node fails, retry with parameter changes before escalating. This implements the design principle: "Failure is normal — rejection → parameter change + re-dispatch, not stop-and-ask."

```
function retry_node(node, initial_result):
  attempts = failure_telemetry.get(node.id, [])

  attempt = {
    attempt_number: len(attempts) + 1,
    failure_status: initial_result.status,
    failure_reason: initial_result.issues,
    dispatch_method: initial_result.dispatch_method,
    parameter_change: "initial dispatch"
  }
  attempts.append(attempt)
  failure_telemetry[node.id] = attempts

  if len(attempts) >= max_retries:
    escalate_with_failure_log(node, attempts)
    return

  # Re-dispatch with parameter change based on attempt count
  new_result = retry_dispatch(node, attempts)
  # New session created — will be picked up by monitoring loop
```

**Parameter change strategies** — applied in order across retry attempts:

| Attempt | Parameter Change | Description |
|---------|-----------------|-------------|
| 2 | Add error context | Append prior failure reason to DESIGN.md in the workspace |
| 3 | Alternative approach hint | Add instruction to use a different implementation strategy |

```
function retry_dispatch(node, attempts):
  n = len(attempts)
  last = attempts[-1]

  if n == 1:
    dispatch_node(node, {
      reason: "retry",
      prior_failures: attempts,
      additional_prompt: "Previous attempt failed: ${last.failure_reason}. Address this specific issue."
    })
  else:
    dispatch_node(node, {
      reason: "retry-alternative",
      prior_failures: attempts,
      additional_prompt: "The previous approach failed: ${last.failure_reason}. Try an alternative strategy."
    })

  # dispatch_node creates a new container or tmux session — monitoring loop picks it up
```

#### Failure Telemetry Record

Each failed attempt emits a structured telemetry record that N+1 can consume:

```
failure_telemetry_record:
  node_id: <node ID>
  attempt_number: <1-based>
  failure_status: "failure"
  failure_reason: <error description>
  parameter_change_applied: <description of what changed>
  outcome: "retry" | "escalated"
  timestamp: <ISO 8601>
```

These records are appended to the node's result in the coordinator:

```
ac_node_update(
  action="progress",
  tree_id=$TREE_ID,
  node_id="$NODE_ID",
  message="Attempt ${attempt_number}/${max_retries}: ${failure_reason}. Parameter change: ${parameter_change_applied}."
)
```

#### Escalation with Failure Log

When max_retries is exhausted, escalate with the full failure history attached:

```
function escalate_with_failure_log(node, attempts):
  ac_node_update(
    action="blocked",
    tree_id=$TREE_ID,
    node_id="$NODE_ID",
    message="Failed after ${len(attempts)} attempts — escalating to human. Failure log: ${format_attempts(attempts)}"
  )

  present_escalation:
    ## Escalation: Node ${node.id} — ${node.title}

    **Attempts exhausted**: ${len(attempts)} / ${max_retries}

    | Attempt | Parameter Change | Failure Reason |
    |---------|-----------------|----------------|
    <for each attempt in attempts>
    | ${attempt.attempt_number} | ${attempt.parameter_change} | ${attempt.failure_reason} |

    **Decision needed**: All automated retry strategies exhausted. Human guidance required.
```

### 5a. Spec-Driven Evaluation

Evaluate each completed node against its acceptance criteria before advancing. This is the core quality gate — without it, the system can only check "did it finish?" not "did it do the right thing?"

#### Review Step Population

When a node enters evaluation, auto-populate the task list with the L1 review checklist. This ensures every review substep is tracked and none are skipped. Create the following tasks (if they don't already exist for this node):

```
TaskCreate("${NODE_ID}: Check prerequisites",
  "Verify L0 agent ran /init-workspace, followed plan→implement→test, ran /finish (finish.jsonl exists), and ran /review (self-review posted to PR). REJECT without evaluation if any prerequisite is missing.")

TaskCreate("${NODE_ID}: Standing rules pre-filter",
  "Grep diff for detector patterns from project CLAUDE.md Standing Rules section. Auto-pass rules with no matches. Flag rules with matches for LLM judge evaluation.")

TaskCreate("${NODE_ID}: Per-criterion assessment",
  "For each acceptance criterion in the node's DESIGN.md, determine PASS/FAIL with reasoning citing specific diff evidence.")

TaskCreate("${NODE_ID}: Standing rules assessment",
  "For each standing rule, determine PASS/FAIL against the diff.")

TaskCreate("${NODE_ID}: Test verification",
  "Verify the agent actually tested — ran the script, executed the container, observed output. 'Reviewed control flow' or 'logic looks correct' is NOT testing. REJECT if untested.")

TaskCreate("${NODE_ID}: Write evaluation.json",
  "Write scalar metrics to .metrics/evaluation.json with criteria_passed, criteria_total, acceptance_rate, verdict, standing_rules array.")

TaskCreate("${NODE_ID}: Post evaluation summary",
  "Post evaluation summary as PR comment. Record verdict and reasoning for L2 review.")
```

These tasks are sequential — each depends on the prior step completing. Skip task creation if review tasks for this node already exist (idempotency).

Reference: `nodes/C.3/l1-review-process.md` in the project directory documents the full review procedure and quality signals.

#### Standing Rules

Standing rules are architectural constraints defined in the project CLAUDE.md (`## Standing Rules` section) that apply to every PR in the project. They are evaluated alongside per-task acceptance criteria — same evaluator, same failure path.

##### Rule Format

Each rule is a bullet in the `## Standing Rules` section of the project CLAUDE.md. Format is freeform prose with an optional `**Detector**:` line:

```markdown
## Standing Rules

- **Rule name.** Rule description in prose.
  **Detector**: grep pattern or file-path glob that triggers this rule (optional)

- **Another rule.** Description only — no detector, LLM-only evaluation.
```

When a `**Detector**:` hint is present, the evaluator runs a grep/glob pre-filter against the diff before invoking the LLM judge. If the pre-filter finds no matches, the rule auto-passes (cheap short-circuit). If it finds matches, the LLM judge evaluates the flagged changes. Rules without a detector always go to the LLM judge.

##### Parsing

At evaluation time, read the project CLAUDE.md and extract the `## Standing Rules` section:

```
PROJECT_CLAUDE_MD = "${PROJECT_DIR}/CLAUDE.md"
standing_rules = parse_standing_rules(PROJECT_CLAUDE_MD)
```

Each parsed rule is a struct:

```
standing_rule:
  name: <bold text before the first period>
  description: <full prose text of the rule>
  detector: <optional detector hint string, or null>
```

If the `## Standing Rules` section is missing or empty, `standing_rules = []` — evaluation proceeds with per-task criteria only.

#### Evaluation Protocol

For each completed node:

1. **Gather evaluation inputs**:
   - Node's acceptance criteria (from the spec/DESIGN.md in the node workspace)
   - Standing rules (from `## Standing Rules` in project CLAUDE.md — see above)
   - Node's output: diff (`git diff` in node workspace), artifacts produced
   - Node's changes summary from the dispatch result
   - Child session's self-reported results (advisory input — the LLM-as-judge verdict is authoritative)

2. **Standing rules pre-filter**: For each standing rule with a `**Detector**:` hint, run the detector against the diff:

```
for rule in standing_rules:
  if rule.detector:
    matches = grep_diff(diff, rule.detector)
    if not matches:
      rule.pre_filter_result = "auto_pass"  # no relevant changes
    else:
      rule.pre_filter_result = "flagged"    # LLM judge evaluates
      rule.flagged_lines = matches
  else:
    rule.pre_filter_result = "no_detector"  # always goes to LLM judge
```

3. **LLM-as-judge evaluation**: Assess each acceptance criterion and standing rule independently:

```
## Evaluation: ${NODE_ID}. ${NODE_TITLE}

For each acceptance criterion, determine pass/fail based on the actual changes produced.

### Criteria Assessment

| # | Criterion | Verdict | Reasoning |
|---|-----------|---------|-----------|
| 1 | <criterion text> | PASS/FAIL | <1-2 sentence justification citing specific evidence from the diff/artifacts> |
| 2 | <criterion text> | PASS/FAIL | <reasoning> |
| ... | ... | ... | ... |

### Standing Rules Assessment

Evaluate each standing rule against the diff. Rules are project-wide architectural constraints — they apply regardless of the task's acceptance criteria.

| # | Rule | Verdict | Reasoning |
|---|------|---------|-----------|
| 1 | <rule name> | PASS/FAIL | <1-2 sentence justification> |
| ... | ... | ... | ... |

For rules with pre-filter results:
- **auto_pass**: The detector found no relevant changes in the diff. Record as PASS without further analysis.
- **flagged**: The detector found potentially relevant changes. Evaluate the flagged lines to determine if they violate the rule.
- **no_detector**: No pre-filter available. Evaluate the full diff against the rule.

Key distinction: additions that violate a rule are failures; removals or migrations away from a deprecated pattern are passes.

### Summary

- **Criteria Pass**: <N>/<total>
- **Criteria Fail**: <N>/<total>
- **Rules Pass**: <N>/<total>
- **Rules Fail**: <N>/<total>
- **Overall**: ACCEPT / REJECT
```

4. **Decision**:

| Overall | Action |
|---------|--------|
| All criteria AND rules pass | **ACCEPT** — write `--status completed`, add to `completed_nodes`, proceed to 5c |
| Any criteria fail, retries remaining | **REJECT** — re-dispatch with feedback (see below) |
| Any standing rule fails, retries remaining | **REJECT** — re-dispatch with standing rule feedback (same retry path) |
| Any criteria or rule fail, no retries remaining | **FAIL** — mark node as failed, log evaluation |

#### Accept Path

Write the deferred coordinator status and advance the node:

```
ac_node_update(
  action="complete",
  tree_id=$TREE_ID,
  node_id="$NODE_ID",
  message="<changes summary>"
)

completed_nodes.append(node)
```

Then proceed to step 5c (commit) and subsequent steps for this node.

#### Reject Path

When evaluation rejects a node's output:

1. **Build feedback prompt**: Append the failed criteria and reasoning to the workspace DESIGN.md:

```
## Evaluation Feedback (Attempt ${ATTEMPT}/${MAX_RETRIES + 1})

The following acceptance criteria were not met:

${FOR_EACH_FAILED_CRITERION}
- **Criterion**: ${CRITERION_TEXT}
  **Verdict**: FAIL
  **Reasoning**: ${REASONING}
${END_FOR}

${IF_STANDING_RULES_FAILED}
The following standing rules were violated:

${FOR_EACH_FAILED_RULE}
- **Rule**: ${RULE_NAME}
  **Description**: ${RULE_DESCRIPTION}
  **Verdict**: FAIL
  **Reasoning**: ${REASONING}
${END_FOR}
${END_IF}

Please address the failed criteria and rule violations. The passing items should not regress.
```

2. **Send feedback to child** (if still alive) or re-dispatch with the augmented spec
3. **Increment retry counter** for this node

#### Re-Dispatch Limits

- **Default**: 2 retries (3 total attempts including the original)
- Tracked per node: `evaluation_attempts[node_id]`
- After exhausting retries, mark the node as failed:

```
ac_node_update(
  action="blocked",
  tree_id=$TREE_ID,
  node_id="$NODE_ID",
  message="Evaluation failed after ${MAX_RETRIES + 1} attempts. Last failures: ${FAILED_CRITERIA_SUMMARY}"
)
```

#### Evaluation Telemetry

Log the evaluation result for each assessed node. Telemetry is persisted via the coordinator:

```
ac_node_update(
  action="progress",
  tree_id=$TREE_ID,
  node_id="$NODE_ID",
  message="Evaluation: ${VERDICT}. ${CRITERIA_PASS_COUNT}/${CRITERIA_TOTAL} criteria passed. ${RULES_PASS_COUNT}/${RULES_TOTAL} standing rules passed. ${REASONING_SUMMARY}"
)
```

#### Scalar Metrics (L0)

After evaluation, write structured scalar metrics to the node workspace so downstream telemetry (finish.jsonl) can consume them. The acceptance criteria pass rate is the L0 scalar metric defined in DESIGN.md.

```bash
NODE_METRICS_DIR="${NODE_WORKSPACE}/.metrics"
mkdir -p "$NODE_METRICS_DIR"

# Build standing_rules JSON array from a temp file written during evaluation.
STANDING_RULES_FILE="${NODE_METRICS_DIR}/standing_rules.jsonl"
if [[ -f "$STANDING_RULES_FILE" ]]; then
  STANDING_RULES_JSON=$(jq -s '.' "$STANDING_RULES_FILE")
else
  STANDING_RULES_JSON="[]"
fi

jq -n \
  --argjson criteria_passed ${CRITERIA_PASS_COUNT} \
  --argjson criteria_total ${CRITERIA_TOTAL} \
  --arg verdict "${VERDICT}" \
  --arg evaluated_at "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
  --argjson standing_rules "$STANDING_RULES_JSON" \
  -c '{$criteria_passed, $criteria_total, acceptance_rate: ($criteria_passed / $criteria_total), $verdict, $evaluated_at, $standing_rules}' \
  > "${NODE_METRICS_DIR}/evaluation.json"
```

The `evaluation.json` file contains:

| Field | Type | Description |
|-------|------|-------------|
| `criteria_passed` | int | Number of acceptance criteria that passed |
| `criteria_total` | int | Total acceptance criteria evaluated |
| `acceptance_rate` | float | `criteria_passed / criteria_total` (0.0–1.0) |
| `verdict` | string | `ACCEPT`, `REJECT`, or `FAIL` |
| `evaluated_at` | string | ISO 8601 timestamp of evaluation |
| `standing_rules` | array | Per-rule outcomes: `[{name, status, reasoning}]`. Empty array when no standing rules are defined. |

Each entry in `standing_rules`:

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Rule name (bold text before the first period in the rule bullet) |
| `status` | string | `"pass"` or `"fail"` |
| `reasoning` | string | 1-2 sentence justification for the verdict |

This file is read by the task-workflow finish operation (step 6) when writing finish.jsonl.

#### Finish Metrics Patch

After writing `evaluation.json`, patch the corresponding `finish.jsonl` entry with evaluation metrics:

```bash
skills/goal-tree/scripts/patch-finish-metrics.sh "${NODE_WORKSPACE}" "${NODE_ID}"
```

The script is idempotent — entries already patched (criteria_passed present) are left unchanged. If `finish.jsonl` does not exist, the script exits cleanly.

### 4a-gate. Evaluation Gate (mandatory)

Before advancing to classification, merge, or any post-evaluation step, verify that `evaluation.json` exists. This is a structural enforcement — the file's presence proves the evaluation protocol ran to completion.

```
EVAL_FILE="${NODE_WORKSPACE}/.metrics/evaluation.json"

if [[ ! -f "$EVAL_FILE" ]]; then
  echo "BLOCKED: ${NODE_ID} — .metrics/evaluation.json missing. Run the evaluation protocol (step 4a) before advancing."
  # Do not proceed. The node stays in pending_evaluation until the gate is satisfied.
  return
fi
```

**This gate cannot be bypassed.** If evaluation.json is missing, the node cannot advance to outcome classification (4b), commit (4c), or merge. The operator must run the full evaluation protocol first.

### 5b. Outcome Classification

For each completed node, classify the outcome relative to the mission:

| Classification | Meaning | Action |
|----------------|---------|--------|
| **Advanced** | Node delivered clear mission value | Record advancement in coordinator result |
| **Neutral** | Node completed but impact is unclear or deferred | Note as "neutral — impact pending" |
| **Setback** | Node completed but revealed a problem or regression | Flag for strategic review in step 5d |

Record the classification alongside the node result:

```
ac_node_update(
  action="progress",
  tree_id=$TREE_ID,
  node_id="$NODE_ID",
  message="<changes summary>. Outcome: <advanced|neutral|setback>. <1-sentence justification>"
)
```

Setback classifications automatically trigger the strategic feedback check in step 5d.

### 5c. Commit After Results

After processing results from a dispatch round, commit changes in node workspaces:

Check for uncommitted changes in node workspaces:

```bash
skills/goal-tree/scripts/check-workspace-state.sh "$PROJECT_DIR"
```

For each workspace reported as `dirty`, use the git skill commit operation:

```
Read: skills/git/operations/commit.md
commit(repo_dir)
record commit hash in completed_nodes
```

### 5d. Completion Checkpoint

Post-completion behavior is determined by autonomy tier:

| Tier | Post-Completion |
|------|-----------------|
| Tier 1 (read-only) | **Auto-continue** — log result, move on |
| Tier 2 (code) | **Validation gate** → agent review → present for human review |
| Tier 3 (strategic) | **Present** for human review immediately |

#### Tier 1: Auto-continue

Log a single status line and proceed to next round:

```
── T1: <node.id> <node.title> ✓ ──
```

#### Tier 2: Validation gate

Before presenting to human, run the validation pipeline:

1. **Automated tests**: Run full test suite in the node workspace
2. **Lint/format**: Run project linters
3. **Agent review**: Verify spec → test → code traceability
   - Each acceptance criterion maps to at least one test
   - Each test exercises the implementation
   - No orphan code (implementation without spec coverage)

Present to human with traceability summary:

```
## Review: <node.id> <node.title>

| Criterion | Test | Status |
|-----------|------|--------|
| <spec item> | <test name> | pass |

Validation: tests ✓ lint ✓ traceability ✓
Files: <N> | Commit: <hash>

Approve, or feedback?
```

#### Tier 3: Present immediately

Show results and wait for human input before continuing.

### 5e. Strategic Feedback Check

After processing results, evaluate whether results change the strategic picture:

- Did a completed node reveal that the tree decomposition is wrong?
- Did a failure expose a missing dependency or incorrect assumption?
- Did results advance a KR in a way that changes priorities?

**Most of the time**: No strategic impact — auto-advance to next round.

**Pause for conversation when**:
- Results contradict a design assumption in the tree
- A node's result suggests the tree needs restructuring (new nodes, removed nodes, changed deps)
- The operator has been disengaged for 3+ rounds and a natural checkpoint exists

When pausing, present the strategic observation and let the operator steer. Do not present a list of everything that happened — focus on the one thing that matters.

### 6. Re-Query and Continue

Query the coordinator for fresh state (may have been updated by child sessions):

```
ac_node_query(action="get", tree_id=$TREE_ID)
```

Check for newly completed nodes in `active_nodes`:

```
for node_id, node_info in active_nodes:
  if node completed since last check:
    collect results
    active_nodes.remove(node_id)
```

Go to step 1 (select next ready batch). If `active_nodes` is non-empty but no new ready nodes are available, continue the monitoring loop (step 4) instead of selecting new nodes.

## Termination

### 7. Completion

When the loop terminates:

```
## Goal Tree Execution Summary

**Nodes completed**: <N>
<for each completed node>
  - <node.id>. <node.title> [container|tmux] (<commit>)

**Nodes skipped**: <N>
<for each skipped node>
  - <node.id>. <node.title> (detector: <reason>)

**Nodes blocked**: <N>
<for each blocked node>
  - <node.id>. <node.title> (reason: <blocker>)

**Retried nodes**: <N>
<for each node with failure telemetry>
  - <node.id>. <node.title>: <attempts> attempts, final outcome: <completed|escalated>

**Dispatch summary**: container: N, tmux: N, escalated: N
**Active nodes at termination**: <N>
**Commits**: <N total>

**Termination reason**: all_complete | blocked | all_skipped | escalated
```

### Termination Routing

| Condition | Action |
|-----------|--------|
| All nodes complete, **bounded project** | Hand off to `operations/synthesize.md` |
| All nodes complete, **open-ended project** | Auto-continue via `operations/next-cycle.md` |
| Blocked/skipped nodes remain | Report and pause for user guidance |

**Open-ended detection**: A project is open-ended when the operator has indicated they will determine completion (e.g., "I'll decide when it's done", continuous OODA, no fixed scope). Check project CLAUDE.md for signals. When in doubt, ask once — then remember the answer for the session.

In open-ended mode, "all nodes complete" means "this batch is done" — not "the project is done." The agent immediately enters the next OODA cycle: observe what changed, orient to the mission, propose new nodes, dispatch.

## Stuck Detection

### Stall Detection (Monitoring Loop)

During the monitoring loop, detect stalled nodes:

```
STALL_THRESHOLD = 10  # monitoring cycles with no progress

for node_id, node_info in active_nodes:

  if node_info.dispatch_method == "container":
    # Container stall: check coordinator for status changes
    current_status = ac_node_query(action="get", tree_id=$TREE_ID, node_id="$NODE_ID")
    if current_status == node_info.last_status:
      node_info.stall_count += 1
    else:
      node_info.stall_count = 0
      node_info.last_status = current_status

  elif node_info.dispatch_method == "tmux":
    # Tmux stall: check output changes
    current_output = tmux capture-pane -t "$SESSION_NAME" -p
    if current_output == node_info.last_output:
      node_info.stall_count += 1
    else:
      node_info.stall_count = 0
      node_info.last_output = current_output

  if node_info.stall_count >= STALL_THRESHOLD:
    handle_stuck(node_info.node, "stall", "No progress for ${STALL_THRESHOLD} monitoring cycles")
```

### Repeated Failure Detection

If the same error appears across retry attempts:

```
if error_summary == last_error_summary:
  repeated_count += 1
  if repeated_count >= 3:  # threshold
    handle_stuck(node, "repeated-failure")
```

### Stuck Handling

```
function handle_stuck(node, reason, detail):
  ac_node_update(
    action="blocked",
    tree_id=$TREE_ID,
    node_id="$NODE_ID",
    message="Stuck: ${reason} — ${detail}"
  )

  skipped_set.add(node.id)

  node_info = active_nodes[node.id]

  # Kill the stalled node
  if node_info.dispatch_method == "container":
    # AC manages container lifecycle — update coordinator status
    # Container will be cleaned up by AC
    pass
  elif node_info.dispatch_method == "tmux":
    tmux kill-session -t "$SESSION_NAME" 2>/dev/null

  # Remove from active nodes
  active_nodes.remove(node.id)

  # Log
  -- Stuck detected --------------------------------
  Node: <node.id>. <node.title>
  Dispatch: <node_info.dispatch_method>
  Detector: <reason>
  Action: skip and continue
  --------------------------------------------------
```

## Parallel Failure Isolation

When dispatching nodes in parallel:

- One node's failure does **not** block independent siblings
- Failed nodes are handled individually (retry with parameter change → escalate)
- Other parallel sessions continue unaffected
- Results are collected as each session completes

```
# Fan-out: 3 containers dispatched in parallel
# Session 1: completes successfully → collect result
# Session 2: fails → retry with error context → new session
# Session 3: completes successfully → collect result
# All three processed independently via monitoring loop
```

## Error Handling

| Error | Response |
|-------|----------|
| Coordinator unreachable | Retry with backoff, pause if persistent |
| Tree not found | Stop with error |
| All dispatches in a round fail | Pause, report failures, ask user |
| Transient error (API, network) | Classify via error-classification, retry with backoff |
| Merge conflict on sub-branch | Escalate to user |
| Context approaching limit | Output summary, suggest /resume-project in new session |
| AC unreachable | Fall back to tmux dispatch for new nodes; continue monitoring existing container nodes via coordinator |
| tmux unavailable | Only affects tmux-dispatched nodes; container dispatch continues normally |

## Example

### 3-node parallel dispatch with monitoring

```
[Goal tree execution starting: 6 nodes (3 ready)]

── Dispatch Round 1 ───────────────────────

| Node | Strategy | Reason |
|------|----------|--------|
| A.1. Add OAuth config | container | Clear spec, dependencies met |
| B.1. Add login UI | container | Clear spec, dependencies met |
| C.1. Update API docs | container | Clear spec, dependencies met |

Dispatching 3 containers via AC...
  → A.1 dispatched: ac_node_update action=dispatch (container: abc123)
  → B.1 dispatched: ac_node_update action=dispatch (container: def456)
  → C.1 dispatched: ac_node_update action=dispatch (container: ghi789)

── Monitoring ─────────────────────────────

  [cycle 1] A.1: working... | B.1: working... | C.1: working...
  [cycle 2] A.1: working... | B.1: working... | C.1: completed ✓
  [cycle 3] A.1: completed ✓ | B.1: working...
  [cycle 4] B.1: completed ✓

── Round 1 Complete ───────────────────────

| Node | Result | Files | Commit |
|------|--------|-------|--------|
| A.1. Add OAuth config | success | 2 files | abc1234 |
| B.1. Add login UI | success | 3 files | def5678 |
| C.1. Update API docs | success | 1 file | ghi9012 |

**Next up**: A.2 (depends: A.1 ✓), B.2 (depends: B.1 ✓)

── Dispatch Round 2 ───────────────────────

| Node | Strategy | Reason |
|------|----------|--------|
| A.2. Implement OAuth flow | container | Depends met, clear spec |
| B.2. Add token refresh | container | Depends met, clear spec |

Dispatching 2 containers via AC...

── Monitoring ─────────────────────────────

  [cycle 1] A.2: working... | B.2: working...
  [cycle 2] A.2: completed ✓ | B.2: completed ✓

## Goal Tree Execution Summary

**Nodes completed**: 5
  - A.1. Add OAuth config [container] (abc1234)
  - A.2. Implement OAuth flow [container] (jkl3456)
  - B.1. Add login UI [container] (def5678)
  - B.2. Add token refresh [container] (mno7890)
  - C.1. Update API docs [container] (ghi9012)

**Dispatch summary**: container: 5
**Active nodes at termination**: 0
**Commits**: 5 total
**Termination reason**: all_complete
```

## Integration Points

- **Called by**: start-project (after approval), resume-project (after state recovery)
- **Calls**: select-ready (via `ac_node_query`), dispatch-decision, dispatch-node, update-goal (via `ac_node_update`)
- **Hands off to**: synthesize (on completion)
- **References**:
  - `task-workflow/references/error-classification.md`
  - `task-workflow/references/retry-with-backoff.md`
  - `references/node-lifecycle.md`
