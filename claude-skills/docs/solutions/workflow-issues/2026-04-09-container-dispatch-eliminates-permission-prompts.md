---
title: "Container dispatch eliminates L0 permission prompts"
date: 2026-04-09
problem_type: workflow_issue
severity: high
symptoms:
  - "Human operator pulled to L0 on every dispatch"
  - "Permission prompts interrupt autonomous execution"
  - "Operating altitude degrades during goal-tree execution"
tags: [goal-tree, dispatch, container, ralph, permission-prompts, operating-altitude, devcontainer]
root_cause: "Subagent and inline dispatch strategies run in unsandboxed environments that require interactive permission approval for file writes, git operations, and shell commands"
module: goal-tree
component: dispatch
repo: claude-skills
---

## Problem

Goal-tree L0 dispatch uses subagent, sub-session, inline, or escalate strategies. All run in the host environment where Claude Code requires permission prompts for tool calls. Every dispatched node triggers multiple permission approvals, pulling the human operator down to L0 and defeating the purpose of hierarchical execution.

This was identified as the #1 bottleneck on human operating altitude in the cycle 1 evaluation.

## Solution

Added "container" as a fifth dispatch strategy. A wrapper script (`dispatch-container.sh`) translates the goal-tree node's DESIGN.md into a Ralph-compatible workspace and invokes `run-container.sh`, which runs Claude Code inside a sandboxed devcontainer with `--dangerously-skip-permissions`.

Key components:
- **Repo interface**: Repos self-describe via `Taskfile.yml` with standard targets (`test`, `lint`, `build`, `typecheck`). The wrapper reads Taskfile and generates `.ralph/gates.md`.
- **Spec translation**: DESIGN.md sections map directly to `specs/task.md` (requirements, acceptance criteria, context).
- **Result parsing**: Ralph exit states (all checkboxes done, BLOCKERS.md, max iterations) map to `dispatch_result` status codes (`success`, `blocked`, `failure`).

```bash
# Dry run (validates translation without Docker)
dispatch-container.sh /path/to/node-workspace --dry-run

# Full execution
dispatch-container.sh /path/to/node-workspace
```

Container is preferred over subagent in `dispatch-decision.md` when the repo has a Taskfile and Docker is available.

## Prevention

- Onboard repos with `Taskfile.yml` containing standard targets so container dispatch is always available
- Default to container strategy for Tier 2 leaf tasks to keep the human at L1+
- Monitor operating altitude metric to detect regression if container dispatch stops working
