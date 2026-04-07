# Node Lifecycle Reference

State machine, completion rules, and dependency resolution for goal tree nodes.

## State Machine

```
                    ┌──────────────┐
                    │   pending    │
                    └──────┬───────┘
                           │ selected for work
                           ▼
                    ┌──────────────┐
            ┌───── │ in_progress  │ ─────┐──────────┐
            │      └──────────────┘      │          │
            │              │             │          │
            ▼              ▼             ▼          ▼
     ┌───────────┐  ┌───────────┐ ┌──────────┐ ┌────────┐
     │ completed │  │  blocked  │ │  skipped  │ │pending │
     └───────────┘  └─────┬─────┘ └────┬──────┘ │(reset) │
                          │             │        └────────┘
                          │ resolved    │ resume
                          ▼             ▼
                    ┌──────────────┐
                    │   pending    │
                    └──────────────┘
```

## State Transitions

| From | To | Trigger | Condition |
|------|----|---------|-----------|
| `pending` | `in_progress` | Node selected for dispatch | Dependencies met, not in skip list |
| `in_progress` | `completed` | Work finished | Task: all acceptance criteria met. Goal: all children completed. |
| `in_progress` | `blocked` | External dependency found | Blocker discovered during implementation |
| `in_progress` | `skipped` | Stuck detection fires | No-progress, repeated failure, or turn budget exceeded |
| `in_progress` | `pending` | Reset on resume | Session resume resets in_progress nodes (they weren't completed) |
| `blocked` | `pending` | Blocker resolved | External dependency cleared by user or other task |
| `skipped` | `pending` | Session resume | Skipped nodes are retryable in new sessions |

### Invalid Transitions

- `completed` → any: completed is terminal
- `pending` → `completed`: must pass through `in_progress`
- `pending` → `blocked`: must discover blocker during work
- `blocked` → `completed`: must pass through `pending` → `in_progress`

## Completion Rules

### Task Completion

A **task** (leaf node) is complete when:

1. All acceptance criteria checkboxes are checked (`- [x]`)
2. A `**result**` field has been written with an outcome summary
3. A Results Log entry has been appended

The dispatch handler (subagent, sub-session, or inline) is responsible for:
- Implementing the work
- Verifying acceptance criteria
- Reporting the structured result

### Goal Completion

A **goal** (non-leaf node) is complete when:

```
all(child.status in {completed, skipped} for child in goal.children)
AND
any(child.status == completed for child in goal.children)
```

In other words: all children must be resolved (completed or skipped), and at least one must be completed (a goal where all children are skipped is itself skipped, not completed).

### Goal Status Derivation

Goal status is derived from children, not set directly:

| Children State | Goal Status |
|---------------|-------------|
| All completed | `completed` |
| Mix of completed and skipped | `completed` |
| All skipped | `skipped` |
| All blocked or skipped (none completed, none pending) | `blocked` |
| Any in_progress | `in_progress` |
| Any pending (with no in_progress) | `pending` |

## Dependency Resolution

### Dependency Scope

Dependencies are expressed via `**depends_on**` and reference **sibling** node IDs (same parent level). Cross-subtree dependencies are not supported — restructure the tree instead.

### Ready Node Selection

A node is **ready** for dispatch when:

```python
node.status == "pending"
AND all(dep.status == "completed" for dep in node.depends_on)
AND node.id not in skipped_set  # from stuck detection in current session
```

### Dependency Checking Algorithm

```
function is_ready(node, tree, skipped_set):
    if node.status != "pending":
        return false
    if node.id in skipped_set:
        return false
    for dep_id in node.depends_on:
        dep = tree.find(dep_id)
        if dep.status != "completed":
            return false
    return true
```

### Implicit Dependencies

Children depend on their parent being decomposed (the tree structure itself is a dependency). A child cannot be dispatched until its parent exists in the tree. This is handled naturally by decomposition happening before execution.

## Blocked Propagation

When a node becomes blocked:

1. Mark the node `[status: blocked]`
2. Check all nodes that depend on it:
   - If they are `pending` and this was their only unmet dependency → they stay `pending` (dependency now unmet)
   - No cascading status changes — dependents remain `pending` and won't pass the ready check
3. Check the parent goal:
   - If all remaining children are `blocked` or `skipped` → parent becomes `blocked`
   - If some children are still `pending` or `in_progress` → parent status unchanged

### Unblocking

When a blocker is resolved (by user or other work):

1. Mark the node `[status: pending]` (re-enters the queue)
2. No cascading changes needed — the normal ready check will pick it up

## Skipped Node Handling

### During Session

When stuck detection fires:

1. Mark node `[status: skipped]`
2. Add to session-local `skipped_set` (prevents re-selection)
3. Record in Results Log with `Status: skipped` and detector details
4. Continue to next ready node

### On Resume

The `skipped_set` is not persisted — it's session-local. On session resume:

1. Skipped nodes remain `[status: skipped]` in GOAL.md
2. `resume-project` resets them to `[status: pending]`
3. They re-enter the queue and can be retried

### Permanent Skip

To permanently skip a node, the user must manually set it and it stays as `skipped`. The resume operation only resets nodes that were skipped by stuck detection (not user-directed skips).

## Parallel Execution Safety

When multiple nodes execute in parallel (subagents or sub-sessions):

1. **Independent nodes only**: Only nodes with no dependencies between them run in parallel
2. **GOAL.md updates are sequential**: The root session serializes all GOAL.md writes
3. **Branch isolation**: Parallel tasks work on separate sub-branches (see `operations/branch-management.md`)
4. **Failure isolation**: One node's failure does not affect independent siblings — they continue
5. **Result collection**: Root session waits for all parallel dispatches, then updates GOAL.md in batch

## Integration Points

- **select-ready.md**: Uses ready check algorithm to find dispatchable nodes
- **update-goal.md**: Applies state transitions and completion rules
- **execute-tree.md**: Implements the orchestration loop with these lifecycle rules
- **resume-project.md**: Applies resume reset logic
- **dispatch-node.md**: Reports results that trigger completion transitions
