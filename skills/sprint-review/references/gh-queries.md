# GitHub Query Reference

Supplementary `gh` CLI patterns, `jq` filters, and shell escaping notes for the sprint review skill. Primary queries are documented in each operation file — this reference covers reusable patterns and gotchas.

## Time-to-Merge jq Filter

Compute per-PR hours from the PR data collected by `gather-data.md` step 2:

```bash
| jq '[.[] | {number, title, hours: (((.mergedAt | fromdateiso8601) - (.createdAt | fromdateiso8601)) / 3600)}]'
```

Average time-to-merge:

```bash
| jq '[.[] | ((.mergedAt | fromdateiso8601) - (.createdAt | fromdateiso8601)) / 3600] | add / length'
```

## Issue-PR Link Extraction

Extract closing issue references from PR bodies collected by `gather-data.md` step 2:

```bash
| jq '[.[] | {number, title, linked_issue: (.body | capture("(?i)(closes|fixes|resolves)\\s+#(?<issue>\\d+)") | .issue // null)}]'
```

Filter to only PRs with a linked issue:

```bash
| jq '[.[] | {number, title, linked_issue: (.body | capture("(?i)(closes|fixes|resolves)\\s+#(?<issue>\\d+)") | .issue // null)} | select(.linked_issue != null)]'
```

## Time-to-PR Calculation

Given PR data (with `body`, `createdAt`) and issue data (with `number`, `createdAt`), compute hours from issue creation to PR creation for linked pairs.

This is a two-pass operation — extract links from PRs, then join with issue timestamps:

```bash
# Step 1: Extract PR → issue mappings
pr_links=$(echo "$pr_data" | jq '[.[] | {pr_number: .number, pr_created: .createdAt, linked_issue: (.body | capture("(?i)(closes|fixes|resolves)\\s+#(?<issue>\\d+)") | .issue // null)} | select(.linked_issue != null)]')

# Step 2: Join with issue createdAt and compute hours
echo "$pr_links" | jq --argjson issues "$issue_data" '
  [.[] | . as $pr |
    ($issues[] | select(.number == ($pr.linked_issue | tonumber))) as $issue |
    {pr: $pr.pr_number, issue: ($pr.linked_issue | tonumber),
     hours: ((($pr.pr_created | fromdateiso8601) - ($issue.createdAt | fromdateiso8601)) / 3600)}
  ]'

# Step 3: Average time-to-PR
echo "$joined" | jq '[.[].hours] | if length > 0 then add / length else null end'
```

## Project Board Queries (via project-board-helper cache)

Cache DB: `~/Library/Caches/guardian/project-board.db`

Sync cache before querying:

```bash
project-board-helper sync
```

All items for a sprint:

```bash
sqlite3 -separator '|' ~/Library/Caches/guardian/project-board.db "
  SELECT i.repo, i.issue_number, i.title, i.content_type,
         COALESCE(sv.value, '') as status
  FROM items i
  JOIN item_field_values spv ON i.item_id = spv.item_id
  JOIN fields spf ON spv.field_id = spf.field_id AND spf.name = 'Sprint'
  LEFT JOIN item_field_values sv ON i.item_id = sv.item_id
  LEFT JOIN fields sf ON sv.field_id = sf.field_id AND sf.name = 'Status'
  WHERE spv.value = '<sprint_name>'
    AND i.content_type = 'Issue';
"
```

Board items with empty status:

```bash
sqlite3 ~/Library/Caches/guardian/project-board.db "
  SELECT i.repo, i.issue_number, i.title
  FROM items i
  JOIN item_field_values spv ON i.item_id = spv.item_id
  JOIN fields spf ON spv.field_id = spf.field_id AND spf.name = 'Sprint'
  LEFT JOIN item_field_values sv ON i.item_id = sv.item_id
  LEFT JOIN fields sf ON sv.field_id = sf.field_id AND sf.name = 'Status'
  WHERE spv.value = '<sprint_name>'
    AND (sv.value IS NULL OR sv.value = '')
    AND i.content_type = 'Issue';
"
```

Look up item ID (for board mutations):

```bash
project-board-helper lookup <owner/repo> <issue_number>
```

Field metadata:

```bash
project-board-helper field Status
project-board-helper field Sprint
```

## Issue Creation

```bash
gh issue create --repo ${owner}/${repo} \
  --title "${title}" \
  --body "${body}" \
  --assignee "${assignee}" \
  --label "action-item"
```

Add to project board:

```bash
gh project item-add ${project_number} --owner ${owner} --url "${issue_url}"
```

## jq Filter Patterns

### Sum a numeric field across array

```bash
jq 'map(.additions) | add'
```

### Compute derived field per element

```bash
jq '[.[] | {number, hours: (((.mergedAt | fromdateiso8601) - (.createdAt | fromdateiso8601)) / 3600)}]'
```

### Average of array

```bash
jq 'add / length'
```

### Group and count by field

```bash
jq 'group_by(.repo) | map({repo: .[0].repo, count: length})'
```

### Filter by field value

```bash
jq '[.[] | select(.status == "Done")]'
```

### Extract unique values

```bash
jq '[.[].labels[].name] | unique'
```

## Zsh Escaping Considerations

### Variable interpolation inside jq

Zsh interprets `$` inside double quotes. When mixing shell variables with `jq` filters:

```bash
# Wrong — zsh tries to expand $sprint_name inside jq
jq '[.items[] | select(.sprint == "$sprint_name")]'

# Right — break out of single quotes for the variable
jq '[.items[] | select(.sprint == "'"${sprint_name}"'")]'
```

### Curly braces in date ranges

The `@{date}` syntax in the compare API uses braces that zsh may interpret as glob patterns:

```bash
# If zsh complains about nomatch, either:
# 1. Quote the entire URL
gh api "repos/${owner}/${repo}/compare/main@{${start_date}}...main@{${end_date}}"

# 2. Or set noglob temporarily
noglob gh api repos/${owner}/${repo}/compare/main@{${start_date}}...main@{${end_date}}
```

### Heredoc in gh issue create

Use `<<'EOF'` (quoted) to prevent shell expansion inside the body, then interpolate only the variables you need:

```bash
gh issue create --repo ${owner}/${repo} \
  --title "${title}" \
  --body "$(cat <<EOF
## Action Item from ${sprint_name} Review

**Source:** ${review_url}
EOF
)"
```
