# Dispatch Task Operation

Dispatches a single task to a subagent via the Task tool and returns a structured result.

**Requirements**: Caller must provide a filled prompt. This operation handles invocation, result parsing, retry, and fallback signaling.

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `prompt` | Yes | Self-contained prompt for the subagent (caller assembles from template + context) |
| `task_subject` | Yes | Short label for the Task tool `description` field |
| `max_retries` | No | Number of re-dispatches on failure (default: 1) |

## Purpose

Encapsulates the mechanical dispatch plumbing so that any skill can offload work to a subagent without reimplementing invocation, result parsing, or retry logic. The caller is responsible for prompt assembly; this operation is responsible for everything after "the prompt is ready."

## Execution Steps

### 1. Spawn Subagent

Invoke the Task tool:

```
Task(
  subagent_type: "general-purpose",
  prompt: <prompt>,
  description: "Implement: <task_subject>"
)
```

### 2. Parse Result

Extract the structured result from the subagent's response:

1. Find text between `RESULT_START` and `RESULT_END` markers
2. Parse as YAML-like key-value pairs:
   - `status`: `success` | `partial` | `failure`
   - `files_modified`: list of paths
   - `changes_summary`: 1-3 sentence description
   - `test_result`: `pass` | `fail` | `no_tests` | `skipped`
   - `lint_result`: `pass` | `fail` | `no_linter` | `skipped`
   - `issues`: description of problems, or "none"
3. If no markers found, treat as:
   ```
   status: failure
   issues: <full subagent response text>
   ```

### 3. Evaluate Result

| Status | Action |
|--------|--------|
| `success` | Return result to caller |
| `partial` | Return result to caller (caller decides whether partial work is acceptable) |
| `failure` | Go to step 4 (retry) |
| No structured result | Go to step 4 (retry) |

### 4. Retry on Failure

If retries remain (`attempt < max_retries`):

1. Append failure context to the original prompt:
   ```
   ## Previous Attempt Failed
   <issues from parsed result>
   Please try a different approach.
   ```
2. Return to step 1 with the augmented prompt
3. Decrement remaining retries

If no retries remain:

Return a fallback signal to the caller:

```
dispatch_result:
  status: fallback
  issues: <issues from last attempt>
  attempts: <number of attempts made>
```

The caller decides how to handle `fallback` (e.g., execute the task inline, pause for user input).

## Return Value

This operation returns a `dispatch_result` dictionary to the caller:

```
dispatch_result:
  status: success | partial | fallback
  files_modified: [list of paths]
  changes_summary: "..."
  test_result: pass | fail | no_tests | skipped
  lint_result: pass | fail | no_linter | skipped
  issues: "..." or "none"
  attempts: <number of dispatch attempts>
```

## Error Handling

| Error | Response |
|-------|----------|
| Task tool returns an error (not a subagent result) | Treat as `status: failure`, enter retry |
| Subagent times out | Treat as `status: failure` with `issues: "subagent timed out"` |
| Malformed RESULT markers (START without END) | Treat as `status: failure`, include raw response in `issues` |

## Example

### Successful dispatch

```
Caller provides:
  prompt: "You are implementing a single task... [full prompt]"
  task_subject: "Extract dispatch-task.md operation"

Step 1: Spawn subagent
  Task(subagent_type: "general-purpose", description: "Implement: Extract dispatch-task.md operation", prompt: ...)

Step 2: Parse result
  Found RESULT_START/RESULT_END markers
  Parsed: status=success, files_modified=[operations/dispatch-task.md], test_result=no_tests

Step 3: Evaluate → success

Return to caller:
  dispatch_result:
    status: success
    files_modified: [operations/dispatch-task.md]
    changes_summary: "Created dispatch-task.md reusable operation"
    test_result: no_tests
    lint_result: pass
    issues: none
    attempts: 1
```

### Dispatch with retry and fallback

```
Step 1: Spawn subagent (attempt 1)
Step 2: Parse → status: failure, issues: "test_parse_config assertion error"
Step 3: Evaluate → failure
Step 4: Retry (1 remaining)
  Append "## Previous Attempt Failed\ntest_parse_config assertion error\nPlease try a different approach."

Step 1: Spawn subagent (attempt 2)
Step 2: Parse → status: failure, issues: "same test still failing"
Step 3: Evaluate → failure
Step 4: No retries remaining

Return to caller:
  dispatch_result:
    status: fallback
    issues: "same test still failing"
    attempts: 2
```

## Integration Points

- **Called by**: auto-advance (step 2a), sprint-review, self-improvement, finish, implement-feature, analyze-project
- **Depends on**: Task tool (subagent_type: general-purpose)
- **Reference**: See `references/subagent-dispatch.md` for the dispatch contract, prompt template structure, and result format spec
