---
name: sprint-planning
description: Research-first sprint planning that loads project context before interviewing. Produces a sprint planning issue and populated backlog. Use when planning a new sprint, creating sprint issues, or populating sprint backlog.
argument-hint: "[sprint-name]"
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Write
  - AskUserQuestion
allowed-prompts:
  - tool: Bash
    prompt: list GitHub issues
  - tool: Bash
    prompt: list GitHub project items
  - tool: Bash
    prompt: list GitHub project fields
  - tool: Bash
    prompt: view GitHub issue details
  - tool: Bash
    prompt: create GitHub issue
  - tool: Bash
    prompt: query GitHub API
  - tool: Bash
    prompt: list tmux sessions
version: 0.1.0
---

# Sprint Planning

Research-first sprint planning. Loads all project context, forms a hypothesis about the sprint increment, then interviews the user with informed, substantive questions.

## Core Principle

**Research before interview.** Never ask a question you could answer by reading project state. Load strategic objectives, prior sprint outcomes, open issues, and in-flight work *before* engaging the user.

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| Owner | `pfeff` | GitHub owner for all queries |
| Repos | `guardian,agent-coordinator,agent-orchestrator,PfeffNet` | Repositories in scope |
| Project board | project #4 | GitHub project board |
| OKR source | Strategic objective issues (S1:, S2: prefixes) | Source of strategic streams |

## Execution Flow

### Step 1: Load Context
**Operation**: `operations/load-context.md`

Gather all project state autonomously before asking any questions:
- Strategic objectives and their current status
- Prior sprint outcomes (what shipped, what didn't)
- Open issues across all in-scope repos
- In-flight work (tmux sessions, board items not yet Done)
- Board field options (sprint names, status values)

### Step 2: Informed Interview
**Operation**: `operations/informed-interview.md`

Using loaded context, interview the user with substantive questions:
- Present a summary of current state and propose a sprint focus
- Ask about priority trade-offs between strategic objectives
- Confirm carryover items vs. fresh starts
- Discuss what "measurable improvement" means for the increment

### Step 3: Create Sprint Issue
**Operation**: `operations/create-issue.md`

Create the sprint planning issue in the appropriate repo:
- Structured body with goals, focus areas, carryover, acceptance criteria
- Assign to sprint field on project board via GraphQL API

### Step 4: Populate Backlog
**Operation**: `operations/populate-backlog.md`

Refine and assign selected issues to the sprint on the project board:
- **Refinement gate**: Assess each issue for problem framing (User, Pain, Current workflow, Success criteria). Interview for missing dimensions and update the issue body. **Invariant: every issue assigned to the sprint must be fully refined.**
- Set sprint field on each issue via GraphQL mutation
- Confirm assignments with user
- Report final sprint composition

## Quick Reference

**Board cache**: `project-board-helper sync` refreshes the local SQLite cache at `~/Library/Caches/guardian/project-board.db`. Use `sqlite3` queries for filtering and `project-board-helper lookup` for item ID resolution.

**Field metadata**: `project-board-helper field Sprint` returns field ID and option IDs.

**GraphQL mutation** (for setting sprint field on items — no cache equivalent for writes):

```graphql
mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: "<project-id>"
    itemId: "<item-id>"
    fieldId: "<field-id>"
    value: { singleSelectOptionId: "<option-id>" }
  }) { projectV2Item { id } }
}
```

## Progressive Disclosure

**Operations** (load on-demand):
- `operations/load-context.md` — Autonomous context gathering
- `operations/informed-interview.md` — Substantive user interview
- `operations/create-issue.md` — Sprint issue creation and board assignment
- `operations/populate-backlog.md` — Issue refinement and sprint field assignment

## Commands

| Command | Operation |
|---------|-----------|
| `/sprint-planning` | Full planning flow (all steps) |
