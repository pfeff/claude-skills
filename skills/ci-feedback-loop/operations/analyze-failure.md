# Analyze Failure

Classify CI failure type and extract actionable context for fix attempts.

## Parameters

- `failure_logs` (required): Output from retrieve-logs — check names, run IDs, and truncated log content
- `pr_number` (required): PR number for context
- `repo` (optional): Repository in `owner/repo` format

## Execution Steps

### 1. Classify failure type

For each failed check's log output, classify into one of:

| Type | Indicators | Fixable? |
|------|-----------|----------|
| **code_error** | Compilation error, type error, import error, syntax error, test assertion failure with specific file/line | Yes |
| **lint_format** | Linting violation, formatting error, style check failure | Yes |
| **test_failure** | Test assertion failure, expected vs. actual mismatch | Yes |
| **flaky_infra** | Timeout, network error, "service unavailable", rate limit, "connection refused", non-deterministic failure | Maybe (re-trigger) |
| **config_error** | Missing env var, missing secret, permission denied, invalid configuration | Maybe (if agent can fix config) |
| **unknown** | Cannot determine failure cause from logs | No |

**Classification heuristics**:

- Search for compilation/syntax error patterns: `SyntaxError`, `CompileError`, `cannot find module`, `undefined variable`
- Search for test failure patterns: `FAIL`, `AssertionError`, `expected .* but got`, `test .* failed`
- Search for lint patterns: `warning:`, `error:` with file paths and line numbers, style violations
- Search for infra patterns: `timeout`, `ETIMEDOUT`, `connection refused`, `503`, `rate limit`
- Search for config patterns: `env var .* not set`, `secret .* not found`, `permission denied`

### 2. Extract actionable context

For fixable failures (`code_error`, `lint_format`, `test_failure`), extract:

- **File paths**: Any file paths mentioned in error output
- **Line numbers**: Specific lines where errors occur
- **Error messages**: The specific error text
- **Expected vs. actual**: For test failures, what was expected and what happened

Read the referenced source files to understand the context:

```
Read: file_path="<referenced file>"
```

For `flaky_infra` failures, note:
- Which step/service failed
- Whether this looks transient (timeout, network) vs. persistent (resource exhaustion)

### 3. Check for regression potential

Get the list of files changed in the PR to understand scope:

```bash
gh pr diff <pr_number> --repo <repo> --name-only
```

Cross-reference the changed files with the error output. If the failing check references files not changed in the PR, it may be a pre-existing issue or flaky test rather than something the PR introduced.

### 4. Compile diagnosis

For each failed check, produce:

```
Check: <name>
Type: <code_error | lint_format | test_failure | flaky_infra | config_error | unknown>
Fixable: <yes | re-trigger | no>
Summary: <one-line description of what went wrong>

Files involved:
  - <file_path>:<line_number> — <error message>

Context:
  <relevant code snippet or error excerpt>

PR files changed: <list of files changed, noting overlap with error files>
```

## Output

A list of failure diagnoses, one per failed check. Each contains:
- Classification type and fixability assessment
- Actionable error details (files, lines, messages)
- Context for the agent to attempt a fix
- PR diff overlap analysis

The `fixable` field drives the next operation:
- `yes` → proceed to attempt-fix
- `re-trigger` → use `gh run rerun` (flaky handling)
- `no` → proceed to escalate

## Error Handling

| Condition | Behavior |
|-----------|----------|
| Log content is too vague to classify | Classify as `unknown`, recommend escalation |
| Multiple failure types in one check | Report the most severe (code_error > test_failure > lint_format > config_error > flaky_infra) |
| Referenced files don't exist locally | Note the gap; agent may need to pull latest changes |
| `gh pr diff` fails | Skip regression check, proceed with available info |

## Tips

- Don't over-analyze: the goal is to give the agent enough context to attempt a fix, not to fully diagnose the issue
- For test failures, reading the test file itself often provides more context than the error message
- If multiple checks fail with different root causes, prioritize the most fundamental failure (e.g., compilation error before test failure)
