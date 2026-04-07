# Create Sprint Issue

Create the sprint planning issue and assign it to the sprint on the project board.

## When to Use

After the informed interview has produced a sprint plan (goal, focus areas, issue list, criteria).

## Prerequisites

- Sprint plan from Step 2 (goal, focus areas, issues, criteria)
- Project board IDs from Step 1 (project ID, sprint field ID, sprint option ID)

## Steps

### 1. Determine Issue Location

Sprint planning issues go in the meta-repository (typically `guardian`).

### 2. Compose Issue Body

Structure the issue with clear sections:

```markdown
## Sprint Goal

[One sentence describing the coherent increment]

## Focus Areas (priority order)

### 1. [Focus Area Name]
[Rationale tied to strategic objectives]
- [ ] owner/repo#N — Issue title
- [ ] owner/repo#N — Issue title

### 2. [Focus Area Name]
...

### 3. [Focus Area Name]
...

## Carryover from [Prior Sprint]
- [ ] owner/repo#N — Issue title (status: [current state])

## Acceptance Criteria
- [ ] [Measurable criterion]
- [ ] [Measurable criterion]

## Task Breakdown
_To be populated as work begins._
```

### 3. Create the Issue

```bash
gh issue create --repo pfeff/guardian \
  --title "Sprint N Planning (dates)" \
  --body "$(cat <<'EOF'
[composed body]
EOF
)"
```

### 4. Add to Project Board

```bash
gh project item-add 4 --owner pfeff --url <issue-url>
```

### 5. Set Sprint Field

Use GraphQL since the CLI item-add doesn't set fields:

```bash
# Find the newly added item (use GraphQL items(last:5) to avoid pagination)
gh api graphql -f query='{
  user(login: "pfeff") {
    projectV2(number: 4) {
      items(last: 5) {
        nodes {
          id
          content { ... on Issue { number title repository { name } } }
        }
      }
    }
  }
}'

# Set the sprint field
gh api graphql -f query='
mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: "<project-id>"
    itemId: "<item-id>"
    fieldId: "<sprint-field-id>"
    value: { singleSelectOptionId: "<sprint-option-id>" }
  }) { projectV2Item { id } }
}'
```

### 6. Report

Show the user:
- Issue URL
- Sprint assignment confirmation

## Error Handling

- If issue creation fails, show the error and ask user to resolve
- If board assignment fails, provide the manual steps
- If sprint field option not found, list available options for user to choose
