# Discuss-and-Dispatch Operation

Behavioral guidance for dispatching work from an interactive conversation. The main thread discusses a problem with the operator, creates a workspace atomically when signaled, continues refining DESIGN.md as the conversation progresses, and hands off to a child session when the operator says the spec is ready.

## When This Applies

The agent recognizes dispatch intent when the operator uses phrases like:
- "dispatch a workspace for this"
- "create a workspace for this"
- "let's dispatch this"
- "set up a workspace"
- "spin up a node for this"

If the agent is uncertain whether the operator intends to dispatch, ask rather than guess.

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `tree_id` | Yes | Coordinator tree ID (from project CLAUDE.md) |
| `project_dir` | Yes | Project directory path |
| `project_branch` | Yes | Project integration branch |
| Conversation context | Yes | The discussion that produced the dispatch signal |

The agent derives these from conversation context and the project's CLAUDE.md:
- `node_id`: Short identifier for the node (e.g., "A.3", "V")
- `title`: Descriptive title from the conversation
- `description`: Summary of the problem discussed
- `repos`: Which repositories are relevant

## Lifecycle

```
┌─────────────────────────────────────────────────────────┐
│ 1. DISCUSS                                               │
│    Operator and agent discuss the problem.                │
│    No workspace exists yet.                              │
└──────────────────────┬──────────────────────────────────┘
                       │ operator signals "dispatch this"
                       ▼
┌─────────────────────────────────────────────────────────┐
│ 2. CREATE (atomic)                                       │
│    Agent runs discuss-dispatch.sh:                        │
│    coord node create → workspace → DESIGN.md → status    │
│    Node registered in .active-nodes                      │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│ 3. REFINE                                                │
│    Conversation continues. Agent updates DESIGN.md       │
│    incrementally as decisions are made.                   │
│    Main thread writes ONLY to DESIGN.md — no code.       │
└──────────────────────┬──────────────────────────────────┘
                       │ operator says "ready" / "hand it off"
                       ▼
┌─────────────────────────────────────────────────────────┐
│ 4. HAND OFF                                              │
│    Agent outputs attach instructions.                    │
│    Child session starts in the workspace.                │
└──────────────────────┬──────────────────────────────────┘
                       │ child session works autonomously
                       ▼
┌─────────────────────────────────────────────────────────┐
│ 5. COMPLETION (detected, not reported)                   │
│    next-cycle.md observe step checks .active-nodes:      │
│    - PR merged? (gh pr view)                             │
│    - Inbox message? (inbox-write.sh)                     │
│    - Tmux session dead?                                  │
│    When detected: update coordinator, clean .active-nodes│
└─────────────────────────────────────────────────────────┘
```

## Execution Steps

### Step 1: Atomic Setup

When the operator signals dispatch, run the setup script:

```bash
skills/goal-tree/scripts/discuss-dispatch.sh \
  --tree-id "$TREE_ID" \
  --node-id "$NODE_ID" \
  --title "$TITLE" \
  --project-dir "$PROJECT_DIR" \
  --project-branch "$PROJECT_BRANCH" \
  --repos "$REPOS" \
  [--description "$DESCRIPTION"] \
  [--parent-id "$PARENT_DB_ID"]
```

The script performs four operations atomically:
1. `coord node create` — registers the node in the coordinator
2. `create-node-workspace.sh` — creates workspace with repo worktrees
3. Sets node status to `in_progress`
4. Registers node in `$PROJECT_DIR/.active-nodes` for completion tracking

Parse the script output to extract `NODE_DB_ID`, `WORKSPACE_PATH`, and `BRANCH`.

After setup, report to the operator:

```
Workspace created at <WORKSPACE_PATH>.
Continuing discussion — DESIGN.md will update as we go.
```

### Step 2: Populate Initial DESIGN.md

After workspace creation, populate DESIGN.md with content from the conversation so far. Use the standard template:

```markdown
# ${NODE_ID}: ${TITLE}

## Task Information

- **Node ID**: ${NODE_ID}
- **Project**: ${PROJECT_NAME}
- **Branch**: ${PROJECT_BRANCH}/${NODE_ID}
- **Repo**: ${REPOS}

## Problem

${PROBLEM_SUMMARY_FROM_CONVERSATION}

## Design Decisions

${DECISIONS_MADE_SO_FAR_OR_EMPTY}

## Open Questions

${UNRESOLVED_QUESTIONS_OR_EMPTY}

## Acceptance Criteria

${CRITERIA_FROM_CONVERSATION_OR_EMPTY}
```

**Only capture what was explicitly discussed.** Do not extrapolate, speculate, or add requirements that were not part of the conversation.

### Step 3: Incremental Updates

As the conversation continues after workspace creation, update DESIGN.md whenever:
- A design decision is made → add to `## Design Decisions`
- A question is resolved → move from `## Open Questions` to the appropriate section
- Acceptance criteria are agreed → add to `## Acceptance Criteria`
- New context emerges → add to `## Problem` or new sections as appropriate

Use the Edit tool for surgical updates. Do not rewrite DESIGN.md from scratch.

### Step 4: Handoff

When the operator signals readiness ("ready", "hand it off", "spec is done", "go ahead"):

**Signed-off spec gate (before handoff).** Dispatch to a child session is GATED on a signed-off spec note existing. Before outputting attach instructions, verify the spec note for this work carries frontmatter `status: signed-off`:

- Locate the spec note (the Obsidian spec note produced via the obsidian-notes skill, or the workspace DESIGN.md when that is the spec of record).
- Check its frontmatter `status`. If it is not `signed-off` (e.g. still `draft`), **do not hand off**. Report:

  ```
  Dispatch blocked: spec is not signed off (status: <status>).
  Run /operator-interview to complete the spec, set status: signed-off, then say "ready" again.
  ```

- Only when `status: signed-off` is confirmed, proceed with the handoff steps below.

1. Summarize DESIGN.md state — list sections and their completeness
2. Output attach instructions:

```
Spec complete. Attach to the workspace:

  tmux attach -t '<NODE_ID>: <TITLE>'

Or start a new Claude Code session in:

  cd <WORKSPACE_PATH>
```

Do not start the child session automatically. The operator decides when and how.

### Step 5: Completion Detection

This step is NOT performed during the dispatch conversation. It happens later, during the OODA observe step (next-cycle.md).

The `.active-nodes` file tracks dispatched nodes. Each line contains:
```
node_id|db_id|workspace_path|branch|tree_id|timestamp
```

During Quick Observe in next-cycle.md, check each active node for completion signals:

1. **PR merged**: `gh pr list --head <branch> --state merged --json number --jq '.[0].number'`
2. **Inbox message**: Check for messages from the child session via `~/.claude/hooks/inbox-write.sh`
3. **Tmux session dead**: `tmux has-session -t '<node_id>:*' 2>/dev/null` — if this fails, the session is gone

Any single signal is sufficient to flag potential completion. On detection:

```bash
# Update coordinator
coord node update $TREE_ID $DB_ID --status completed --result "PR merged"

# Remove from .active-nodes
sed -i '' "/^${NODE_ID}|/d" "$PROJECT_DIR/.active-nodes"
```

**Constraint**: This is a lightweight check in the observe step, not a polling loop or background monitor. It runs once per OODA cycle.

## Hard Rules

1. **After workspace exists, main thread writes ONLY to DESIGN.md.** No implementation, no code changes, no PRs, no commits on the main thread for this node. If you catch yourself about to write code, stop and note it in DESIGN.md instead.

2. **DESIGN.md captures only what was explicitly discussed.** Do not add requirements, architecture decisions, or acceptance criteria that the operator did not discuss. No speculation, no "nice to have" additions, no extrapolation.

3. **Handoff is explicit.** The child session does not start until the operator says the spec is ready. Creating the workspace does NOT mean work begins. The workspace is the spec, not the work.

4. **Completion detection is passive.** Check during OODA observe, not actively. Never poll or set up background monitors.

## Error Handling

| Error | Response |
|-------|----------|
| Script fails at step 1 (coord create) | Report failure, nothing was created |
| Script fails at step 2 (workspace) | Report partial state: node created but no workspace. Operator can retry workspace creation manually |
| Script fails at step 3 (status update) | Report partial state: node and workspace exist, status not updated. Operator can update manually via `coord node update` |
| Coordinator API unreachable | Offer to create workspace without coordinator registration. Note the gap for manual fixup |
| Operator never says "ready" | Conversation ends naturally. Workspace exists with whatever DESIGN.md state was reached. Child session can be started later |
| Child session abandoned (no PR, dead tmux) | Completion detection flags it. Operator decides whether to retry or close |

## Relationship to Other Operations

- **dispatch-node.md**: Dispatches nodes from execute-tree (automated pipeline). discuss-dispatch is for interactive, conversation-driven dispatch.
- **dispatch-task-cmd.md**: User command to dispatch existing GOAL.md nodes. discuss-dispatch creates new nodes from conversation.
- **next-cycle.md**: Consumes `.active-nodes` during Quick Observe to detect completion.

This operation does NOT modify dispatch-node.md or dispatch-task-cmd.md. They serve different entry points into the same downstream pipeline.
