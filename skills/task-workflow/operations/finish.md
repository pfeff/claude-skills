# Finish Operation

Guided post-completion workflow that automates mechanical steps and prompts for judgment steps after the last task in a workspace completes.

## Purpose

Walks the user through the end-of-task sequence: commit, PR, review, knowledge capture, metrics, and close. Prevents skipped steps (especially knowledge capture) and enforces safe ordering (R9).

## Inputs

- **--no-review** (optional): Skip the review phase entirely
- **--draft** (optional): Create PR as draft

## Coordinator Sync (Optional)

If `COORDINATOR_URL` and `COORDINATOR_TOKEN` are set, report completion data to the coordinator API after all tasks finish. This is additive — native task tools remain the primary interface.

```bash
# Helper: report completion to coordinator
coord_report_completion() {
  local pr_url="$1" tasks_completed="$2"
  if [[ -n "${COORDINATOR_URL:-}" && -n "${COORDINATOR_TOKEN:-}" && -n "${COORDINATOR_TASK_ID:-}" ]]; then
    curl -s -X POST "${COORDINATOR_URL}/api/tasks/${COORDINATOR_TASK_ID}/report" \
      -H "Authorization: Bearer ${COORDINATOR_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"status\":\"completed\",\"outputs\":{\"pr_url\":\"${pr_url}\",\"tasks_completed\":${tasks_completed}}}" > /dev/null
  fi
}
```

## Implementation Steps

### 1. Task Completion Check (R1)

Query `TaskList` and inspect task statuses.

**If all tasks are completed**: Proceed to step 2.

**If tasks remain incomplete**: Warn the user:

```
Incomplete tasks detected:
- #3 [in_progress] Implement auth middleware
- #5 [pending] Write integration tests

Continue with /finish anyway?
```

Use `AskUserQuestion` to confirm. If the user declines, stop.

### 2. Commit Phase (R2)

Identify workspace repositories from the "Relevant Repositories" section in CLAUDE.md, then check each for uncommitted changes:

```bash
# For each known repo listed in CLAUDE.md
git -C "<repo>" status --porcelain
```

**If uncommitted changes exist**: Invoke the git skill's commit operation for each repo with changes. Follow the commit operation's full process (resolve symlinks, branch guard, stage, craft message, commit, verify).

**If no uncommitted changes**: Report "No uncommitted changes" and proceed.

**On failure**: Print manual instructions and continue:

```
Commit failed in <repo>. You can commit manually:
  cd <repo> && git add <specific-files> && git commit -m "<message>"
```

### 4. PR Phase (R3, R9)

Check if a PR already exists for the current branch:

```bash
gh pr view --json url,state 2>/dev/null
```

**If PR already exists**: Report the existing PR URL and proceed to step 5.

**If no PR exists**: Invoke `/gh-pr-create`. Pass `--draft` if the user specified it.

**On failure**: Print manual instructions and continue:

```
PR creation failed. You can create one manually:
  gh pr create --title "<title>" --body "<body>"
```

**Gate (R9)**: Record the PR URL. This is required before step 8 (close instructions) can proceed.

### 4a. CI Check and Fix Loop

After PR creation (or if a PR already exists), check CI status and fix failures before proceeding.

```bash
gh pr checks <PR_NUMBER> --repo <REPO> --watch
```

**If all checks pass**: Proceed to step 4b.

**If checks fail** (max 3 rounds):

1. **Diagnose**: Fetch the failed check logs:
   ```bash
   gh run view <RUN_ID> --repo <REPO> --log-failed
   ```

2. **Fix**: Address the failure based on the diagnosis:
   - **Checklist check failures** (unchecked items): Update the PR body to check or strike out the item with rationale
   - **Lint/format failures**: Fix the code, commit, and push
   - **Test failures**: Fix the test or the code, commit, and push
   - **Other CI failures**: Diagnose and fix; if the failure is outside your control (infra flake, external service), warn the user and continue

3. **Verify**: Wait for checks to re-run:
   ```bash
   gh pr checks <PR_NUMBER> --repo <REPO> --watch
   ```

4. **Repeat** if checks still fail (up to 3 rounds total)

**After 3 failed rounds**: Warn the user and continue to step 4b:

```
CI checks still failing after 3 fix attempts. You may need to investigate manually:
  gh pr checks <PR_NUMBER> --repo <REPO>
```

### 4b. Background Metrics Dispatch

Immediately after step 4 (before review and knowledge capture), dispatch metrics collection to a background subagent. Metrics has no dependency on steps 5-6, so it runs concurrently while the user works through review and knowledge capture.

Load the dispatch-task operation:

```
Read: skills/task-workflow/operations/dispatch-task.md
```

Provide inputs:
- `prompt`: Include the metrics collection instructions from step 7 below, plus all data already available: task_id, epic, task_count (from `TaskList`), started_at, pr_url. Instruct the subagent to write directly to `~/src/work/.metrics/finish.jsonl`.
- `task_subject`: "Collect finish metrics"
- `max_retries`: 0 (metrics are non-critical — no retry)

Use `run_in_background: true` on the Task tool so the parent continues immediately to step 5.

The dispatch result is checked in step 7.

### 5. Review Phase (R4)

**If `--no-review` was specified**: Submit a minimal review comment to satisfy the `PR Review` CI check, then skip to step 6:

```bash
gh pr review <PR_NUMBER> --repo <REPO> --comment --body "Self-reviewed, simple change."
```

**Otherwise**: Invoke `/review <PR_NUMBER>` (passing the PR number captured in step 4). This runs the review specialists and automatically posts inline comments on the PR via `post-review.md`, satisfying the `PR Review` CI check.

After review results are displayed, check if there are findings at warning or critical severity.

**If findings exist**: Ask the user:

```
Review found issues. Would you like to:
1. Fix issues now (will loop: fix → commit → re-review)
2. Skip and continue
```

**If user chooses to fix** (max 3 rounds):
1. User addresses the issues
2. Invoke git skill commit operation for the fixes
3. Push the new commits
4. Re-invoke `/review <PR_NUMBER>`
5. Repeat until clean, user chooses to skip, or 3 rounds reached

**If review is clean or user skips**: Proceed to step 6.

**On failure**: Print manual instructions and continue:

```
Review failed. You can run it manually:
  /review <PR_NUMBER>
```

> **Why PR number matters**: The `PR Review` CI check requires at least one GitHub review comment on the PR. Running `/review <PR_NUMBER>` triggers `post-review.md` which posts inline comments. Running `/review` without a PR number only runs a local branch diff and never touches GitHub.

### 6. Knowledge Capture Phase (R5)

Prompt the user for each knowledge capture tool. These are optional but the user must consciously accept or decline — do not silently skip.

**6a. Compound (solution capture)**:

```
Would you like to capture a reusable solution from this work?
1. Yes — run /compound
2. No — skip
```

If yes, invoke `/compound` and wait for completion before continuing.

**6b. Lessons Learned**:

```
Would you like to run a retrospective on this session?
1. Yes — run /lessons-learned
2. No — skip
```

If yes, invoke `/lessons-learned` and wait for completion before continuing.

**On failure of either**: Print manual instructions and continue:

```
<tool> failed. You can run it manually later:
  /<tool>
```

### 7. Metrics Phase (R7)

Check the background subagent dispatched in step 4b. If the dispatch completed successfully, step 7 is already done — report success and proceed. If the dispatch failed or was not used (fallback), collect metrics inline.

**Data to collect**:

| Metric | Source |
|--------|--------|
| task_id | DESIGN.md first line (e.g., `57`) |
| epic | Workspace path segment (e.g., `guardian`) |
| task_count | `TaskList` — count of completed tasks |
| started_at | Workspace creation time from `.envrc` or directory mtime |
| finished_at | Current timestamp |
| elapsed_hours | `finished_at - started_at` |
| review_rounds | Count of review fix loops in step 5 (0 if skipped or clean on first pass) |
| pr_url | Captured from step 4 |

**Log location**: `~/src/work/.metrics/finish.jsonl`

**Format** (one JSON object per line):

```json
{"task_id":57,"epic":"my-project","task_count":5,"started_at":"2026-02-20T10:00:00Z","finished_at":"2026-02-22T15:30:00Z","elapsed_hours":53.5,"review_rounds":1,"pr_url":"https://github.com/user/repo/pull/12"}
```

```bash
mkdir -p ~/src/work/.metrics && chmod 700 ~/src/work/.metrics
jq -n \
  --argjson task_id 57 \
  --arg epic "my-project" \
  --argjson task_count 5 \
  --arg started_at "2026-02-20T10:00:00Z" \
  --arg finished_at "2026-02-22T15:30:00Z" \
  --argjson elapsed_hours 53.5 \
  --argjson review_rounds 1 \
  --arg pr_url "https://github.com/user/repo/pull/12" \
  -c '{$task_id,$epic,$task_count,$started_at,$finished_at,$elapsed_hours,$review_rounds,$pr_url}' \
  >> ~/src/work/.metrics/finish.jsonl
```

**On failure**: Warn and continue — metrics are non-critical:

```
Metrics capture failed. Non-critical, continuing.
```

### 7b. Coordinator Completion Report

If `COORDINATOR_URL`, `COORDINATOR_TOKEN`, and `COORDINATOR_TASK_ID` are set, report completion data to the coordinator:

```bash
coord_report_completion "$pr_url" "$task_count"
```

This mirrors the finish outcome (PR URL, task count) to the coordinator for visibility. Failures are non-blocking — warn and continue.

### 8. Close Instructions (R6, R9)

**Gate check (R9)**: If no PR URL was captured in step 4 (both creation and lookup failed), warn:

```
⚠ No PR was created or found. Create a PR before closing:
  gh pr create --title "<title>" --body "<body>"
```

Print manual close instructions:

```
All done! To close this workspace, run from your control session:

  /close-workspace

(This must run from outside this tmux session because it removes the worktree.)
```

## Error Handling

| Phase | Error | Response |
|-------|-------|----------|
| Task check | TaskList unavailable | Warn, proceed (assume complete) |
| Commit | Git failure | Print manual commit command, continue |
| PR | gh CLI failure | Print manual PR command, continue |
| PR | No commits on branch | Warn, skip PR creation |
| CI | Check failure | Diagnose and fix (up to 3 rounds), then continue |
| CI | 3 fix rounds exhausted | Warn user, continue to review |
| Review | Agent spawn failure | Print `/review` command, continue |
| Compound | Skill failure | Print `/compound` command, continue |
| Lessons | Skill failure | Print `/lessons-learned` command, continue |
| Metrics | File write failure | Warn, continue |
| Close | No PR exists | Warn user to create PR, print close instructions |

## Examples

### Clean run — all steps succeed

```
User: /finish

Checking tasks...
  All 5 tasks completed ✓

Checking for uncommitted changes...
  cursor-rules: 2 files changed
  Committing... ✓  abc1234 feat: add /finish operation

Creating PR...
  ✓  https://github.com/user/repo/pull/18

Running review...
  Security:     0 findings
  Simplicity:   0 findings
  Architecture: 1 info
  No critical or warning findings ✓

Capture a reusable solution? (/compound)  → No
Run a retrospective? (/lessons-learned)   → No

Capturing metrics... ✓

All done! To close this workspace, run from your control session:

  /close-workspace

(This must run from outside this tmux session because it removes the worktree.)
```

### Review finds issues — fix loop

```
User: /finish

Checking tasks... ✓
Committing... ✓
Creating PR... ✓

Running review...
  Security:     1 warning — SQL injection in query builder
  Fix issues now? → Yes

  [user fixes the issue]

  Committing fix... ✓
  Re-running review...
    Security: 0 findings ✓

Capture a reusable solution? → Yes
  [runs /compound]
Run a retrospective? → No

Capturing metrics... ✓

All done! To close this workspace, run from your control session:

  /close-workspace

(This must run from outside this tmux session because it removes the worktree.)
```

### Partial failure — PR creation fails

```
User: /finish

Checking tasks... ✓
Committing... ✓
Creating PR... ✗
  PR creation failed. You can create one manually:
    gh pr create --title "feat: add /finish operation" --body "..."

Running review... ✓
Knowledge capture... ✓
Capturing metrics... ✓

⚠ No PR was created or found. Create a PR before closing:
  gh pr create --title "<title>" --body "<body>"

To close this workspace, run from your control session:

  /close-workspace

(This must run from outside this tmux session because it removes the worktree.)
```

## Integration Points

- **Git skill commit operation**: `skills/git/operations/commit.md`
- **PR creation**: `commands/gh-pr-create.md`
- **Review skill**: `skills/review/SKILL.md`
- **Compound skill**: `skills/compound/SKILL.md`
- **Lessons learned skill**: `skills/lessons-learned/SKILL.md`
- **Close workspace script**: `skills/task-workflow/scripts/close-workspace.sh`
- **Close workspace operation**: `skills/task-workflow/operations/close-workspace.md`
- **Metrics log**: `~/src/work/.metrics/finish.jsonl`
- **Task tracking**: Claude native `TaskList`, `TaskUpdate` tools
- **Coordinator API** (optional): `COORDINATOR_URL`/`COORDINATOR_TOKEN`/`COORDINATOR_TASK_ID` — reports completion data to coordinator when set
