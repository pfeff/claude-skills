# Poll Checks

Poll PR check status until all checks resolve (pass or fail) or timeout is reached.

## Parameters

- `pr_number` (required): PR number to monitor
- `repo` (optional): Repository in `owner/repo` format. Defaults to current repo.
- `poll_interval` (optional): Initial polling interval in seconds. Default: 30
- `max_wait` (optional): Maximum wait time in seconds. Default: 1800 (30 minutes)

## Execution Steps

### 1. Initial check query

```bash
gh pr checks <pr_number> --repo <repo> --json name,state,bucket,link,workflow,completedAt
```

The `bucket` field normalizes check states into: `pass`, `fail`, `pending`, `skipping`, `cancel`.

### 2. Classify overall status

Parse the JSON output and classify:

| Condition | Status | Action |
|-----------|--------|--------|
| All checks `bucket == "pass"` or `"skipping"` | **pass** | Return success |
| Any check `bucket == "fail"` or `"cancel"` | **fail** | Return failed checks list |
| Any check `bucket == "pending"` and no failures | **pending** | Wait and re-poll |
| No check runs returned (empty array) | **pending** | Wait and re-poll (checks haven't started yet) |

### 3. Poll loop with backoff

If status is `pending`, wait and re-poll with exponential backoff:

```
elapsed = 0
interval = poll_interval  # default 30s

while elapsed < max_wait:
    sleep(interval)
    elapsed += interval
    query checks again
    classify status
    if status != pending: return status

    # Backoff schedule
    if elapsed > 900:      # 15 minutes
        interval = 120
    elif elapsed > 300:    # 5 minutes
        interval = 60
    # else: keep initial interval

return "timeout"
```

Use `sleep` in a Bash command for the wait:

```bash
sleep <interval>
```

Then re-query:

```bash
gh pr checks <pr_number> --repo <repo> --json name,state,bucket,link,workflow,completedAt
```

### 4. Extract failed check details

When status is `fail`, extract details for each failed check:

```bash
# Parse failed checks from JSON
# For each failed check, extract:
# - name: check run name
# - workflow: workflow name (if GitHub Actions)
# - link: URL to the check run
# - run_id: extracted from link URL (format: .../runs/<run_id>/...)
```

The `link` field contains the run URL. Extract the run ID:

```bash
# Example link: https://github.com/owner/repo/actions/runs/12345678/job/67890
# Extract run_id: 12345678
echo "<link>" | grep -oP 'runs/\K[0-9]+'
```

## Output

Return one of:

**Success (all checks passed)**:
```
status: pass
checks: [list of check names and their states]
```

**Failure (one or more checks failed)**:
```
status: fail
failed_checks:
  - name: <check name>
    workflow: <workflow name>
    link: <check run URL>
    run_id: <extracted run ID>
passed_checks: [list of passing check names]
```

**Timeout (max wait exceeded)**:
```
status: timeout
elapsed: <seconds waited>
pending_checks: [list of still-pending check names]
```

## Error Handling

| Condition | Behavior |
|-----------|----------|
| `gh pr checks` fails (PR not found, auth error) | Return error, do not retry |
| Empty check list on first query | Treat as pending, poll until checks appear or timeout |
| Network error during poll | Retry once after 10s, then treat as error |
| Mixed results (some fail, some pending) | Wait for pending to resolve before reporting failure — unless a fail is definitive (conclusion set) |

## Tips

- The `bucket` field is more reliable than `state` for programmatic consumption
- `gh pr checks` exit code 8 means checks are still pending
- Check for `completedAt` to distinguish truly pending vs. stale check runs
