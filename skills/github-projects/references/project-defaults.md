# Project Defaults

Default configuration values for the Guardian GitHub Projects V2 board.

## Project Identity

| Setting | Value |
|---------|-------|
| Owner | `pfeff` |
| Project name | `Guardian` |
| Project number | `4` |
| Project node ID | `PVT_kwHNa8POARiyqQ` |
| Project URL | `https://github.com/users/pfeff/projects/4` |

## Cache

| Setting | Value |
|---------|-------|
| Cache DB path | `~/Library/Caches/guardian/project-board.db` |
| Cache tool | `project-board-helper` |
| Sync command | `project-board-helper sync` |

## Common Fields

| Field Name | Type | Typical Values |
|------------|------|----------------|
| Status | SingleSelect | Backlog, Planned, In Progress, Done |
| Sprint | SingleSelect | Sprint N (dates) |
| Horizon | SingleSelect | H1, H2, H3 |
| Strategic Objective | SingleSelect | Various |

Field IDs and option IDs are dynamic — always resolve via `project-board-helper field <name>`.

## Repositories

Common repositories on this project board:

| Repository | Description |
|------------|-------------|
| `pfeff/guardian` | Meta-repository, project docs, sprint planning |
| `pfeff/cursor-rules` | Skills, commands, workflow automation (deprecated — migrated to `pfeff/claude-skills`) |
| `pfeff/agent-coordinator` | Agent coordination service |
| `pfeff/agent-orchestrator` | Agent orchestration service |

## Issue Reference Format

Standard format used across skills: `owner/repo#number`

Examples:
- `pfeff/guardian#42`
- `pfeff/cursor-rules#152`

To construct a URL from a reference:
```
https://github.com/<owner>/<repo>/issues/<number>
```
