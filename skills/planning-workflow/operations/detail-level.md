# Detail Level Selection

Select plan detail level based on task complexity. Prevents over-planning simple tasks and under-planning complex ones.

## Parameters

- `task_description` (required): The issue title, description, and requirements
- `specflow_summary` (optional): Output from SpecFlow analysis — flow count, edge case count, gap count

## Detail Levels

### Minimal

**For**: Simple bugs, small features, one-file changes, documentation fixes.

**Indicators**:
- Single flow with 0-1 decision points
- No specification gaps found
- Familiar domain, strong local knowledge
- Estimated 1-2 files changed

**Plan includes**:
- Problem statement
- Acceptance criteria (checkable)

### More

**For**: Standard features, multi-file changes, moderate complexity.

**Indicators**:
- 2-3 flows with a few decision points
- Some edge cases worth noting
- May involve unfamiliar components
- Estimated 3-8 files changed

**Plan includes**:
- Problem statement
- Technical considerations
- Risks and mitigations
- Acceptance criteria (checkable)
- Dependencies

### A Lot

**For**: Major features, architectural changes, cross-cutting concerns.

**Indicators**:
- 4+ flows or complex decision trees
- Multiple specification gaps
- New patterns or significant refactoring
- Cross-repository impact
- Estimated 8+ files changed

**Plan includes**:
- Problem statement
- Implementation phases (ordered)
- Technical considerations
- Alternative approaches considered
- Risks and mitigations
- Resource requirements
- Acceptance criteria (checkable)
- Dependencies

## Execution Steps

### 1. Score complexity signals

Evaluate these signals from the task and prior phases:

| Signal | Minimal (0) | More (1) | A Lot (2) |
|--------|-------------|----------|-----------|
| Flows | 0-1 | 2-3 | 4+ |
| Edge cases | 0-2 | 3-5 | 6+ |
| Spec gaps | 0 | 1-2 | 3+ |
| Files affected | 1-2 | 3-8 | 8+ |
| Cross-repo | No | No | Yes |

### 2. Select level

- Total score 0-2: **Minimal**
- Total score 3-5: **More**
- Total score 6+: **A Lot**

If uncertain, prefer one level up rather than under-planning.

### 3. Log selection

```markdown
## Plan Detail Level

**Level**: <Minimal/More/A Lot>
**Rationale**: <one sentence explaining why this level was chosen>
```

## Output

The selected detail level and rationale. The plan generator uses this to determine which sections to include.
