---
name: goal-tree
description: Orchestrate multi-task projects as hierarchical goal trees. Use when a project spans multiple tasks, repos, or sessions and needs coordinated decomposition, parallel dispatch, and synthesis. Sits above task-workflow — feeds work into workspaces, does not replace them.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Agent
  - AskUserQuestion
allowed-prompts:
  - tool: Bash
    prompt: fetch GitHub issues
  - tool: Bash
    prompt: create GitHub issues
  - tool: Bash
    prompt: update GitHub issues
  - tool: Bash
    prompt: create tmux sessions
  - tool: Bash
    prompt: list tmux sessions
  - tool: Bash
    prompt: check tmux session existence
  - tool: Bash
    prompt: kill tmux sessions
  - tool: Bash
    prompt: check git status
  - tool: Bash
    prompt: create git worktrees
  - tool: Bash
    prompt: remove git worktrees
  - tool: Bash
    prompt: merge git branches
  - tool: Bash
    prompt: create workspace from script
  - tool: Bash
    prompt: create node workspace via script
  - tool: Bash
    prompt: merge node branch via script
  - tool: Bash
    prompt: synthesize node via script
  - tool: Bash
    prompt: check workspace state via script
  - tool: Bash
    prompt: cleanup worktrees via script
  - tool: Bash
    prompt: cleanup sessions via script
  - tool: Bash
    prompt: close project via script
  - tool: Bash
    prompt: create GitHub PRs
  - tool: Bash
    prompt: sleep for backoff between retries
  - tool: Bash
    prompt: query coordinator API via coord CLI
  - tool: Bash
    prompt: create coordinator tree and nodes
  - tool: Bash
    prompt: update coordinator node status
  - tool: Bash
    prompt: create node via discuss-dispatch script
  - tool: Bash
    prompt: check active nodes for completion
version: 1.0.0
---

# Goal Tree Workflow

Orchestrates multi-task projects as hierarchical goal trees. Decomposes a user's objective into goals and tasks, dispatches work via workspace sessions, and synthesizes results into PRs.

## Hard Rules

These apply in ALL modes (coordinator-backed or bootstrap). Do not violate these regardless of context pressure. The three principles are **generative** — derive behavior from them rather than memorizing specific restrictions.

### Isolation

Work happens in worktrees via scripts. Source repos and shared state are never modified directly.

- Source repos (`~/src/github/`) stay on main. Create a worktree via `create-node-workspace.sh` before editing any repo file. Repo paths in project CLAUDE.md are SOURCE locations, not working directories.
- Use scripted paths for infrastructure: `create-node-workspace.sh` for workspaces, `create-tmuxp-session.sh` for sessions. No raw `git worktree add` or `tmux new-session`.
- Batch work into scripts. Each major phase should be one script execution, not a long chain of individual shell commands.

### Phase Gates

Think → confirm → act. Each phase has appropriate tools. Do not bleed across phase boundaries.

- **Strategic phases are text-only.** During OODA orient/propose, next-cycle conversation, spec refinement, or any discussion about *what* to do: no tool calls, no file edits, no implementation. If the user mentions a tactical item during strategy, capture it as a proposed node — do not act on it. Transition to execution only after direction is confirmed.
- **Conversation is incremental.** During strategic phases, advance through dialogue — don't accumulate context into summary structures. If you're about to present a "summary so far" or "proposed frame," ask: could I advance with one question instead? Summaries close; questions advance. Prefer advancing.
- **The tree is the only path to execution.** When direction is confirmed, the next step is *always* to register nodes in the coordinator — never to start implementing directly. New work → proposed nodes → coordinator registration → dispatch pipeline. There is no shortcut from conversation to implementation that bypasses the tree.
- **Conversation before decomposition, decomposition before execution.** Confirm the spec before decomposing. Get tree approval before creating files, issues, or directories.
- **Plan before implementing.** Every task gets planning-workflow or a PLAN.md before code changes. Do not jump from reading code to writing code.
- **Recognize dispatch signals.** When the operator says "dispatch a workspace", "create a workspace for this", or similar during conversation, load `operations/discuss-dispatch.md` and follow its lifecycle. After workspace creation, the main thread writes ONLY to DESIGN.md — no implementation.

### Flow

Ready work dispatches immediately, in parallel. Minimize blocking. Be decisive during execution.

- Independent nodes dispatch as parallel workspace sessions. Sequential dispatch of independent nodes is a protocol violation.
- Dispatch ready nodes immediately. Conversation about node B does NOT block dispatching node A if A's spec is clear and dependencies are met.
- During execution, propose and act — checkpoints belong at phase boundaries (spec confirmation, tree approval, dispatch rounds), not after every thought. State assumptions and proceed; the user will redirect if needed.
- Auto-continue the OODA loop. When ready nodes are exhausted in an open-ended project, immediately run `operations/next-cycle.md`. Do not stop and ask "what next?"

## Core Concepts

**Goal Tree**: Hierarchical decomposition of an objective into goals (decomposable) and tasks (implementable leaves). Persisted via the coordinator API.

**Coordinator as backend**: The `coord` CLI (`scripts/coord`) is the interface. Reads and writes go through it. Env: `COORDINATOR_URL` (default `http://localhost:4000`), `COORDINATOR_TOKEN` (required).

**Bootstrap mode**: When the coordinator is unavailable OR a TCETRA hostname is detected, use GOAL.md + TodoWrite for task tracking. All other conventions still apply — worktrees, scripted sessions, parallel dispatch via workspace sessions. Once the coordinator is running (non-TCETRA only), register the remaining tree and switch to the normal loop.

**Environment detection**: Operations should check the environment before selecting a backend. Use `scripts/detect-env.sh` which outputs "work" (TCETRA → GOAL.md) or "personal" (coordinator). See `lib/env-detection.md` for details.

**Worktree isolation**: Every task gets a node workspace with repo worktrees on a per-node branch. Source repos are never modified directly.

**OODA loop**: Sessions follow Observe → Orient → Decide → Act. Resume and status operations use OODA preambles — narrative summaries of capability/performance/gaps rather than raw data dumps. During Quick Observe (next-cycle.md), check `$PROJECT_DIR/.active-nodes` for dispatched nodes awaiting completion — look for merged PRs, inbox messages, or dead tmux sessions. See `operations/discuss-dispatch.md` step 5 for detection logic.

## Commands

| Command | When | Operation |
|---------|------|-----------|
| `/project:start` | New project | `operations/start-project.md` |
| `/project:resume` | After interruption | `operations/resume-project.md` (OODA preamble → execute) |
| `/project:status` | Situational awareness | `operations/status.md` (observe only) |
| `/project:orient` | Strategic alignment | `operations/orient.md` (map to strategy) |
| `/project:finish` | All nodes complete | `operations/synthesize.md` |
| `/project:close` | Tear down workspace | `operations/close-project.md` |
| `/project:next` | Continue OODA loop | `operations/next-cycle.md` |
| `/dispatch-task` | Dispatch node to workspace | `operations/dispatch-task-cmd.md` |
| `/goal-tree` | Load skill context | Context loader (no canned action) |

Legacy aliases: `/start-project`, `/resume-project`, `/finish-project`, `/close-project` still work.

## Execution Flow

**Start**: Load `operations/start-project.md` — conversation → spec confirmation → decomposition → approval → coordinator registration (or bootstrap) → execution.

**Resume**: Load `operations/resume-project.md` — OODA preamble (observe state, orient to strategy) → conversation → execute-tree loop.

**Execute** (coordinator mode): Load `operations/execute-tree.md` — loop: select ready nodes → dispatch decisions → create workspace sessions → monitor via tmux → collect results → update coordinator → repeat.

**Execute** (bootstrap mode): TodoWrite tracks tasks. The dispatch pipeline still applies:
1. Identify independent tasks (no unmet dependencies)
2. Create node workspaces via `scripts/create-node-workspace.sh`
3. Dispatch independent tasks as parallel workspace sessions (use `operations/dispatch-node.md` for workspace creation and tmux startup)
4. Monitor sessions, commit results, advance to next batch
5. Once coordinator is available, register tree and switch modes

Bootstrap mode is NOT an excuse for serial dispatch. Use parallel workspace sessions even without the coordinator.

**Dispatch strategy** (per-node):
- Clear spec (any complexity) → **Workspace session**
- Needs conversation first → **Discuss-dispatch** (conversation → workspace session)
- Needs human judgment → **Escalate**

## Operations Reference

Load on-demand as needed:

| Operation | Purpose |
|-----------|---------|
| `start-project.md` | Entry: conversation → guardian issue → tree registration |
| `execute-tree.md` | Main orchestration loop with fan-out |
| `dispatch-decision.md` | Per-node strategy selection |
| `dispatch-node.md` | Execute chosen strategy (workspace session/escalate) |
| `dispatch-task-cmd.md` | User-facing node dispatch (GOAL.md → workspace) |
| `select-ready.md` | Query coordinator for ready nodes |
| `parse-goal.md` | Query coordinator → structured tree |
| `update-goal.md` | Update node status/results |
| `branch-management.md` | Worktree and branch isolation |
| `resume-project.md` | OODA preamble → execution loop |
| `next-cycle.md` | Lightweight OODA iteration (in-session continuation) |
| `status.md` | Observe: capability/performance/gap narrative |
| `orient.md` | Map observations to strategy, surface drift |
| `synthesize.md` | Merge, PR, report |
| `close-project.md` | Tear down and archive |
| `discuss-dispatch.md` | Interactive dispatch: conversation → workspace → incremental DESIGN.md → handoff |

## Scripts

Called by operations — use these instead of raw commands:

| Script | Purpose |
|--------|---------|
| `scripts/create-node-workspace.sh` | Create node workspace with repo worktrees |
| `scripts/coord` | CLI client for coordinator API |
| `scripts/merge-node-branch.sh` | Merge node branch into integration |
| `scripts/synthesize-node.sh` | Commit + merge all repos in a node |
| `scripts/check-workspace-state.sh` | Report clean/dirty/missing per worktree |
| `scripts/workspace-status.sh` | Enhanced status with branch and last commit info |
| `scripts/workspace-pr-status.sh` | PR and branch status across workspace repos |
| `scripts/coord-query.sh` | Formatted coord queries (pending-nodes, node-status, etc.) |
| `scripts/cleanup-worktrees.sh` | Remove all node workspace worktrees |
| `scripts/cleanup-sessions.sh` | Kill project tmux sessions |
| `scripts/close-project.sh` | Close and archive a project |
| `scripts/discuss-dispatch.sh` | Atomic setup: coord node + workspace + DESIGN.md + .active-nodes |
| `scripts/patch-finish-metrics.sh` | Patch finish.jsonl with evaluation.json metrics after L1 evaluation |

**Prefer scripts over pipelines**: Before composing `jq`/`python` pipelines, check if a script above already provides the data. See `docs/reference/command-simplification.md` for common patterns and alternatives.
