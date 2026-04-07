# Gather Data Operation

Collect raw sprint activity from GitHub across all configured repos. This is the first step in the sprint review pipeline — all downstream operations depend on its output.

**References**: R1 (Data Gathering), DD2 (Multi-repo), DD3 (Date-range Filtering)

## Inputs

| Parameter | Source | Description |
|-----------|--------|-------------|
| `owner` | SKILL.md config | GitHub owner (default: `pfeff`) |
| `repos` | `--repos` arg (optional) | Explicit repo list — overrides board discovery when provided |
| `sprint-name` | User argument | Sprint identifier for board query (e.g., `Sprint 3 (Mar 3-7)`) |
| `start-date` | User argument | Sprint start date (ISO 8601) |
| `end-date` | User argument | Sprint end date (ISO 8601) |
| `fallback-repos` | SKILL.md config | Default repo list used when board returns no results (default: `guardian,agent-coordinator,agent-orchestrator`) |

## Process

Discover which repos to query, then iterate over each and execute the queries below. Collect results into a structured dataset for downstream operations.

### 0. Discover Repos

Determine the repo list before issuing per-repo queries. Priority order:

1. **Explicit `--repos`**: If the user provided `--repos`, use exactly those repos. Skip board discovery entirely.
2. **Board-derived**: Query the project board for sprint-tagged items and extract unique repos.
3. **Fallback**: If the board returns zero repos, use `fallback-repos` from SKILL.md config.

#### When `--repos` is not provided

Sync the board cache and query for sprint items:

```bash
project-board-helper sync
```

```bash
sqlite3 -separator '|' ~/Library/Caches/guardian/project-board.db "
  SELECT DISTINCT i.repo
  FROM items i
  JOIN item_field_values spv ON i.item_id = spv.item_id
  JOIN fields spf ON spv.field_id = spf.field_id AND spf.name = 'Sprint'
  WHERE spv.value = '<sprint_name>'
    AND i.content_type = 'Issue'
    AND i.repo IS NOT NULL
    AND i.repo != ''
  ORDER BY i.repo;
"
```

Each row returns a full repo reference (e.g., `pfeff/guardian`). Extract the repo name portion after the `/` for use in the per-repo queries below.

**If repos found**: Use the board-derived list. Log:
```
Repos discovered from board (sprint: <sprint_name>): guardian, cursor-rules, dotfiles
```

**If no repos found**: Fall back to `fallback-repos`. Log:
```
No board items found for sprint "<sprint_name>" — using fallback repos: guardian, agent-coordinator, agent-orchestrator
```

### 1. Query Issues Closed in Date Range

```bash
gh issue list --repo ${owner}/${repo} \
  --state closed \
  --search "closed:${start_date}..${end_date}" \
  --json number,title,closedAt,createdAt,labels,assignees,body \
  --limit 200
```

**Output fields**: `number`, `title`, `closedAt`, `createdAt` (for time-to-PR calculation), `labels` (for OKR classification), `assignees`, `body` (for requirement ID extraction).

### 2. Query PRs Merged in Date Range

```bash
gh pr list --repo ${owner}/${repo} \
  --state merged \
  --search "merged:${start_date}..${end_date}" \
  --json number,title,mergedAt,createdAt,additions,deletions,author,body \
  --limit 200
```

**Output fields**: `number`, `title`, `mergedAt`, `createdAt` (for time-to-merge), `additions`, `deletions`, `author`, `body` (for issue-PR link extraction).

### 3. Query Lines Changed via API

If PR-level additions/deletions are insufficient (e.g., need repo-wide totals independent of PRs), use the compare API:

```bash
gh api repos/${owner}/${repo}/compare/main@{${start_date}}...main@{${end_date}} \
  --jq '.files | map({additions, deletions}) | {added: map(.additions) | add, removed: map(.deletions) | add}'
```

**Fallback**: If the compare API fails (e.g., date range too wide, branch history diverged), sum additions/deletions from the PR query in step 2 instead. Log a warning that the totals reflect only merged PRs, not all commits.

### 4. Calculate Time-to-Merge

Derive from PR data already fetched in step 2. For each PR:

```
time_to_merge = mergedAt - createdAt
```

Compute per-repo:
- **Average** time-to-merge
- **Median** time-to-merge
- **Min / Max** for range context

Apply the `jq` time-to-merge filter from `references/gh-queries.md` to the step 2 response — do not issue a separate API call.

### 4b. Calculate Time-to-PR (Issue-to-PR Correlation)

Link PRs to their originating issues by parsing closing keywords from the PR `body` field (fetched in step 2).

1. For each PR, extract issue references matching `(Closes|Fixes|Resolves)\s+#(\d+)` from the body
2. Match extracted issue numbers to issues fetched in step 1
3. For each matched pair, compute: `time_to_pr = pr.createdAt - issue.createdAt`
4. Compute per-repo **average** and **median** time-to-PR

Apply the `jq` issue-PR link extraction filter from `references/gh-queries.md` to the step 2 response. Cross-reference with step 1 issue data for the time calculation.

PRs with no closing keyword or referencing issues outside the fetched set are excluded from the calculation. Log the count of unlinked PRs.

## Error Handling

### Authentication Failure

If `gh` returns an auth error (exit code 4, or stderr contains "authentication"):
1. Log: `"GitHub authentication failed. Run 'gh auth status' to check credentials."`
2. Abort the pipeline — no point continuing without data.

### Repo Not Found

If a specific repo returns a 404 or "not found":
1. Log: `"Repository ${owner}/${repo} not found — skipping."`
2. Continue with remaining repos.
3. Include the skipped repo in the output summary so downstream operations know data is incomplete.

### Empty Results

If a repo returns zero issues and zero PRs:
1. Include it in the output with zeroed metrics.
2. Do not skip — a repo with no activity in the sprint is meaningful data.

### Rate Limiting

If `gh api` returns HTTP 403 with rate limit headers:
1. Log the remaining quota and reset time.
2. Pause briefly and retry once.
3. If still limited, report partial results and note which queries failed.

## Output Format

Present gathered data as a summary table per repo, then a combined totals row:

```markdown
## Data Gathering Results

### Per-Repo Summary

| Repo | Issues Closed | PRs Merged | Lines Added | Lines Removed | Avg Time-to-Merge | Avg Time-to-PR |
|------|--------------|------------|-------------|---------------|-------------------|----------------|
| guardian | 12 | 8 | 1,450 | 320 | 18.5h | 36.2h |
| agent-coordinator | 5 | 3 | 620 | 110 | 12.0h | 22.4h |
| agent-orchestrator | 3 | 2 | 380 | 90 | 24.0h | 48.0h |
| **Total** | **20** | **13** | **2,450** | **520** | **17.2h** | **33.8h** |

### Detailed Issue List

| Repo | # | Title | Closed |
|------|---|-------|--------|
| guardian | #42 | Implement state machine | 2026-02-18 |
| ... | ... | ... | ... |

### Detailed PR List

| Repo | # | Title | Merged | +/- | Time-to-Merge | Linked Issue |
|------|---|-------|--------|-----|---------------|--------------|
| guardian | #43 | Add state machine impl | 2026-02-18 | +450/-80 | 14.2h | #42 |
| ... | ... | ... | ... | ... | ... | ... |
```

### 5. Query Open Issues Created in Date Range (Optional)

Count new issues spawned during the sprint for the Completion Rate section:

```bash
gh issue list --repo ${owner}/${repo} \
  --state open \
  --search "created:${start_date}..${end_date}" \
  --json number \
  --limit 200 | jq length
```

## Output Format

Present gathered data as a summary table per repo, then a combined totals row:

```markdown
## Data Gathering Results

### Per-Repo Summary

| Repo | Issues Closed | PRs Merged | Lines Added | Lines Removed | Avg Time-to-Merge | Avg Time-to-PR |
|------|--------------|------------|-------------|---------------|-------------------|----------------|
| guardian | 12 | 8 | 1,450 | 320 | 18.5h | 36.2h |
| agent-coordinator | 5 | 3 | 620 | 110 | 12.0h | 22.4h |
| agent-orchestrator | 3 | 2 | 380 | 90 | 24.0h | 48.0h |
| **Total** | **20** | **13** | **2,450** | **520** | **17.2h** | **33.8h** |

### Detailed Issue List

| Repo | # | Title | Closed |
|------|---|-------|--------|
| guardian | #42 | Implement state machine | 2026-02-18 |
| ... | ... | ... | ... |

### Detailed PR List

| Repo | # | Title | Merged | +/- | Time-to-Merge | Linked Issue |
|------|---|-------|--------|-----|---------------|--------------|
| guardian | #43 | Add state machine impl | 2026-02-18 | +450/-80 | 14.2h | #42 |
| ... | ... | ... | ... | ... | ... | ... |
```

This output is consumed by:
- **classify-okrs** (issues and PRs with labels/body for stream mapping)
- **reconcile-board** (issue/PR numbers to compare against board items)
- **generate-report** (all metrics for the velocity and summary sections)
