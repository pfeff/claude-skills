# Populate Backlog

Refine and assign selected issues to the sprint on the project board.

## When to Use

After the sprint planning issue is created. Refines problem framing on each issue, then assigns all agreed-upon issues to the sprint field.

## Prerequisites

- Sprint plan with specific issue list from Step 2
- Project board IDs (project, sprint field, sprint option) from Step 1
- Sprint planning issue created in Step 3
- `project-board-helper` binary installed
- `sqlite3` CLI (ships with macOS)
- Cache DB: `~/Library/Caches/guardian/project-board.db`

## Steps

### 1. Collect Issue URLs

From the sprint plan, build a list of all issues to assign:

```
pfeff/guardian#N
pfeff/agent-coordinator#N
pfeff/agent-orchestrator#N
...
```

### 2. Refine Problem Framing

**Invariant: every issue assigned to the sprint must be fully refined.**

For each candidate issue, assess problem framing using the 4-dimension pattern from `planning-workflow/operations/problem-validation.md`.

#### 2a. Assess and interview

For each issue, fetch its body and run the problem-validation assessment (see `planning-workflow/operations/problem-validation.md` for dimension definitions, classification scheme, and interview approach):

```bash
gh issue view <number> -R pfeff/<repo> --json body,title -q '.title + "\n\n" + .body'
```

#### 2b. Update the issue body (if gaps found)

If any dimensions were missing and filled via interview, prepend a Problem Validation section to the issue body:

```bash
gh issue edit <number> -R pfeff/<repo> --body "$(cat <<'EOF'
## Problem Validation

**User**: <validated user/persona>
**Pain**: <validated problem statement>
**Current workflow**: <validated current process>
**Success criteria**: <validated definition of done>

---

<original issue body>
EOF
)"
```

If all dimensions were already Covered, skip the edit.

#### 2c. Gate check

After processing all issues, confirm the full list is refined before proceeding:

```
Refinement complete:
  ✓ pfeff/repo#N — all dimensions covered
  ✓ pfeff/repo#N — refined via interview (User, Pain added)
  ...

All N issues refined. Proceeding to board assignment.
```

If the user declines to refine an issue, remove it from the sprint candidate list and note the exclusion.

### 3. Ensure Issues Are on the Board

For each issue, check if it's already a project item. If not, add it:

```bash
gh project item-add 4 --owner pfeff --url https://github.com/pfeff/<repo>/issues/<N>
```

### 4. Look Up Item IDs

Use `project-board-helper lookup` to resolve each issue to its project item ID:

```bash
# For each issue in the sprint plan:
project-board-helper lookup pfeff/<repo> <number>
```

This returns the item ID instantly from the local cache (falls back to targeted GraphQL on cache miss).

### 5. Set Sprint Field in Batch

Get the sprint field ID and target option ID:

```bash
project-board-helper field Sprint
```

Parse the output to find the `field_id` and the option ID matching the target sprint name.

For each item, set the sprint field:

```bash
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

Values come from:
- `project-id`: `PVT_kwHNa8POARiyqQ` (default)
- `item-id`: from `project-board-helper lookup` (step 4)
- `sprint-field-id`: from `project-board-helper field Sprint`
- `sprint-option-id`: from the field output's options list

### 6. Confirm with User

Present the final sprint composition:

```
Sprint N backlog populated:

[Focus Area 1]
  - pfeff/repo#N — Title (assigned)
  - pfeff/repo#N — Title (assigned)

[Focus Area 2]
  - pfeff/repo#N — Title (assigned)

Total: N issues assigned to Sprint N
```

### 7. Verify

Re-sync the cache and verify all items show the correct sprint:

```bash
project-board-helper sync
```

Then query the cache to confirm assignments:

```bash
sqlite3 ~/Library/Caches/guardian/project-board.db "
  SELECT i.repo || '#' || i.issue_number || ' — ' || i.title
  FROM items i
  JOIN item_field_values spv ON i.item_id = spv.item_id
  JOIN fields spf ON spv.field_id = spf.field_id AND spf.name = 'Sprint'
  WHERE spv.value = '<target_sprint>'
    AND i.content_type = 'Issue'
  ORDER BY i.repo, i.issue_number;
"
```

## Error Handling

- If an issue can't be added to the board (wrong repo, permissions), skip and report
- If sprint field update fails, collect failures and report at end
- If item ID not found via `project-board-helper lookup`, run `project-board-helper sync` and retry
