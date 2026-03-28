# Subagent Dispatch Reference

Canonical reference for the subagent dispatch contract. Load this reference when adopting subagent dispatch in any skill.

## Dispatch Prompt Template

The parent assembles a self-contained prompt for each subagent. Use this structure as the baseline; callers may add skill-specific sections.

```
You are implementing a single task in a software project. Make the code changes described below, run tests to verify, and report your results.

Do not commit changes. Do not create PRs. Do not modify files outside the scope of this task.

## Task

**Subject**: ${TASK_SUBJECT}
**Description**: ${TASK_DESCRIPTION}

## Design Requirements

${RELEVANT_REQUIREMENTS}

## Design Decisions

${RELEVANT_DESIGN_DECISIONS}

## Prior Task Context

${TASK_LEDGER_ENTRIES_FOR_DEPENDENCIES}

(If empty: "This is the first task — no prior context.")

## Working Directory

- Workspace: ${WORKSPACE_PATH}
- Repository: ${REPO_PATH}

## Instructions

1. Read the source files relevant to this task
2. Implement the changes described above
3. If a test runner is available (check for pyproject.toml, mix.exs, go.mod, package.json), run tests
4. If a linter is available (check for .pre-commit-config.yaml, .eslintrc), run lint
5. If tests or lint fail, attempt to fix (up to 2 retries)

## Required Output Format

When finished, report your results in this exact format:

RESULT_START
status: success | partial | failure
files_modified:
  - path/to/file1.md
  - path/to/file2.md
changes_summary: |
  <1-3 sentence description of what was changed and why>
test_result: pass | fail | no_tests | skipped
lint_result: pass | fail | no_linter | skipped
issues: |
  <any problems encountered, or "none">
RESULT_END
```

### Template Variables

| Variable | Source | Description |
|----------|--------|-------------|
| `${TASK_SUBJECT}` | `TaskGet` result | Short task title |
| `${TASK_DESCRIPTION}` | `TaskGet` result | Full task description |
| `${RELEVANT_REQUIREMENTS}` | DESIGN.md | R-IDs referenced by the task, filtered from DESIGN.md |
| `${RELEVANT_DESIGN_DECISIONS}` | DESIGN.md | DD-IDs referenced by the task, filtered from DESIGN.md |
| `${TASK_LEDGER_ENTRIES_FOR_DEPENDENCIES}` | Task ledger (in-context) | Ledger entries for `blockedBy` tasks only |
| `${WORKSPACE_PATH}` | Environment | Workspace root directory |
| `${REPO_PATH}` | Environment | Repository path within workspace |

### Prompt Assembly Rules

1. **Self-contained**: The subagent has no access to the parent's conversation context. Everything needed must be in the prompt.
2. **Scoped**: Include only requirements and design decisions relevant to the specific task, not the entire DESIGN.md.
3. **Dependency context**: For tasks with `blockedBy` entries, include ledger entries for those tasks so the subagent knows what changed.
4. **No commit instructions**: The parent commits after verifying the subagent's work.

## Result Format Spec

### Markers

Results are delimited by `RESULT_START` and `RESULT_END` on their own lines. Content between markers is parsed as YAML-like key-value pairs.

### Fields

| Field | Required | Values | Description |
|-------|----------|--------|-------------|
| `status` | Yes | `success`, `partial`, `failure` | Overall outcome |
| `files_modified` | Yes | YAML list of paths | Files the subagent created or edited |
| `changes_summary` | Yes | Multi-line string | 1-3 sentence description of changes |
| `test_result` | Yes | `pass`, `fail`, `no_tests`, `skipped` | Test execution outcome |
| `lint_result` | Yes | `pass`, `fail`, `no_linter`, `skipped` | Lint execution outcome |
| `issues` | Yes | Multi-line string or `"none"` | Problems encountered |

### Status Definitions

| Status | Meaning | Parent Action |
|--------|---------|---------------|
| `success` | All changes made, tests and lint pass | Validate and commit |
| `partial` | Some changes made, but not all (e.g., tests fail on one part) | Validate partial work, decide whether to commit or retry |
| `failure` | Unable to complete the task | Retry or fallback to inline |

### Parsing Rules

1. Find `RESULT_START` line — everything after this line until `RESULT_END` is the result body
2. Parse body as YAML key-value pairs
3. Multi-line values use YAML `|` block scalar syntax
4. List values use YAML `- item` syntax
5. If `RESULT_START` is found but `RESULT_END` is missing, treat as `status: failure`
6. If neither marker is found, treat entire response as `status: failure` with full text as `issues`

## Retry Logic

Used by `dispatch-task.md` operation. Included here as the canonical spec.

### Retry Budget

- Default: 1 retry (2 total attempts)
- Configurable via `max_retries` input to dispatch-task operation

### Retry Prompt Augmentation

On failure, append to the original prompt:

```
## Previous Attempt Failed
<issues field from parsed result>
Please try a different approach.
```

### Fallback

When retries are exhausted, dispatch-task returns `status: fallback` to the caller. The caller handles fallback (typically: execute the task inline or pause for user input).

## Task Ledger Format

Maintained by the parent orchestrator in conversation context (not a file). Appended after each task completion.

```markdown
## Task Ledger

### Task <N>: <subject>
- **Status**: completed | failed
- **Dispatch**: subagent | inline | inline (fallback)
- **Files modified**: path/to/file1.md, path/to/file2.md
- **Changes**: <1-3 sentence summary>
- **Test result**: pass | fail | no_tests
- **Commit**: <short hash>
```

### Ledger Rules

1. One entry per task, appended in completion order
2. The ledger lives in conversation context, not written to disk
3. When dispatching a dependent task, include **only** the ledger entries for its `blockedBy` tasks — not the entire ledger
4. Ledger entries for failed tasks use `Status: failed` and include the failure reason in `Changes`

## Failure Categories

| Category | Detection | Response |
|----------|-----------|----------|
| Test failure | `test_result: fail` | Retry with failure context |
| Lint failure | `lint_result: fail` | Retry with failure context |
| Implementation error | `status: failure` with code errors in `issues` | Retry with failure context |
| Ambiguous requirements | `issues` mentions unclear spec or multiple approaches | Fallback to inline (needs human judgment) |
| Missing dependency | `issues` mentions missing file, package, or service | Fallback to inline |
| Subagent timeout | Task tool returns timeout | Retry once, then fallback |
| No structured result | Missing RESULT markers | Retry once, then fallback |

## Dispatch Decision Criteria

Before dispatching, the parent evaluates task suitability:

```
dispatch_mode = "subagent"  # default when feature flag is on

# Fall back to inline if:
if task.description contains "clarify", "discuss", or "decide":
    dispatch_mode = "inline"
if task spans multiple repos:
    dispatch_mode = "inline"
if task.blockedBy references a failed task:
    dispatch_mode = "inline"
if DESIGN.md has unresolved spec gaps for this task:
    dispatch_mode = "inline"
```

## Operations

| Operation | Location | Use Case |
|-----------|----------|----------|
| `dispatch-task.md` | `task-workflow/operations/` | Single-task dispatch with retry and fallback |
| `fan-out.md` | `task-workflow/operations/` | Parallel dispatch of N independent agents |

Load the appropriate operation for your use case. Both operations follow this reference for result format and parsing.
