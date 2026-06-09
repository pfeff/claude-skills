# Add to Board

Add a GitHub issue to the project board. Idempotent — calling on an issue already on the board is a no-op.

## Parameters

- `owner` (required): Project owner (default: `pfeff`)
- `project_number` (required): Project number (default: `4`)
- `issue_url` (required): Full GitHub issue URL (e.g., `https://github.com/<owner>/<repo>/issues/42`)

## Prerequisites

- `gh` CLI authenticated with `project` scope

## Execution Steps

### 1. Add item

```bash
gh project item-add <project_number> --owner <owner> --url <issue_url>
```

Example:
```bash
gh project item-add 4 --owner pfeff --url https://github.com/<owner>/<repo>/issues/42
```

### 2. Sync cache

After adding, sync the cache so the new item is available for lookups and queries:

```bash
project-board-helper sync
```

### 3. Verify

Confirm the item appears in the cache:

```bash
project-board-helper lookup <owner/repo> <issue_number>
```

## Constructing the Issue URL

From an issue reference like `<owner>/<repo>#42`:

```
https://github.com/<owner>/<repo>/issues/42
```

Pattern: `https://github.com/<owner>/<repo>/issues/<number>`

## Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| Item already on board | Issue was previously added | Safe to ignore — operation is idempotent |
| Invalid URL | Malformed issue URL | Verify URL format: `https://github.com/<owner>/<repo>/issues/<number>` |
| Permission denied | Insufficient project access | Check `gh auth status` and project membership |
| Repository not found | Issue URL references nonexistent repo | Verify the repository exists and is accessible |
