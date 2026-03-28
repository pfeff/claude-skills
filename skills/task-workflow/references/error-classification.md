# Error Classification Reference

Classifies errors as **transient** (retry with backoff) or **permanent** (escalate immediately). Used by auto-advance and validate-implementation operations to decide retry strategy.

## Classification Rules

When an operation step fails, match the error output against these patterns **in order**. First match wins.

### Transient Errors

Retry with exponential backoff (see `references/retry-with-backoff.md`).

| Pattern | Source | Signal |
|---------|--------|--------|
| Exit code + stderr contains `rate limit` or `429` | gh CLI, curl, API calls | API rate limit |
| Exit code + stderr contains `5[0-9]{2}` (500-599) | gh CLI, curl, API calls | Server error |
| stderr contains `timed out` or `timeout` | Any network operation | Network timeout |
| stderr contains `connection refused` or `connection reset` | Any network operation | Service unavailable |
| stderr contains `temporary failure` or `temporarily unavailable` | DNS, network | Transient DNS/network |
| stderr contains `Could not resolve host` | DNS | DNS resolution failure |
| stderr contains `lock` and (`file exists` or `unable to create`) | git | Git lock file contention |
| stderr contains `cannot lock ref` | git push/fetch | Git ref lock |
| stderr contains `The remote end hung up unexpectedly` | git push/fetch/clone | Git transport failure |
| stderr contains `SSL` and (`handshake` or `connection`) | Any TLS operation | TLS negotiation failure |
| Test output contains `timed out` or `timeout` but NOT assertion keywords | Test runner | Test infrastructure flake |
| Test output contains `connection refused` in test failure | Test runner | Test dependency unavailable |
| stderr contains `Resource temporarily unavailable` | Any | OS resource contention |
| stderr contains `retry` and `after` (Retry-After header) | API calls | Server-requested backoff |

### Permanent Errors

Escalate immediately — do not retry.

| Pattern | Source | Signal |
|---------|--------|--------|
| Test output contains `assert` or `AssertionError` or `expected` | Test runner | Genuine test failure |
| Test output contains `SyntaxError` or `syntax error` | Test runner | Code syntax error |
| Test output contains `ImportError` or `ModuleNotFoundError` | Test runner | Missing dependency |
| Test output contains `NameError` or `undefined` | Test runner | Code reference error |
| stderr contains `command not found` or `not recognized` | Any | Missing tool |
| stderr contains `permission denied` (not network-related) | Filesystem | Permission issue |
| stderr contains `No such file or directory` (not in network context) | Filesystem | Missing file |
| stderr contains `merge conflict` or `CONFLICT` | git | Merge conflict |
| stderr contains `401` or `403` without `retry` or `rate` | API calls | Authentication failure |
| Exit code 128 + stderr contains `not a git repository` | git | Wrong directory |
| Lint output with specific file:line references | Linter | Code style violation |

### Uncertain (Default: Transient)

If error output does not match any pattern above:

1. Classify as **transient** (conservative default per DD4)
2. Use a reduced retry budget: `max(1, transient_retries / 2)` rounded down
3. Log: "Uncertain error classification — defaulting to transient with reduced retries"

## Usage

Operations load this reference when a step fails:

```
1. Capture the failing command's exit code and stderr/stdout
2. Match against Transient patterns first, then Permanent patterns
3. If transient: proceed to retry-with-backoff.md
4. If permanent: follow existing escalation path (pause or fix-and-retry)
5. If uncertain: treat as transient with reduced budget
```

## Retry-After Header

When stderr or response headers contain a `Retry-After` value:
- Parse the value as seconds
- Use `max(retry_after_value, calculated_backoff)` as the delay
- Log: "Server requested backoff of <N>s, using <actual_delay>s"

## Examples

### Transient: GitHub API rate limit
```
$ gh pr create --title "..."
HTTP 429: API rate limit exceeded - https://api.github.com/...
```
→ Pattern match: `429` → **transient**

### Permanent: Test assertion failure
```
$ pytest tests/
FAILED tests/test_handler.py::test_webhook_auth - AssertionError: expected 200, got 401
```
→ Pattern match: `AssertionError` + `expected` → **permanent**

### Transient: Git lock contention
```
$ git commit -m "feat: ..."
fatal: Unable to create '/path/.git/index.lock': File exists.
```
→ Pattern match: `lock` + `file exists` → **transient**

### Uncertain: Unknown error
```
$ some-tool --run
Error: unexpected internal state
```
→ No pattern match → **uncertain** → treat as transient with reduced retries
