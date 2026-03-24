# Solution File Schema

Documented solutions use YAML frontmatter for structured metadata and markdown body for details. Solutions are filed in category subdirectories based on `problem_type`.

## Directory Structure

```
docs/solutions/
├── SCHEMA.md               # This file
├── build-errors/            # Compilation, dependency, packaging failures
├── test-failures/           # Flaky tests, assertion errors, test setup issues
├── performance-issues/      # Slow queries, memory leaks, latency problems
├── runtime-errors/          # Crashes, exceptions, unexpected behavior at runtime
├── integration-issues/      # API mismatches, service communication, auth failures
├── workflow-issues/         # CI/CD, tooling, development process problems
├── best-practices/          # Proven patterns worth codifying
└── patterns/
    └── critical-patterns.md # Must-know patterns (always checked)
```

## YAML Frontmatter

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | Descriptive title of the problem and solution |
| `date` | string | ISO 8601 date (YYYY-MM-DD) |
| `problem_type` | enum | Category — determines filing directory (see below) |
| `severity` | enum | `critical`, `high`, `medium`, `low` |
| `symptoms` | array | 1-5 observable symptoms |

### Optional Fields

| Field | Type | Description |
|-------|------|-------------|
| `tags` | array | Searchable keywords (lowercase, hyphen-separated) |
| `root_cause` | string | What caused the issue |
| `module` | string | Module or system affected |
| `component` | string | Technical component type |
| `resolution_type` | string | How the problem was resolved |
| `repo` | string | Repository where the fix was applied |

### problem_type Values

| Value | Directory |
|-------|-----------|
| `build_error` | `build-errors/` |
| `test_failure` | `test-failures/` |
| `runtime_error` | `runtime-errors/` |
| `performance_issue` | `performance-issues/` |
| `integration_issue` | `integration-issues/` |
| `workflow_issue` | `workflow-issues/` |
| `best_practice` | `best-practices/` |

## File Naming

```
<YYYY-MM-DD>-<short-description>.md
```

Example: `2026-02-18-supervisor-restart-loop.md`

## Body Structure

```markdown
---
title: "Supervisor restart loop on config reload"
date: 2026-02-18
problem_type: runtime_error
severity: high
symptoms:
  - "Supervisor restarts child 5 times then crashes"
  - "Config reload triggers cascade failure"
tags: [supervisor, config, restart]
root_cause: "Init raised on invalid config state"
module: PolicyEngine
---

## Problem
What went wrong and how it manifested.

## Solution
What was done to fix it, with code examples if applicable.

## Prevention
How to avoid this in the future.
```

## Searching Solutions

Grep-based pre-filtering on frontmatter fields:

```bash
# Search by tag
Grep: pattern="tags:.*(kafka|msk)" path=docs/solutions/ -i=true

# Search by symptom
Grep: pattern="symptoms:.*timeout" path=docs/solutions/ -i=true

# Search by module
Grep: pattern="module:.*Orchestrator" path=docs/solutions/ -i=true
```

Always check `docs/solutions/patterns/critical-patterns.md` regardless of search results.
