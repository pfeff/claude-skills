# Fan-Out Operation

Spawns N subagents in parallel via the Task tool, collects all results, handles partial failures, and returns aggregated output.

**Requirements**: Caller must provide a list of agent specifications (prompt + description per agent).

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `agents` | Yes | List of agent specs, each with `prompt` (string) and `description` (short label) |
| `result_format` | No | `structured` (expect RESULT_START/END markers) or `raw` (return full response text). Default: `raw` |

## Purpose

Generalizes the parallel dispatch pattern (e.g., review skill's Step 5: spawn 4 agents, collect results, synthesize) into a reusable operation. Any skill that needs to run independent work streams concurrently can use this instead of reimplementing parallel Task tool invocation and result collection.

Fan-out differs from `dispatch-task.md` in that it:
- Spawns multiple agents simultaneously (not sequential retry)
- Does not retry individual failures (caller decides how to handle)
- Returns all results (successes and failures) for the caller to aggregate

## Execution Steps

### 1. Validate Inputs

Verify the `agents` list is non-empty. Each entry must have `prompt` and `description`.

If validation fails, return an error to the caller immediately.

### 2. Spawn All Agents in Parallel

Issue all Task tool calls in a **single message** so they execute concurrently:

```
For each agent in agents:
  Task(
    subagent_type: "general-purpose",
    prompt: agent.prompt,
    description: agent.description
  )
```

All calls must be in the same tool-use block to ensure parallel execution.

### 3. Collect Results

As each agent returns, record its result:

```
results = []
for each agent response:
  result = {
    description: agent.description,
    status: "success" | "failure",
    response: <full agent response text>
  }

  if result_format == "structured":
    # Parse RESULT_START/END markers (same logic as dispatch-task step 2)
    if markers found:
      result.parsed = <parsed key-value pairs>
      result.status = result.parsed.status
    else:
      result.status = "failure"
      result.parsed = { issues: <full response text> }

  results.append(result)
```

### 4. Assess Outcome

Classify the overall fan-out result:

| Condition | Overall Status |
|-----------|---------------|
| All agents succeeded | `all_succeeded` |
| Some agents succeeded, some failed | `partial` |
| All agents failed | `all_failed` |

### 5. Return Aggregated Results

Return to the caller:

```
fan_out_result:
  status: all_succeeded | partial | all_failed
  total: <number of agents>
  succeeded: <count>
  failed: <count>
  results:
    - description: "Agent 1 label"
      status: success
      response: "..." (or parsed: {...} if structured)
    - description: "Agent 2 label"
      status: failure
      response: "..."
```

The caller is responsible for synthesizing results (e.g., merging findings, generating a report). This operation only handles dispatch and collection.

## Error Handling

| Error | Response |
|-------|----------|
| Empty agents list | Return error immediately, do not spawn |
| Individual agent error (Task tool failure) | Mark that agent as `status: failure`, continue collecting others |
| Individual agent timeout | Mark as `status: failure` with `response: "agent timed out"` |
| All agents fail | Return `all_failed` status — caller decides whether to retry, fall back, or abort |

## Example

### Review skill: 4 parallel review agents

```
Caller provides:
  agents:
    - prompt: "<security agent prompt + diff>", description: "Review: security"
    - prompt: "<simplicity agent prompt + diff>", description: "Review: simplicity"
    - prompt: "<architecture agent prompt + diff>", description: "Review: architecture"
    - prompt: "<correctness agent prompt + diff>", description: "Review: correctness"
  result_format: raw

Step 2: Spawn all 4 agents in a single tool-use block

Step 3: Collect results
  Agent 1 (security): success, response: "## Security Review\n..."
  Agent 2 (simplicity): success, response: "## Simplicity Review\n..."
  Agent 3 (architecture): success, response: "## Architecture Review\n..."
  Agent 4 (correctness): success, response: "## Correctness Review\n..."

Step 4: Assess → all_succeeded

Step 5: Return
  fan_out_result:
    status: all_succeeded
    total: 4
    succeeded: 4
    failed: 0
    results: [... all 4 results ...]

Caller (review skill Step 6) synthesizes findings from all 4 responses.
```

### Sprint-review: 3 parallel analysis tasks with partial failure

```
Caller provides:
  agents:
    - prompt: "<classify OKRs prompt + data>", description: "Classify OKRs"
    - prompt: "<reconcile board prompt + data>", description: "Reconcile board"
    - prompt: "<check workspaces prompt + data>", description: "Check workspaces"
  result_format: structured

Step 2: Spawn 3 agents in parallel

Step 3: Collect results
  Agent 1 (OKRs): success, parsed: { status: success, ... }
  Agent 2 (board): success, parsed: { status: success, ... }
  Agent 3 (workspaces): failure, parsed: { status: failure, issues: "gh api rate limited" }

Step 4: Assess → partial

Step 5: Return
  fan_out_result:
    status: partial
    total: 3
    succeeded: 2
    failed: 1
    results: [... all 3 results ...]

Caller decides: proceed with 2 successful results, note workspace check was skipped.
```

## Integration Points

- **Called by**: review (Step 5), sprint-review (Steps 2-4), implement-feature (Phase 2 parallel), analyze-project (parallel agents)
- **Depends on**: Task tool (subagent_type: general-purpose)
- **Related**: `dispatch-task.md` for single-task dispatch with retry; fan-out is for concurrent independent work
- **Reference**: See `references/subagent-dispatch.md` for the dispatch contract and RESULT_START/END format spec
