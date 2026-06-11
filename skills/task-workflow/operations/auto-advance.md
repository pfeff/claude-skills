# Auto-Advance Operation

Autonomously cycles through the workspace task list: pick next task → implement → validate → commit → repeat. The human reviews aggregate output at PR boundary.

**Requirements**: Must be run from within an initialized workspace with a populated task list (`CLAUDE_CODE_TASK_LIST_ID` set in `.envrc`).

## Inputs

None — uses the workspace's task list and DESIGN.md for all context.

## Coordinator Sync (Optional)

If `COORDINATOR_URL` and `COORDINATOR_TOKEN` are set, mirror task state changes to the coordinator API. This is additive — native `TaskList`/`TaskUpdate` remain the primary interface.

```bash
source ${CLAUDE_PLUGIN_ROOT}/skills/goal-tree/scripts/coord-helpers.sh
```

This provides `coord_create_task`, `coord_sync_status`, and `coord_report_progress`. All are no-ops when coordinator env vars are unset.

`COORDINATOR_TASK_ID` is the coordinator's task ID (set in `.envrc` during workspace setup when coordinator is active). It maps the local task to the coordinator's task record.

## Purpose

Eliminates per-task human prompts by chaining task selection, implementation, validation, and commit into an autonomous loop. The agent operates independently until: all tasks complete, a validation failure exhausts retries, the agent encounters an ambiguous decision, a commit fails, or stuck detection triggers escalation. See DESIGN.md R1-R8 for full requirements.

## Within-Session Driver (`/goal`)

This loop is **self-driving by default** — once entered, it runs the loop body until a termination condition fires. A session may *optionally* be driven by native `/goal` instead, which is purely additive on top of the loop:

```
/goal <completion-condition>; stop after N turns
```

`/goal` installs a session-scoped Stop hook that re-engages the agent toward the stated condition for up to `N` turns. Used this way, `/goal` is the **within-session driver / turn budget** for the auto-advance loop (the same role applies on the re-entry path — see `resume.md`). It keeps the agent advancing through the task list without per-turn human prompts.

**The authoritative completion gate is NOT `/goal`.** `/goal`'s evaluator inspects the session transcript to decide whether to release the Stop hook; that is a *driver* signal, never the source of truth for "node complete." The authoritative "done" remains the **tool-based complete-check** that this loop already enforces:

- every native `TaskList` task is `completed` (the entry guard / step 6 termination condition), **and**
- validation passed for each task (step 3), **and**
- every acceptance criterion in the workspace DESIGN.md is checked off (step 7a AC gate: `grep -c '^- \[ \] \*\*AC-' DESIGN.md` returns 0), **and**
- changes are committed **and pushed**, with a PR opened for L0 nodes (step 7a).

These conditions are evaluated with `TaskList` / `git` / `gh` — real tool state, not transcript inference. Step 7's termination on "no pending tasks (+ validation + commit/PR success)" **is** that complete-check; `/goal` does not replace or relax it.

### `/goal`-stop ≠ node-complete

A `/goal` halt (turn budget exhausted, or its transcript evaluator deciding the condition is met) can occur while the tool-based check still says **NOT complete** — e.g. pending tasks remain, commits are unpushed, or the worktree is dirty. In that case the node is **not done**:

| Tool-based check at `/goal`-stop | Meaning | Action |
|----------------------------------|---------|--------|
| All Tasks completed + validated + all ACs checked + committed/pushed (PR open) | Complete | Done — release. |
| Pending/in-progress tasks remain, unchecked ACs, unpushed commits, or dirty tree | **Incomplete** | **Re-drive** — re-issue `/goal` (or nudge the session) to resume the loop. Do **not** treat the halt as completion. |

The supervising layer (L1) is responsible for detecting the halted-but-incomplete state (via `TaskList` / `git status` / `gh pr` on the worktree) and re-driving rather than signing off. A clean stop is only a completion when the tool-based gate above passes.

## Configuration

Read workspace settings before entering the loop:

```
max_retries = env(AUTO_ADVANCE_MAX_RETRIES, default=2)
max_revert_retries = env(AUTO_ADVANCE_MAX_REVERT_RETRIES, default=3)
use_subagents = env(AUTO_ADVANCE_USE_SUBAGENTS, default=false)
transient_retries = env(AUTO_ADVANCE_TRANSIENT_RETRIES, default=3)
backoff_ceiling = env(AUTO_ADVANCE_BACKOFF_CEILING, default=60)

# Stuck detection (see "Stuck Detection" section below)
max_turns_per_task = env(AUTO_ADVANCE_MAX_TURNS_PER_TASK, default=10)
no_progress_threshold = env(AUTO_ADVANCE_NO_PROGRESS_THRESHOLD, default=1)
repeated_failure_threshold = env(AUTO_ADVANCE_REPEATED_FAILURE_THRESHOLD, default=3)
stuck_action = env(AUTO_ADVANCE_STUCK_ACTION, default="skip-task")
```

`max_retries` is passed to validate-implementation and used in pause messages for validation fix-and-retry attempts.

`max_revert_retries` controls the revert-and-retry loop (step 3a). This is distinct from `max_retries` (which controls validate-implementation's fix-and-retry within a single approach). When validation fails after `max_retries` fix attempts, the agent reverts changes and re-implements with an alternative approach, up to `max_revert_retries` times. Each attempt is logged as structured telemetry. Escalation to human occurs only after all revert-retry attempts are exhausted. In execute-tree, the equivalent parameter is `max_retries` on the dispatch pipeline — it controls re-dispatch with parameter changes, not revert-and-retry.

`use_subagents` enables subagent dispatch mode (see "Subagent Dispatch" section below). When `false`, the loop behaves identically to the original inline execution.

`transient_retries` and `backoff_ceiling` govern retry behavior for transient errors (rate limits, timeouts, 5xx). See `references/error-classification.md` for classification rules and `references/retry-with-backoff.md` for the backoff algorithm. These are independent of `max_retries`.

`max_turns_per_task` limits loop iterations per task (safety net). `no_progress_threshold` controls how many consecutive implementation steps with no file changes trigger escalation (default: 1, meaning a single empty diff escalates). `repeated_failure_threshold` sets how many identical errors within the validation retry loop trigger escalation (tracked inside validate-implementation.md). `stuck_action` determines whether to skip the task and continue (`skip-task`) or pause the loop (`pause-loop`). See "Stuck Detection" section below.

## Entry Guard

Before entering the loop, check preconditions via `TaskList`:

| Condition | Action |
|-----------|--------|
| No tasks exist | Output "No tasks to process." and stop |
| All tasks completed | Output completion summary (step 7) and stop |
| A task is already `in_progress` | Resume it (skip to step 2) |
| Pending unblocked tasks exist | Enter loop at step 1 |
| All pending tasks are blocked | Output pause message: "All remaining tasks are blocked by unresolved dependencies: <blockedBy list>" and stop |

If some tasks are already completed and others are pending, this is a session resume — proceed silently without re-processing completed tasks.

Initialize loop-level state:

```
skipped_tasks = {}  # set of task IDs skipped by stuck detection
```

## Loop Body

Repeat steps 1–6 until a termination condition is met.

### 1. Pick Next Task

```
TaskList → find first task where:
  - status == "pending"
  - blockedBy is empty (no unresolved dependencies)
  - taskId not in skipped_tasks (stuck detection skip list)

If no such task exists:
  - If blocked tasks remain → pause: "Remaining tasks are blocked: <details>"
  - If no tasks remain → go to step 7 (completion summary)
```

Select the task:

```
TaskGet(taskId) → read full description
TaskUpdate(taskId, status: "in_progress")
```

**Coordinator sync**: If coordinator env vars are set, mirror the status change:
```bash
coord_sync_status "$taskId" "in_progress"
```

Record the task subject for the completion summary.

Initialize stuck detection counters for this task:

```
turn_counter = 0
no_progress_count = 0
```

### 1b. Dispatch Decision (subagent mode only)

**Skip this step if `use_subagents` is `false`.** Proceed directly to step 2.

Evaluate whether the current task is suitable for subagent dispatch:

```
dispatch_mode = "subagent"  # default when feature flag is on

# Fall back to inline if:
if task description contains "clarify", "discuss", or "decide":
    dispatch_mode = "inline"
if task references files in multiple repos:
    dispatch_mode = "inline"
if task.blockedBy references a failed task:
    dispatch_mode = "inline"
```

| Dispatch Mode | Action |
|---------------|--------|
| `subagent` | Go to step 2a (Subagent Dispatch) |
| `inline` | Go to step 2 (Implement — existing inline path) |

### 2a. Subagent Dispatch

**This step replaces step 2 (Implement) when dispatch_mode is `subagent`.**

#### 2a.1 Assemble Context

1. **Read DESIGN.md**: Extract requirements and design decisions relevant to the task
2. **Read task ledger**: If the task has `blockedBy` entries, include the ledger entries for those dependencies
3. **Fill dispatch prompt** using the template:
   ```
   Read: skills/task-workflow/templates/subagent-task-prompt.md.tmpl
   ```
   Substitute variables per `references/subagent-dispatch.md` — Template Variables table.
   If no `blockedBy` dependencies, set `${TASK_LEDGER_ENTRIES_FOR_DEPENDENCIES}` to "This is the first task — no prior context."

#### 2a.2 Dispatch via Shared Operation

Load and execute the dispatch-task operation:

```
Read: skills/task-workflow/operations/dispatch-task.md
```

Provide inputs:
- `prompt`: The assembled prompt from step 2a.1
- `task_subject`: The task subject from TaskGet
- `max_retries`: 1

#### 2a.3 Handle Dispatch Result

| `dispatch_result.status` | Action |
|--------------------------|--------|
| `success` | Proceed to step 3 (Validate — parent re-validates) |
| `partial` | Proceed to step 3 (Validate — check if partial work passes) |
| `fallback` | Fall back to step 2 (Implement — inline execution) |

After step 2a, proceed to step 3 (Validate Implementation) — the parent re-validates to verify the subagent's work.

### 2. Implement

Read the task description and consult DESIGN.md for requirements, architecture, and design decisions.

**Implementation approach**:
1. Read relevant source files to understand current state
2. Implement the change following DESIGN.md requirements
3. Apply incremental commits principle — commit at logical boundaries within the task if the change is large enough to warrant it

**Ambiguity detection**: While implementing, if any of these conditions arise, stop the loop:
- The task description is too vague to determine what to build
- Multiple valid approaches exist and DESIGN.md doesn't disambiguate
- An external dependency or service is needed that isn't available

If ambiguity is detected, go to step 8 (pause with message).

### 2.5. No-Progress Check

After implementation (step 2 or 2a), check whether the agent produced meaningful file changes:

```bash
git diff --stat
```

| Result | Action |
|--------|--------|
| Non-empty diff (files changed) | Reset `no_progress_count = 0`. Proceed to step 3. |
| Empty diff (no changes) | Increment `no_progress_count += 1` |

If `no_progress_count >= no_progress_threshold`: trigger stuck escalation with reason "no-progress" (see "Stuck Detection" section).

**Note**: An empty diff after implementation means the agent completed the implement step without producing any file changes. This can happen when the agent is looping on research, re-reading files, or unable to determine what to change. With the default threshold of 1, a single empty diff triggers escalation. Increase the threshold if tasks legitimately require exploration before producing changes.

### 3. Validate Implementation

Load and execute the validate-implementation operation:

```
Read: skills/task-workflow/operations/validate-implementation.md
```

Execute the operation's steps: detect test runner → detect linter → run tests → run lint → retry on failure.

**Important**: The validate-implementation operation's retry loop (step 5 in that operation) asks the user for guidance when retries are exhausted. In auto-advance mode, **do not pause immediately** — instead enter the revert-and-retry loop (step 3a).

| Validation Result | Action |
|-------------------|--------|
| All checks pass | Proceed to step 4 |
| Checks fail, agent fixes within retries | Proceed to step 4 |
| Retries exhausted | Go to step 3a (revert-and-retry) |

### 3a. Revert-and-Retry Loop

When validation fails and the validate-implementation retry budget is exhausted, revert the failed changes and re-attempt with a different approach. This implements the design principle: "Failure is normal — rejection → parameter change + re-dispatch, not stop-and-ask."

```
revert_retry_attempts = []  # telemetry for this task's revert-retry cycle
revert_retry_count = 0
max_revert_retries = env(AUTO_ADVANCE_MAX_REVERT_RETRIES, default=3)
```

#### Loop:

```
while revert_retry_count < max_revert_retries:
  revert_retry_count += 1

  # 1. Record the failed attempt as telemetry
  attempt_record = {
    attempt_number: revert_retry_count,
    failure_reason: <validation error summary>,
    approach_used: <description of what was tried>,
    parameter_change: <what will change on next attempt>,
    timestamp: <ISO 8601>,
    files_modified: <from git diff --name-only>,
    validation_errors: <structured test/lint output>
  }
  revert_retry_attempts.append(attempt_record)

  # 2. Revert changes back to last good state (include untracked files)
  git stash --include-untracked

  # 3. Select alternative approach
  approach_hint = select_alternative_approach(revert_retry_attempts)

  # 4. Re-implement with alternative approach
  #    The approach hint is injected as additional context:
  #    "Previous approach failed: <failure_reason>. Try: <approach_hint>"
  implement_with_hint(task, approach_hint)

  # 5. Re-validate
  validation_result = validate_implementation()

  if validation_result.passed:
    # Success — proceed to step 4 (commit)
    break

# If loop exits without success:
if not validation_result.passed:
  escalate_with_revert_log(task, revert_retry_attempts)
```

**Alternative approach strategies** — applied in order across retry attempts:

| Attempt | Strategy | Description |
|---------|----------|-------------|
| 1 | Different algorithm | Change the implementation approach (e.g., iterative vs recursive, different data structure) |
| 2 | Simplified scope | Implement a minimal version that satisfies core acceptance criteria |
| 3 | Decomposed steps | Break the change into smaller incremental steps, validating between each |

```
function select_alternative_approach(attempts):
  n = len(attempts)
  last = attempts[-1]

  if n == 1:
    return "Previous approach failed: ${last.failure_reason}. Use a fundamentally different implementation strategy."
  elif n == 2:
    return "Two approaches have failed. Implement the simplest possible version that satisfies the core acceptance criteria. Defer edge cases."
  else:
    return "Multiple approaches have failed. Break the change into the smallest possible incremental step. Make one change, validate it works, then build on it."
```

#### Revert-Retry Telemetry

Each revert-retry attempt produces a structured telemetry record following the same schema as execute-tree's `failure_telemetry_record` (see execute-tree step 4), with `node_id` replaced by `task_id`:

```
revert_retry_telemetry_record:
  task_id: <task ID>
  attempt_number: <1-based>
  failure_reason: <validation error summary>
  parameter_change_applied: <alternative approach hint>
  outcome: "retry" | "success" | "escalated"
  timestamp: <ISO 8601>
```

**Coordinator sync** (if available):
```bash
coord_report_progress "retry" "Attempt ${attempt_number}/${max_revert_retries}: ${failure_reason}. Trying: ${parameter_change}."
```

#### Escalation After Revert-Retry Exhaustion

When max_revert_retries is exhausted, pause with the full failure log:

```
function escalate_with_revert_log(task, attempts):
  # Present structured failure history
  output:
    ## Auto-Advance Paused

    **Completed before pause**: <N> tasks
    <for each completed task>
      - <task subject> (<commit hash>)

    **Blocked on**: <current task subject>
    **Reason**: Validation failed after ${len(attempts)} revert-and-retry attempts

    | Attempt | Approach | Failure |
    |---------|----------|---------|
    <for each attempt in attempts>
    | ${attempt.attempt_number} | ${attempt.parameter_change} | ${attempt.failure_reason} |

    **Decision needed**: All automated retry strategies exhausted.
      Review the failure pattern above and provide guidance.
```

### 3.5. Repeated Failure Check

After validation (step 3), check the validation result for repeated-failure signals.

The validate-implementation operation tracks error repetition within its fix-and-retry loop (step 5b). When all retry attempts produce the same error summary, it reports `repeated_error: true` along with the `error_summary` and `attempt_count`.

```
if validation_result.repeated_error == true:
    trigger stuck escalation with reason "repeated-failure"
```

**If validation passed**: Proceed to step 4 (no check needed).

**If validation failed but errors were different across retries**: The agent was making progress (changing the error). Proceed to normal retry exhaustion handling (step 3 already handles this).

**Note**: This check is complementary to validation retry exhaustion. Retry exhaustion means "agent ran out of attempts." Repeated failure means "agent's fixes aren't changing the outcome" — a stronger signal that the task needs human help.

### 4. Commit

Use the git skill's commit operation to commit the implementation:

```
Read: skills/git/operations/commit.md
```

Execute the commit operation: resolve repo path → branch guard → review state → stage → craft message → commit → verify.

**On failure, classify the error** before deciding next steps. Load `references/error-classification.md` and match the git error output:

| Commit Result | Action |
|---------------|--------|
| Commit succeeds | Proceed to step 5 |
| Pre-commit hook fails | Attempt fix (1 retry), then go to step 8 (pause) if still failing |
| Transient git error (lock file, transport failure, ref lock) | Apply transient retry per `references/retry-with-backoff.md` using `transient_retries` and `backoff_ceiling`. If retries succeed, proceed to step 5. If exhausted, go to step 8 (pause) with retry history. |
| Permanent git error (merge conflict, not a repo) | Go to step 8 (pause) |

Record the commit hash for the completion summary.

### 5. Mark Task Complete

```
TaskUpdate(taskId, status: "completed")
```

**Coordinator sync**: If coordinator env vars are set, mirror the completion:
```bash
coord_sync_status "$taskId" "completed"
coord_report_progress "completed" "<task subject> — <commit hash>"
```

Add to running tallies:
- Increment `tasks_completed`
- Append task subject to `completed_tasks` list
- Append commit hash(es) to `commits` list

**Task ledger update (subagent mode only)**: Append a ledger entry for this task:

```markdown
### Task <N>: <subject>
- **Status**: completed
- **Dispatch**: subagent | inline | inline (fallback)
- **Files modified**: <from subagent result or git diff --name-only>
- **Changes**: <from subagent changes_summary or brief inline summary>
- **Test result**: <from validation step>
- **Commit**: <short hash>
```

The ledger is maintained in conversation context (not a file) and consulted when dispatching dependent tasks in step 2a.

### 5a. Acceptance Criteria Check-Off

After marking the task complete, update the AC contract in the workspace DESIGN.md.

The completed task's description carries a `Satisfies: AC-N[, AC-M]` line (written by init-workspace decomposition). For each AC it names:

1. **Gather the AC's task set**: via `TaskList` + `TaskGet`, find all tasks whose descriptions name this AC in their Satisfies line.
2. **All completed?** If any tracing task is still pending/in-progress, the AC stays open — skip it.
3. **Re-verify the criterion**: task completion is necessary but not sufficient. Confirm the criterion itself holds with concrete evidence — a passing test name, a command and its output, or direct file inspection. Do not check off on the strength of "its tasks are done" alone.
4. **Flip the checkbox** in DESIGN.md: `- [ ] **AC-N**:` → `- [x] **AC-N**:` (Edit tool, surgical).
5. **Record the evidence** in the running tallies (`ac_evidence` map: AC-ID → one-line evidence summary) for the completion summary. Evidence lives in the summary, not inline in DESIGN.md.

If re-verification fails — all tracing tasks completed but the criterion does not hold — the decomposition missed something. Create a new task to close the gap (with the same `Satisfies: AC-N` line) and leave the box unchecked.

Tasks with no Satisfies line (e.g., standard doc/demo tasks without matching ACs) skip this step.

The workspace DESIGN.md lives in the workspace root (outside the repo worktrees), so the checkbox edit is durable on disk immediately — no commit involved. The checkbox state is the session-resumable progress record that step 7a's completion gate reads.

### 6. Check for More Tasks

Increment turn counter:

```
turn_counter += 1
```

**Turn budget check**: If `turn_counter >= max_turns_per_task`, trigger stuck escalation with reason "budget" (see "Stuck Detection" section). This check runs before selecting the next task to prevent runaway iterations on a single task.

```
TaskList → check for remaining pending unblocked tasks
```

| Condition | Action |
|-----------|--------|
| Turn budget exceeded | Trigger stuck escalation (reason: budget) |
| More unblocked pending tasks | Go to step 1 |
| Only blocked tasks remain | Go to step 7 with note about blocked tasks |
| No tasks remain | Go to step 7 |

## Termination

### 7. Completion and PR Creation

Output when the loop ends normally (all tasks done or only blocked tasks remain).

**7a. All tasks complete — create PR**:

When all tasks are complete (no blocked tasks remaining):

0. **Acceptance Criteria gate** — never open a PR over an open AC:
   ```bash
   grep -c '^- \[ \] \*\*AC-' DESIGN.md   # workspace DESIGN.md; must return 0
   ```
   Deferred criteria (`_(deferred: <reason>)_` annotation from init-workspace decomposition) count as open only if still unchecked **and** undeferred.

   | Result | Action |
   |--------|--------|
   | 0 unchecked ACs | Proceed to sub-step 1 |
   | Unchecked AC with an incomplete or missing covering task | Create a covering task (`Satisfies: AC-N`) and return to the loop (step 1) |
   | Unchecked AC whose tasks all completed but re-verification failed (step 5a already spawned a gap task) | Return to the loop (step 1) |
   | Unchecked AC that cannot be covered by automatable work | Go to step 8 (pause): "AC-N cannot be satisfied autonomously: <reason>" |

1. **Commit remaining changes**: Check for uncommitted changes:
   ```bash
   git status --porcelain
   ```
   If changes exist, invoke git skill commit operation (`skills/git/operations/commit.md`).

2. **Check for existing PR**:
   ```bash
   gh pr view --json url,state 2>/dev/null
   ```
   If a PR already exists for the current branch, record the URL and skip to sub-step 4.

   **On `gh` failure**: Classify the error via `references/error-classification.md`. If transient (429, 5xx, timeout), apply transient retry per `references/retry-with-backoff.md`. If retries exhausted or permanent error, treat as "no existing PR" and proceed to sub-step 3.

3. **Create PR**: Invoke `/gh-pr-create`. This reads CLAUDE.md for the issue reference and generates `Closes #N` in the PR body automatically. PR title follows conventional commit format.

   **AC checklist in PR body**: Include the workspace DESIGN.md `## Acceptance Criteria` section verbatim (checked boxes and deferral annotations intact) as an `## Acceptance Criteria` section of the PR body, so the reviewer reviews against the same contract the session was driven by.

   **On failure**: Classify the error via `references/error-classification.md`.
   - If transient (429, 5xx, timeout): apply transient retry per `references/retry-with-backoff.md`. If retries succeed, proceed to sub-step 4.
   - If retries exhausted or permanent error: print manual instructions and continue to summary:
   ```
   PR creation failed. You can create one manually:
     gh pr create --title "<title>" --body "<body>"
   ```

4. **Wait for CI checks with auto-fix**: If a PR was created or found, invoke the CI feedback loop skill:

   ```
   Load: skills/ci-feedback-loop/SKILL.md
   ```

   Execute the skill's end-to-end flow with inputs:
   - `pr_number`: extracted from PR URL
   - `repo`: current repository
   - Configuration: `max_retries=3`, `poll_interval=30`, `max_wait=1800`

   The skill polls checks, retrieves failure logs, attempts fixes, and escalates if unable to resolve.

   | CI Feedback Result | Action |
   |--------------------|--------|
   | Success (all checks pass, possibly after fixes) | Record "CI: passed" and proceed to sub-step 5 |
   | No checks configured (empty check list after timeout) | Record "CI: no checks configured" and proceed to sub-step 5 |
   | Escalated (posted PR comment) | Go to step 8 (pause) with escalation details |
   | PR creation failed (no PR to check) | Skip CI check, proceed to sub-step 5 |
   | `gh` transient error (429, 5xx, timeout) | Apply transient retry per `references/retry-with-backoff.md`. If exhausted, skip CI check and proceed to sub-step 5 with "CI: check unavailable (transient error)". |

   On escalation, output a pause message (step 8 pattern):
   ```
   ## Auto-Advance Paused

   **Completed before pause**: <N> tasks
   <for each completed task>
     - <task subject> (<commit hash>)

   **PR**: <PR URL>
   **Reason**: CI feedback loop escalated: <escalation reason>
   **Fix attempts**: <N attempts made, summary of each>

   **Decision needed**: Review CI failures and escalation comment on the PR.
     PR: <PR URL>
   ```

5. **Output completion summary with PR**:
   ```
   ## Auto-Advance Complete

   **Tasks completed**: <N>
   <for each completed task>
     - <task subject> (<commit hash>)

   **Acceptance criteria**: <N>/<N> checked
   <for each AC, from the ac_evidence map (step 5a)>
     - [x] AC-N — evidence: <one-line evidence summary>
   <for each deferred AC>
     - [ ] AC-N — deferred: <reason>

   **Commits**: <N total>
   **PR**: <PR URL> | creation failed (see manual instructions above)
   **CI**: passed | no checks configured | skipped (no PR)
   **Termination**: All tasks complete
   ```

6. **Invoke /finish (conditional)**:

   Check the workspace CLAUDE.md for an `## Auto-Advance` section:
   ```
   Grep: pattern="^## Auto-Advance" path="CLAUDE.md" output_mode="count"
   ```

   | Condition | Action |
   |-----------|--------|
   | `## Auto-Advance` section found | Invoke `/finish` — this handles knowledge capture, metrics, and close. Commit and PR steps in `/finish` are idempotent and will find the already-created PR. |
   | `## Auto-Advance` section not found | Stop — the completion summary is the final output. The user invokes `/finish` manually. |

**7b. Blocked tasks remain — no PR**:

When blocked tasks prevent full completion, output summary without PR creation:

```
## Auto-Advance Complete

**Tasks completed**: <N>
<for each completed task>
  - <task subject> (<commit hash>)

**Commits**: <N total>
**Termination**: Blocked tasks remain

**Blocked tasks**:
  - <task subject> (blocked by: <blockedBy list>)

All changes are committed. No PR created — resolve blocked tasks first.
```

### 8. Pause Message

Output when the loop stops due to a problem:

```
## Auto-Advance Paused

**Completed before pause**: <N> tasks
<for each completed task>
  - <task subject> (<commit hash>)

**Blocked on**: <current task subject>
**Reason**: <one of:>
  - Validation failed: <test/lint> still failing after <max_retries> retries. <failure summary>
  - Transient error exhausted: <error type> after <transient_retries> retries (<total backoff>s total backoff). <last error>
  - Ambiguous decision: <description of what's unclear>
  - Commit failed: <git error message>
  - Stuck detected (budget): Task exceeded turn budget (<turn_counter>/<max_turns_per_task> turns)
  - Stuck detected (no-progress): <no_progress_count> consecutive iterations with no file changes (threshold: <no_progress_threshold>)
  - Stuck detected (repeated-failure): Same error appeared <repeated_failure_count> times in sequence (threshold: <repeated_failure_threshold>). Error: <last_error_summary>

**Decision needed**: <what the human should do>
  <contextual guidance based on the reason — see references/retry-with-backoff.md Escalation Guidance table>
```

When the pause is caused by transient retry exhaustion, include the retry history from `references/retry-with-backoff.md`:

```
**Retry history**:
  - Attempt 1: <error summary> (backoff: <N>s)
  - Attempt 2: <error summary> (backoff: <N>s)
  - Attempt 3: <error summary> (backoff: <N>s)
  Total backoff: <sum>s
```

## Error Handling

| Error | Response |
|-------|----------|
| TaskList unavailable | Stop, report tool error |
| DESIGN.md missing | Stop, report "DESIGN.md not found — cannot implement without requirements" |
| Operation file not found | Stop, report missing file — this is a setup error |
| Agent context approaching limit | Output step 7 summary (completed count and task subjects), omit detailed commit history |
| CI feedback loop escalates | Go to step 8 (pause) with escalation details and PR URL |
| CI feedback loop skill unavailable | Fall back to `gh pr checks --watch --fail-fast`; pause on failure |
| Transient error (any step) | Classify via `references/error-classification.md`, retry via `references/retry-with-backoff.md` with `transient_retries` budget. If exhausted, go to step 8 (pause) with retry history. |
| Uncertain error (any step) | Treat as transient with reduced budget per `references/error-classification.md` uncertain rules. |
| Stuck detected | Execute stuck escalation flow (see below) |

## Stuck Detection

When any stuck detector fires (steps 2.5, 3.5, or 6), execute this escalation flow:

### Triggers

| Detector | Step | Condition | Config |
|----------|------|-----------|--------|
| No-progress | 2.5 | `no_progress_count >= no_progress_threshold` | `AUTO_ADVANCE_NO_PROGRESS_THRESHOLD` (default: 1) |
| Repeated failure | 3.5 | `validation_result.repeated_error == true` | `AUTO_ADVANCE_REPEATED_FAILURE_THRESHOLD` (default: 3) — tracked within validation retry loop |
| Turn budget | 6 | `turn_counter >= max_turns_per_task` | `AUTO_ADVANCE_MAX_TURNS_PER_TASK` (default: 10) |

### Escalation Flow

When triggered:

1. **Build diagnostics**:
   ```
   stuck_reason = {
     detector: "no-progress" | "repeated-failure" | "budget",
     counter: <the counter that exceeded the threshold>,
     threshold: <the configured threshold>,
     last_error: <validation_result.error_summary if available>,
     turns_used: <turn_counter>
   }
   ```

2. **Mark task for skip**:
   ```
   TaskUpdate(taskId, status: "pending")
   ```
   Reset the task from `in_progress` back to `pending`. Add the task ID to a `skipped_tasks` set so step 1 skips it on the next iteration.

3. **Log to output**:
   ```
   ── Stuck detected ──────────────────────
   Task: <task subject>
   Detector: <detector name>
   Detail: <counter>/<threshold> (<description>)
   Action: <stuck_action>
   ────────────────────────────────────────
   ```

4. **Execute action** based on `stuck_action`:

   | `stuck_action` | Behavior |
   |----------------|----------|
   | `skip-task` | Add task to `skipped_tasks`. Go to step 6 (check for more tasks). The skipped task will not be picked up again in this session. |
   | `pause-loop` | Go to step 8 (pause) with stuck-detected reason. |

### Skipped Tasks in Completion Summary

When the loop completes (step 7), include skipped tasks in the output:

```
**Skipped (stuck)**: <N>
<for each skipped task>
  - <task subject> (detector: <detector>, detail: <counter>/<threshold>)
```

This section appears after the completed tasks list and before the PR creation step.

### Interaction with Existing Mechanisms

- **Validation retries** (`max_retries`): Run first. Repeated failure detection (step 3.5) evaluates the error *after* validation retries are exhausted or between retry attempts. If retries fix the error, repeated failure count resets.
- **Transient error retries**: Independent. Stuck detection tracks loop-level patterns, not transient retry attempts within a single step.
- **Subagent dispatch**: Dispatch has its own retry limit. If the subagent fails and falls back to inline, the parent's stuck counters continue from where they were — the fallback counts as continued iteration on the same task.
- **Resume**: On session resume, if a task was previously skipped due to stuck detection, it remains in `pending` state but the `skipped_tasks` set is empty (not persisted). The task can be retried in a new session. To permanently block it, the human should mark it manually.

## Example

### 3-task workspace with clean run

```
[Auto-advance starting: 3 pending tasks]

─── Task 1/3 ───────────────────────────
Starting: Create auto-advance operation

  [reads DESIGN.md, implements operation file]

Validating...
  Tests: passed (pytest)
  Lint: passed (pre-commit)

Committing...
  abc1234 feat: add auto-advance operation for task loop

Task complete ✓

─── Task 2/3 ───────────────────────────
Starting: Integrate into work session flow

  [reads init-workspace.md, modifies it]

Validating...
  Tests: passed (pytest)
  Lint: failed (pre-commit)
  Fixing... (1/2)
  Lint: passed (pre-commit)

Committing...
  def5678 feat: trigger auto-advance from init-workspace

Task complete ✓

─── Task 3/3 ───────────────────────────
Starting: Update SKILL.md and permissions

  [reads SKILL.md, updates sections]

Validating...
  Tests: passed (pytest)
  Lint: passed (pre-commit)

Committing...
  ghi9012 feat: register auto-advance in SKILL.md

Task complete ✓
  AC-3 checked off (evidence: SKILL.md registers operation; grep confirms)

AC gate: 0 unchecked criteria ✓
Committing remaining changes... (none)
Checking for existing PR... (none found)
Creating PR via /gh-pr-create... (AC checklist included in body)
  ✓  https://github.com/pfeff/cursor-rules/pull/18
Waiting for CI checks...
  CI: no checks configured

## Auto-Advance Complete

**Tasks completed**: 3
  - Create auto-advance operation (abc1234)
  - Integrate into work session flow (def5678)
  - Update SKILL.md and permissions (ghi9012)

**Acceptance criteria**: 3/3 checked
  - [x] AC-1 — evidence: operation file exists and loads
  - [x] AC-2 — evidence: init-workspace step 13 triggers the loop
  - [x] AC-3 — evidence: SKILL.md registers operation; grep confirms

**Commits**: 3 total
**PR**: https://github.com/pfeff/cursor-rules/pull/18
**CI**: no checks configured
**Termination**: All tasks complete

Checking CLAUDE.md for ## Auto-Advance section... found
Invoking /finish...
  [/finish runs: task check, checkbox reconciliation, commit (no changes),
   PR (exists), knowledge capture, metrics, close instructions]
```

### Pause on validation failure

```
[Auto-advance starting: 4 pending tasks]

─── Task 1/4 ───────────────────────────
Starting: Implement webhook handler
  [implements handler]

Validating...
  Tests: FAILED
  Fixing... (1/2) → still failing
  Fixing... (2/2) → still failing

## Auto-Advance Paused

**Completed before pause**: 0 tasks

**Blocked on**: Implement webhook handler
**Reason**: Validation failed: tests still failing after 2 retries (default max_retries=2).
  TestWebhookAuth: expected 200, got 401 — auth middleware rejects valid tokens

**Decision needed**: Fix the test failure manually, then resume the session.
  The test expects auth middleware to accept the webhook token, but the
  middleware may need configuration for webhook-specific auth.
```

### Transient error with successful retry

```
─── Task 2/4 ───────────────────────────
Starting: Push changes and create PR

Committing...
  $ git push origin feature-branch
  fatal: The remote end hung up unexpectedly

  Classifying error... transient (git transport failure)
  Transient error (attempt 1/3): git transport failure. Backing off 2s...
  $ sleep 2
  $ git push origin feature-branch
  → success

  Retry succeeded on attempt 1

  abc1234 feat: implement webhook handler

Task complete ✓
```

### Transient error with retry exhaustion

```
─── Task 3/4 ───────────────────────────
Starting: Create pull request

Creating PR via /gh-pr-create...
  HTTP 429: API rate limit exceeded

  Classifying error... transient (API rate limit)
  Transient error (attempt 1/3): API rate limit. Backing off 3s...
  $ sleep 3
  HTTP 429: API rate limit exceeded
  Transient error (attempt 2/3): API rate limit. Backing off 5s...
  $ sleep 5
  HTTP 429: API rate limit exceeded
  Transient error (attempt 3/3): API rate limit. Backing off 10s...
  $ sleep 10
  HTTP 429: API rate limit exceeded

## Auto-Advance Paused

**Completed before pause**: 2 tasks
  - Implement webhook handler (abc1234)
  - Add webhook tests (def5678)

**Blocked on**: Create pull request
**Reason**: Transient error exhausted: API rate limit after 3 retries (18s total backoff).
  HTTP 429: API rate limit exceeded

**Retry history**:
  - Attempt 1: API rate limit (backoff: 3s)
  - Attempt 2: API rate limit (backoff: 5s)
  - Attempt 3: API rate limit (backoff: 10s)
  Total backoff: 18s

**Decision needed**: Check API rate limit status. Wait for rate limit window to reset, then resume.
```

### Subagent dispatch with fallback

```
[Auto-advance starting: 3 pending tasks (subagent mode)]

─── Task 1/3 (subagent) ────────────────
Starting: Add retry configuration to .envrc template

  Dispatching to subagent...
  Subagent returned: status=success, 2 files modified

Validating (parent re-check)...
  Tests: passed (pytest)
  Lint: passed (pre-commit)

Committing...
  abc1234 feat(CR-SKILL-02): add retry config to .envrc template

Task complete ✓
Ledger updated: Task 1

─── Task 2/3 (subagent → fallback) ─────
Starting: Implement resume operation

  Dispatching to subagent...
  Subagent returned: status=failure
    issues: "Could not determine correct state machine transitions"
  Re-dispatching with failure context...
  Subagent returned: status=failure
    issues: "Same issue — need clarification on pause vs blocked states"

  Falling back to inline execution...
  [reads DESIGN.md, implements resume operation inline]

Validating...
  Tests: passed (pytest)

Committing...
  def5678 feat(CR-SKILL-02): implement resume operation

Task complete ✓
Ledger updated: Task 2 (dispatch: inline fallback)

─── Task 3/3 (subagent) ────────────────
Starting: Register operations in SKILL.md

  Dispatching to subagent...
  (Prior task context: Task 1 + Task 2 ledger entries included)
  Subagent returned: status=success, 1 file modified

Validating (parent re-check)...
  Lint: passed (pre-commit)

Committing...
  ghi9012 feat(CR-SKILL-02): register new operations in SKILL.md

Task complete ✓

## Auto-Advance Complete

**Tasks completed**: 3
  - Add retry configuration to .envrc template (abc1234) [subagent]
  - Implement resume operation (def5678) [inline fallback]
  - Register operations in SKILL.md (ghi9012) [subagent]

**Dispatch summary**: 2 subagent, 1 inline fallback
**Commits**: 3 total
**PR**: https://github.com/pfeff/cursor-rules/pull/19
**CI**: no checks configured
**Termination**: All tasks complete

Checking CLAUDE.md for ## Auto-Advance section... found
Invoking /finish...
  [/finish runs: task check, checkbox reconciliation, commit (no changes),
   PR (exists), knowledge capture, metrics, close instructions]
```

### Stuck detection with skip-task

```
[Auto-advance starting: 4 pending tasks]

─── Task 1/4 ───────────────────────────
Starting: Implement auth middleware

  [reads DESIGN.md, implements middleware]

No-progress check: changes detected ✓

Validating...
  Tests: FAILED — TestAuthMiddleware: expected 200, got 401
  Fixing... (1/2)
  Tests: FAILED — TestAuthMiddleware: expected 200, got 401
  Fixing... (2/2)
  Tests: FAILED — TestAuthMiddleware: expected 200, got 401

Repeated failure check: same error 3/3 times

── Stuck detected ──────────────────────
Task: Implement auth middleware
Detector: repeated-failure
Detail: 3/3 (same error: TestAuthMiddleware: expected 200, got 401)
Action: skip-task
────────────────────────────────────────

─── Task 2/4 ───────────────────────────
Starting: Add rate limiting to API

  [reads DESIGN.md, implements rate limiting]

No-progress check: changes detected ✓

Validating...
  Tests: passed (pytest)
  Lint: passed (pre-commit)

Committing...
  abc1234 feat: add rate limiting to API

Task complete ✓

[... tasks 3-4 complete normally ...]

## Auto-Advance Complete

**Tasks completed**: 3
  - Add rate limiting to API (abc1234)
  - Update API documentation (def5678)
  - Register routes in app config (ghi9012)

**Skipped (stuck)**: 1
  - Implement auth middleware (detector: repeated-failure, detail: 3/3)

**Commits**: 3 total
**PR**: https://github.com/pfeff/cursor-rules/pull/20
**CI**: passed
**Termination**: All completable tasks done (1 skipped)
```

## Integration Points

- **Predecessor**: `/init-workspace` (creates task list) or session resume (tasks already exist)
- **Successor**: `/finish` (knowledge capture, metrics, close) — auto-invoked in step 7a sub-step 6 when workspace CLAUDE.md contains `## Auto-Advance` section; otherwise invoked manually by user
- **PR creation**: `commands/gh-pr-create.md` — invoked in step 7a when all tasks complete
- **validate-implementation**: `operations/validate-implementation.md` — test + lint with retries
- **Git commit**: `skills/git/operations/commit.md` — atomic commits per task
- **Task tools**: `TaskList`, `TaskGet`, `TaskUpdate` — native Claude task management
- **Coordinator API** (optional): `COORDINATOR_URL`/`COORDINATOR_TOKEN`/`COORDINATOR_TASK_ID` — mirrors task status to coordinator when set
- **Task tool (subagent dispatch)**: `Task(subagent_type: general-purpose)` — spawns isolated subagent for task implementation (step 2a)
- **CI feedback loop**: `skills/ci-feedback-loop/SKILL.md` — monitors PR checks, auto-fixes failures, escalates when unable to resolve (step 7a sub-step 4)
- **DESIGN.md**: Consulted during implementation for requirements and architecture; dispatch prompt template defined in DESIGN.md
- **Reference pattern**: `skills/review/operations/run-review.md` step 5 — parallel subagent dispatch pattern
- **Error classification**: `references/error-classification.md` — transient vs permanent error taxonomy
- **Retry with backoff**: `references/retry-with-backoff.md` — exponential backoff algorithm and escalation format
