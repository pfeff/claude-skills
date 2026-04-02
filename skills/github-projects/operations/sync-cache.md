# Sync Cache

Refresh the local SQLite cache from the GitHub Projects V2 API. Must be called before read operations to ensure data freshness.

## Parameters

None. Uses defaults from `references/project-defaults.md`.

## Prerequisites

- `project-board-helper` binary installed
- `gh` CLI authenticated with `project` scope

## Execution Steps

### 1. Run sync

```bash
project-board-helper sync
```

This fetches all project items, fields, and field values from the GitHub API and writes them to the local SQLite cache at `~/Library/Caches/guardian/project-board.db`.

### 2. Verify sync

Confirm the cache was updated by checking item count:

```bash
sqlite3 ~/Library/Caches/guardian/project-board.db "SELECT COUNT(*) FROM items;"
```

## When to Sync

- **Before queries**: Sync before `list-by-sprint`, `lookup-item`, or `field-metadata` if data may be stale
- **After mutations**: Sync after `add-to-board` to pick up newly added items in the cache
- **Not required after**: `set-status` or `set-sprint` — these update the remote board but the cache doesn't need to reflect the change immediately unless a subsequent query depends on it

## Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| `project-board-helper: command not found` | Binary not installed | `go install github.com/pfeff/project-board-helper/cmd/project-board-helper@latest` |
| Auth failure | `gh` not authenticated or missing `project` scope | `gh auth refresh -s project` |
| Network error | GitHub API unreachable | Retry; if persistent, check `gh auth status` |
| Empty cache after sync | Project has no items, or wrong project configured | Verify project number and owner in `project-board-helper` config |
