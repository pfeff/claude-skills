# Field Metadata

Query field definitions to discover field IDs and option IDs needed for mutations. Every `set-status` or `set-sprint` call requires these IDs.

## Parameters

- `field_name` (required): The field to query (e.g., `Status`, `Sprint`, `Horizon`, `Strategic Objective`)

## Prerequisites

- `project-board-helper` binary installed
- Cache synced (run `sync-cache` first if stale)

## Execution Steps

### 1. Query field definition

```bash
project-board-helper field <field_name>
```

Example:
```bash
project-board-helper field Status
```

### 2. Parse output

The output contains the field ID and all option IDs. Extract:

- **Field ID**: The `field_id` value (e.g., `PVTSSF_lAHNa8POARiyqc4A1234`)
- **Option IDs**: Each option has a name and ID mapping

Example output structure:
```
field_id: PVTSSF_lAHNa8POARiyqc4A1234
options:
  Backlog: abc123
  Planned: def456
  In Progress: ghi789
  Done: jkl012
```

### 3. Select target option

Match the desired option name (case-sensitive) to get its option ID. This ID is used in GraphQL mutations.

## Common Fields

| Field | Purpose | Typical Options |
|-------|---------|-----------------|
| Status | Workflow state | Backlog, Planned, In Progress, Done |
| Sprint | Sprint assignment | Sprint 1 (Feb 17-21), Sprint 2 (Feb 24-28), ... |
| Horizon | Planning horizon | H1, H2, H3 |
| Strategic Objective | OKR alignment | Various objective names |

## Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| Unknown field name | Field doesn't exist on the project | Check available fields — common names: Status, Sprint, Horizon |
| Empty options | Field has no options (may be text/number type) | Verify field type on the project board |
| Stale data | Field options changed on the board | Run `sync-cache` then retry |
