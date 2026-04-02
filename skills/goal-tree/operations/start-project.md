# Start Project Operation

Entry point for goal tree orchestration. Guides the user from project description through goal tree decomposition, approval, and then — only after approval — guardian issue creation, coordinator tree registration, and execution setup.

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `description` | No | Initial project description (if not provided, start with conversation) |
| `repos` | No | Comma-separated repository names (if known upfront) |
| `guardian_issue` | No | Existing guardian issue reference (e.g., `owner/repo#123`) to use instead of creating new |

## Purpose

Transforms a user's project idea into a structured, executable goal tree. The output is a goal tree registered with the coordinator API and a guardian issue that serves as the durable backend for the project. The coordinator is the single source of truth — no GOAL.md file is written.

## Execution Steps

### 1. Context Gathering

Read guardian-level documentation to understand the project landscape:

Read guardian docs if available. Check for local copies first:

```
Glob(pattern: "~/src/github/<owner>/guardian/{REQUIREMENTS,ARCHITECTURE,PROJECT}.md")
```

If local copies exist, use the Read tool. Otherwise fetch via API:

```bash
gh api repos/<owner>/guardian/contents/REQUIREMENTS.md --jq '.content | @base64d' 2>/dev/null
gh api repos/<owner>/guardian/contents/ARCHITECTURE.md --jq '.content | @base64d' 2>/dev/null
```

If guardian docs exist, use them to ground the decomposition in existing architecture and requirements.

### 2. Project Discussion (MANDATORY)

**Always have this conversation — even if `description` and guardian docs are provided.** Do not skip to decomposition. The user's intent, priorities, and scope boundaries cannot be reliably inferred from documentation alone.

Present what you learned from context gathering, then begin a **focused conversation** to fill in the project spec. The goal is a natural dialogue, not an interrogation.

#### Running Project Spec

The spec table tracks what's been established. Re-display it after each exchange so the user sees the full picture — nothing scrolls away unconfirmed.

```markdown
## Project Spec (Draft)

| Dimension | Status | Value |
|-----------|--------|-------|
| **Objective** | ✓ confirmed | <concrete end-state> |
| **Motivation** | ? needs input | <inferred or blank> |
| **Scope** | ? needs input | <repos, in/out of scope> |
| **Constraints** | — not yet asked | |
| **Success criteria** | — not yet asked | |
```

**Status values**: `✓ confirmed` (user validated), `~ inferred` (from docs, needs confirmation), `? needs input` (no information yet), `— not yet asked`.

#### Conversation rules

1. **Lead with understanding, not questions.** Open by summarizing what you learned from context gathering. Pre-fill dimensions you can infer from docs as `~ inferred`. Then ask 1-2 focused questions about the most important unknowns — let the answers shape what you ask next.
2. **Keep each turn focused.** Ask about one concern at a time, or two when they're closely related. Group questions only when they share enough context that answering them together is natural (e.g., scope + constraints). Never present more than 3 questions in a single turn.
3. **Ask clarifying questions.** When an answer is ambiguous, has multiple interpretations, or implies unstated assumptions, ask a follow-up before marking it `✓ confirmed`. "You said 'lightweight' — do you mean fewer features, or lower resource usage?" This is how the spec gets precise.
4. After each response, update the spec table and re-display. Move answered dimensions to `✓ confirmed`. Surface follow-up questions that arise from the answers — earlier answers often resolve or reshape later questions.
5. If documentation suggests an answer, pre-fill as `~ inferred` with the source noted — the user confirms or overrides.
6. **Block on unanswered questions**: do not proceed to decomposition until all dimensions are `✓ confirmed`. But get there through dialogue, not a checklist dump.
7. If the user's answer contradicts an inference, update immediately — do not defend the inference.
8. Stay at the *what* level — objectives, scope, outcomes. Do not discuss *how* to implement. Implementation design happens later during task dispatch.

**Objective concreteness gate:** The objective must be concrete and falsifiable — not aspirational. "Ship PM Tool MVP" is too vague. "Coordinator replaces GitHub Projects as the primary planning interface" is concrete. If the user gives a broad objective, ask: "Can you make that more specific? What concrete capability or state change marks this as done?"

If `description` is provided, use it as a starting point — not a complete answer. State what you understand from it, ask what's missing or different from your interpretation.

#### Checkpoint: Confirm understanding before decomposition

**Do not proceed to step 4 (Decompose) until the user has confirmed the spec.** After all dimensions are `✓ confirmed`, present the final spec table and ask: "Does this capture the project correctly? Ready for me to decompose into a goal tree?"

This is a hard gate. The decomposition is expensive to revise — get alignment on *what* before investing in *how to break it down*.

#### Progressive refinement during execution

The conversation does not end at decomposition. After the tree is approved and execution begins:

1. **Refinement rounds continue.** As tasks complete and new information emerges, the user may refine scope, reprioritize, or add/remove nodes. These are normal mid-flight adjustments, not failures of the original spec.
2. **Ripe tasks dispatch immediately.** Ongoing conversation about node B does NOT block dispatching node A if A's dependencies are met and spec is clear. Conversation and execution run in parallel — the agent dispatches what's ready while discussing what's uncertain.
3. **New questions surface new nodes.** If a clarifying question reveals work that wasn't in the original tree, add it as a new node via the coordinator. Don't wait for a full re-decomposition.

### 3. Identify Repositories

If `repos` not provided:

1. Check the conversation for repo references
2. Check guardian docs for repo inventory
3. Ask the user which repos are involved

Resolve each repo name to a source path:

```
Glob(pattern: "~/src/github/*/<repo-name>")
```

### 4. Decompose into Goal Tree

Analyze the confirmed project spec and decompose into a hierarchical goal tree.

**Present the decomposition as a tree preview in a normal message — do not use Claude Code plan mode, TodoWrite, or other artifact formats.** The tree preview should contain *only* the tree structure. Do not bundle context summaries, data model designs, key file lists, bootstrap steps, or verification plans into the same message — those belong in later steps or in the node-level specs.

**Do not create any files, issues, or directories in this step.** The decomposition exists only as text in the conversation until the user approves it.

**Decomposition principles**:

1. **Top-down**: Start with 2-5 major sub-goals that map to distinct functional areas
2. **Outcome-oriented and concrete**: Goals describe observable outcomes, not aspirations. Each goal should be falsifiable — you can point at something and say "this is done" or "this is not done".
3. **Implementable leaves**: Leaf tasks should be completable by a single agent in a single session
4. **Cross-repo awareness**: Assign `repos` at the appropriate level — some goals span repos, some are repo-specific
5. **Dependency-aware**: Identify natural ordering (data model before API, API before UI)
6. **Right-sized**: Leaf tasks should be 1-3 files of changes. If larger, decompose further.
7. **What, not how**: Nodes describe *what* to achieve, not *how* to implement. "Add OAuth token validation" is good. "Create a middleware function that calls the OAuth library" is too detailed. Implementation design happens during task dispatch.

**Decomposition checklist**:

- [ ] Each sub-goal represents a distinct capability or concern
- [ ] Leaf tasks have concrete acceptance criteria
- [ ] Dependencies are between siblings only (restructure if cross-subtree deps needed)
- [ ] Repos are assigned where work will happen
- [ ] No task requires human judgment embedded in its spec (escalate those)

### 5. Present for Approval

Display the goal tree to the user in a readable format:

```
## Goal Tree: <title>

A. Sub-goal A [pending]
   A.1. Task A.1 [pending] → repos: api-service
   A.2. Task A.2 [pending] → repos: api-service (depends: A.1)
B. Sub-goal B [pending]
   B.1. Task B.1 [pending] → repos: web-app
   B.2. Task B.2 [pending] → repos: web-app (depends: B.1)

Total: <N> goals, <M> tasks across <R> repos
```

Ask:
- "Does this decomposition look right?"
- "Any tasks to add, remove, or restructure?"
- "Ready to start execution?"

If the user requests changes, revise the decomposition text and re-present. **Do not create files, issues, or directories until the user approves.**

### 6. Create Guardian Issue (or adopt existing)

**Prerequisite: User has approved the goal tree in step 5.**

If `guardian_issue` provided:

```bash
gh issue view <guardian_issue> --json title,body,url
```

Use the existing issue as the project spec. Skip to step 7.

If creating new:

```bash
gh issue create \
  --repo <primary-repo> \
  --title "<project title>" \
  --body "## Project Spec

### Objective
<from conversation>

### Motivation
<from conversation>

### Scope
**Repos**: <repo list>
**In scope**: <what's included>
**Out of scope**: <what's excluded>

### Constraints
<from conversation>

### Success Criteria
<from conversation>

## Progress
<!-- Progress sync managed by coordinator -->
<will be populated automatically>"
```

Record the issue reference (e.g., `pfeff/cursor-rules#213`).

### 7. Register Tree with Coordinator

**Prerequisite: User has approved the goal tree in step 5.**

#### 7.0 Check coordinator availability

Before attempting registration, verify the coordinator is reachable:

```bash
coord health 2>/dev/null
```

If the coordinator is **not available** (connection refused, env vars unset, or the project's first goal is to deploy the coordinator itself):

1. **Tell the user**: "Coordinator is not available. Using TodoWrite for bootstrap tracking. Once AC is running, the remaining tree will be registered with the coordinator."
2. **Create the project directory and CLAUDE.md** (skip to step 8) — this doesn't depend on the coordinator.
3. **Create worktrees using the scripted path** (step 8b) — workspace creation is a local git operation.
4. **Use TodoWrite to track bootstrap tasks** — the subset of nodes needed to get the coordinator running.
5. **After the coordinator is available**, register the full tree (return to step 7a) and transition remaining work to the coordinator-backed execution loop.

This is the **bootstrap mode** — an explicit, documented path, not a silent fallback. The agent should name it when entering it.

Ensure `COORDINATOR_URL` and `COORDINATOR_TOKEN` are set in the environment.

#### 7a. Create the tree

```bash
coord tree create \
  --title "<root goal title>" \
  --context "<problem statement, motivation, scope from conversation>" \
  --guardian-issue "<owner/repo#number>"
```

Parse the response to extract the tree ID (JSON field `id` from the response).

```bash
TREE_ID=$(coord tree create --title "..." --context "..." --guardian-issue "..." | jq -r '.data.id')
```

#### 7b. Create nodes

For each node in the approved decomposition, create it via the coordinator API:

```bash
# Top-level goals (no parent)
coord node create $TREE_ID \
  --node-id "A" \
  --title "Sub-goal A title" \
  --description "Sub-goal description" \
  --status pending \
  --repos "repo-1,repo-2"

# Extract the database ID from the response for use as parent-id
A_DB_ID=$(... | jq -r '.data.id')

# Child tasks (with parent)
coord node create $TREE_ID \
  --node-id "A.1" \
  --title "Task A.1 title" \
  --description "Task description" \
  --status pending \
  --repos "repo-1" \
  --parent-id $A_DB_ID

A1_DB_ID=$(... | jq -r '.data.id')

# If A.2 depends on A.1:
coord node create $TREE_ID \
  --node-id "A.2" \
  --title "Task A.2 title" \
  --description "Task description" \
  --status pending \
  --repos "repo-1" \
  --parent-id $A_DB_ID

A2_DB_ID=$(... | jq -r '.data.id')

coord node add-dependency $TREE_ID $A2_DB_ID --depends-on $A1_DB_ID
```

Repeat for all nodes in the tree. Track the mapping of node IDs (e.g., "A.1") to database IDs for dependency wiring.

### 8. Create Project Directory + CLAUDE.md

```bash
mkdir -p ~/src/work/<project-slug>
```

The project slug is a 2-3 word identifier. Choose it carefully — it's the primary way the user identifies the project in `ls`, tmux session names, and branch prefixes.

**Slug selection rules:**
1. **Derive from the objective, not the title.** If the objective is "Migrate traceability to AC and execute S1," the slug is about the *work*, not the project name. `s1-traceability` is better than `guardian-platform`.
2. **Match the scope.** A slug that's too narrow (`ac-local-prod`) becomes wrong when scope expands. A slug that's too broad (`guardian`) is meaningless. Target the scope of the actual goal tree.
3. **Explain your reasoning.** Tell the user what slug you chose and why. If they don't like it, change it — the directory hasn't been created yet.
4. **Check for existing workspaces.** Run `ls ~/src/work/` to see what's already there. Avoid collisions and maintain continuity with prior sessions when applicable.

Write a CLAUDE.md in the project directory. This file is the agent's primary context on session entry — it must contain enough to operate correctly even if the skill isn't explicitly loaded.

```markdown
# Goal: <root goal title>

## Workflow
This is a goal-tree project. Load the skill before doing anything:
  Read(${CLAUDE_PLUGIN_ROOT}/skills/goal-tree/SKILL.md)

**Hard rules** (always apply — derive behavior from these principles):

**Isolation**: Work in worktrees via scripts. Source repos are read-only.
- Paths in "Repos" below are SOURCE repos. Create a worktree via `create-node-workspace.sh` before editing any file.
- Use scripted paths: `create-node-workspace.sh`, `create-tmuxp-session.sh`. No raw git/tmux commands.

**Phase gates**: Think → confirm → act. The tree is the only path to execution.
- Strategic phases (OODA orient/propose, spec refinement) are text-only. No tool calls or implementation. Capture tactical items as proposed nodes.
- When direction is confirmed, register nodes in the coordinator first — never implement directly. New work → nodes → dispatch pipeline.
- Plan before implementing — every task gets a PLAN.md.
- Read `.github/PULL_REQUEST_TEMPLATE.md` before creating any PR.

**Flow**: Ready work dispatches immediately, in parallel. Be decisive during execution.
- Independent tasks dispatch as parallel subagents. Don't batch-refine before dispatching.
- Auto-continue the OODA loop when ready nodes are exhausted. Don't stop and ask "what next?"

To resume: `/resume-project` or `/goal-tree`
To continue the OODA loop: `/project:next`

## Context
<problem statement, motivation, scope from conversation>

## Guardian
- **Issue**: <owner/repo#number>
- **Spec**: <issue URL>

## Coordinator
- **Tree ID**: <tree-id or "pending — bootstrap mode">
- **API**: $COORDINATOR_URL

## Design Decisions
| Decision | Choice | Rationale |
|----------|--------|-----------|
| <any decisions made during conversation> |

## Repos (SOURCE — do not edit directly)
<list of repos and their source paths>
⚠️ These are source repos on main. Create a node workspace before editing any files.
```

### 8b. Create Session via Scripted Path

**Always use the scripted session creation** — even in bootstrap mode. Do not use raw `tmux new-session`.

```bash
${CLAUDE_PLUGIN_ROOT}/skills/task-workflow/scripts/create-tmuxp-session.sh \
  "<project-slug>" \
  "<project-dir>"
```

This creates a properly configured tmux session with nvim, shell, and claude panes. The session runs *inside* the project directory, which means file operations within the workspace won't trigger excessive approval prompts.

### 9. Transition to Execution

**Normal mode** (coordinator available): Hand off to `operations/execute-tree.md` to begin the orchestration loop. GitHub progress sync is managed automatically by the coordinator.

**Bootstrap mode** (coordinator unavailable): Execute bootstrap tasks using TodoWrite tracking. Each task still gets a node workspace via the scripted path:

```bash
skills/goal-tree/scripts/create-node-workspace.sh \
  "$PROJECT_DIR" "$NODE_ID" "$PROJECT_BRANCH" "$OWNER" <repo1> [repo2 ...]
```

Work in the node workspace, not directly in the source repo. Once the coordinator is running, register the remaining tree (step 7a) and switch to the normal execute-tree loop.

Note: In normal mode, repo worktrees are created per-node at dispatch time by `operations/dispatch-node.md`. In bootstrap mode, they are created here as part of the bootstrap execution.

## Error Handling

| Error | Response |
|-------|----------|
| Guardian repo not accessible | Skip guardian doc reading, proceed with user input |
| `gh issue create` fails | Report error, ask user to create manually, continue with manual issue reference |
| Repo not found in ~/src/github/ | Ask user for correct path |
| User rejects decomposition | Iterate: revise text, re-present — do not create files until approved |
| `coord` CLI fails (connection) | Enter bootstrap mode (step 7.0) — TodoWrite for bootstrap tasks, scripted workspaces, register tree after AC is available |
| `coord tree create` fails | If connection error → bootstrap mode. If other error → report and ask user |
| `coord node create` fails | Report error with node details, retry once |

## Example

### User initiates project

```
User: "I need to add OAuth authentication across our API and web app"

Agent:
  1. Reads guardian REQUIREMENTS.md — finds auth requirements
  2. Conversation (multiple turns):
     Turn 1: "I found auth requirements in guardian docs. Here's what I understand so far:
              [spec table with inferred values]. What's the concrete end-state —
              which OAuth providers do you need?"
     Turn 2: User answers → "Got it. Google and GitHub OAuth.
              [updated spec table]. What's driving the timeline on this?"
     Turn 3: User answers → "Makes sense.
              [updated spec table — all ✓]. Does this capture the project correctly?
              Ready for me to decompose into a goal tree?"
     Turn 4: User confirms → proceed to decomposition
  3. Resolves repo paths
  4. Presents goal tree preview (tree only — no extra context):

     A. OAuth Provider Integration [pending]
        A.1. Add OAuth config and secrets management [pending] → api-service
        A.2. Implement Google OAuth flow [pending] → api-service (depends: A.1)
        A.3. Implement GitHub OAuth flow [pending] → api-service (depends: A.1)
     B. API Auth Middleware [pending]
        B.1. Add OAuth token validation [pending] → api-service (depends: A.2)
        B.2. Add session management [pending] → api-service (depends: B.1)
     C. Frontend Integration [pending]
        C.1. Add login UI [pending] → web-app (depends: B.1)
        C.2. Add token refresh handling [pending] → web-app (depends: C.1)

  5. User approves (or iterates)
  6. Creates guardian issue pfeff/api-service#45
  7. Checks coordinator → available → registers tree + nodes via coord CLI
     (If unavailable → enters bootstrap mode, uses TodoWrite + scripted workspaces)
  8. Creates project directory with CLAUDE.md, session via scripted path
  9. Begins execution
```

## Integration Points

- **Called by**: `/start-project` command
- **Produces**: Coordinator tree + nodes, CLAUDE.md, guardian issue, project directory (no repo worktrees)
- **Hands off to**: `execute-tree.md` for orchestration
- **References**: planning-workflow for problem-validation pattern
