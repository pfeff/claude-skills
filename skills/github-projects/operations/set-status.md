# Set Status

Change an item's Status field on the project board via GraphQL mutation.

## Parameters

- `owner_repo` (required): Repository in `owner/repo` format (e.g., `<owner>/<repo>`)
- `issue_number` (required): Issue number
- `target_status` (required): Status option name (e.g., `In Progress`, `Done`, `Planned`)

## Prerequisites

- Item must already be on the project board (use `add-to-board` first if not)
- `gh` CLI authenticated with `project` scope
- `project-board-helper` installed (for item ID and field metadata lookups)

## Execution Steps

### 1. Look up item ID

```bash
project-board-helper lookup <owner_repo> <issue_number>
```

Returns the project item ID. If not found, the item is not on the board — use `add-to-board` first.

### 2. Get Status field ID and option ID

```bash
project-board-helper field Status
```

Parse output to find:
- `field_id`: The Status field ID
- The option ID matching `<target_status>` (case-sensitive match)

### 3. Execute mutation

```bash
gh api graphql -f query='
mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: "<project_node_id>"
    itemId: "<item_id>"
    fieldId: "<status_field_id>"
    value: { singleSelectOptionId: "<status_option_id>" }
  }) { projectV2Item { id } }
}'
```

Values:
- `project_node_id`: Default `PVT_kwHNa8POARiyqQ` (see `references/project-defaults.md`)
- `item_id`: From step 1
- `status_field_id`: From step 2
- `status_option_id`: From step 2

### 4. Verify (optional)

After mutation, optionally sync cache and verify:

```bash
project-board-helper sync
sqlite3 ~/Library/Caches/<project>/project-board.db "
  SELECT sv.value
  FROM items i
  JOIN item_field_values sv ON i.item_id = sv.item_id
  JOIN fields sf ON sv.field_id = sf.field_id AND sf.name = 'Status'
  WHERE i.repo = '<owner_repo>' AND i.issue_number = <issue_number>;
"
```

## Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| Item not found in lookup | Item not on board | Run `add-to-board` first, then `sync-cache`, then retry |
| Status option not found | Typo or option doesn't exist | Check available options via `project-board-helper field Status` |
| GraphQL error | Auth failure or invalid IDs | Check `gh auth status`; verify IDs from field-metadata |
| Item already in target status | No-op | Mutation succeeds silently — safe to call idempotently |
