---
name: compound
description: Document a solved problem as a searchable solution with YAML frontmatter. Use when the user solves a problem and wants to capture it for future agent discovery, or invokes /compound.
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

**Single-problem focus**: Unlike a session retrospective, `/compound` documents one solved problem at a time. Lightweight, focused, fast.

**Grep-first discoverability**: YAML frontmatter fields (`problem_type`, `tags`, `symptoms`, `module`) enable agents to filter solutions by scanning metadata before reading content.

**Schema**: Solution docs follow the schema defined in `references/SCHEMA.md` (bundled with this skill).

## Invocation

```
/compound                          # Interactive — asks what you solved
/compound timeout in auth flow     # Pre-seeded with problem context
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
**When**: User invokes `/compound` to capture a solved problem

**Quick summary**: Gather problem context, generate frontmatter, write solution doc, suggest git commit.

## Output

Creates a solution document at:
```
<repo>/docs/solutions/<category>/<YYYY-MM-DD>-<short-description>.md
```

## Integration Points

- **Schema**: `references/SCHEMA.md` — frontmatter field definitions (bundled)
- **Template**: `templates/solution.md.tmpl` — base template (bundled)
- **Search**: Agents discover solution docs via grep-first frontmatter search

## See Also

- `references/SCHEMA.md` — Frontmatter schema reference
