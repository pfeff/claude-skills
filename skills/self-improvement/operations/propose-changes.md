# Propose Changes Operation

**When**: User requests `/self-improvement REC-XXX --propose`

## Purpose

Generate specific, reviewable changes for a recommendation. Shows diff-style preview before any modifications.

## Execution

### Step 1: Load Analysis

If not already analyzed, run analyze-improvement first:

```
Read(file_path: "${CLAUDE_PLUGIN_ROOT}/skills/self-improvement/operations/analyze-improvement.md")
```

Gather:
- Target files
- Modification type
- Recommendation context

### Step 2: Read Target Files

For each target file identified:

```
Read(file_path: "{target_file}")
```

Identify specific sections to modify based on:
- Line numbers from analysis
- Section headers
- Pattern matching for relevant code

### Step 3: Generate Proposed Edits

For each modification:

**Addition**: New content to insert
```markdown
### Addition to {file}

**Location**: After line {N} (section: {header})

```diff
+ {new content line 1}
+ {new content line 2}
```

**Rationale**: {why this change addresses the recommendation}
```

**Modification**: Changes to existing content
```markdown
### Modification in {file}

**Location**: Lines {start}-{end}

```diff
- {original line 1}
- {original line 2}
+ {new line 1}
+ {new line 2}
```

**Rationale**: {why this change addresses the recommendation}
```

**Deletion**: Content to remove
```markdown
### Deletion from {file}

**Location**: Lines {start}-{end}

```diff
- {content to remove}
```

**Rationale**: {why removal addresses the recommendation}
```

### Step 4: Validate Changes

Check proposed changes for:
- Syntax validity (markdown structure)
- Consistency with existing patterns
- No unintended side effects
- Completeness (all aspects of recommendation addressed)

### Step 5: Format Proposal

```markdown
## Proposed Changes for REC-{id}

**Recommendation**: {title}
**Files affected**: {count}
**Total lines changed**: +{additions} / -{deletions}

---

### File 1: `{path}`

**Change type**: {Addition/Modification/Deletion}
**Section**: {header or line range}

```diff
{unified diff format}
```

**Rationale**: {explanation linking to recommendation}

---

### File 2: `{path}`

[repeat for each file]

---

## Summary

| File | Additions | Deletions | Change Type |
|------|-----------|-----------|-------------|
| `operations/create-workspace.md` | +5 | -2 | Modification |
| `SKILL.md` | +1 | 0 | Addition |

## Traceability

These changes implement REC-{id} from `{source_file}`.
After applying, the source file will be updated to mark this recommendation as implemented.

## Next Steps

- Review the proposed changes above
- Use `/self-improvement REC-{id} --apply` to implement
- Use `/self-improvement REC-{id} --apply --dry-run` to simulate without writing
```

## Change Generation Guidelines

### For Workflow Improvements

Focus on:
- Operation step modifications
- Adding parallel execution hints
- Improving error handling
- Updating example commands

### For Command Improvements

Focus on:
- Option additions
- Help text updates
- Default value changes
- Argument handling

### For Utility Improvements

Focus on:
- Script modifications
- New helper functions
- Performance optimizations
- Error handling improvements

### For Skill Improvements

Focus on:
- SKILL.md operation updates
- New operation files
- Reference documentation
- Integration point changes

## Diff Format

Use unified diff format for clarity:
- `+` prefix for additions (green in most viewers)
- `-` prefix for deletions (red in most viewers)
- Context lines without prefix
- `@@` markers for location

## Error Handling

**Cannot generate valid changes**:
```
Unable to generate specific changes for REC-{id}.

Possible reasons:
- Target files have changed significantly since recommendation
- Recommendation requires manual architectural decisions
- Insufficient context in original recommendation

Suggestion: Review the recommendation manually and implement changes directly.
```

**Ambiguous modification point**:
```
Multiple potential modification points found for REC-{id}.

Options:
1. {location 1}: {context}
2. {location 2}: {context}

Use AskUserQuestion to clarify preferred location.
```
