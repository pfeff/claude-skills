# Scan Recommendations Operation

**When**: User requests `/claude-skills:self-improvement` to list pending recommendations

## Purpose

Find and extract pending skill/command-related recommendations from lessons learned files. Filter to actionable items and rank by priority.

## Execution

### Step 1: Resolve Vault Path and Locate Files

Resolve Obsidian vault constants via the host-config helper:

```bash
source "$HOME/.claude/skills/obsidian-notes/scripts/host-config.sh" || {
  echo "[obsidian-notes] vault unavailable; falling back to docs/lessons-learned/" >&2
}
```

On success: `$OBSIDIAN_VAULT_PATH` is the vault filesystem root for read-side globs. On failure (helper returned non-zero), search `docs/lessons-learned/` instead — the rest of this operation is read-only and the same Grep patterns apply.

Search for lessons files:
```bash
ls -1t "$OBSIDIAN_VAULT_PATH"/Generated/*Lesson*.md 2>/dev/null | head -20
```

### Step 2: Extract Recommendations

For each file, search for recommendation sections:

```
Grep(pattern: "#### REC-\\d+:", path: "{file}")
```

Extract from each recommendation block:
- **REC-ID**: e.g., `REC-001`
- **Title**: Text after REC-ID
- **Category**: From `**Category**:` line
- **Priority**: From `**Priority**:` or `**Impact**:` line
- **Effort**: From `**Effort**:` line
- **Status**: Check if marked as implemented in action items

### Step 3: Filter for Skill-Related Categories

Include recommendations in these categories:
- **Workflow** - Improvements to skill operations
- **Commands** - Slash command enhancements
- **Utilities** - Helper scripts and tools
- **Skills** - Direct skill improvements (derived from content)

Exclude:
- **Documentation** - Unless specifically about skill docs
- **User Practices** - Behavioral recommendations
- **External Tools** - Third-party tool suggestions

### Step 4: Check Implementation Status

For each recommendation, check if already implemented:

1. Look for `- [x]` checkbox in action items section
2. Search target skill files for REC-ID reference in comments
3. Check for `IMPLEMENTED: REC-XXX` markers

Mark status: `pending` | `in-progress` | `implemented`

### Step 5: Rank by Priority

Sort order:
1. Priority: HIGH > MEDIUM > LOW
2. Effort: Quick < Medium < Complex (prefer quick wins)
3. Age: Older recommendations first (FIFO within priority)

### Step 5.5: Cross-Reference with Task List

Query native task system for task associations:

```
TaskList
```

For each recommendation, search task list for matching REC-ID:
- Extract task ID and status if found
- Track association: `hasTask: true/false`, `taskId: N`, `taskStatus: pending/in_progress/completed`

**5c. Update Task Metadata (if missing)**

For tasks that reference a REC-ID but lack `sourceFile` metadata:

```
TaskUpdate(
  taskId: "{task_id}",
  metadata: {
    recId: "REC-{id}",
    sourceFile: "{lessons_file_path}"
  }
)
```

This enables reverse lookup: Task → Source Obsidian document.

### Step 6: Format Output

```markdown
## Pending Recommendations

| Priority | REC-ID | Category | Title | Effort | Task | Source |
|----------|--------|----------|-------|--------|------|--------|
| HIGH | REC-001 | Workflow | Add parallel file reading | Quick | #8 | 20260115-Lessons.md |
| HIGH | REC-004 | Commands | Add --verbose flag | Medium | - | 20260115-Lessons.md |
| MEDIUM | REC-003 | Utilities | Cache git status results | Quick | - | 20260114-Lessons.md |

**Found**: 5 actionable recommendations
**Filtered out**: 3 (Documentation), 2 (User Practices), 1 (Implemented)

### Quick Actions

- `/self-improvement REC-001` - Analyze top recommendation
- `/self-improvement --batch --limit 3` - Process top 3
- `/self-improvement --category Workflow` - Focus on workflow improvements
```

## Extraction Patterns

### Recommendation Block Pattern

```
#### REC-(\d+): (.+)
\*\*Category\*\*: (.+)
\*\*Effort\*\*: (.+)
\*\*Impact\*\*: (.+)
```

### Action Item Status Pattern

```
- \[([ x])\] (REC-\d+)
```

### Implemented Marker Pattern

```
<!-- IMPLEMENTED: REC-\d+ -->
```

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--category` | string | all | Filter by category |
| `--priority` | string | all | Filter by priority level |
| `--limit` | int | 10 | Max recommendations to show |
| `--include-implemented` | boolean | false | Show implemented recommendations too |
| `--source` | string | all | Filter by source file pattern |

## Error Handling

**No files found**:
```
No lessons learned files found. Run `/claude-skills:lessons-learned` to generate recommendations.
```

**No recommendations extracted**:
```
Found [N] lessons learned files but no actionable recommendations.
Consider running `/lessons-learned --aggregate` to identify patterns.
```

**All implemented**:
```
All [N] recommendations have been implemented. Great work!
Run `/claude-skills:lessons-learned` on recent sessions to generate new recommendations.
```
