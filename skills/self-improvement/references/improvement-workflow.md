# Improvement Workflow Reference

Documents the complete feedback loop between lessons learned analysis and skill enhancement.

## Improvement Cycle Overview

| Phase | Skill | Command | Output |
|-------|-------|---------|--------|
| 1. Capture | lessons-learned | `/claude-skills:lessons-learned` | Session analysis note |
| 2. Aggregate | lessons-learned | `/lessons-learned --aggregate` | Pattern frequency report with effectiveness tracking |
| 3. Scan | self-improvement | `/claude-skills:self-improvement` | Pending recommendations |
| 4. Implement | self-improvement | `/self-improvement REC-XXX --apply` | Updated skill files, version bump, CHANGELOG entry |

## Review Cadence

### Session-End Analysis

**When**: After completing significant work sessions (>30 min of focused work)

**Action**: Run `/claude-skills:lessons-learned`

**Frequency**: 1-3x per day during active development

**Skip when**:
- Session was primarily reading/research
- No blockers or inefficiencies encountered
- <30 min of actual work

### Pattern Aggregation

**When**: Accumulated 5+ lessons learned files since last aggregation

**Action**: Run `/lessons-learned --aggregate`

**Frequency**: Weekly or bi-weekly

**Indicators to run**:
- Same pattern appearing in multiple sessions
- Recommendation categories clustering
- Efficiency scores consistently low in same area

### Improvement Processing

**When**: Aggregation surfaces HIGH priority items or 5+ pending recommendations

**Action**: Run `/claude-skills:self-improvement` then process top recommendations

**Frequency**: After each aggregation or when backlog grows

---

## Decision Criteria

### Batch vs Single Processing

| Scenario | Recommendation | Rationale |
|----------|----------------|-----------|
| 1-2 HIGH priority items | Single processing | Focus, thorough review |
| 3+ similar category items | Batch with `--category` | Related changes together |
| Quick wins only | Batch with `--limit 5` | Rapid iteration |
| Complex/architectural | Single with `--propose` first | Careful review needed |
| First time using skill | Single processing | Learn the flow |

**Batch mode triggers**:
- `/self-improvement --batch --limit 3` - Process top 3
- `/self-improvement --batch --category Workflow` - All Workflow items
- `/self-improvement --batch --priority HIGH` - All HIGH priority

### Priority Selection Strategy

**Default strategy**: Priority-first, then effort (quick wins)

1. All HIGH priority items before MEDIUM
2. Within priority: Quick effort before Medium before Complex
3. Within effort: Older recommendations first (FIFO)

**Alternative strategies**:

| Strategy | Use When | Command |
|----------|----------|---------|
| Category-focused | Deep work on one area | `--category Workflow` |
| Quick-wins only | Limited time available | `--priority HIGH --limit 3` |
| Specific fix | Known issue to address | `REC-XXX` directly |

### Aggregation Triggers

**Run `/lessons-learned --aggregate` when**:
- 5+ new lessons learned files since last run
- Same recommendation appearing 3+ times
- Planning improvement sprint
- Before major skill refactoring

**Skip aggregation when**:
- <5 files to analyze
- Recent aggregation (<1 week)
- Actively implementing changes

---

## Feedback Loop

### How Improvements Affect Future Recommendations

```
Session N: Issue detected → Recommendation generated
    ↓
Improvement applied → Skill version bumped, CHANGELOG updated
    ↓
Session N+1: Issue should not recur
    ↓
Aggregation: Pattern frequency compared to previous baseline
    ↓
Validation: Effectiveness score shows improvement trend
```

### Tracking Effectiveness

**Signs of effective improvement**:
- Pattern frequency decreases in subsequent aggregations
- Session efficiency scores improve
- Fewer recommendations in same category

**Signs improvement needs revision**:
- Same pattern reappears
- New anti-patterns emerge from fix
- Recommendation marked implemented but issue persists

### Traceability Chain

Each improvement maintains links:
- `<!-- IMPLEMENTED: REC-XXX -->` in modified files
- `- [x] REC-XXX (implemented YYYY-MM-DD)` in source lessons file
- Version bump in affected skill's `SKILL.md` frontmatter
- CHANGELOG.md entry with reasoning and REC-ID reference
- Cross-references in subsequent lessons learned notes

### Task Integration

**Convention**: Include `REC-XXX` in task subject or description to link tasks to recommendations.

**Automatic completion**: When `/self-improvement REC-XXX --apply` succeeds, the system:
1. Searches task list for tasks containing `REC-XXX` or with `metadata.recId: REC-XXX`
2. Marks matching task as completed
3. Updates task metadata with `sourceFile` for reverse lookup

**Task column in scan output**: `/claude-skills:self-improvement` displays associated task ID (e.g., `#8`) or `-` if none.

**Metadata structure**:
```
TaskUpdate(
  taskId: "8",
  metadata: {
    recId: "REC-001",
    sourceFile: "/path/to/lessons-file.md",
    implementedAt: "2026-01-30T..."
  }
)
```

This enables bidirectional navigation:
- **Forward**: REC-001 → find task with matching recId → view/update task
- **Reverse**: Task #8 → read sourceFile from metadata → navigate to source Obsidian document

---

## Workflow Examples

### Weekly Improvement Routine

```
Monday-Thursday: Normal development
  - Run /claude-skills:lessons-learned at session end (if meaningful work)

Friday: Improvement review (30-60 min)
  1. /claude-skills:lessons-learned --aggregate
  2. Review pattern frequency report
  3. /claude-skills:self-improvement
  4. /claude-skills:self-improvement --batch --priority HIGH --limit 3
  5. Verify changes, commit
```

### After Significant Blocker

```
1. Complete session work
2. /claude-skills:lessons-learned (captures blocker as bottleneck)
3. If Five Whys generated systemic recommendation:
   a. /claude-skills:self-improvement REC-XXX --propose
   b. Review proposed changes
   c. /claude-skills:self-improvement REC-XXX --apply
4. Document in Obsidian if architectural
```

### Skill Development Sprint

```
1. /claude-skills:lessons-learned --aggregate --limit 50
2. Identify top 3 improvement areas by frequency
3. For each area:
   a. /claude-skills:self-improvement --category [area]
   b. Process all items in category
   c. Verify no regressions
4. Final aggregation to validate improvement
```

---

## Integration Points

| Skill | Integration |
|-------|-------------|
| `lessons-learned` | Source of recommendations |
| `obsidian-notes` | Note creation, linking |
| `git` | Commit after apply (optional) |
| `task-workflow` | Workspace context for targeted analysis |

---

## Anti-Patterns to Avoid

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| Running /claude-skills:lessons-learned after every message | Noise, low signal | Run after meaningful sessions |
| Never aggregating | Missing systemic patterns | Schedule weekly |
| Processing all recommendations at once | Fatigue, errors | Batch limit 3-5 |
| Skipping --propose for complex changes | Unexpected side effects | Always propose first |
| Ignoring LOW priority indefinitely | Technical debt | Monthly sweep |

---

## See Also

- `scan-recommendations.md` - Finding pending recommendations
- `analyze-improvement.md` - Feasibility assessment
- `propose-changes.md` - Generating diffs
- `apply-improvement.md` - Implementing with confirmation
- `recommendation-categories.md` - Category to target mapping
