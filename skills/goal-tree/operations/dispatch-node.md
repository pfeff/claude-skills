# Dispatch Node Operation

Executes the chosen dispatch strategy for a node. Handles subagent invocation, sub-session creation, container dispatch, inline execution, and escalation.

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `node` | Yes | The node to dispatch (includes db_id, node_id, title, etc.) |
| `decision` | Yes | Output from dispatch-decision (strategy + context) |
| `tree` | Yes | Full parsed goal tree (from coordinator) |
| `tree_id` | Yes | Coordinator tree ID |
| `project_dir` | Yes | Project directory path |
| `project_branch` | Yes | Project branch name |
| `prior_failures` | No | List of prior failure telemetry records (populated on retry dispatches). Each entry contains: attempt_number, failure_reason, parameter_change_applied. |
| `additional_prompt` | No | Extra context appended to dispatch prompt on retry (error details, approach hints). |

## Output

```
dispatch_result:
  status: "success" | "partial" | "failure" | "blocked" | "escalated"
  node_id: "<node ID>"
  files_modified: [list of paths]
  changes_summary: "<description>"
  commits: [list of hashes]
  acceptance_criteria_met: [list of met criteria]
  issues: "<problems encountered>" | "none"
  dispatch_method: "subagent" | "sub-session" | "container" | "inline" | "escalated"
```

## Node Workspace Setup

**Before any dispatch strategy**, create a node workspace with repo worktrees. This applies to all strategies (subagent, inline, sub-session).

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

During any dispatch strategy (subagent, inline, sub-session), the agent may encounter something unexpected — a missing API, a contradictory schema, an ambiguous requirement. These are **assumption boundaries**: moments where the agent is about to act on an uncertain belief.

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

For subagent dispatches, assumption boundaries are handled by the subagent returning `status: blocked` with the question, rather than guessing and proceeding.

## Strategy Execution

### Subagent Dispatch

Reuses the subagent contract from `task-workflow/references/subagent-dispatch.md`.

#### 1. Assemble Prompt

Build a self-contained prompt for the subagent:

```
You are implementing a single task in a goal-tree project. Make the code changes described below, run tests to verify, and report your results.

Do not commit changes. Do not create PRs. Do not modify files outside the scope of this task.

## Task

**ID**: ${NODE_ID}
**Subject**: ${NODE_TITLE}
**Description**: ${NODE_DESCRIPTION}

## Acceptance Criteria

${ACCEPTANCE_CRITERIA_AS_CHECKLIST}

Each criterion above is a specific, verifiable statement. Your output will be evaluated against these criteria by the parent session (LLM-as-judge). For each criterion, the evaluator will determine pass/fail based on your actual changes.

## Goal Tree Context

This task is part of a larger project:
- **Project**: ${ROOT_GOAL_TITLE}
- **Parent goal**: ${PARENT_GOAL_TITLE}
- **Position**: ${NODE_ID} of ${TOTAL_NODES} nodes

## Design Decisions

${RELEVANT_DESIGN_DECISIONS}

## Prior Task Results

${DEPENDENCY_RESULTS_LOG_ENTRIES}

(If empty: "This is the first task — no prior context.")

## Working Directory

- Node workspace: ${NODE_DIR}
- Repository: ${NODE_DIR}/${REPO}

## Important Context

The coordinator API manages this project's goal tree. The tree ID is ${TREE_ID} and this node's database ID is ${NODE_DB_ID}. The `coord` CLI is available for querying project state if needed.

## Instructions

1. Read the planning-workflow skill and run it for this task:
   Read(~/.claude/skills/planning-workflow/SKILL.md)
2. Implement the changes following the generated plan
3. If a test runner is available, run tests
4. If a linter is available, run lint
5. If tests or lint fail, attempt to fix (up to 2 retries)

## Required Output Format

When finished, report your results in this exact format:

RESULT_START
status: success | partial | failure
files_modified:
  - path/to/file1.md
  - path/to/file2.md
changes_summary: |
  <1-3 sentence description of what was changed and why>
test_result: pass | fail | no_tests | skipped
lint_result: pass | fail | no_linter | skipped
acceptance_criteria_met:
  - "criterion 1 text"
  - "criterion 2 text"
issues: |
  <any problems encountered, or "none">
RESULT_END
```

#### 2. Dispatch via Agent Tool

The subagent works directly in the node workspace. The node branch provides isolation — no `isolation: "worktree"` needed.

```
Agent(
  subagent_type: "general-purpose",
  description: "Implement: ${NODE_TITLE}",
  prompt: <assembled prompt>
)
```

#### 3. Parse Result

Follow parsing rules from `task-workflow/references/subagent-dispatch.md`:

1. Find `RESULT_START`/`RESULT_END` markers
2. Parse YAML-like key-value pairs
3. If no markers found → treat as `status: failure`

#### 4. Handle Failure

| Attempt | Action |
|---------|--------|
| First failure | Retry with failure context appended to prompt |
| Second failure | Return `status: failure` with `dispatch_method: "subagent"` — caller falls back to inline |

### Container Dispatch

For leaf tasks where repos have Taskfile and Docker is available. Runs inside Ralph's sandboxed devcontainer — eliminates permission prompts entirely.

#### 1. Invoke Wrapper Script

```bash
skills/goal-tree/scripts/dispatch-container.sh "${NODE_DIR}"
```

The wrapper script handles the full lifecycle:
1. Translates `DESIGN.md` → `specs/task.md` (L1→L0 spec format)
2. Generates `.ralph/gates.md` from each repo's `Taskfile.yml`
3. Generates `.ralph/workspace.md` for multi-repo nodes
4. Copies `PROMPT_plan.md` and `PROMPT_build.md` from Ralph-wiggum skill
5. Invokes `run-container.sh` with plan then build phases
6. Parses results into `dispatch_result` JSON

#### 2. Parse Result

The wrapper outputs structured JSON to stdout. Parse it directly:

```
dispatch_result:
  status: <from wrapper JSON>
  node_id: <from wrapper JSON>
  files_modified: <from wrapper JSON>
  changes_summary: <from wrapper JSON>
  commits: <from wrapper JSON>
  acceptance_criteria_met: <from wrapper JSON>
  issues: <from wrapper JSON>
  dispatch_method: "container"
```

#### 3. Handle Failure

| Status | Action |
|--------|--------|
| `success` | All tasks completed — proceed to post-implementation lifecycle |
| `partial` | Some tasks completed — return to caller for retry decision |
| `blocked` | Ralph wrote BLOCKERS.md — return `status: blocked` with blocker text |
| `failure` | Max iterations or error — return `status: failure` for caller retry loop |

On failure, the caller (execute-tree) may retry with parameter changes or fall back to subagent/inline.

#### 4. Dry Run

For validation without execution, use `--dry-run`:

```bash
skills/goal-tree/scripts/dispatch-container.sh "${NODE_DIR}" --dry-run
```

This prepares the workspace (specs, gates, prompts) without invoking the container. Useful for verifying the translation pipeline.

### Sub-Session Dispatch

For deep subtrees that exceed subagent capacity.

#### 1. Write Workspace Context

Write CLAUDE.md for the sub-session in the node workspace with coordinator context:

- Project context
- Subtree scope
- Tree ID and node DB ID for coordinator API access
- Instructions to run planning-workflow for each leaf task
- Auto-advance configuration

#### 2. Spawn Session

```bash
~/.claude/skills/task-workflow/scripts/create-tmuxp-session.sh \
  "${NODE_ID}: ${NODE_TITLE}" \
  "${NODE_DIR}"
```

#### 3. Monitor

The root session checks sub-session status periodically:

```bash
tmux has-session -t "${NODE_ID}" 2>/dev/null
```

```bash
# Check coordinator for node completion
coord tree show $TREE_ID | jq ".data.nodes[] | select(.node_id == \"${NODE_ID}\") | .status"
```

#### 4. Collect Results

When the sub-session completes:

1. Query coordinator for node status and results
2. Return structured result (branch merging happens during synthesis)

### Inline Execution

The root session implements the task directly in the node workspace.

#### 1. Read Context

```
Read: DESIGN.md (relevant requirements)
Read: dependency results from coordinator (query dependent nodes)
```

#### 2. Run Planning Workflow (Gate)

Run planning-workflow for the task. This is a **hard gate** — do not proceed to implementation without a plan.

```
Read: ~/.claude/skills/planning-workflow/SKILL.md
```

Run the planning pipeline (problem-validation → plan-generation) scoped to this task.

**Verification:** Confirm PLAN.md was created or updated with a plan for this node before proceeding. If planning-workflow was skipped or produced no plan, stop and report `status: failure` with `issues: "planning-workflow gate not satisfied"`.

#### 3. Implement

Follow the generated plan. Execute in the node workspace directory (`${NODE_DIR}/${REPO}`).

#### 4. Validate

Run tests and lint (same as validate-implementation from task-workflow).

#### 5. Report Result

Build the dispatch_result from the inline implementation:

```
dispatch_result:
  status: "success"
  node_id: "<node ID>"
  files_modified: <from git diff --name-only>
  changes_summary: "<inline summary>"
  commits: []  # root session commits separately
  dispatch_method: "inline"
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

## Failure Handling

Dispatch-node returns failures to execute-tree, which owns the retry loop (step 4). Dispatch-node performs one internal retry for subagents (prompt enrichment), then returns `status: failure` for execute-tree to handle via its retry-with-parameter-change loop.

### Subagent Failure Chain

```
Subagent attempt 1 → failure
  → Retry with failure context (attempt 2) → failure
    → Return to caller with status: failure
      → Caller (execute-tree) retry loop:
        → Attempt 2: re-dispatch with error context → failure
        → Attempt 3: re-dispatch with alternative approach hint → failure
        → Escalate to human with full failure log
```

When `prior_failures` is provided (retry dispatch from execute-tree), append the failure history to the subagent prompt:

```
## Prior Failure History

This task has been attempted ${len(prior_failures)} time(s) previously.

<for each prior failure>
### Attempt ${attempt.attempt_number}
- **Failure reason**: ${attempt.failure_reason}
- **Parameter change applied**: ${attempt.parameter_change_applied}

${additional_prompt}
```

### Container Failure

```
Container dispatch returns non-success status
  → status: "blocked" → return to caller with blocker text
  → status: "partial" → return to caller for retry decision
  → status: "failure" → return to caller
    → Caller (execute-tree) retry loop:
      → Attempt 2: re-dispatch as container with adjusted spec context → failure
      → Attempt 3: fall back to subagent strategy → failure
      → Escalate to human with full failure log
```

Container dispatch does not perform internal retries — Ralph's loop already iterates up to `MAX_ITER` (default 20). If the container exits with failure, the task exhausted Ralph's retry budget.

### Sub-Session Failure

```
Sub-session completes with failures
  → Root session queries coordinator for node status
  → Evaluates: can remaining failures be fixed inline?
    → Yes: fix inline in node workspace
    → No: return status: failure → execute-tree retry loop handles retries
```

### Failure Telemetry

Each dispatch failure emits a structured telemetry record (see execute-tree step 4 "Failure Telemetry Record" for schema). Dispatch-node populates the `dispatch_method` and `failure_reason` fields; execute-tree adds the retry-loop fields (`attempt_number`, `parameter_change_applied`, `parameter_change_strategy`).

### Error Classification

For transient errors during dispatch (API rate limits, network issues):

1. Load `task-workflow/references/error-classification.md`
2. Classify the error
3. If transient: retry with backoff per `task-workflow/references/retry-with-backoff.md`
4. If permanent: return failure immediately

## Post-Implementation Lifecycle

After a node's implementation is complete (any dispatch strategy), the root session drives the full landing sequence. Do not stop after committing — continue through the entire pipeline:

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
Review sub-session or subagent output for lessons worth capturing. Look for:

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

If running as a sub-session, notify the parent's inbox:
```bash
~/.claude/hooks/inbox-write.sh sub-session "<node_id>" "<node_title>: PR ready for review"
```

> **Review gate**: The `PR Review` CI check requires `APPROVED` state. Child sessions (GitHub App) cannot self-approve. The operator must `gh pr review --approve` before the PR can merge.

### 8. Post-Merge (operator or parent session only)
After the operator approves and merges:

- **Deploy** (when applicable): If the node targets a running service (e.g., AC), upgrade the service after merge.
- **Update Coordinator**: Report the result to the coordinator and mark the node complete. This happens in execute-tree step 4.

**Key principle**: Child sessions drive the pipeline up to PR creation and review request, then yield control. The operator holds the merge gate.

## Integration Points

- **Called by**: execute-tree (step 3)
- **Depends on**: dispatch-decision output, Agent tool, task-workflow scripts, `coord` CLI, `dispatch-container.sh`
- **References**:
  - `task-workflow/references/subagent-dispatch.md` — dispatch contract and result format
  - `task-workflow/operations/dispatch-task.md` — mechanical dispatch plumbing
  - `task-workflow/references/error-classification.md` — error taxonomy
  - `task-workflow/references/retry-with-backoff.md` — backoff algorithm
  - `operations/branch-management.md` — node workspace creation
  - `scripts/dispatch-container.sh` — container dispatch wrapper (DESIGN.md → Ralph)
