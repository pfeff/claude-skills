---
name: compound
description: Document a solved problem as a searchable solution with YAML frontmatter. Use when the user solves a problem and wants to capture it for future agent discovery, or invokes /claude-skills:compound.
argument-hint: "[short problem description or blank for interactive]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - AskUserQuestion
version: 0.1.0
---

# Compound Skill

Captures a solved problem as a searchable solution document with YAML frontmatter. Solution docs are filed in `docs/solutions/<category>/` within a repository and discovered by agents via grep-first frontmatter search.

## Core Concepts

**Single-problem focus**: Unlike `/claude-skills:lessons-learned` (session retrospective), `/claude-skills:compound` documents one solved problem at a time. Lightweight, focused, fast.

**Grep-first discoverability**: YAML frontmatter fields (`problem_type`, `tags`, `symptoms`, `module`) enable agents to filter solutions by scanning metadata before reading content.

**Schema**: Solution docs follow the schema defined in [guardian/docs/solutions/SCHEMA.md](https://github.com/pfeff/guardian/blob/main/docs/solutions/SCHEMA.md).

## Invocation

```
/claude-skills:compound                          # Interactive — asks what you solved
/claude-skills:compound timeout in auth flow     # Pre-seeded with problem context
```

## Execution

When this skill is invoked:

**Step 1**: Load operation details

```
Read(file_path: "${CLAUDE_PLUGIN_ROOT}/skills/compound/operations/document-solution.md")
```

**Step 2**: Execute the operation interactively

**Step 3**: Report the created file path and suggest committing

## Operations

### Document Solution (Default)

**File**: `operations/document-solution.md`
**When**: User invokes `/claude-skills:compound` to capture a solved problem

**Quick summary**: Gather problem context, generate frontmatter, write solution doc, suggest git commit.

## Output

Creates a solution document at:
```
<repo>/docs/solutions/<category>/<YYYY-MM-DD>-<short-description>.md
```

## Integration Points

- **Schema**: `guardian/docs/solutions/SCHEMA.md` — frontmatter field definitions
- **Template**: `${CLAUDE_PLUGIN_ROOT}/skills/task-workflow/templates/solution.md.tmpl` — base template
- **Search**: `init-workspace` step 8 discovers these docs via grep-first
- **Lessons-learned**: Can bridge to `/claude-skills:compound` when a discussed problem has a clear fix

## See Also

- `/claude-skills:lessons-learned` — Session retrospective (may bridge to `/claude-skills:compound`)
- `/claude-skills:self-improvement` — Apply recommendations to skills
- `guardian/docs/solutions/SCHEMA.md` — Frontmatter schema reference
