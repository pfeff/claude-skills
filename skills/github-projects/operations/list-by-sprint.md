# List by Sprint

Query project board items filtered by sprint name, with optional status filter. Uses the local SQLite cache for fast lookups.

## Parameters

- `sprint_name` (required): Exact sprint name to filter by (e.g., `Sprint 3 (Mar 3-7)`)
- `status_filter` (optional): Status value to further filter results (e.g., `Planned`, `In Progress`)

## Prerequisites

- Cache synced via `sync-cache`
- `sqlite3` CLI available

## Execution Steps

### 1. Query with sprint filter only

```bash
sqlite3 -separator '|' ~/Library/Caches/guardian/project-board.db "
  SELECT i.repo, i.issue_number, i.title,
         COALESCE(sv.value, '') as status
  FROM items i
  JOIN item_field_values spv ON i.item_id = spv.item_id
  JOIN fields spf ON spv.field_id = spf.field_id AND spf.name = 'Sprint'
  LEFT JOIN item_field_values sv ON i.item_id = sv.item_id
  LEFT JOIN fields sf ON sv.field_id = sf.field_id AND sf.name = 'Status'
  WHERE spv.value = '<sprint_name>'
    AND i.content_type = 'Issue'
  ORDER BY i.repo, i.issue_number;
"
```

Replace `<sprint_name>` with the target sprint name (case-sensitive).

### 2. Query with sprint and status filter

```bash
sqlite3 -separator '|' ~/Library/Caches/guardian/project-board.db "
  SELECT i.repo, i.issue_number, i.title,
         COALESCE(sv.value, '') as status
  FROM items i
  JOIN item_field_values spv ON i.item_id = spv.item_id
  JOIN fields spf ON spv.field_id = spf.field_id AND spf.name = 'Sprint'
  JOIN item_field_values sv ON i.item_id = sv.item_id
  JOIN fields sf ON sv.field_id = sf.field_id AND sf.name = 'Status'
  WHERE spv.value = '<sprint_name>'
    AND sv.value = '<status_filter>'
    AND i.content_type = 'Issue'
  ORDER BY i.repo, i.issue_number;
"
```

### 3. Parse output

Each row returns: `repo|issue_number|title|status`

Format for display:
```
pfeff/guardian#42 — Implement state machine (In Progress)
pfeff/cursor-rules#152 — Create GitHub Projects V2 skill (Planned)
```

## Extended Query: Include Additional Fields

To include Horizon and Strategic Objective:

```bash
sqlite3 -separator '|' ~/Library/Caches/guardian/project-board.db "
  SELECT i.repo, i.issue_number, i.title,
         COALESCE(sv.value, '') as status,
         COALESCE(hv.value, '') as horizon,
         COALESCE(sov.value, '') as strategic_objective
  FROM items i
  JOIN item_field_values spv ON i.item_id = spv.item_id
  JOIN fields spf ON spv.field_id = spf.field_id AND spf.name = 'Sprint'
  LEFT JOIN item_field_values sv ON i.item_id = sv.item_id
  LEFT JOIN fields sf ON sv.field_id = sf.field_id AND sf.name = 'Status'
  LEFT JOIN item_field_values hv ON i.item_id = hv.item_id
  LEFT JOIN fields hf ON hv.field_id = hf.field_id AND hf.name = 'Horizon'
  LEFT JOIN item_field_values sov ON i.item_id = sov.item_id
  LEFT JOIN fields sof ON sov.field_id = sof.field_id AND sof.name = 'Strategic Objective'
  WHERE spv.value = '<sprint_name>'
    AND i.content_type = 'Issue'
  ORDER BY i.repo, i.issue_number;
"
```

## Discovering Available Sprint Names

If the sprint name is unknown, list all sprint values:

```bash
project-board-helper field Sprint
```

This returns all sprint option names and their IDs.

## Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| No results returned | Sprint name doesn't match (case-sensitive) | Check available sprint names via `project-board-helper field Sprint` |
| Cache DB not found | Never synced | Run `sync-cache` first |
| Stale results | Board changed since last sync | Run `sync-cache` then retry |
