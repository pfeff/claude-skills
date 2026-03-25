---
name: ci-feedback-loop
description: Monitor PR check status after push, auto-fix CI failures, and escalate when unable to fix. Use when an agent has pushed commits to a PR and needs to ensure checks pass before continuing.
allowed-tools:
  - Read
  - Bash
  - Grep
  - Glob
  - Edit
  - Write
  - Agent
version: 1.0.0
---

# CI Feedback Loop

After pushing commits to a PR branch, monitor check status, diagnose failures, attempt fixes, and escalate if unable to resolve.

## When to Use

- After pushing commits to a PR branch in the auto-advance loop
- When a user asks to monitor and fix CI failures on a PR
- When CI checks fail and the agent should attempt automated remediation

## Prerequisites

- `gh` CLI installed and authenticated with `repo` scope
- A PR exists with check runs (GitHub Actions, external CI, etc.)

## Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `max_retries` | 3 | Maximum fix attempts before escalating |
| `poll_interval` | 30 | Initial polling interval in seconds |
| `max_wait` | 1800 | Maximum wait time for checks in seconds (30 min) |

## Overview

The skill runs a monitor-diagnose-fix loop:

```
Push to PR branch
      │
      ▼
 Poll checks ◄──────────────┐
      │                      │
  ┌───┴───┐                  │
  │Result?│                  │
  └───┬───┘                  │
      │                      │
 pass → Done                 │
 pending → Wait (backoff) ───┘
 fail → Retrieve logs
            │
            ▼
      Analyze failure
            │
       ┌────┴────┐
       │Fixable? │
       └────┬────┘
            │
       yes → Attempt fix → Push → Re-poll
       no  → Retries left?
                yes → Re-trigger (flaky)
                no  → Escalate (PR comment)
```

## Operations

### 1. Poll Checks
**When**: After any push to the PR branch (initial or fix attempt).
**Implementation**: Load `operations/poll-checks.md`
**Quick summary**: Polls `gh pr checks --json` with exponential backoff until all checks resolve or timeout.

### 2. Retrieve Logs
**When**: One or more checks have failed.
**Implementation**: Load `operations/retrieve-logs.md`
**Quick summary**: Fetches failure logs via `gh run view --log-failed` with API fallback.

### 3. Analyze Failure
**When**: Failure logs have been retrieved.
**Implementation**: Load `operations/analyze-failure.md`
**Quick summary**: Classifies failure type (code error, flaky/infra, configuration) and extracts actionable context.

### 4. Attempt Fix
**When**: Failure is classified as fixable and retries remain.
**Implementation**: Load `operations/attempt-fix.md`
**Quick summary**: Agent applies fix, pushes to PR branch, decrements retry counter, re-enters poll loop.

### 5. Escalate
**When**: Retry limit reached, timeout exceeded, or failure classified as unfixable.
**Implementation**: Load `operations/escalate.md`
**Quick summary**: Posts structured PR comment with failure summary, attempted fixes, and next steps for human.

## End-to-End Flow

When invoked, run operations sequentially in a loop:

### Input

- `pr_number` (required): PR number to monitor
- `repo` (optional): Repository in `owner/repo` format. Defaults to current repo.

### Loop

```
1. poll-checks(pr_number) → status
2. if status == "pass" → return success
3. if status == "timeout" → escalate("Checks timed out")
4. if status == "fail":
   a. retrieve-logs(failed_checks) → logs
   b. analyze-failure(logs) → diagnosis
   c. if diagnosis.fixable AND retries > 0:
      - attempt-fix(diagnosis) → push
      - retries -= 1
      - goto 1
   d. if NOT diagnosis.fixable OR retries == 0:
      - escalate(diagnosis, attempts)
      - return failure
```

### Output

- **Success**: All checks passed (possibly after fixes). Agent can continue auto-advance.
- **Failure**: Escalation comment posted on PR. Agent should stop auto-advance and wait for human.
