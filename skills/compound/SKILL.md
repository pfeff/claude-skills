---
name: compound
description: "[DEPRECATED — will be removed after Phase 5 observation window] Document a solved problem as a searchable solution with YAML frontmatter. Retained as a transitional tool; retrieval has moved to QMD-over-Obsidian, so new solution knowledge should go into the vault directly instead of docs/solutions."
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

> **⚠️ DEPRECATED (qmd-retrieval migration, DD4/DD5)** — retrieval has moved to QMD-over-Obsidian. `docs/solutions/` is no longer a retrieval surface. New solution knowledge should be captured as regular Obsidian notes (via `/finish` session-journal or a direct note), not through this skill. `/compound` is retained functionally during the Phase 5 observation window (2–4 weeks post-2026-04-24) and will be removed afterward per DD5. Do not invoke for new captures — prefer the Obsidian path.

Historically: captured a solved problem as a searchable solution document with YAML frontmatter, filed in `docs/solutions/<category>/` within a repository and discovered by agents via grep-first frontmatter search. The grep-first retrieval path has been replaced by QMD hybrid search over the Obsidian vault — the description below applies to the legacy behavior preserved during the transition window.

## Core Concepts (legacy — retained for transition window)

**Single-problem focus**: Unlike `/claude-skills:lessons-learned` (session retrospective), `/claude-skills:compound` documents one solved problem at a time. Lightweight, focused, fast.

**Grep-first discoverability**: YAML frontmatter fields (`problem_type`, `tags`, `symptoms`, `module`) historically enabled agents to filter solutions by scanning metadata. Retrieval now runs through QMD — these fields are not consulted at query time.

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

- **Schema**: `guardian/docs/solutions/SCHEMA.md` — frontmatter field definitions (legacy)
- **Template**: `${CLAUDE_PLUGIN_ROOT}/skills/task-workflow/templates/solution.md.tmpl` — base template (legacy)
- **Search**: _Historical_. `init-workspace` step 9 now retrieves via QMD (`references/solution-search.md`); it does not read `docs/solutions/`.
- **Lessons-learned**: Phase 3d no longer bridges to `/claude-skills:compound`. Problems worth capturing are written as Obsidian notes directly.

## See Also

- `/claude-skills:lessons-learned` — Session retrospective (may bridge to `/claude-skills:compound`)
- `/claude-skills:self-improvement` — Apply recommendations to skills
- `guardian/docs/solutions/SCHEMA.md` — Frontmatter schema reference
