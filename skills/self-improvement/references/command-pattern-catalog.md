# Command Pattern Catalog

Reference catalog of complex shell command patterns found across skills. Each pattern is categorized as **necessarily complex** (leave as-is) or **simplifiable** (with a documented alternative).

Use this catalog when:
- Reviewing FEEDBACK.md entries about command friction
- Evaluating whether a new script or CLI enhancement is warranted
- Writing new operations that need similar patterns

## Necessarily Complex Patterns

These patterns are inherently complex due to what they accomplish. Simplification attempts would just move complexity elsewhere without reducing it.

### NC-1: JWT Generation for GitHub App Authentication

**Location**: `goal-tree/scripts/generate-app-token.sh`
**Pattern**: OpenSSL signing → base64url encoding → curl token exchange
**Why necessary**: Cryptographic operations require these exact steps. The script already encapsulates the complexity — agents call the script, not the raw commands.

### NC-2: Recursive jq Tree Traversal for GOAL.md Sync

**Location**: `goal-tree/scripts/coord` (tree_sync function)
**Pattern**: 170+ line jq program with recursive DFS, parent-child mapping, depth calculation
**Why necessary**: Tree-to-markdown conversion requires recursive traversal. The jq program is the simplest correct implementation. Already encapsulated in the coord CLI.

### NC-3: GraphQL Mutations via gh api

**Location**: `github-projects/operations/*`, `<project>-sync/references/project-field-ids.md`
**Pattern**: `gh api graphql -f query='mutation(...)' -f proj=... -f item=... -f field=... -f opt=...`
**Why necessary**: GitHub Projects V2 requires GraphQL. The gh CLI's `-f` flag approach is the recommended method. Inline queries are unavoidable for one-off mutations. For repeated mutations, use `set-project-field` script.

### NC-4: SQLite Multi-Table Joins for Board Cache

**Location**: `sprint-review/references/gh-queries.md`
**Pattern**: `sqlite3 -separator '|' <db> "SELECT ... FROM items JOIN ... WHERE ..."`
**Why necessary**: Querying cached board data requires SQL joins. The schema is fixed; the queries are correct. Alternatives (fetching from API each time) would be slower.

### NC-5: git Worktree Detection

**Location**: `git/operations/merge-pr.md`
**Pattern**: Compare `git rev-parse --git-common-dir` vs `--git-dir`
**Why necessary**: This is the canonical way to detect worktrees. Simple and correct.

## Simplifiable Patterns

These patterns can be replaced with simpler alternatives.

### S-1: Coordinator ID Extraction (repeated pattern)

**Location**: `goal-tree/operations/start-project.md`, `dispatch-node.md`, `update-goal.md`
**Current pattern**:
```bash
TREE_ID=$(coord tree create --title "..." | jq -r '.data.id')
NODE_DB_ID=$(coord node create ... | jq -r '.data.id')
```
**Frequency**: 5+ occurrences across goal-tree operations
**Alternative**: Add `--quiet` or `--id-only` flag to coord CLI that outputs just the ID instead of full JSON. Example: `TREE_ID=$(coord tree create --title "..." --id-only)`
**Status**: Candidate for coord CLI enhancement (Task 3)

### S-2: Coordinator Node Filtering with jq

**Location**: `goal-tree/operations/update-goal.md`, `dispatch-node.md`
**Current pattern**:
```bash
coord tree show $TREE_ID | jq ".data.nodes[] | select(.node_id == \"$NODE_ID\")"
```
**Frequency**: 3+ occurrences
**Alternative**: `coord node show $TREE_ID --by-node-id $NODE_ID` — coord already has `node show` but it requires the database ID, not the logical node_id. Adding a `--by-node-id` lookup flag would eliminate the jq filter.
**Status**: Candidate for coord CLI enhancement (Task 3)

### S-3: Coordinator curl API Calls (duplicated helper)

**Location**: `task-workflow/operations/init-workspace.md`, `auto-advance.md`, `next-task.md`
**Current pattern**:
```bash
curl -s -X POST "${COORDINATOR_URL}/api/missions/${COORDINATOR_MISSION_ID}/tasks" \
  -H "Authorization: Bearer ${COORDINATOR_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"task":{"objective":"...","status":"pending"}}'
```
**Frequency**: 3+ operations define nearly identical `coord_create_task()` / `coord_sync_status()` helpers
**Alternative**: Move the helper functions to a shared script in the goal-tree skill (which owns the coord CLI). Operations reference the shared helpers instead of redefining them.
**Status**: Candidate for script extraction (Task 4)

### S-4: Time-to-Merge jq Calculation

**Location**: `sprint-review/references/gh-queries.md`
**Current pattern**:
```bash
| jq '[.[] | {number, title, hours: (((.mergedAt | fromdateiso8601) - (.createdAt | fromdateiso8601)) / 3600)}]'
```
**Frequency**: 2-3 occurrences in sprint review queries
**Alternative**: Extract to a jq module file (`sprint-review/scripts/time-delta.jq`) and invoke with `jq -f`. Or add a sprint-review helper script that takes PR JSON and outputs the table.
**Status**: Low priority — sprint review is infrequent

### S-5: Issue-PR Link Extraction with Regex

**Location**: `sprint-review/references/gh-queries.md`
**Current pattern**:
```bash
| jq '[.[] | {number, linked_issue: (.body | capture("(?i)(closes|fixes|resolves)\\s+#(?<issue>\\d+)") | .issue // null)}]'
```
**Frequency**: 1-2 occurrences
**Alternative**: Use `gh pr list --json closingIssuesReferences` (available in modern gh versions) instead of regex parsing PR bodies. Falls back cleanly when field is unavailable.
**Status**: Low priority — sprint review is infrequent

### S-6: Multi-Pass jq Joins (PR-to-Issue Correlation)

**Location**: `sprint-review/references/gh-queries.md`
**Current pattern**:
```bash
echo "$pr_links" | jq --argjson issues "$issue_data" '
  [.[] | . as $pr |
    ($issues[] | select(.number == ($pr.linked_issue | tonumber))) as $issue |
    {pr: $pr.pr_number, issue: ($pr.linked_issue | tonumber),
     hours: ...}]'
```
**Frequency**: 1 occurrence
**Alternative**: Single gh query that fetches PRs with linked issue data in one call, avoiding the client-side join entirely. Or extract to a standalone script.
**Status**: Low priority — sprint review is infrequent

### S-7: Path Normalization with eval echo

**Location**: `task-workflow/operations/open-workspace.md`
**Current pattern**:
```bash
workspace_path=$(eval echo "$arg")
workspace_path=$(cd "$workspace_path" 2>/dev/null && pwd)
```
**Alternative**: Use `realpath` or `readlink -f` which handle tilde expansion and path normalization safely without `eval`.
**Status**: Low priority — simple fix when the file is next touched

### S-8: DESIGN.md Field Extraction with grep/sed

**Location**: `task-workflow/operations/open-workspace.md`
**Current pattern**:
```bash
issue_ref=$(grep "^- GitHub Issue:" "$workspace_path/DESIGN.md" | sed 's/^- GitHub Issue: *//')
task_id_extracted=$(echo "$first_line" | sed 's/^# \([^:]*\):.*/\1/')
```
**Frequency**: 2-3 occurrences
**Alternative**: Use bash parameter expansion: `${first_line#\# }` then `${var%%:*}`. Or use a single awk command. These are minor improvements — the current patterns work.
**Status**: Low priority — cosmetic

### S-9: Project Board Item Count with wc -l

**Location**: `task-workflow/operations/open-workspace.md`
**Current pattern**:
```bash
matches=$(find ~/src/work -maxdepth 2 -type d -name "$task_id-*" 2>/dev/null)
match_count=$(echo "$matches" | wc -l | tr -d ' ')
```
**Alternative**: Use bash array: `matches=( ~/src/work/*/"$task_id"-*/ ); match_count=${#matches[@]}`. Avoids subshell, pipe, and whitespace trimming.
**Status**: Low priority — cosmetic

## Priority Summary

| ID | Impact | Effort | Priority |
|----|--------|--------|----------|
| S-1 | High (5+ sites) | Low (coord flag) | **High** |
| S-2 | Medium (3+ sites) | Low (coord flag) | **High** |
| S-3 | Medium (3+ operations) | Low (extract script) | **High** |
| S-4 | Low (infrequent use) | Medium | Low |
| S-5 | Low (infrequent use) | Low | Low |
| S-6 | Low (infrequent use) | Medium | Low |
| S-7 | Low (1 site) | Low | Low |
| S-8 | Low (cosmetic) | Low | Low |
| S-9 | Low (cosmetic) | Low | Low |

## How to Use This Catalog

1. **When writing new operations**: Check if a pattern here applies. Use the simpler alternative if available.
2. **When reviewing FEEDBACK.md**: Cross-reference friction entries against this catalog. If a pattern is already documented as necessarily complex, note that in the feedback triage. If simplifiable, check if the alternative has been implemented.
3. **When enhancing tools**: Prioritize S-1 through S-3 — these have the highest frequency and clearest alternatives.
