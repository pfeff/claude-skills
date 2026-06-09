# Resume Project Operation

Re-enters a goal tree project with an OODA preamble. Recovers state, presents a capability/performance/gap narrative, and enters conversation before execution.

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `project_dir` | No | Project directory (default: current working directory) |

## Purpose

Primary entry point for ongoing work. Starts with Observe/Orient (what's the state, what does it mean) before entering the execution loop. The preamble is not a gate — if the operator says "go", the loop runs autonomously. But it ensures every session starts grounded in strategic context.

## Execution Steps

### 1. Locate Project Context

Read the project CLAUDE.md to find the tree ID, repo paths, and coordinator details.

Search order:
1. Current directory
2. `${project_dir}/CLAUDE.md`
3. Parent directory (if in a repo subdirectory)

If not found: "No project CLAUDE.md found. Use `/start-project` to create a new project."

### 2. Observe

Gather state in parallel:

```bash
coord tree show $TREE_ID
```

```
Read ~/src/github/<owner>/<strategic-repo>/PROJECT.md
```

Parse the tree response. Categorize nodes by status:
- completed: what's done (check results for what capability was gained)
- in_progress: stale from previous session — will be reset to pending
- pending: available work
- blocked/skipped: problems to surface

### 3. Present Preamble

Present a **capability/performance/gap narrative** — not PM artifacts or node counts.

**Capabilities**: What can the system do now based on completed work and KR status? What can't it do yet?

**Performance**: Metrics trend from PROJECT.md — improving, stalled, regressing? Flag stale measurements (if "Next measurement" date has passed, say so). Interpret, don't just report.

**Gaps**: What's broken, blocked, or missing? Derive from blocked nodes, TODO KRs, and project CLAUDE.md gaps section.

Surface **one strategic question** if the data warrants it. Not a list of everything that might need attention.

### 4. Orient

Map current state to mission/OKRs:
- Is current tree work aligned with highest-priority strategic objectives?
- Have completed capabilities changed what's most valuable next?
- Any drift since last session?

This can be woven into the preamble or presented as a follow-up — keep it conversational.

### 5. Conversation Handoff

The operator decides:

| Response | Action |
|----------|--------|
| "go" / "continue" / "looks good" | Reset stale nodes, enter execute-tree loop |
| Discusses strategy | Stay in conversation, refine understanding |
| Requests tree changes | Add/remove/restructure nodes via coord CLI |
| Requests doc changes | Capture as commits via worktree |
| Asks a question | Answer, then re-offer handoff |

### 6. Reset Stale Nodes

Before entering the loop, reset nodes left in_progress or skipped from the previous session:

```bash
# Reset in_progress nodes to pending
coord node update $TREE_ID $NODE_DB_ID --status pending

# Reset skipped nodes (retryable in new session)
coord node update $TREE_ID $NODE_DB_ID --status pending
```

### 7. Check Sub-Sessions

Look for tmux sessions still running from previous execution:

```bash
tmux list-sessions -F "#{session_name}" 2>/dev/null
```

Filter for project slug. For each:

| Session State | Action |
|---------------|--------|
| Running, coordinator shows progress | Reconnect — monitor for completion |
| Running, no progress | Kill and reset node to pending |
| Not found, node was in_progress | Already reset in step 6 |

### 8. Enter Execution Loop

```
Load: operations/execute-tree.md
execute_tree(tree_id, project_dir, project_branch)
```

## Error Handling

| Error | Response |
|-------|----------|
| Project CLAUDE.md not found | Direct to `/start-project` |
| Tree not found in coordinator | Report error: tree may have been deleted |
| Coordinator unreachable | Report connection failure, suggest checking AC |
| Node workspace missing | Re-create from source repo at dispatch time |

## Example

```
**Capability snapshot**: Agents can complete simple tasks autonomously (12min
time-to-merge). Token management now supports prod instances (env-file flag +
refresh endpoint). Multi-task orchestration has OODA preamble but execute-tree
loop unchanged.

**Performance**: No measurement since Sprint 2 (Feb 28). Autonomous completion
rate unknown — need to re-run baseline script.

**Gap**: Execute-tree still runs as autonomous batch loop without strategic
feedback channel. New operations (status, orient) written but not wired into
SKILL.md commands yet.

The design work is done — implementation is the bottleneck. Continue wiring
up the skill files, or reprioritize?
```

## Integration Points

- **Called by**: `/resume-project` command
- **Calls**: `coord tree show`, Read (strategic meta-repo docs), execute-tree
- **References**: `operations/status.md` (preamble shares observation logic)
