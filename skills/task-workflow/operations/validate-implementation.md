# Validate Implementation Operation

Runs tests and lint checks after task implementation, retrying on failure before proceeding to commit.

**Requirements**: Must be run from within a repository worktree with uncommitted changes.

## Inputs

None — auto-detects test runner and linter from project config files in the current repository root. The working directory determines which project is validated.

## Purpose

Provides automated quality gates between task implementation and commit. Detects the project's test runner and linter from config files, executes both, and handles failures with a retry loop. This prevents broken code from being committed and supports safe auto-advance of task workflows.

## Execution Steps

### 1. Detect Test Runner

Scan the repository root for config files to determine the test command.

```
Check in order (first match wins):
  pyproject.toml or setup.cfg  → pytest
  mix.exs                      → mix test
  go.mod                       → go test ./...
  Cargo.toml                   → cargo test
  package.json                 → npm test
  Makefile (has "test" target) → make test
```

If no config file matches, ask the user:

```
AskUserQuestion: "No test runner detected. What command runs your tests?"
  Options: ["pytest", "mix test", "go test ./...", "npm test"]
  (user can provide custom command via "Other")

Validate user-provided commands: reject input containing shell metacharacters
(;, &&, ||, |, $(), backticks) to prevent accidental command chaining.
```

Store the detected command for use in subsequent steps.

### 2. Detect Lint/Format Runner

Scan the repository root for lint/format tooling.

```
Check in order (first match wins):
  .pre-commit-config.yaml  → pre-commit run --all-files
  pyproject.toml [ruff]    → ruff check .
  .eslintrc* or eslint.*   → npx eslint .
  mix.exs                  → mix format --check-formatted
  go.mod                   → test -z "$(gofmt -l .)"
  Makefile (has "lint")    → make lint
```

If no linter detected, skip lint step (not an error).

### 3. Run Tests

Execute the detected test command:

```bash
<test_command>
```

Capture exit code and output.

- **Exit 0**: Tests passed. Proceed to step 4.
- **Non-zero**: Tests failed. Go to step 5 (retry loop).

### 4. Run Lint/Format Checks

If a linter was detected in step 2, execute it:

```bash
<lint_command>
```

Capture exit code and output.

- **Exit 0**: Lint passed. Proceed to step 6 (success).
- **Non-zero**: Lint failed. Go to step 5 (retry loop).

If no linter was detected, skip directly to step 6.

### 5. Retry Loop (On Failure)

When tests or lint fail, first classify the error to determine the retry strategy.

**Load `references/error-classification.md`** and match the failure output:

| Classification | Strategy | Budget |
|----------------|----------|--------|
| **Transient** (timeout, connection refused, flaky infrastructure) | Backoff and re-run unchanged | `env(AUTO_ADVANCE_TRANSIENT_RETRIES, default=3)` |
| **Permanent** (assertion error, syntax error, code bug) | Analyze and fix, then re-run | `env(AUTO_ADVANCE_MAX_RETRIES, default=2)` |
| **Uncertain** | Treat as transient with reduced budget | `max(1, transient_retries / 2)` |

#### 5a. Transient retry path

For transient errors (test flakes, infrastructure issues), apply backoff per `references/retry-with-backoff.md`:

```
transient_retries = env(AUTO_ADVANCE_TRANSIENT_RETRIES, default=3)
backoff_ceiling = env(AUTO_ADVANCE_BACKOFF_CEILING, default=60)

While transient_attempt < transient_retries:
  1. Calculate backoff delay per references/retry-with-backoff.md
  2. Log: "Transient error (attempt {N}/{transient_retries}): {error_summary}. Backing off {delay}s..."
  3. Bash: sleep <delay>
  4. Re-run the failing command (unchanged — no code fix)
  5. If passes: continue to next check (or step 6)
  6. If fails: re-classify the new error
     - Still transient: increment transient_attempt, continue loop
     - Now permanent: switch to fix-and-retry path (5b)
     - Uncertain: increment transient_attempt, continue loop
```

If transient retries exhausted, fall through to the user prompt below.

#### 5b. Fix-and-retry path (permanent errors)

For permanent errors (code bugs, assertion failures), the agent attempts to fix the code:

```
attempt = 1
max_retries = env(AUTO_ADVANCE_MAX_RETRIES, default=2)
repeated_failure_threshold = env(AUTO_ADVANCE_REPEATED_FAILURE_THRESHOLD, default=3)
last_error = null
repeated_count = 0

While attempt <= max_retries:
  1. Show the failure output to the agent context
  2. Extract error summary: first line of failing test/lint output
  3. Track error repetition:
     if error_summary == last_error:
       repeated_count += 1
     else:
       repeated_count = 1
     last_error = error_summary
  4. Analyze the failure and attempt a fix
  5. Re-run the failing command (test or lint)
  6. If passes: continue to next check (or step 6 if all checks pass)
  7. If fails: re-classify the new error
     - If now transient: switch to transient retry path (5a)
     - If still permanent: increment attempt, continue loop
```

After the loop exits (retries exhausted), include error repetition data in the result:

```
validation_result = {
  passed: false,
  repeated_error: (repeated_count >= repeated_failure_threshold),
  error_summary: last_error,
  attempt_count: repeated_count
}
```

This result is consumed by auto-advance step 3.5 for stuck detection.

#### 5c. Retries exhausted

If either retry path exhausts its budget:

```
Show failure summary to user (include retry history if transient retries were attempted)
AskUserQuestion: "Tests/lint still failing after {total_attempts} attempts. How to proceed?"
  Options:
    - "Skip validation and commit anyway"
    - "Let me fix it manually"
```

**Retry scope**: Each check (test, lint) has its own retry budget for both transient and fix-and-retry paths. Fixing a test failure does not consume a lint retry.

### 6. Report Results

Print a summary:

```
## Validation Results

**Tests**: passed (pytest)
**Lint**: passed (pre-commit) | skipped (no linter detected)

Ready to commit.
```

On failure with user override:

```
## Validation Results

**Tests**: FAILED (2 retries exhausted)
**Lint**: skipped

User chose: Skip validation and commit anyway
```

## Error Handling

| Error | Response |
|-------|----------|
| Test timeout (> 5 minutes) | Kill process, classify as transient (infrastructure), enter transient retry path (5a) |
| Any command error (not found, permission, etc.) | Show error output, ask user for guidance |
| User chooses "Let me fix it manually" | Stop operation, return control to user |
| Transient test/lint failure | Backoff and re-run via transient retry path (5a) |
| Error reclassifies mid-retry (transient → permanent or vice versa) | Switch to appropriate retry path with remaining budget |

## Example

### Go project with test failure and successful retry

```
Detecting test runner...
  Found: go.mod → go test ./...

Detecting linter...
  Found: Makefile (lint target) → make lint

Running tests...
  $ go test ./...
  --- FAIL: TestParseConfig (0.00s)
      expected "prod" got ""
  FAIL

Tests failed. Attempting fix (1/2)...
  [agent analyzes failure, edits config_test.go]

Re-running tests...
  $ go test ./...
  ok  ./... 1.23s

Running lint...
  $ make lint
  All checks passed.

## Validation Results
Tests: passed (go test, 1 retry)
Lint: passed (make lint)

Ready to commit.
```

## Integration Points

- **Predecessor**: Task implementation (after `TaskUpdate(status: in_progress)` work)
- **Successor**: `/commit-changes` (git commit operation)
- **Error classification**: `references/error-classification.md` — transient vs permanent error taxonomy
- **Retry with backoff**: `references/retry-with-backoff.md` — exponential backoff algorithm for transient retries
- **Requirements**: R1 (detection), R2 (test execution), R3 (lint execution), R4 (retry loop), R5 (success path). See workspace DESIGN.md for requirement definitions.
- **Constraint**: R6 — runs entirely within the work session, no control session changes
