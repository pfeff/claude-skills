# Reconcile Board Operation

Pipeline adapter for board reconciliation. Receives gather-data output and delegates comparison logic to `board-reconciliation.md`.

**References**: R1-R5 (Board Reconciliation), DD1 (Internal Operation), DD3 (Adapter Pattern)

## Inputs

| Input | Source | Description |
|-------|--------|-------------|
| Issues list | gather-data output | All issues closed in the sprint date range |
| PRs list | gather-data output | All PRs merged in the sprint date range |
| owner | SKILL.md config | GitHub owner (default: `pfeff`) |
| project-number | SKILL.md config | GitHub project number (default: `4`) |
| sprint-name | User argument | Sprint identifier to filter board items (e.g., `Sprint 2 (Feb 24 - Mar 7)`) |

## Process

### 1. Prepare Activity Data

Extract from gather-data output:
- **Issues**: `{repo, number, title}` for each closed issue
- **PRs**: `{repo, number, title}` for each merged PR

### 2. Delegate to Board Reconciliation

Load the core reconciliation operation:

```
Read: operations/board-reconciliation.md
```

Pass inputs:
- `issues` — extracted issue list from step 1
- `prs` — extracted PR list from step 1
- `owner` — from SKILL.md config
- `project-number` — from SKILL.md config
- `sprint-name` — from user argument

Execute the board-reconciliation process (sync cache, query board, build comparison sets, compute differences, calculate coverage).

### 3. Return Output

Pass the board-reconciliation output through unchanged. The output format is defined in `board-reconciliation.md`.

## Output Consumers

This operation's output is consumed by:
- **generate-report** — tracking coverage and reconciliation tables go into the Completion Rate section
- **create-actions** — persistent low coverage may generate a process improvement action item
