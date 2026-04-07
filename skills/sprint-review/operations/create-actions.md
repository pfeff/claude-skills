# Create Actions Operation

Convert the report's action items (Section 7) into GitHub issues with cross-references back to the review. Requires user confirmation before creating any issues.

**References**: R5 (Action Item Creation)

## Inputs

| Input | Source | Description |
|-------|--------|-------------|
| Action items table | generate-report output (Section 7) | Actions with description, owner, and target |
| Sprint name | User argument | For labeling and sprint tagging |
| Review issue URL | Runtime | The GitHub issue where the review report is posted (for cross-references) |
| Owner | SKILL.md config | GitHub owner (default: `pfeff`) |
| Default repo | SKILL.md config | Repo for action items (default: `guardian`) |

## Process

### 1. Parse Action Items

Extract each row from the Section 7 action items table:

| Field | Source |
|-------|--------|
| Number | `A1`, `A2`, etc. |
| Description | Action column — becomes the issue title |
| Owner | Owner column — becomes the assignee |
| Target | Target column — sprint or date for the issue |

### 2. Confirm with User

Before creating any issues, present the full list and ask for confirmation using `AskUserQuestion`:

```
The following action items will be created as GitHub issues:

A1: [description] → guardian (assigned: [owner], target: [target])
A2: [description] → guardian (assigned: [owner], target: [target])
...

Which items should be created?
```

Allow the user to:
- Confirm all items
- Select a subset
- Skip issue creation entirely
- Reassign the target repo for specific items

### 3. Create Issues

For each confirmed action item, create a GitHub issue:

```bash
gh issue create --repo ${owner}/${repo} \
  --title "${action_description}" \
  --body "$(cat <<'BODY'
## Action Item from ${sprint_name} Review

**Source:** ${review_issue_url}
**Action ID:** ${action_number}
**Target:** ${target}

### Description

${action_description}

### Context

This action item was generated from the ${sprint_name} sprint review report,
Process Recommendation ${related_recommendation}.

### Acceptance Criteria

- [ ] ${action_description}
BODY
)" \
  --assignee "${owner}" \
  --label "action-item"
```

### 4. Tag to Project Board (Optional)

If the project board has a sprint field, add the new issue to the board with the target sprint:

```bash
# Get the issue number from creation output
issue_url=$(gh issue create ... )
issue_number=$(echo "$issue_url" | grep -o '[0-9]*$')

# Add to project board
gh project item-add ${project_number} --owner ${owner} --url "${issue_url}"
```

Sprint field assignment requires the GraphQL API and is optional — log a note if it cannot be automated.

### 5. Report Created Issues

After creation, present a summary:

```markdown
## Action Items Created

| # | Issue | Title | Assignee | Target |
|---|-------|-------|----------|--------|
| A1 | guardian#110 | Auto-tag issues with current sprint | pfeff | Sprint 2, Week 1 |
| A2 | guardian#111 | Define Sprint 2 S1 validation deliverable | pfeff | Sprint 2 planning |
| ... | ... | ... | ... | ... |

${created_count} of ${total_count} action items created as GitHub issues.
```

## Error Handling

- **Issue creation fails**: Log the error, continue with remaining items, report partial results.
- **Assignee not found**: Create the issue without `--assignee` and note in the summary.
- **Label doesn't exist**: Create without label rather than failing. Note in summary.
- **No review issue URL**: Omit the Source field rather than blocking creation.

## Output

A summary of created issues with their numbers and URLs, suitable for appending to the review report as a cross-reference.
