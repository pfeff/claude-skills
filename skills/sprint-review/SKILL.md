---
name: sprint-review
description: Automate sprint review data gathering (gh queries), OKR classification, board reconciliation, workspace hygiene checks, report generation, and action item creation across multiple repos. Use when the user needs to run a sprint review or invokes /sprint-review.
argument-hint: "[sprint-name start-date end-date]"
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - Task
  - AskUserQuestion
allowed-prompts:
  - tool: Bash
    prompt: list GitHub issues
  - tool: Bash
    prompt: list GitHub pull requests
  - tool: Bash
    prompt: query GitHub API
  - tool: Bash
    prompt: list GitHub project items
  - tool: Bash
    prompt: list GitHub project fields
  - tool: Bash
    prompt: create GitHub issue
  - tool: Bash
    prompt: view GitHub issue details
  - tool: Bash
    prompt: scan open workspaces
version: 0.1.0
---

# Sprint Review Skill

Automates the end-of-sprint review pipeline: data gathering, OKR classification, board reconciliation, report generation, and action item creation.

## Invocation

```
/sprint-review                                          # Prompts for sprint name, dates, and repos
/sprint-review "Sprint 1" 2026-02-17 2026-02-21        # Explicit sprint name and date range
/sprint-review "Sprint 2" 2026-02-24 2026-03-07 --repos guardian,agent-coordinator
```

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| sprint-name | No | Sprint identifier (prompted if omitted) |
| start-date | No | Sprint start date, ISO 8601 (prompted if omitted) |
| end-date | No | Sprint end date, ISO 8601 (prompted if omitted) |
| `--repos` | No | Comma-separated repo list. Overrides board-derived repo discovery when provided. |

If arguments are omitted, use `AskUserQuestion` to prompt for them before proceeding.

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| Owner | `pfeff` | GitHub owner for all repo and project queries |
| Fallback repos | `guardian,agent-coordinator,agent-orchestrator` | Fallback repo list used when board returns no sprint-tagged items |
| Project board | `pfeff`'s project #4 | GitHub project board for repo discovery and board reconciliation |
| OKR source | `guardian/REQUIREMENTS.md` | Source of strategic stream definitions |

## Execution Flow

### Step 1: Gather Data
**Operation**: `operations/gather-data.md`

Discover repos from the project board (or use `--repos` override / fallback defaults), then query GitHub for raw sprint activity across all discovered repos:
- Repo discovery from board items tagged for the sprint
- Issues closed in the date range
- PRs merged in the date range
- Lines changed (additions/deletions) via GitHub API
- Time-to-merge metrics

### Steps 2-4: Parallel Analysis via Fan-Out

Steps 2, 3, and 4 are independent after Step 1 completes. Dispatch all three in parallel using the fan-out operation:

```
Read: skills/task-workflow/operations/fan-out.md
```

Provide inputs:
- `result_format`: `raw`
- `agents`:

| Agent | Prompt Source | Description |
|-------|-------------|-------------|
| Classify OKRs | `operations/classify-okrs.md` + Step 1 data output | "Sprint review: classify OKRs" |
| Reconcile Board | `operations/reconcile-board.md` + Step 1 data output | "Sprint review: reconcile board" |
| Check Workspaces | `operations/check-workspaces.md` + Step 1 data output | "Sprint review: check workspaces" |

Each agent prompt includes the operation's full instructions and the raw data from Step 1 (closed issues, merged PRs, metrics).

**Handling partial failures**: If fan-out returns `status: partial`, proceed with successful results. Note which analyses were skipped in Step 5's report. If `status: all_failed`, fall back to running Steps 2-4 sequentially inline.

#### Step 2: Classify OKRs
**Operation**: `operations/classify-okrs.md`

Map each closed issue and merged PR to strategic streams (S1, S2, S3) using `REQUIREMENTS.md` as the OKR source. Produce a breakdown table by stream.

#### Step 3: Reconcile Board
**Operation**: `operations/reconcile-board.md`

Compare project board items tagged for the sprint against actual activity discovered in Step 1. Surface:
- Work done but not board-tracked
- Board items with no activity or empty status

#### Step 4: Check Workspaces
**Operation**: `operations/check-workspaces.md`

Scan open workspaces and check GitHub issue status. Surface stale workspaces where the issue is closed but the workspace is still open. Uses closed issues from Step 1 to minimize API calls.

### Step 5: Generate Report
**Operation**: `operations/generate-report.md`
**Template**: `references/report-template.md`

Assemble structured REPORT.md from the fan-out results (or inline results on fallback). Sections: Summary, Velocity Metrics, Completion Rate, Strategic Alignment, Workspace Hygiene, Retrospective, Process Recommendations, Action Items.

### Step 6: Create Action Items
**Operation**: `operations/create-actions.md`

Convert report recommendations into GitHub issues with cross-references to the review. Prompt user for confirmation before creating issues.

## Operations

| Operation | File | Trigger |
|-----------|------|---------|
| Gather Data | `operations/gather-data.md` | Step 1 — always runs first |
| Classify OKRs | `operations/classify-okrs.md` | Step 2 — after data gathering |
| Reconcile Board | `operations/reconcile-board.md` | Step 3 — after data gathering |
| Board Reconciliation | `operations/board-reconciliation.md` | Internal — core comparison logic used by Reconcile Board |
| Check Workspaces | `operations/check-workspaces.md` | Step 4 — after data gathering, uses closed issues |
| Generate Report | `operations/generate-report.md` | Step 5 — after classification, reconciliation, and workspace check |
| Create Actions | `operations/create-actions.md` | Step 6 — after report, with user confirmation |

## References

| File | Purpose |
|------|---------|
| `references/report-template.md` | REPORT.md template derived from Sprint 1 review |
| `references/gh-queries.md` | Reference `gh` and `jq` query patterns |

## Permissions

| Permission | Commands | Purpose |
|------------|----------|---------|
| list GitHub issues | `gh issue list` | Query issues closed in date range |
| list GitHub pull requests | `gh pr list` | Query PRs merged in date range |
| query GitHub API | `gh api` | Fetch lines changed, detailed PR/issue data |
| sync project board cache | `project-board-helper sync` | Refresh local board cache |
| query project board cache | `sqlite3 ~/Library/Caches/guardian/project-board.db` | Board reconciliation |
| look up board item ID | `project-board-helper lookup` | Resolve issue to item ID |
| query board field metadata | `project-board-helper field` | Discover sprint/status fields |
| create GitHub issue | `gh issue create` | Create action items from recommendations |
| view GitHub issue details | `gh issue view` | Fetch full issue details |
| scan open workspaces | `scan-task-dirs.sh` | Discover open workspaces for hygiene check |
