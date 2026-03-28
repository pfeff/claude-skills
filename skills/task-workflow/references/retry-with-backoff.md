# Retry with Backoff Reference

Reusable retry pattern with exponential backoff and jitter. Used after `references/error-classification.md` classifies an error as transient.

## Parameters

| Parameter | Source | Default |
|-----------|--------|---------|
| `transient_retries` | `env(AUTO_ADVANCE_TRANSIENT_RETRIES)` | 3 |
| `backoff_ceiling` | `env(AUTO_ADVANCE_BACKOFF_CEILING)` | 60 (seconds) |
| `backoff_base` | Hardcoded | 2 (seconds) |

## Backoff Formula

```
delay = min(backoff_base * 2^attempt + jitter, backoff_ceiling)
```

Where:
- `attempt` starts at 0 (first retry)
- `jitter` = random value between 0 and `backoff_base` (use `$((RANDOM % backoff_base))` in Bash)

### Example Delays (base=2, ceiling=60)

| Attempt | Base Delay | With Jitter (0-2s) | Capped |
|---------|-----------|---------------------|--------|
| 0 | 2s | 2-4s | 2-4s |
| 1 | 4s | 4-6s | 4-6s |
| 2 | 8s | 8-10s | 8-10s |
| 3 | 16s | 16-18s | 16-18s |
| 4 | 32s | 32-34s | 32-34s |
| 5 | 64s | 64-66s | 60s (ceiling) |

## Retry Procedure

When an error is classified as transient:

```
attempt = 0
max_attempts = transient_retries  # from env, default 3

While attempt < max_attempts:
  1. Calculate delay:
     delay = min(backoff_base * 2^attempt + jitter, backoff_ceiling)

  2. Log the retry:
     "Transient error (attempt {attempt + 1}/{max_attempts}): {error_summary}. Backing off {delay}s..."

  3. Wait:
     Bash: sleep <delay>

  4. Re-run the failing command

  5. If succeeds:
     Log: "Retry succeeded on attempt {attempt + 1}"
     → Continue to next step in the operation

  6. If fails:
     Classify the new error (load error-classification.md)
     - If still transient: increment attempt, continue loop
     - If now permanent: exit loop, escalate as permanent error
     - If uncertain: increment attempt, continue loop

  7. Increment attempt

If all attempts exhausted:
  → Escalate with retry history (see Escalation section)
```

### Reduced Budget (Uncertain Errors)

When error-classification.md classifies an error as uncertain, the retry budget is halved:

```
reduced_retries = max(1, transient_retries / 2)  # integer division
```

Follow the same procedure above but with `reduced_retries` as the max.

## Retry-After Override

If `error-classification.md` detected a Retry-After header value:

```
delay = max(retry_after_value, calculated_backoff)
```

Log: "Server requested {retry_after_value}s, using {delay}s (calculated: {calculated_backoff}s)"

## Escalation

When retries are exhausted, provide structured context for the pause message:

```
### Retry History
- **Error type**: <transient classification from error-classification.md>
- **Attempts**: <attempt count> / <max_attempts>
- **Total backoff**: <sum of all delays>s
- **Last error**: <most recent error output, truncated to 3 lines>
- **Guidance**: <contextual suggestion based on error type>
```

### Escalation Guidance by Error Type

| Error Type | Guidance |
|------------|----------|
| API rate limit (429) | "Check API rate limit status. Wait for rate limit window to reset, then resume." |
| Network timeout | "Check network connectivity. The target service may be down. Resume when connectivity is restored." |
| GitHub API 5xx | "GitHub API may be experiencing issues. Check https://www.githubstatus.com/ and resume when resolved." |
| Git lock/transport | "Another git process may be running, or the remote is temporarily unavailable. Check and resume." |
| Test flake | "Tests failed intermittently — may be a flaky test or test infrastructure issue. Review test output and resume." |
| Uncertain | "Error did not match known patterns. Review the error output and determine if the issue is transient or requires code changes." |

## Integration

Operations use this reference by:

1. Loading `references/error-classification.md` to classify the error
2. If transient or uncertain: loading this reference and following the retry procedure
3. If permanent: following the operation's existing escalation path

The calling operation is responsible for:
- Capturing command output (exit code + stderr/stdout)
- Passing error context to classification
- Incorporating retry history into pause messages
