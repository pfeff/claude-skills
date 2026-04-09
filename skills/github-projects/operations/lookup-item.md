# Lookup Item

Resolve a GitHub issue reference to its project board item ID. The item ID is required for all GraphQL mutations (`set-status`, `set-sprint`).

## Parameters

- `owner_repo` (required): Repository in `owner/repo` format (e.g., `pfeff/guardian`)
- `issue_number` (required): Issue number

## Prerequisites

- `project-board-helper` installed
- Cache synced via `sync-cache`

## Execution Steps

### 1. Look up item ID

```bash
project-board-helper lookup <owner_repo> <issue_number>
```

Example:
```bash
project-board-helper lookup pfeff/guardian 42
```

Returns the project item ID (e.g., `PVTI_lAHNa8POARiyqc4BcDef`).

### 2. Handle cache miss

If the item is not found, the issue may have been recently added to the board. Sync and retry:

```bash
project-board-helper sync
project-board-helper lookup <owner_repo> <issue_number>
```

If still not found after sync, the issue is not on the project board. Use `add-to-board` to add it.

## Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| Item not found | Issue not on project board | Use `add-to-board` to add it, then `sync-cache`, then retry |
| Item not found after sync | Issue genuinely not on board | Confirm the issue exists: `gh issue view <number> --repo <owner/repo>` |
| Stale item ID | Item was removed and re-added | Run `sync-cache` to refresh |
