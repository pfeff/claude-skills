# Escalate

Post a structured PR comment when the agent cannot fix CI failures. Provides human with context to diagnose and resolve.

## Parameters

- `pr_number` (required): PR number to comment on
- `repo` (optional): Repository in `owner/repo` format
- `reason` (required): Why escalation is needed — `"exhausted"` (retry limit), `"timeout"` (checks timed out), `"unfixable"` (agent can't fix)
- `failed_checks` (required): List of failed check names and their diagnoses
- `attempt_history` (optional): List of fix attempts made (attempt number, action, result)

## Execution Steps

### 1. Build escalation comment

Compose a structured PR comment with all relevant context:

```markdown
## CI Feedback Loop — Escalation

**Reason**: <reason description>

### Failed Checks

<for each failed check>
- **<check name>** — <failure type>
  - Error: <one-line error summary>
  - Link: <check run URL>
</for each>

### Fix Attempts

<if attempts were made>
| Attempt | Action | Result |
|---------|--------|--------|
| 1 | <description> | <outcome> |
| 2 | <description> | <outcome> |
| ... | ... | ... |

<if no attempts>
No fix attempts were made — failure was classified as unfixable.

### Next Steps

<contextual guidance based on reason>
```

### 2. Determine "Next Steps" content

| Reason | Next Steps |
|--------|------------|
| `exhausted` | "The agent made {N} fix attempts but checks still fail. Manual investigation is needed. Check the failure logs linked above for details." |
| `timeout` | "Checks did not complete within the configured timeout ({max_wait}s). This may indicate a hung CI job, queued runner, or infrastructure issue. Re-run the checks manually or investigate the CI system." |
| `unfixable` | "The agent determined it cannot fix this failure: {unfixable reason}. Manual intervention is required." |

### 3. Post comment

```bash
gh pr comment <pr_number> --repo <repo> --body "<comment body>"
```

Use a heredoc for the body to preserve formatting:

```bash
gh pr comment <pr_number> --repo <repo> --body "$(cat <<'EOF'
<comment body>
EOF
)"
```

### 4. Log escalation

Report the escalation so the caller can stop the auto-advance loop:

```
escalated: true
reason: <reason>
pr_number: <pr_number>
comment_url: <URL of posted comment, from gh output>
```

## Output

Confirmation that escalation comment was posted, with:
- `escalated: true`
- `reason`: Why escalation occurred
- `pr_number`: Which PR was commented on
- The auto-advance loop should stop and wait for human input

## Error Handling

| Condition | Behavior |
|-----------|----------|
| `gh pr comment` fails (auth, PR closed) | Log the error; output the comment body so the agent can communicate it another way |
| Comment body exceeds GitHub limit (65536 chars) | Truncate attempt history, keep failed checks and next steps |
| PR was merged or closed while agent was working | Skip comment, note that PR is no longer open |

## Tips

- Keep the comment actionable — humans should know what to look at and what was already tried
- Don't dump full log output into the comment — link to the check run instead
- The attempt history helps humans avoid re-trying the same fixes the agent already attempted
