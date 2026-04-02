# Solution Search Reference

Grep-first search protocol for discovering relevant solution docs from `docs/solutions/` directories. Used by `init-workspace` (step 8) and available to any skill needing to surface past solutions.

## Search Paths

Collect all `docs/solutions/` directories:

```
1. Each subdirectory in the current workspace that contains docs/solutions/
2. Primary repo main clone's docs/solutions/ (worktree may be freshly created)
```

## Grep-First Protocol

Two-stage filtering: scan frontmatter fields first, read full content only for matches.

### Stage 1: Frontmatter Grep

Extract keywords from the task context (issue title, error messages, module names, component names). Run these Grep calls **in parallel** across all search paths:

```
# Search by title
Grep: pattern="title:.*<keyword>" path=<search-path> -i=true output_mode=files_with_matches

# Search by tags
Grep: pattern="tags:.*<keyword>" path=<search-path> -i=true output_mode=files_with_matches

# Search by symptoms
Grep: pattern="symptoms:.*<keyword>" path=<search-path> -i=true output_mode=files_with_matches

# Search by module
Grep: pattern="module:.*<keyword>" path=<search-path> -i=true output_mode=files_with_matches

# Search by problem_type
Grep: pattern="problem_type:.*<keyword>" path=<search-path> -i=true output_mode=files_with_matches

# Search by component
Grep: pattern="component:.*<keyword>" path=<search-path> -i=true output_mode=files_with_matches
```

**Keyword extraction heuristics**:
- Module/system names (e.g., "PolicyEngine", "Orchestrator")
- Technical terms (e.g., "N+1", "timeout", "authentication")
- Error indicators (e.g., "crash", "slow", "failing")
- Component names (e.g., "supervisor", "adapter", "webhook")
- Problem types (e.g., "runtime_error", "build_error")

### Stage 2: Read Matched Files

For each unique file path returned by Stage 1:
1. Read the full file content
2. Summarize the problem and solution
3. Note relevance to the current task

**Ranking**: Files matching more frontmatter fields rank higher.

### Always Check Critical Patterns

Regardless of keyword matches, always read:
```
Read: <repo>/docs/solutions/patterns/critical-patterns.md
```

This file contains must-know patterns (critical severity, recurring, or cross-cutting).

## Report Format

```
**Existing solutions**: <N relevant | none found>

Found N relevant solutions:
  - <category>/<filename> — <title> (severity: <level>)
    Relevance: matched on <fields>
  - ...

Critical patterns: checked (<N matches | no matches>)
```

## Frontmatter Fields Reference

See [guardian/docs/solutions/SCHEMA.md](https://github.com/pfeff/guardian/blob/main/docs/solutions/SCHEMA.md) for the complete field schema.

| Field | Type | Searchable | Description |
|-------|------|-----------|-------------|
| `title` | string | Yes | Problem + solution summary |
| `problem_type` | enum | Yes | Category (maps to directory) |
| `severity` | enum | No | critical/high/medium/low |
| `symptoms` | array | Yes | Observable behaviors |
| `tags` | array | Yes | Searchable keywords |
| `root_cause` | string | No | What caused the issue |
| `module` | string | Yes | Module or system name |
| `component` | string | Yes | Technical component type |
| `repo` | string | No | Repository of the fix |
