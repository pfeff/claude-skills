# Analyze Improvement Operation

**When**: User specifies a REC-ID to analyze (e.g., `/self-improvement REC-001`)

## Purpose

Deep analysis of a specific recommendation to assess feasibility, identify target files, and prepare for implementation.

## Execution

### Step 1: Resolve Vault Path and Locate Recommendation

Determine the Obsidian vault path using hostname lookup:

1. Read `~/.claude/skills/obsidian-notes/SKILL.md` for the hostname → vault path table
2. Run `hostname` to determine the current machine
3. Match hostname against the table (support prefix matching for wildcard entries like `TCETRA*`)
4. Set `{vault_path}` to the matched path

**Fallback** (macOS only): If hostname lookup fails:
```bash
mdfind "kMDItemDisplayName == '*Lesson*'" | grep "Generated/.*Lesson.*\.md$"
```

Search lessons learned files for the specific REC-ID:

```
Grep(pattern: "#### REC-{id}:", path: "{vault_path}/Generated/")
```

Read the full recommendation context (surrounding 30 lines).

### Step 2: Parse Recommendation Details

Extract:
- **Title**: From `#### REC-XXX: {title}`
- **Category**: From `**Category**:` line
- **Effort**: From `**Effort**:` line
- **Impact**: From `**Impact**:` line
- **Description**: Body text after metadata
- **Context**: Surrounding analysis that generated this recommendation

### Step 3: Identify Target Files

Based on category, determine target location:

```
Read(file_path: "${CLAUDE_PLUGIN_ROOT}/skills/self-improvement/references/recommendation-categories.md")
```

Map category to likely targets:
- **Workflow** -> `skills/*/operations/*.md`
- **Commands** -> `~/.claude/commands/*.md`
- **Utilities** -> `skills/*/scripts/*`
- **Skills** -> `skills/*/SKILL.md`

Search for specific files mentioned in recommendation or related by keyword.

### Step 4: Assess Feasibility

**Complexity Assessment**:
- **Low**: Single file change, clear modification point
- **Medium**: Multiple files, straightforward pattern
- **High**: Architectural change, cross-cutting concerns

**Dependency Check**:
- Identify files that import/reference target
- Check for related tests
- Note any configuration dependencies

**Conflict Detection**:
- Search for recent changes to target files
- Check for overlapping recommendations
- Identify potential regression risks

### Step 5: Generate Analysis Report

```markdown
## REC-{id}: {title}

**Source**: {filename}
**Category**: {category} | **Priority**: {priority} | **Effort**: {effort}

### Original Recommendation

{full recommendation text}

### Context

{surrounding analysis that led to this recommendation}

### Target Files

| File | Section | Modification Type |
|------|---------|-------------------|
| `skills/task-workflow/operations/create-workspace.md` | Lines 45-60 | Add parallel execution |
| `skills/task-workflow/SKILL.md` | Operations table | Update description |

### Feasibility Assessment

- **Complexity**: {Low/Medium/High}
- **Dependencies**: {list or "None detected"}
- **Conflicts**: {list or "None detected"}
- **Risk Level**: {Low/Medium/High}

### Implementation Notes

{specific observations about how to implement}

### Next Steps

- Use `/self-improvement REC-{id} --propose` to see specific changes
- Use `/self-improvement REC-{id} --apply` to implement with confirmation
```

## Category-to-Target Mapping

Quick reference (detailed in `references/recommendation-categories.md`):

| Category | Primary Targets | Secondary Targets |
|----------|----------------|-------------------|
| Workflow | `operations/*.md` | `SKILL.md` |
| Commands | `~/.claude/commands/*.md` | Related skill |
| Utilities | `scripts/*` | `operations/*.md` |
| Skills | `SKILL.md` | All skill files |
| Documentation | `references/*.md` | `SKILL.md` |

## Error Handling

**REC-ID not found**:
```
REC-{id} not found in lessons learned files.

Available recommendations:
[list from scan-recommendations]

Use `/claude-skills:self-improvement` to see all pending recommendations.
```

**Source file deleted/moved**:
```
Source file for REC-{id} no longer exists at original location.
Searching for relocated file...

[If found]: Located at {new_path}
[If not found]: Cannot locate source. Recommendation may be outdated.
```

**Target files not found**:
```
Warning: Could not locate target files for this recommendation.
Category suggests: {expected_paths}
Manual review recommended.
```
