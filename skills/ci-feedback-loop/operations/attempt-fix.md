# Attempt Fix

Apply a fix for a CI failure and push to the PR branch. Manages retry budget and regression detection.

## Parameters

- `diagnosis` (required): Output from analyze-failure — failure type, files, error messages, context
- `pr_number` (required): PR number
- `repo` (optional): Repository in `owner/repo` format
- `attempt` (required): Current attempt number (1-indexed)
- `max_retries` (required): Maximum attempts allowed (default: 3)
- `previous_attempts` (optional): List of previous fix descriptions to avoid repeating

## Execution Steps

### 1. Check retry budget

If `attempt > max_retries`, do not attempt a fix. Return `exhausted` to trigger escalation.

### 2. Route by failure type

| Failure Type | Action |
|-------------|--------|
| `code_error` | Analyze error, read affected files, apply code fix |
| `lint_format` | Run formatter/linter with auto-fix if available, or apply manual fix |
| `test_failure` | Read test and implementation, fix the discrepancy |
| `flaky_infra` | Re-trigger the failed jobs (step 3) |
| `config_error` | Attempt config fix if within agent's capability |
| `unknown` | Do not attempt — return `unfixable` |

### 3. Handle flaky/infrastructure failures

For `flaky_infra` type, re-trigger without code changes:

```bash
# Re-run only failed jobs
gh run rerun <run_id> --repo <repo> --failed
```

If `gh run rerun` is not available or fails:

```bash
# Push an empty commit to re-trigger checks
git commit --allow-empty -m "ci: re-trigger checks (attempt <attempt>/<max_retries>)"
git push
```

Return to poll-checks after re-trigger.

### 4. Apply code fix

For fixable failure types (`code_error`, `lint_format`, `test_failure`):

1. **Read the affected files** identified in the diagnosis
2. **Understand the error** in context of the code
3. **Apply the fix** using Edit tool
4. **Verify the fix locally** if possible (run the specific test, linter, or compiler check)

When applying the fix, consider:
- The diagnosis `previous_attempts` list — do not make the same change again
- The specific error message and file/line information
- The PR's original intent (read the PR description if needed)

### 5. Verify no regression

Before pushing, check that the fix doesn't obviously break other things:

- If a test runner is available locally, run the specific failing test
- If a linter is available locally, run it on the changed files
- Review the diff to ensure the change is minimal and targeted

```bash
git diff
```

### 6. Commit and push

```bash
git add <affected files>
git commit -m "fix: <concise description of what was fixed>

Addresses CI failure in <check name> (attempt <attempt>/<max_retries>)"
git push
```

### 7. Record attempt

Add this attempt to the history for future reference:

```
attempt: <number>
type: <failure type>
action: <what was done — "re-triggered failed jobs" | "fixed <description>">
files_changed: [list of files modified]
```

## Output

Return one of:

**Fix pushed**:
```
result: pushed
attempt: <number>
action: <description of fix>
files_changed: [list]
```
The caller should re-enter the poll-checks loop.

**Re-triggered**:
```
result: re-triggered
attempt: <number>
action: "Re-ran failed jobs via gh run rerun"
```
The caller should re-enter the poll-checks loop.

**Exhausted**:
```
result: exhausted
attempts_made: <number>
history: [list of previous attempt descriptions]
```
The caller should proceed to escalation.

**Unfixable**:
```
result: unfixable
reason: <why the agent can't fix this>
```
The caller should proceed to escalation.

## Error Handling

| Condition | Behavior |
|-----------|----------|
| `git push` fails (conflict, permission) | Return `unfixable` with reason |
| `gh run rerun` fails | Fall back to empty commit push |
| Local test/lint verification fails | Review the fix, adjust if possible; if stuck, return `unfixable` |
| Agent makes same fix as previous attempt | Return `unfixable` — agent is stuck in a loop |
| Fix modifies files outside the original PR scope | Warn but proceed — the agent may need to fix a test file not in the original diff |

## Tips

- Keep fixes minimal and targeted — don't refactor or improve code while fixing CI
- For test failures, read both the test file and the implementation before deciding what to fix
- If the same test fails after two different fix attempts, it's likely the agent misunderstands the intent — escalate rather than trying a third variation
- Empty commit re-triggers are a blunt instrument — prefer `gh run rerun --failed` when available
