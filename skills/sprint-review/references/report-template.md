# ${sprint_name} Review Report

**Sprint:** ${sprint_name} (${start_date} – ${end_date})
**Repos:** ${repos}

---

## 1. Summary

<!-- 2-3 sentence executive summary: completion rate, volume headline, dominant strategic stream, key outcome or gap. -->

---

## 2. Velocity Metrics

### Board Scope

| Metric | Value |
|--------|-------|
| Board items completed | ${board_done}/${board_total} (${board_pct}%) |
| Pre-sprint completed | ${pre_sprint_done} of ${board_done} Done items closed before ${start_date} |

### Sprint Week (${start_date} – ${end_date})

| Metric | Value |
|--------|-------|
| Issues closed | ${issues_closed} |
| PRs merged | ${prs_merged} |
| Lines added | ${lines_added} |
| Lines removed | ${lines_removed} |
| Net change | ${net_change} |
| Avg time-to-merge | ${avg_ttm} |
| Avg time-to-PR | ${avg_ttp} |

#### By Repository

| Repo | Issues Closed | PRs Merged | +Lines | -Lines |
|------|--------------|------------|--------|--------|
<!-- One row per repo, filtered to sprint date range only -->
| ${repo} | ${repo_issues_week} | ${repo_prs_week} | ${repo_added} | ${repo_removed} |
| **Total** | **${total_issues_week}** | **${total_prs_week}** | **${lines_added}** | **${lines_removed}** |

---

## 3. Completion Rate

- **${board_done}/${board_total} sprint board items completed (${board_pct}%)**
- ${pre_sprint_done} of ${board_done} Done items were closed before sprint week (${start_date})
- ${sprint_week_done} Done items closed during sprint week
- ${empty_status_count} items have empty board status but confirmed closed on GitHub (hygiene gap)
- ${carryover_count} carry-overs from tagged sprint items
- ~${new_issues_count} open issues spawned during sprint (next sprint candidates)

---

## 4. Strategic Alignment (OKR Mapping)

| Stream | Issues | PRs | Focus |
|--------|--------|-----|-------|
| S1: Generate Revenue | ${s1_issues} | ${s1_prs} | ${s1_focus} |
| S2: Maintain Stability | ${s2_issues} | ${s2_prs} | ${s2_focus} |
| S3: Compound the Advantage | ${s3_issues} | ${s3_prs} | ${s3_focus} |

<!-- Brief analysis: which stream dominated, what does the distribution mean for strategic priorities. -->

---

## 4.5. Workspace Hygiene

<!-- Output from check-workspaces operation. Shows stale workspaces (issue closed but workspace open). -->

${workspace_hygiene_summary}

<!-- If stale workspaces exist: -->
| Task ID | Epic | Issue | Issue State | Workspace Path |
|---------|------|-------|-------------|----------------|
| ${task_id} | ${epic} | ${issue_ref} | ${issue_state} | ${workspace_path} |

<!-- If zero stale: "All N open workspace(s) have active issues. No cleanup needed." -->

---

## 5. Retrospective Analysis

### What Went Well

<!-- 3-6 bullet points. Each: bold headline sentence + 1-2 supporting sentences with data. Focus on outcomes, not just outputs. -->

### What Didn't Go Well

<!-- 3-6 bullet points. Same format. Be specific about impact — "board tracking captured 33% of activity" not "tracking could improve". -->

### Key Learnings

<!-- 3-5 numbered lessons. Each: bold principle + explanation. These should be actionable insights, not platitudes. -->

---

## 6. Process Recommendations

<!-- P1-P5 (adjust count as needed). Each recommendation:
### P{n}: {imperative headline}
1-2 paragraph explanation of the problem, proposed solution, and expected impact.
-->

---

## 7. Action Items

| # | Action | Owner | Target |
|---|--------|-------|--------|
<!-- A1-A{n}. Each action should be concrete, assignable, and time-bound. Link to process recommendations where applicable. -->
| A1 | ${action_description} | ${owner} | ${target_sprint_or_date} |
