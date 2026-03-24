# Document Solution Operation

**When**: User invokes `/compound` to capture a solved problem as a searchable solution doc.

## Purpose

Captures a single solved problem with structured YAML frontmatter so future agents can discover it via grep-first search. Fast and focused — not a retrospective.

## Execution

### Step 1: Load Schema

Read the solution doc schema for field definitions:

```
Read(file_path: "${CLAUDE_PLUGIN_ROOT}/skills/compound/templates/solution.md.tmpl")
```

Also read the full schema reference if the template lacks detail:

```
# Check workspace repos first, fall back to main clone
Glob(pattern: "**/docs/solutions/SCHEMA.md")
```

### Step 2: Gather Problem Context

If `$ARGUMENTS` contains a problem description, use it as seed context. Otherwise, derive context from the current conversation.

**Information needed** (ask only for what can't be inferred):

| Field | Source | Ask if missing |
|-------|--------|----------------|
| Problem description | Conversation context or `$ARGUMENTS` | Yes |
| What was the fix | Conversation context | Yes |
| Repository | Current working directory or workspace | Only if ambiguous |
| Module/component | Code context | Only if unclear |

**Use AskUserQuestion** to fill gaps efficiently. Prefer a single question with multiple fields over multiple rounds.

Example:
```
I'll capture this as a solution doc. Based on our session:

**Problem**: OTP supervisor restart loop on config reload
**Fix**: Validate config in handle_continue/2 before applying
**Repo**: agent-coordinator
**Module**: PolicyEngine

Anything to adjust before I write it up?
```

### Step 3: Generate Frontmatter

Map the gathered context to YAML frontmatter fields:

| Field | How to derive |
|-------|---------------|
| `title` | Concise problem + solution summary |
| `date` | Today's date (YYYY-MM-DD) |
| `problem_type` | Classify from problem description (see SCHEMA.md enum) |
| `severity` | Infer from impact: `critical` (system down), `high` (feature broken), `medium` (degraded), `low` (cosmetic/minor) |
| `symptoms` | Observable behaviors that indicate the problem (1-5 items) |
| `tags` | Lowercase, hyphen-separated searchable keywords |
| `root_cause` | What actually caused the issue |
| `module` | Module or system name |
| `component` | Technical component type if applicable |
| `repo` | Repository where the fix was applied |

### Step 4: Determine File Location

1. Map `problem_type` to directory:

| problem_type | Directory |
|-------------|-----------|
| `build_error` | `build-errors/` |
| `test_failure` | `test-failures/` |
| `runtime_error` | `runtime-errors/` |
| `performance_issue` | `performance-issues/` |
| `integration_issue` | `integration-issues/` |
| `workflow_issue` | `workflow-issues/` |
| `best_practice` | `best-practices/` |

2. Determine target repo path:
   - If in a workspace: use the relevant repo worktree's `docs/solutions/`
   - If not in a workspace: ask user which repo

3. Construct filename: `<YYYY-MM-DD>-<short-description>.md`
   - `short-description`: 3-5 words, lowercase, hyphen-separated

4. Verify the directory exists:
```
Glob(pattern: "docs/solutions/<category>/", path: "<repo-path>")
```
If missing, create it.

### Step 5: Write Solution Document

Write the file using the standard body structure:

```markdown
---
title: "<title>"
date: <YYYY-MM-DD>
problem_type: <type>
severity: <level>
symptoms:
  - "<symptom 1>"
  - "<symptom 2>"
tags: [<tag1>, <tag2>]
root_cause: "<root cause>"
module: <Module>
repo: <repo-name>
---

## Problem

<What went wrong and how it manifested.>

## Solution

<What was done to fix it, with code examples if applicable.>

## Prevention

<How to avoid this in the future.>
```

### Step 6: Check for Critical Pattern Promotion

If `severity` is `critical` OR the problem has recurred (user confirms), suggest promoting to `critical-patterns.md`:

```
This is a critical/recurring issue. Should I add it to
docs/solutions/patterns/critical-patterns.md?
```

If yes, append an entry to `critical-patterns.md` following the existing format:

```markdown
### CP-N: <pattern title>

**Severity**: <severity>
**Repos**: <repo list>
**Tags**: <tags>

<description>
```

### Step 7: Report and Suggest Commit

Display:
```
Solution documented:
  <repo>/docs/solutions/<category>/<filename>

Fields: problem_type=<type>, severity=<level>, tags=[<tags>]

Commit with: git add docs/solutions/ && git commit -m "docs: add solution for <short description>"
```

## Error Handling

| Error | Response |
|-------|----------|
| No repo context | Ask user which repo to file under |
| `docs/solutions/` doesn't exist | Create directory structure |
| Can't classify problem_type | Ask user to pick from enum |
| Duplicate filename | Append `-2`, `-3` suffix |

## Idempotency

Re-running with the same problem context will detect the existing file via filename match and ask whether to update or skip.
