# Generate Report Operation

Assemble a structured REPORT.md from the outputs of gather-data, classify-okrs, and reconcile-board. Uses the report template as the skeleton.

**References**: R4 (Report Generation), DD1 (Use Sprint 1 Report as Template)

## Inputs

| Input | Source | Description |
|-------|--------|-------------|
| Velocity data | gather-data output | Per-repo and aggregate metrics |
| Issue/PR lists | gather-data output | Detailed items with timestamps |
| OKR breakdown | classify-okrs output | Stream classification table and per-item details |
| Board reconciliation | reconcile-board output | Coverage %, tracked/untracked items, status gaps |
| Workspace hygiene | check-workspaces output | Stale workspace list, healthy count, skipped/error notes |
| Report template | `references/report-template.md` | Skeleton with placeholder variables |
| Sprint args | User arguments | sprint-name, start-date, end-date, repos |

## Process

### 1. Load Template

Read `references/report-template.md` as the report skeleton.

### 2. Populate Section 1: Summary

Write a 2-3 sentence executive summary covering:
- Board completion rate (from reconcile-board)
- Volume headline — total issues closed and PRs merged (from gather-data)
- Dominant strategic stream and its percentage (from classify-okrs)
- One key outcome or notable gap

This section requires synthesis, not just data insertion. Use the quantitative data to support a qualitative assessment.

### 3. Populate Section 2: Velocity Metrics

Section 2 has two subsections with distinct data sources:

**Board Scope subsection** (sourced from reconcile-board):
- Board items completed → from reconcile-board (done count / total count)
- Pre-sprint completed → from reconcile-board temporal breakdown (`pre_sprint_done` of `board_done` Done items closed before `start_date`)

**Sprint Week subsection** (sourced from gather-data, date-range filtered):
- Issues closed, PRs merged → from gather-data totals
- Lines added/removed, net change → from gather-data
- Avg time-to-merge → from gather-data
- Avg time-to-PR → from gather-data step 4b (time from issue creation to first PR creation; only for PRs with closing keyword linking to a fetched issue)

**By Repository table** (nested under Sprint Week, sourced from gather-data):
- One row per repo, filtered to the sprint date range
- If gather-data includes items outside the sprint window (e.g., a repo's issues were closed before the sprint started), note the discrepancy

### 4. Populate Section 3: Completion Rate

Combine gather-data and reconcile-board:
- Board items done / total → from reconcile-board
- Pre-sprint vs sprint-week breakdown → from reconcile-board temporal breakdown (`pre_sprint_done` and `sprint_week_done`)
- Empty status count → from reconcile-board
- Carry-overs → board items tagged but not closed in the date range (from reconcile-board "no activity" set)
- New issues spawned → from gather-data output (open issues created in the date range)

### 5. Populate Section 4: Strategic Alignment

Insert the classify-okrs stream breakdown table directly. Add a brief analysis paragraph noting:
- Which stream dominated and by what percentage
- Whether the distribution aligns with stated priorities (reference PROJECT.md or sprint goals if available)
- Any streams with zero or near-zero activity

### 5.5. Populate Section 4.5: Workspace Hygiene

Insert the check-workspaces output directly. This section reports:
- Count of stale workspaces (issue closed, workspace still open)
- Table of stale workspaces with task ID, epic, issue ref, and path
- Count of healthy workspaces
- Notes on skipped or errored checks

If zero stale workspaces, include the "all healthy" summary line.

### 6. Populate Section 5: Retrospective Analysis

This section requires qualitative analysis synthesized from quantitative data. Guide the LLM to generate insights by providing structured prompts:

**What Went Well** — Identify 3-6 positive outcomes. Look for:
- High completion rates or velocity improvements vs. prior sprint
- Components that reached milestones (tests passing, architecture complete)
- Workflow improvements that reduced friction
- Strategic deliverables that advanced OKRs

**What Didn't Go Well** — Identify 3-6 problems. Look for:
- Board tracking gaps (from reconcile-board coverage %)
- Strategic stream imbalance (from classify-okrs)
- Metrics that are misleading or based on proxies
- Date-range anomalies (repos with activity outside sprint window)

**Key Learnings** — Distill 3-5 actionable principles from the retrospective. Each should be:
- A bold statement followed by supporting evidence
- Actionable (implies something to change), not just an observation

### 7. Populate Section 6: Process Recommendations

Generate 3-5 process recommendations (P1-P5). Each recommendation should:
- Address a specific problem identified in the retrospective
- Propose a concrete, implementable solution
- State the expected impact

Common recommendation patterns (from Sprint 1):
- Board hygiene automation
- Strategic allocation floors
- Metric instrumentation
- Date-range alignment
- Status transition enforcement

### 8. Populate Section 7: Action Items

Convert process recommendations into a concrete action table. Each action item needs:
- Sequential number (A1, A2, ...)
- Specific action description (imperative, one sentence)
- Owner
- Target (sprint or date)

Use `AskUserQuestion` to confirm the owner and target for each action item before finalizing.

### 9. Write Output

Write the completed report to the user's working directory as `REPORT.md`.

## Output

The completed `REPORT.md` file, following the template structure with all placeholders replaced by actual data and analysis.

This output is consumed by:
- **create-actions** — reads the Action Items table (Section 7) to create GitHub issues
- The user — as the primary deliverable of the sprint review
