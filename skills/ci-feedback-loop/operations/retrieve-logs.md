# Retrieve Logs

Fetch CI failure logs for failed check runs. Uses `gh run view --log-failed` with API fallback.

## Parameters

- `failed_checks` (required): List of failed checks from poll-checks, each containing `run_id`, `name`, `link`
- `repo` (optional): Repository in `owner/repo` format. Defaults to current repo.

## Execution Steps

### 1. Fetch logs for each failed check

For each failed check, attempt the primary method first:

**Primary: `gh run view --log-failed`**

```bash
gh run view <run_id> --repo <repo> --log-failed 2>&1
```

Check the output:
- If non-empty and contains error-relevant content → use this output
- If empty or contains only headers → fall back to API method

### 2. Fallback: Direct API log download

If `--log-failed` returns empty (known bug in older gh versions, cli/cli#10551):

```bash
# Download logs as ZIP
gh api -H "Accept: application/vnd.github+json" \
  "/repos/<owner>/<repo>/actions/runs/<run_id>/attempts/1/logs" > /tmp/ci-logs-<run_id>.zip

# Extract
unzip -o /tmp/ci-logs-<run_id>.zip -d /tmp/ci-logs-<run_id>/

# Find failed step logs (files ending in .txt, sorted by name for step order)
ls /tmp/ci-logs-<run_id>/
```

Then read the extracted log files to find failure content.

### 3. Fallback: Check run annotations

If both log methods fail or produce unhelpful output, try annotations:

```bash
# First, get check run IDs for this workflow run
gh api "/repos/<owner>/<repo>/actions/runs/<run_id>/jobs" \
  --jq '.jobs[] | select(.conclusion == "failure") | {id: .id, name: .name, steps: [.steps[] | select(.conclusion == "failure") | .name]}'

# Then get annotations for failed jobs
gh api "/repos/<owner>/<repo>/check-runs/<job_id>/annotations" \
  --jq '.[] | {level: .annotation_level, message: .message, path: .path, start_line: .start_line}'
```

Annotations provide structured failure data: severity level, message, file path, and line numbers.

### 4. Truncate and summarize

CI logs can be very long. Truncate to keep context manageable:

- **Maximum log output per check**: 200 lines
- **Priority**: Error lines first, then the 50 lines surrounding each error
- **Indicators of error lines**: lines containing `error`, `Error`, `ERROR`, `FAILED`, `failed`, `exception`, `Exception`, exit code messages

If logs exceed the limit, include:
1. The first 20 lines (setup context)
2. Lines containing error indicators with 5 lines of surrounding context
3. The last 20 lines (summary/exit status)

### 5. Compile output

For each failed check, produce:

```
Check: <name>
Run ID: <run_id>
Log source: <"gh run view --log-failed" | "API ZIP download" | "annotations">

--- Failure Output ---
<truncated log content>
--- End ---
```

## Output

A structured collection of failure logs, one per failed check. Each contains:
- Check name and run ID
- Retrieval method used
- Truncated failure log content
- Annotations (if available)

## Error Handling

| Condition | Behavior |
|-----------|----------|
| `gh run view --log-failed` returns empty | Fall back to API ZIP download |
| API ZIP download fails (404, 403) | Fall back to annotations |
| Annotations unavailable | Return whatever partial output was collected; note the gap |
| All methods fail | Return error with check name and link for manual inspection |
| Log content exceeds 200 lines | Truncate with error-focused extraction |

## Cleanup

Remove temporary log files after processing:

```bash
rm -rf /tmp/ci-logs-<run_id>.zip /tmp/ci-logs-<run_id>/
```

## Tips

- `--log-failed` is the fastest path — try it first even if you suspect it might fail
- Annotations are the most structured data source but not all CI systems produce them
- GitHub Actions steps that use `::error::` syntax generate annotations automatically
- The ZIP download can be large for long-running workflows; extraction is faster than parsing the ZIP in memory
