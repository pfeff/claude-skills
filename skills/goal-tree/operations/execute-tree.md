# Execute Tree Operation

Main orchestration loop for goal tree execution. Iterates: select ready nodes → decide dispatch strategy → fan-out dispatch → collect results → update coordinator → repeat.

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `tree_id` | Yes | Coordinator tree ID |
| `project_dir` | Yes | Project directory path |
| `project_branch` | Yes | Project branch name |

## Purpose

Drives the goal tree from pending to complete. Handles parallel dispatch of independent nodes, result collection, failure recovery, and stuck detection. Stops when all nodes are complete, all remaining are blocked/skipped, or an unrecoverable error occurs.

## Protocol Requirements

These are mandatory — do not shortcut the pipeline.

1. **Every node goes through the full pipeline.** You MUST run select-ready → dispatch-decision → dispatch-node for each node. Do not implement tasks directly without going through dispatch-decision first.
2. **Parallel dispatch is the default.** When select-ready returns multiple independent nodes, dispatch them as parallel subagents (multiple Agent tool calls in one message). Sequential inline execution of independent nodes is a protocol violation, not a simplification.
3. **Planning-workflow is a gate, not a suggestion.** Every dispatched node — whether subagent or inline — must run planning-workflow before implementation. For subagents this is in the prompt. For inline this is verified by checking PLAN.md exists before proceeding to implementation.

## Entry Guard

Before entering the loop:

### 1. Query Goal Tree

```bash
coord tree show $TREE_ID
```

Parse the JSON response to get the full tree state.

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
total_dispatches = 0       # total dispatch attempts
parallel_dispatches = 0    # parallel fan-out count
max_retries = 3            # max retry attempts per node before escalation
failure_telemetry = {}     # node_id → [list of attempt records]
```

## Loop Body

Repeat steps 1-5 until termination.

### 1. Select Ready Nodes

```bash
coord tree ready $TREE_ID
```

Parse the JSON response to get ready nodes, then group for parallel dispatch per `operations/select-ready.md`.

| Batch Result | Action |
|-------------|--------|
| Non-empty batch | Proceed to step 2 |
| Empty, reason: "complete", **bounded** | Go to Termination (step 6) |
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
| <id>. <title> | subagent | 1 | <rationale> (auto) |

Tier 1/2 nodes will auto-dispatch. Need your input on the Tier 3 items above.
```

Tier 1 and 2 nodes in a mixed batch dispatch immediately — don't hold them waiting for Tier 3 resolution.

### 3. Fan-Out Dispatch

Group decisions by strategy and dispatch:

```
Load: operations/dispatch-node.md

# Separate by dispatch type
subagent_nodes = [(n, d) for n, d in decisions if d.strategy == "subagent"]
subsession_nodes = [(n, d) for n, d in decisions if d.strategy == "sub-session"]
inline_nodes = [(n, d) for n, d in decisions if d.strategy == "inline"]
escalate_nodes = [(n, d) for n, d in decisions if d.strategy == "escalate"]
```

#### 3a. Handle Escalations First

If any nodes need escalation, present them to the user before dispatching others:

```
for node, decision in escalate_nodes:
  coord node update $TREE_ID $NODE_DB_ID --status blocked
  present escalation to user
```

If **all** nodes in the batch are escalations, pause the loop.

#### 3b. Dispatch Subagents in Parallel

Launch all subagent dispatches simultaneously using the Agent tool:

```
# All subagent nodes in the same independent group → parallel
for node, decision in subagent_nodes:
  coord node update $TREE_ID $NODE_DB_ID --status in_progress

# Dispatch all subagents in a single message with multiple Agent tool calls
results = dispatch_all_subagents(subagent_nodes)
```

This is the fan-out: multiple Agent tool invocations in one message. Each subagent works in its own node workspace (created by dispatch-node before dispatch).

#### 3c. Dispatch Sub-Sessions in Parallel

Launch sub-sessions concurrently:

```
for node, decision in subsession_nodes:
  coord node update $TREE_ID $NODE_DB_ID --status in_progress
  create_subsession(node, decision)  # tmux session
```

Sub-sessions run asynchronously. The root session monitors them.

#### 3d. Execute Inline Sequentially

Inline tasks execute in the root session one at a time:

```
for node, decision in inline_nodes:
  coord node update $TREE_ID $NODE_DB_ID --status in_progress
  result = dispatch_inline(node, decision)
  process_result(node, result)  # step 4
```

### 4. Process Results

For each dispatch result:

```
if result.status == "success":
  coord node update $TREE_ID $NODE_DB_ID \
    --status completed \
    --result "<changes summary>"

  coord node add-result $TREE_ID $NODE_DB_ID \
    --status completed \
    --dispatch <dispatch_method> \
    --files "<comma-separated files>" \
    --summary "<changes summary>" \
    --commit "<commit hash>"

  completed_nodes.append(node)

elif result.status == "partial":
  coord node update $TREE_ID $NODE_DB_ID \
    --result "<changes summary> (partial)"
  # Decide: retry remaining criteria or accept partial

elif result.status in ("failure", "did_not_finish"):
  # did_not_finish (container exceeded wall-clock budget) routes through the
  # same retry path as failure. retry_dispatch inspects the failure_status
  # captured on the attempt and selects the widen-timeout parameter change
  # for did_not_finish, or the prompt-change strategies for failure.
  retry_node(node, result)

elif result.status == "blocked":
  coord node update $TREE_ID $NODE_DB_ID --status blocked

elif result.status == "escalated":
  # Already handled in step 3a
  pass
```

`did_not_finish` is unique to container dispatch (`dispatch-container.sh --timeout`). It indicates the dispatch ran out of wall-clock time, not that the underlying work was wrong. The retry path treats it as a failure and may widen the timeout budget on the next attempt — see the parameter change strategies below.

#### Retry Loop (`retry_node`)

When a node fails, retry with parameter changes before escalating. This implements the design principle: "Failure is normal — rejection → parameter change + re-dispatch, not stop-and-ask."

```
function retry_node(node, initial_result):
  attempts = failure_telemetry.get(node.id, [])

  # Record this failure as attempt. failure_status and duration_seconds are
  # required by retry_dispatch's timeout-widen branch — see below.
  attempt = {
    attempt_number: len(attempts) + 1,
    failure_status: initial_result.status,            # "failure" | "did_not_finish"
    failure_reason: initial_result.issues,
    duration_seconds: initial_result.duration_seconds, # populated by container dispatch
    dispatch_method: initial_result.dispatch_method,
    parameter_change: "initial dispatch"
  }
  attempts.append(attempt)
  failure_telemetry[node.id] = attempts

  if len(attempts) >= max_retries:
    # Exhausted retries — escalate with full failure log
    escalate_with_failure_log(node, attempts)
    return

  # Re-dispatch with parameter change based on attempt count
  new_result = retry_dispatch(node, attempts)
  process_result(node, new_result)  # recursive — will retry again if needed
```

**Parameter change strategies** — applied in order across retry attempts:

| Attempt | Parameter Change | Description |
|---------|-----------------|-------------|
| 2 | Add error context | Append prior failure reason and error output to dispatch prompt |
| 3 | Alternative approach hint | Add instruction to use a different implementation strategy (e.g., "The previous approach failed because X. Try Y instead.") |
| any (timeout) | Widen timeout budget | When the prior failure is `did_not_finish`, double the container `--timeout` for the next attempt instead of changing the prompt. |

```
function retry_dispatch(node, attempts):
  n = len(attempts)
  last = attempts[-1]

  # Timeout-driven retries get a wider budget rather than a prompt change.
  # The killed dispatch ran for `duration_seconds` (≈ the budget that was
  # applied) before the timeout fired. Doubling that is a clean signal to the
  # next attempt without needing to track the prior --timeout flag separately.
  if last.failure_status == "did_not_finish":
    new_timeout_seconds = last.duration_seconds * 2
    result = dispatch_node(node, {
      reason: "retry-widen-timeout",
      prior_failures: attempts,
      timeout: "${new_timeout_seconds}s"
    })
    return result

  if n == 1:
    result = dispatch_node(node, {
      reason: "retry",
      prior_failures: attempts,
      additional_prompt: "Previous attempt failed: ${last.failure_reason}. Address this specific issue."
    })
  else:
    result = dispatch_node(node, {
      reason: "retry-alternative",
      prior_failures: attempts,
      additional_prompt: "The previous approach failed: ${last.failure_reason}. Try an alternative strategy."
    })

  return result
```

#### Failure Telemetry Record

Each failed attempt emits a structured telemetry record that N+1 can consume:

```
failure_telemetry_record:
  node_id: <node ID>
  attempt_number: <1-based>
  failure_status: "failure" | "did_not_finish"
  failure_reason: <error description>
  duration_seconds: <wall-clock seconds, when reported by dispatch>
  parameter_change_applied: <description of what changed>
  outcome: "retry" | "escalated"
  timestamp: <ISO 8601>
```

These records are appended to the node's result in the coordinator:

```bash
coord node add-result $TREE_ID $NODE_DB_ID \
  --status retry \
  --summary "Attempt ${attempt_number}/${max_retries}: ${failure_reason}. Parameter change: ${parameter_change_applied}."
```

#### Escalation with Failure Log

When max_retries is exhausted, escalate with the full failure history attached:

```
function escalate_with_failure_log(node, attempts):
  coord node update $TREE_ID $NODE_DB_ID \
    --status blocked \
    --result "Failed after ${len(attempts)} attempts — escalating to human"

  # Record all attempts as a single telemetry summary
  coord node add-result $TREE_ID $NODE_DB_ID \
    --status failed \
    --summary "Exhausted ${max_retries} retries. Failure log: ${format_attempts(attempts)}"

  # Present escalation with full context
  present_escalation:
    ## Escalation: Node ${node.id} — ${node.title}

    **Attempts exhausted**: ${len(attempts)} / ${max_retries}

    | Attempt | Method | Parameter Change | Failure Reason |
    |---------|--------|-----------------|----------------|
    <for each attempt in attempts>
    | ${attempt.attempt_number} | ${attempt.dispatch_method} | ${attempt.parameter_change} | ${attempt.failure_reason} |

    **Decision needed**: All automated retry strategies exhausted. Human guidance required.
```

### 4a. Spec-Driven Evaluation

Evaluate each node in `pending_evaluation` against its acceptance criteria before committing or advancing. This is the core quality gate — without it, the system can only check "did it finish?" not "did it do the right thing?"

#### Evaluation Protocol

For each node in `pending_evaluation`:

1. **Gather evaluation inputs**:
   - Node's acceptance criteria (from the spec/DESIGN.md in the node workspace)
   - Node's output: diff (`git diff` in node workspace), artifacts produced
   - Node's changes summary from the dispatch result
   - Subagent's self-reported `acceptance_criteria_met` list (advisory input — the LLM-as-judge verdict is authoritative)

2. **LLM-as-judge evaluation**: Assess each acceptance criterion independently:

```
## Evaluation: ${NODE_ID}. ${NODE_TITLE}

For each acceptance criterion, determine pass/fail based on the actual changes produced.

### Criteria Assessment

| # | Criterion | Verdict | Reasoning |
|---|-----------|---------|-----------|
| 1 | <criterion text> | PASS/FAIL | <1-2 sentence justification citing specific evidence from the diff/artifacts> |
| 2 | <criterion text> | PASS/FAIL | <reasoning> |
| ... | ... | ... | ... |

### Summary

- **Pass**: <N>/<total>
- **Fail**: <N>/<total>
- **Overall**: ACCEPT / REJECT
```

3. **Decision**:

| Overall | Action |
|---------|--------|
| All criteria pass | **ACCEPT** — write `--status completed`, add to `completed_nodes`, proceed to 4c |
| Any criteria fail, retries remaining | **REJECT** — re-dispatch with feedback (see below) |
| Any criteria fail, no retries remaining | **FAIL** — mark node as failed, log evaluation |

#### Accept Path

Write the deferred coordinator status and advance the node:

```bash
coord node update $TREE_ID $NODE_DB_ID \
  --status completed \
  --result "<changes summary>"

completed_nodes.append(node)
```

Then proceed to step 4c (commit) and subsequent steps for this node.

#### Reject Path

When evaluation rejects a node's output:

1. **Build feedback prompt**: Append the failed criteria and reasoning to the original dispatch prompt:

```
## Evaluation Feedback (Attempt ${ATTEMPT}/${MAX_RETRIES + 1})

The following acceptance criteria were not met:

${FOR_EACH_FAILED_CRITERION}
- **Criterion**: ${CRITERION_TEXT}
  **Verdict**: FAIL
  **Reasoning**: ${REASONING}
${END_FOR}

Please address the failed criteria. The passing criteria should not regress.
```

2. **Re-dispatch** with the augmented prompt (same strategy as original dispatch)
3. **Increment retry counter** for this node

#### Re-Dispatch Limits

- **Default**: 2 retries (3 total attempts including the original)
- Tracked per node: `evaluation_attempts[node_id]`
- After exhausting retries, mark the node as failed:

```bash
coord node update $TREE_ID $NODE_DB_ID \
  --status blocked \
  --result "Evaluation failed after ${MAX_RETRIES + 1} attempts. Last failures: ${FAILED_CRITERIA_SUMMARY}"
```

#### Evaluation Telemetry

Log the evaluation result for each assessed node. Telemetry is persisted via the coordinator `add-result` call:

```bash
coord node add-result $TREE_ID $NODE_DB_ID \
  --summary "Evaluation: ${VERDICT}. ${PASS_COUNT}/${TOTAL} criteria passed. ${REASONING_SUMMARY}"
```

#### Scalar Metrics (L0)

After evaluation, write structured scalar metrics to the node workspace so downstream telemetry (finish.jsonl) can consume them. The acceptance criteria pass rate is the L0 scalar metric defined in DESIGN.md.

```bash
NODE_METRICS_DIR="${NODE_WORKSPACE}/.metrics"
mkdir -p "$NODE_METRICS_DIR"
jq -n \
  --argjson criteria_passed ${PASS_COUNT} \
  --argjson criteria_total ${TOTAL} \
  --arg verdict "${VERDICT}" \
  --arg evaluated_at "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
  -c '{$criteria_passed, $criteria_total, acceptance_rate: ($criteria_passed / $criteria_total), $verdict, $evaluated_at}' \
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

This file is read by the task-workflow finish operation (step 7) when writing finish.jsonl.

### 4b. Outcome Classification

For each completed node, classify the outcome relative to the mission:

| Classification | Meaning | Action |
|----------------|---------|--------|
| **Advanced** | Node delivered clear mission value | Record advancement in coordinator result |
| **Neutral** | Node completed but impact is unclear or deferred | Note as "neutral — impact pending" |
| **Setback** | Node completed but revealed a problem or regression | Flag for strategic review in step 4d |

Record the classification alongside the node result:

```bash
coord node add-result $TREE_ID $NODE_DB_ID \
  --summary "<changes summary>. Outcome: <advanced|neutral|setback>. <1-sentence justification>"
```

Setback classifications automatically trigger the strategic feedback check in step 4d.

### 4c. Commit After Results

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

### 4d. Completion Checkpoint

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

### 4e. Strategic Feedback Check

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

### 5. Re-Query and Continue

Query the coordinator for fresh state (may have been updated by sub-sessions):

```bash
coord tree show $TREE_ID
```

Check for sub-session completions:

```
for active sub-session:
  if session completed:
    # Query coordinator for node status (sub-session updates coordinator directly)
    coord tree show $TREE_ID
    collect results from node statuses
    # Branch merging deferred to synthesize step
```

Go to step 1 (select next ready batch).

## Termination

### 6. Completion

When the loop terminates:

```
## Goal Tree Execution Summary

**Nodes completed**: <N>
<for each completed node>
  - <node.id>. <node.title> [<dispatch_method>] (<commit>)

**Nodes skipped**: <N>
<for each skipped node>
  - <node.id>. <node.title> (detector: <reason>)

**Nodes blocked**: <N>
<for each blocked node>
  - <node.id>. <node.title> (reason: <blocker>)

**Retried nodes**: <N>
<for each node with failure telemetry>
  - <node.id>. <node.title>: <attempts> attempts, final outcome: <completed|escalated>

**Dispatch summary**: <subagent: N, inline: N, sub-session: N, fallback: N>
**Parallel dispatches**: <N fan-outs>
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

Reuses stuck detection patterns from task-workflow auto-advance:

### No-Progress Detection

After each inline implementation step, check `git diff --stat`:

```
if empty diff:
  no_progress_count += 1
  if no_progress_count >= 1:  # threshold
    handle_stuck(node, "no-progress")
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
  coord node update $TREE_ID $NODE_DB_ID \
    --status skipped \
    --result "Stuck: ${reason} — ${detail}"

  skipped_set.add(node.id)

  # Log
  -- Stuck detected --------------------------------
  Node: <node.id>. <node.title>
  Detector: <reason>
  Action: skip and continue
  --------------------------------------------------
```

## Parallel Failure Isolation

When dispatching nodes in parallel:

- One node's failure does **not** block independent siblings
- Failed nodes are handled individually (retry with parameter change → escalate)
- Other parallel dispatches continue unaffected
- Results are collected as each dispatch completes

```
# Fan-out: 3 subagents dispatched in parallel
# Agent 1: success → process result
# Agent 2: failure → retry with error context → success
# Agent 3: success → process result
# All three processed independently
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

## Example

### 3-node parallel dispatch with checkpoints

```
[Goal tree execution starting: 6 nodes (3 ready)]

── Dispatch Round 1 ───────────────────────

| Node | Strategy | Reason |
|------|----------|--------|
| A.1. Add OAuth config | subagent | Single repo, clear spec |
| B.1. Add login UI | subagent | Single repo, clear spec |
| C.1. Update API docs | subagent | Single repo, clear spec |

Ready to dispatch, or want to adjust?

  → User: "go"

  Dispatching 3 subagents in parallel...

── Round 1 Complete ───────────────────────

| Node | Result | Files | Commit |
|------|--------|-------|--------|
| A.1. Add OAuth config | success | 2 files | abc1234 |
| B.1. Add login UI | success | 3 files | def5678 |
| C.1. Update API docs | partial | 1 file | — |

**Next up**: A.2 (depends: A.1 ✓), B.2 (depends: B.1 ✓), C.1 retry

Continuing. Redirect?

  → (no response, continuing)

── Dispatch Round 2 ───────────────────────

| Node | Strategy | Reason |
|------|----------|--------|
| A.2. Implement OAuth flow | subagent | Depends met, clear spec |
| C.1. Update API docs | inline | Retry partial completion |

Ready to dispatch?

  → User: "go, auto-advance from here"

  (checkpoints compressed to status lines for remaining rounds)

── Round 2: A.2 success (4 files), C.1 success (1 file) ──
── Round 3: B.2 success (2 files) ──

## Goal Tree Execution Summary

**Nodes completed**: 5
  - A.1. Add OAuth config [subagent] (abc1234)
  - A.2. Implement OAuth flow [subagent] (ghi9012)
  - B.1. Add login UI [subagent] (def5678)
  - B.2. Add token refresh [subagent] (mno7890)
  - C.1. Update API docs [inline] (jkl3456)

**Dispatch summary**: subagent: 4, inline: 1
**Parallel dispatches**: 1 fan-out (3 parallel)
**Commits**: 5 total
**Termination reason**: all_complete
```

## Integration Points

- **Called by**: start-project (after approval), resume-project (after state recovery)
- **Calls**: select-ready (via `coord tree ready`), dispatch-decision, dispatch-node, update-goal (via `coord node update`)
- **Hands off to**: synthesize (on completion)
- **References**:
  - `task-workflow/references/error-classification.md`
  - `task-workflow/references/retry-with-backoff.md`
  - `references/node-lifecycle.md`
