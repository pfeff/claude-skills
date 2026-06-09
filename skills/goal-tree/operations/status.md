# Status Operation

Observe phase utility. Pulls current state from AC and strategic meta-repo docs, presents a capability/performance/gap narrative.

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `project_dir` | No | Project directory (default: current working directory) |

## Purpose

Quick situational awareness without entering the execution loop. Answers: "Where are we?" in terms of capabilities, performance, and gaps — not PM milestones.

## Execution Steps

### 1. Locate Project Context

Read CLAUDE.md from the project directory. Extract tree ID and repo paths.

### 2. Gather State

In parallel:

```
# AC tree state
ac_node_query(action="get", tree_id=$TREE_ID)

# Strategic meta-repo docs
Read ~/src/github/<owner>/<strategic-repo>/PROJECT.md
```

### 3. Synthesize Narrative

Present a 3-section narrative:

**Capabilities**: What can the system do now? What can't it do? Derive from:
- Completed nodes and their results
- KR status from PROJECT.md (look for "Status: Complete" vs "TODO" vs "In Progress")

**Performance**: Are metrics moving? Derive from:
- Measurement data in PROJECT.md (baselines, sprint comparisons)
- Flag stale measurements: if a "Next measurement" date has passed, say so
- Trend, not just numbers: "improved from X to Y" or "no data since [date]"

**Gaps**: What's broken, missing, or blocking? Derive from:
- Blocked/skipped nodes in the tree
- KRs with status TODO that have unmet prerequisites
- Gaps section from project CLAUDE.md

### 4. Surface One Strategic Question (if applicable)

If the data reveals something worth discussing — a stale metric, a completed capability that changes priorities, a gap that's grown — surface it as a single question. Not a list. Not every time.

### 5. Stop

Do not enter the execution loop. The operator decides what to do next.

## Example Output

```
**Capability snapshot**: Agents can complete simple tasks autonomously (12min
time-to-merge). Multi-task orchestration exists but defaults to batch execution
without feedback. Strategy refinement requires manual doc editing — no
conversational path yet.

**Performance**: Autonomous task completion demonstrated but not sustained at
≥1/week. No measurement since Sprint 2 (Feb 28). Dogfooding AC blocked by
friction — token expiry, no OODA loop.

**Gap**: The system can execute but can't evaluate whether it's executing the
right things. OODA control loop design is complete; implementation in progress.

Sprint 3 measurement is overdue. Want to run it, or deprioritize?
```

## Integration Points

- **Called by**: `/status` command
- **Calls**: `ac_node_query` MCP tool, Read (strategic meta-repo docs)
- **Does not call**: execute-tree, dispatch-node
