# Finish Operation

Guided post-completion workflow that automates mechanical steps and prompts for judgment steps after the last task in a workspace completes.

## Purpose

Walks the user through the end-of-task sequence: commit, PR, knowledge capture, metrics, and close. Prevents skipped steps (especially knowledge capture) and enforces safe ordering (R9).

## Inputs

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

### 2. Issue Checkbox Reconciliation (R8)

Fetch the linked GitHub issue body and reconcile its checkboxes against completed work.

```bash
gh issue view <number> --repo <repo> --json body --jq '.body'
```

**If the issue body contains checkboxes** (`- [ ]` or `- [x]`):

1. For each unchecked item (`- [ ]`), evaluate whether it was addressed by the completed tasks (using `TaskList` context, PR diff, and your knowledge of the work done)
2. Check off items that are genuinely complete (`- [ ]` → `- [x]`)
3. Leave items unchecked if the work was not done
4. Update the issue body:

```bash
gh issue edit <number> --repo <repo> --body "$UPDATED_BODY"
```

5. Report the reconciliation:

```
Issue checkbox reconciliation:
  ✓ [x] Implement auth middleware (task #3 completed)
  ✓ [x] Add unit tests (task #4 completed)
  ⚠ [ ] Update API docs (not addressed)
```

**If unchecked items remain**: Warn the user. Do not block — they may choose to close anyway.

**If no checkboxes exist**: Skip silently.

**On failure**: Warn and continue — this is non-blocking:

```
Failed to update issue checkboxes. You can update manually:
  gh issue edit <number> --repo <repo> --body "..."
```

### 2a. Gap Capture

Before committing and creating the PR, prompt for known gaps or deferred items. These are structured into `dispatch_result.json` so the goal tree can automatically register them as new nodes.

```
AskUserQuestion: "Are there known gaps or deferred items from this work?"
  Options:
    - "No gaps" → skip to step 3
    - "Yes" → collect gap details
```

**If gaps exist**, collect each gap interactively:

```
For each gap:
  AskUserQuestion: "Gap title (imperative form, e.g. 'Handle edge case X'):"
  AskUserQuestion: "Description (what was deferred and why):"
  AskUserQuestion: "Severity?"
    Options: ["minor", "moderate", "major"]
  AskUserQuestion: "Suggested parent node ID (or leave blank for current node's parent):"
    Options: ["<blank>", "<enter node ID>"]
```

**Write `dispatch_result.json`** to the workspace root with the collected gaps:

```json
{
  "status": "completed",
  "summary": "<task completion summary from TaskList>",
  "gaps": [
    {
      "title": "<gap title>",
      "description": "<gap description>",
      "severity": "<minor|moderate|major>",
      "suggested_parent": "<node ID or null>"
    }
  ]
}
```

```bash
WORKSPACE_ROOT="$(pwd)"
# Write dispatch_result.json (jq constructs the JSON from collected inputs)
jq -n \
  --arg status "completed" \
  --arg summary "$SUMMARY" \
  --argjson gaps "$GAPS_JSON" \
  '{status: $status, summary: $summary, gaps: $gaps}' \
  > "${WORKSPACE_ROOT}/dispatch_result.json"
```

**If no gaps**: Write `dispatch_result.json` with an empty gaps array:

```json
{
  "status": "completed",
  "summary": "<task completion summary>",
  "gaps": []
}
```

**Reference**: See `goal-tree/references/dispatch-result-schema.md` for the full schema.

**On failure**: Warn and continue — gap capture is non-blocking:

```
Gap capture failed. You can manually create dispatch_result.json later.
```

### 3. Commit Phase (R2)

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

**If PR already exists**: Report the existing PR URL and proceed to step 4a.

**If no PR exists**: Invoke `/gh-pr-create`. Pass `--draft` if the user specified it.

**On failure**: Print manual instructions and continue:

```
PR creation failed. You can create one manually:
  gh pr create --title "<title>" --body "<body>"
```

**Gate (R9)**: Record the PR URL. This is required before step 7 (close instructions) can proceed.

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

Immediately after step 4 (before knowledge capture), dispatch metrics collection to a background subagent. Metrics has no dependency on step 5, so it runs concurrently while the user works through knowledge capture.

Load the dispatch-task operation:

```
Read: skills/task-workflow/operations/dispatch-task.md
```

Provide inputs:
- `prompt`: Include the metrics collection instructions from step 6 below, plus all data already available: task_id, epic, task_count (from `TaskList`), started_at, pr_url. Instruct the subagent to write directly to `~/src/work/.metrics/finish.jsonl`.
- `task_subject`: "Collect finish metrics"
- `max_retries`: 0 (metrics are non-critical — no retry)

Use `run_in_background: true` on the Task tool so the parent continues immediately to step 5.

The dispatch result is checked in step 6.

### 5. Knowledge Capture Phase (R5)

Prompt the user for each knowledge capture tool. These are optional but the user must consciously accept or decline — do not silently skip.

**5a. Compound (solution capture)**:

```
Would you like to capture a reusable solution from this work?
1. Yes — run /claude-skills:compound
2. No — skip
```

If yes, invoke `/claude-skills:compound` and wait for completion before continuing.

**5b. Lessons Learned**:

```
Would you like to run a retrospective on this session?
1. Yes — run /claude-skills:lessons-learned
2. No — skip
```

If yes, invoke `/claude-skills:lessons-learned` and wait for completion before continuing.

**On failure of either**: Print manual instructions and continue:

```
<tool> failed. You can run it manually later:
  /<tool>
```

### 6. Metrics Phase (R7)

Check the background subagent dispatched in step 4b. If the dispatch completed successfully, step 6 is already done — report success and proceed. If the dispatch failed or was not used (fallback), collect metrics inline.

**Data to collect**:

| Metric | Source |
|--------|--------|
| task_id | DESIGN.md first line (e.g., `57`) |
| epic | Workspace path segment (e.g., `guardian`) |
| task_count | `TaskList` — count of completed tasks |
| started_at | Workspace creation time from `.envrc` or directory mtime |
| finished_at | Current timestamp |
| elapsed_hours | `finished_at - started_at` |
| pr_url | Captured from step 4 |
| criteria_passed | `.metrics/evaluation.json` — number of acceptance criteria passed (optional) |
| criteria_total | `.metrics/evaluation.json` — total acceptance criteria evaluated (optional) |
| acceptance_rate | `.metrics/evaluation.json` — `criteria_passed / criteria_total` (optional) |
| rules_passed | `.metrics/evaluation.json` — number of standing rules passed (optional) |
| rules_total | `.metrics/evaluation.json` — total standing rules evaluated (optional) |
| rules_pass_rate | `.metrics/evaluation.json` — `rules_passed / rules_total` (optional) |

**Evaluation metrics**: Check for `.metrics/evaluation.json` in the workspace root. This file is written by execute-tree step 4a (Scalar Metrics) when the task was dispatched via goal-tree. If the file exists, include `criteria_passed`, `criteria_total`, and `acceptance_rate` in the finish record. If the file also contains a non-empty `standing_rules` array, include `rules_passed`, `rules_total`, and `rules_pass_rate`. If absent (e.g., standalone task-workflow without goal-tree), omit these fields.

```bash
EVAL_METRICS="${WORKSPACE_ROOT}/.metrics/evaluation.json"
if [[ -f "$EVAL_METRICS" ]]; then
  CRITERIA_PASSED=$(jq -r '.criteria_passed' "$EVAL_METRICS")
  CRITERIA_TOTAL=$(jq -r '.criteria_total' "$EVAL_METRICS")
  ACCEPTANCE_RATE=$(jq -r '.acceptance_rate' "$EVAL_METRICS")

  # Standing rules aggregate metrics
  RULES_TOTAL=$(jq -r '.standing_rules | length' "$EVAL_METRICS")
  if [[ "$RULES_TOTAL" -gt 0 ]]; then
    RULES_PASSED=$(jq -r '[.standing_rules[] | select(.status == "pass")] | length' "$EVAL_METRICS")
    RULES_PASS_RATE=$(jq -r '[.standing_rules[] | select(.status == "pass")] | length / (.standing_rules | length)' "$EVAL_METRICS")
  fi
fi
```

**Log location**: `~/src/work/.metrics/finish.jsonl`

**Format** (one JSON object per line):

```json
{"task_id":57,"epic":"guardian","task_count":5,"started_at":"2026-02-20T10:00:00Z","finished_at":"2026-02-22T15:30:00Z","elapsed_hours":53.5,"pr_url":"https://github.com/pfeff/guardian/pull/12","criteria_passed":3,"criteria_total":3,"acceptance_rate":1.0,"rules_passed":1,"rules_total":1,"rules_pass_rate":1.0}
```

The `criteria_*` and `rules_*` fields are optional — omitted when no evaluation data exists or when no standing rules are defined.

```bash
mkdir -p ~/src/work/.metrics && chmod 700 ~/src/work/.metrics

EVAL_METRICS="${WORKSPACE_ROOT}/.metrics/evaluation.json"
EVAL_ARGS=""
EVAL_FIELDS=""
if [[ -f "$EVAL_METRICS" ]]; then
  EVAL_ARGS="--argjson criteria_passed $(jq -r '.criteria_passed' "$EVAL_METRICS") \
    --argjson criteria_total $(jq -r '.criteria_total' "$EVAL_METRICS") \
    --argjson acceptance_rate $(jq -r '.acceptance_rate' "$EVAL_METRICS")"
  EVAL_FIELDS=', $criteria_passed, $criteria_total, $acceptance_rate'

  # Include standing rule aggregates if rules were evaluated
  RULES_TOTAL=$(jq -r '.standing_rules | length' "$EVAL_METRICS")
  if [[ "$RULES_TOTAL" -gt 0 ]]; then
    RULES_PASSED=$(jq -r '[.standing_rules[] | select(.status == "pass")] | length' "$EVAL_METRICS")
    EVAL_ARGS="$EVAL_ARGS \
      --argjson rules_passed $RULES_PASSED \
      --argjson rules_total $RULES_TOTAL \
      --argjson rules_pass_rate $(jq -r '[.standing_rules[] | select(.status == "pass")] | length / (.standing_rules | length)' "$EVAL_METRICS")"
    EVAL_FIELDS="$EVAL_FIELDS, \$rules_passed, \$rules_total, \$rules_pass_rate"
  fi
fi

jq -n \
  --argjson task_id 57 \
  --arg epic "guardian" \
  --argjson task_count 5 \
  --arg started_at "2026-02-20T10:00:00Z" \
  --arg finished_at "2026-02-22T15:30:00Z" \
  --argjson elapsed_hours 53.5 \
  --arg pr_url "https://github.com/pfeff/guardian/pull/12" \
  $EVAL_ARGS \
  -c "{task_id: \$task_id, epic: \$epic, task_count: \$task_count, started_at: \$started_at, finished_at: \$finished_at, elapsed_hours: \$elapsed_hours, pr_url: \$pr_url${EVAL_FIELDS}}" \
  >> ~/src/work/.metrics/finish.jsonl
```

**On failure**: Warn and continue — metrics are non-critical:

```
Metrics capture failed. Non-critical, continuing.
```

### 6b. Coordinator Completion Report

If `COORDINATOR_URL`, `COORDINATOR_TOKEN`, and `COORDINATOR_TASK_ID` are set, report completion data to the coordinator:

```bash
coord_report_completion "$pr_url" "$task_count"
```

This mirrors the finish outcome (PR URL, task count) to the coordinator for visibility. Failures are non-blocking — warn and continue.

### 7. Close Instructions (R6, R9)

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
| Checkbox reconciliation | gh CLI failure | Warn, continue |
| Commit | Git failure | Print manual commit command, continue |
| PR | gh CLI failure | Print manual PR command, continue |
| PR | No commits on branch | Warn, skip PR creation |
| CI | Check failure | Diagnose and fix (up to 3 rounds), then continue |
| CI | 3 fix rounds exhausted | Warn user, continue to knowledge capture |
| Compound | Skill failure | Print `/claude-skills:compound` command, continue |
| Lessons | Skill failure | Print `/claude-skills:lessons-learned` command, continue |
| Metrics | File write failure | Warn, continue |
| Close | No PR exists | Warn user to create PR, print close instructions |

## Examples

### Clean run — all steps succeed

```
User: /finish

Checking tasks...
  All 5 tasks completed ✓

Reconciling issue checkboxes (pfeff/cursor-rules#42)...
  ✓ [x] Add /finish operation
  ✓ [x] Wire up metrics capture
  ✓ [x] Add knowledge capture prompts
  Updated issue body ✓

Checking for uncommitted changes...
  cursor-rules: 2 files changed
  Committing... ✓  abc1234 feat: add /finish operation

Creating PR...
  ✓  https://github.com/pfeff/cursor-rules/pull/18

Capture a reusable solution? (/compound)  → No
Run a retrospective? (/lessons-learned)   → No

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
- **Compound skill**: `skills/compound/SKILL.md`
- **Lessons learned skill**: `skills/lessons-learned/SKILL.md`
- **Close workspace script**: `skills/task-workflow/scripts/close-workspace.sh`
- **Close workspace operation**: `skills/task-workflow/operations/close-workspace.md`
- **Dispatch result schema**: `skills/goal-tree/references/dispatch-result-schema.md`
- **Metrics log**: `~/src/work/.metrics/finish.jsonl`
- **Task tracking**: Claude native `TaskList`, `TaskUpdate` tools
- **Coordinator API** (optional): `COORDINATOR_URL`/`COORDINATOR_TOKEN`/`COORDINATOR_TASK_ID` — reports completion data to coordinator when set
