---
name: github-projects
description: Manage GitHub Projects V2 boards — list items by sprint, set status/sprint fields, add issues to boards, query field metadata. Use when working with GitHub project boards, sprint assignments, or board status transitions.
allowed-tools:
  - Bash
  - Read
allowed-prompts:
  - tool: Bash
    prompt: sync project board cache
  - tool: Bash
    prompt: query project board cache
  - tool: Bash
    prompt: query board field metadata
  - tool: Bash
    prompt: look up board item ID
  - tool: Bash
    prompt: add issue to project board
  - tool: Bash
    prompt: update project item field via GraphQL
  - tool: Bash
    prompt: view GitHub issue details
version: 1.0.0
---

# GitHub Projects V2

Consolidated operations for GitHub Projects V2 board management. Provides query and mutation operations backed by a local SQLite cache (`project-board-helper`) and GraphQL mutations via `gh api graphql`.

## Prerequisites

- `project-board-helper` binary: `go install github.com/pfeff/project-board-helper/cmd/project-board-helper@latest`
- `gh` CLI with project scope: `gh auth refresh -s project`
- `sqlite3` (ships with macOS)
- `jq` for JSON processing

Cache DB: `~/Library/Caches/guardian/project-board.db`

## Operations

### 1. Sync Cache
**When**: Before any query operation, or after mutations to refresh state
**Implementation**: Load `operations/sync-cache.md`
**Quick summary**: Runs `project-board-helper sync` to refresh the local SQLite cache from the GitHub API

### 2. Field Metadata
**When**: Need field IDs or option IDs for mutations (Status, Sprint, etc.)
**Implementation**: Load `operations/field-metadata.md`
**Quick summary**: Queries field definitions via `project-board-helper field <name>`, extracts field IDs and option IDs

### 3. List by Sprint
**When**: Query board items for a specific sprint, optionally filtered by status
**Implementation**: Load `operations/list-by-sprint.md`
**Quick summary**: SQLite query against cache DB filtering by Sprint field value, with optional Status filter

### 4. Set Status
**When**: Change an item's status (e.g., to "In Progress", "Done")
**Implementation**: Load `operations/set-status.md`
**Quick summary**: GraphQL `updateProjectV2ItemFieldValue` mutation for the Status field. Item must already be on the board.

### 5. Set Sprint
**When**: Assign an item to a sprint
**Implementation**: Load `operations/set-sprint.md`
**Quick summary**: GraphQL `updateProjectV2ItemFieldValue` mutation for the Sprint field. Item must already be on the board.

### 6. Add to Board
**When**: Add a GitHub issue to the project board
**Implementation**: Load `operations/add-to-board.md`
**Quick summary**: `gh project item-add` with project number and owner. Idempotent — safe to call on items already on the board.

### 7. Lookup Item
**When**: Need to resolve an issue reference (owner/repo#number) to a project item ID for mutations
**Implementation**: Load `operations/lookup-item.md`
**Quick summary**: `project-board-helper lookup <owner/repo> <number>` against the local cache

## Common Patterns

### Read Path (cache-backed)
```
sync-cache → field-metadata / list-by-sprint / lookup-item
```
All read operations query the local SQLite cache. Call `sync-cache` first to ensure freshness.

### Write Path (GraphQL mutations)
```
lookup-item → set-status / set-sprint
```
Mutations require the item ID (from `lookup-item`) and field/option IDs (from `field-metadata`).

### Add + Configure
```
add-to-board → sync-cache → lookup-item → set-sprint + set-status
```
New items need to be added to the board first, then cache synced to pick up the new item ID.

## Quick Reference

| Operation | Tool | Command |
|-----------|------|---------|
| Sync cache | `project-board-helper` | `project-board-helper sync` |
| Field metadata | `project-board-helper` | `project-board-helper field <name>` |
| List by sprint | `sqlite3` | Query against cache DB |
| Set status | `gh api graphql` | `updateProjectV2ItemFieldValue` mutation |
| Set sprint | `gh api graphql` | `updateProjectV2ItemFieldValue` mutation |
| Add to board | `gh` | `gh project item-add <number> --owner <owner> --url <url>` |
| Lookup item | `project-board-helper` | `project-board-helper lookup <owner/repo> <number>` |

## Defaults

| Setting | Value |
|---------|-------|
| Owner | `pfeff` |
| Project number | `4` |
| Project node ID | `PVT_kwHNa8POARiyqQ` |
| Cache DB | `~/Library/Caches/guardian/project-board.db` |

For full default configuration, see `references/project-defaults.md`.

## Error Handling

| Error | Resolution |
|-------|------------|
| `project-board-helper` not found | `go install github.com/pfeff/project-board-helper/cmd/project-board-helper@latest` |
| Auth failure / missing project scope | `gh auth refresh -s project` |
| Item not found on board | Use `add-to-board` first, then `sync-cache` |
| Stale cache | Run `sync-cache` to refresh |
| Unknown field name | Check available fields with `project-board-helper field` (no args) |

## Progressive Disclosure

- `operations/*.md` — Detailed implementation steps for each operation
- `references/graphql-templates.md` — Reusable GraphQL mutation and query blocks
- `references/project-defaults.md` — Default project IDs, field names, and configuration
