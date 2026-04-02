# Set Sprint

Assign an item to a sprint on the project board via GraphQL mutation.

## Parameters

- `owner_repo` (required): Repository in `owner/repo` format (e.g., `pfeff/guardian`)
- `issue_number` (required): Issue number
- `target_sprint` (required): Sprint option name (e.g., `Sprint 3 (Mar 3-7)`)

## Prerequisites

- Item must already be on the project board (use `add-to-board` first if not)
- `gh` CLI authenticated with `project` scope
- `project-board-helper` installed

## Execution Steps

### 1. Look up item ID

```bash
project-board-helper lookup <owner_repo> <issue_number>
```

If not found, item is not on the board — use `add-to-board` first.

### 2. Get Sprint field ID and option ID

```bash
project-board-helper field Sprint
```

Parse output to find:
- `field_id`: The Sprint field ID
- The option ID matching `<target_sprint>` (case-sensitive match)

### 3. Execute mutation

```bash
gh api graphql -f query='
mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: "<project_node_id>"
    itemId: "<item_id>"
    fieldId: "<sprint_field_id>"
    value: { singleSelectOptionId: "<sprint_option_id>" }
  }) { projectV2Item { id } }
}'
```

Values:
- `project_node_id`: Default `PVT_kwHNa8POARiyqQ` (see `references/project-defaults.md`)
- `item_id`: From step 1
- `sprint_field_id`: From step 2
- `sprint_option_id`: From step 2

### 4. Verify (optional)

```bash
project-board-helper sync
sqlite3 ~/Library/Caches/guardian/project-board.db "
  SELECT spv.value
  FROM items i
  JOIN item_field_values spv ON i.item_id = spv.item_id
  JOIN fields spf ON spv.field_id = spf.field_id AND spf.name = 'Sprint'
  WHERE i.repo = '<owner_repo>' AND i.issue_number = <issue_number>;
"
```

## Batch Assignment

To assign multiple items to the same sprint, resolve the sprint field/option IDs once in step 2, then repeat steps 1 and 3 for each item:

```bash
for item in "pfeff/guardian 42" "pfeff/cursor-rules 152"; do
  repo=$(echo "$item" | cut -d' ' -f1)
  number=$(echo "$item" | cut -d' ' -f2)
  item_id=$(project-board-helper lookup "$repo" "$number")
  gh api graphql \
    -f query='mutation($proj:ID! $item:ID! $field:ID! $opt:String!) { updateProjectV2ItemFieldValue(input: { projectId:$proj itemId:$item fieldId:$field value: { singleSelectOptionId:$opt } }) { projectV2Item { id } } }' \
    -f proj="<project_node_id>" \
    -f item="$item_id" \
    -f field="<sprint_field_id>" \
    -f opt="<sprint_option_id>"
done
```

## Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| Item not found in lookup | Item not on board | Run `add-to-board` first, then `sync-cache`, then retry |
| Sprint option not found | Name mismatch (case-sensitive) | Check available sprints via `project-board-helper field Sprint` |
| GraphQL error | Auth failure or invalid IDs | Check `gh auth status`; verify IDs from field-metadata |
