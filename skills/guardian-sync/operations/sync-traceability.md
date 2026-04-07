# Sync Traceability Operation

Regenerate TRACEABILITY.md from GitHub Project data.

## Purpose

Creates an up-to-date traceability matrix showing the mapping from OKRs through requirements to implementation issues.

## Implementation

### 1. Ensure Guardian Repo is Current

Pull latest changes before modifying any files. Abort if the pull fails (e.g., diverged branch).

```bash
GUARDIAN_PATH="${HOME}/src/github/pfeff/guardian"
cd "${GUARDIAN_PATH}" && git pull --ff-only
```

If `git pull --ff-only` fails, **stop the operation** and report the error. The local branch may have diverged from the remote — resolve manually before retrying.

### 2. Fetch Project Data

Query GitHub Project #4 for all items with their custom fields:

```bash
gh project item-list 4 --owner pfeff --format json --limit 500
```

### 3. Generate Matrix

The TRACEABILITY.md structure:

```markdown
# Traceability Matrix

**Generated:** YYYY-MM-DDTHH:MM:SSZ

## Requirements to Issues

| OKR | Requirement | Title | Repo | Issue | Status |
|-----|-------------|-------|------|-------|--------|
| O1/KR1.1 | AO-CORE-01 | Orchestrator State Machine | agent-orchestrator | #42 | Done |

## Coverage Summary

- **AO**: X issues
- **CR**: Y issues
- **GN**: Z issues
- **UNLINKED**: N issues

## Gaps (No Requirement ID)

- [ ] repo#123: Issue title
```

### 4. Parse and Format

Extract from JSON response:
- `content.type` - Filter for "Issue" type
- `content.repository` - Source repo name
- `content.number` - Issue number
- `title` - Issue title
- `status` - Project status (Todo, In Progress, Done)
- Custom fields: `OKR`, `Requirement ID`

### 5. Write Output

Write to guardian repository:

```bash
GUARDIAN_PATH="${HOME}/src/github/pfeff/guardian"
```

## Script Reference

The guardian repo includes `scripts/sync-traceability.sh` which implements this logic:

```bash
cd ~/src/github/pfeff/guardian
./scripts/sync-traceability.sh
```

## Manual Execution Steps

If the script is unavailable, execute manually:

1. **Fetch project items**:
   ```bash
   gh project item-list 4 --owner pfeff --format json --limit 500 > /tmp/project-items.json
   ```

2. **Generate header**:
   ```bash
   echo "# Traceability Matrix" > TRACEABILITY.md
   echo "" >> TRACEABILITY.md
   echo "**Generated:** $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> TRACEABILITY.md
   ```

3. **Generate requirements table** using jq to parse the JSON

4. **Generate coverage summary** by grouping requirement IDs by prefix

5. **List gaps** where Requirement ID is null or empty

## Post-Sync Actions

After regenerating:

1. Review gaps section for unlinked issues
2. Commit updated TRACEABILITY.md if changes exist
3. Consider running `validate-coverage` for deeper analysis
