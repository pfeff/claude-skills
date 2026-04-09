# Next Cycle Operation

Lightweight OODA iteration for open-ended projects. Observes what changed, orients to the mission, proposes next moves, and dispatches.

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `project_dir` | No | Project directory (default: current working directory) |

## Purpose

Restarts the OODA loop after a batch of work completes. Unlike `/project:resume` (which recovers from session interruption), this is an in-session continuation — the agent already has context and just needs to cycle.

Use when:
- A dispatch round completed and no ready nodes remain
- The operator says "next", "continue", or "keep going"
- The tree is empty after harvesting completed work

Do NOT use when:
- Ready nodes exist (just run execute-tree directly)
- The project is finished (use `/project:finish`)

## Execution Steps

### 1. Quick Observe

Query the tree and summarize what changed since last cycle:

```bash
coord tree show $TREE_ID
```

Present a 2-3 line summary:
- Nodes completed this cycle
- Nodes remaining (pending, blocked)
- Any new gaps or opportunities surfaced by completed work

Do NOT re-read all repos or run full agent surveys. This is a delta observation, not a full scan. Only reach out to repos or external state if completed work revealed something that needs verification.

#### Content Flow: SCAN Checkpoint

Check the content pipeline alongside tree state:

1. **Pipeline state**: Identify content-tagged nodes in the tree (nodes with `content:` prefix or content tag). Report their current stage (pending, in-progress, completed, shipped). If a content project is already active, note it and skip to Orient — do not re-SCAN for new signals.

2. **Demand signal scan** (only when no content project is active and capacity is available): Review demand signals from target companies — job postings, engineering blogs, OSS activity, conference talks. Sources: `career-targets.md` in guardian, target company public activity. This is a manual checklist, not automated.

3. **Signal inventory**: Note any new or existing unmatched signals. Signals persist until manually pruned — there is no auto-drop threshold.

### 1b. Review Prior Lessons

Before scoping new work, check for lessons from previous iterations:

```bash
ls ${PROJECT_DIR}/memory/lessons_*.md 2>/dev/null
```

If lesson files exist, scan them for patterns relevant to the upcoming cycle:
- **Process improvements** to apply this iteration
- **Assumptions that proved wrong** and should not be repeated
- **Patterns that worked** and should be reused

Summarize in 1-2 sentences any lessons that should influence the next batch of work. If no lessons exist or none are relevant, continue without comment.

### 2. Orient

In 2-3 sentences, connect the current state to the mission:
- What capability did we just gain?
- What's the highest-leverage next move?
- Is anything drifting from the mission?

If a completed node's result changes the strategic picture (new gap, invalidated assumption, unlocked opportunity), flag it. Otherwise, keep moving.

#### Content Flow: MATCH Checkpoint

If the SCAN checkpoint surfaced unmatched demand signals:

1. **Match signals against artifacts**: Compare each signal against the artifact registry (cursor-rules skills, guardian docs, agent-coordinator, agent-orchestrator, ai-agents-book, career intelligence). A match requires a real, shipped artifact that speaks to the signal — no speculative content.

2. **Evaluate content worthiness**: Does a matched signal warrant a content node? Consider: is there a real audience asking this question? Does the artifact demonstrate genuine capability?

3. **WIP limit gate**: Check if a content project is already active (WIP limit: 1 active content project at a time). If at capacity, note the matched signal for next cycle — do not create a new content node.

4. **Prioritize alongside system nodes**: Content nodes compete on the same tree as system nodes. They don't get special priority or deferral — evaluate on leverage like any other work.

### 2a. Cycle Metrics

Before the qualitative retrospective, surface quantitative data from `finish.jsonl` to ground the review in measured outcomes.

**Determine cycle date range**: Use the most recent `lessons_cycle_*.md` file timestamp as the cycle start. If no lesson files exist, default to the last 7 days. The cycle end is now.

```bash
# Find cycle start from most recent lesson file, or default to 7 days ago
METRICS_FILE=~/src/work/.metrics/finish.jsonl
CYCLE_START=$(stat -f '%Sm' -t '%Y-%m-%dT%H:%M:%SZ' \
  "$(ls -t ${PROJECT_DIR}/memory/lessons_cycle_*.md 2>/dev/null | head -1)" 2>/dev/null \
  || date -u -v-7d '+%Y-%m-%dT%H:%M:%SZ')
```

**Determine epic**: Extract from the project CLAUDE.md or workspace path segment (e.g., `guardian`, `mission`).

**Query metrics**:

```bash
if [[ -f "$METRICS_FILE" ]]; then
  jq -r --arg epic "$EPIC" --arg since "$CYCLE_START" '
    select(.epic == $epic and .finished_at >= $since)
  ' "$METRICS_FILE" | jq -s '
    if length == 0 then "No metrics found for this cycle."
    else
      "Tasks: \(length)",
      "Elapsed hours: \(map(.elapsed_hours) | add | . * 10 | round / 10)",
      "Avg hours/task: \(map(.elapsed_hours) | add / length | . * 10 | round / 10)",
      "Review rounds: \(map(.review_rounds) | add) total (\(map(.review_rounds) | add / length | . * 10 | round / 10) avg)"
    end
  '
else
  echo "No finish.jsonl found — metrics collection not yet active."
fi
```

Present the output as a "Cycle Metrics" block before the retrospective. If the file is missing or no entries match, state that clearly and continue — metrics are informational, not blocking.

### 2b. End-of-Cycle Retrospective

Before proposing new work, run a brief retrospective on the just-completed cycle:

1. **What advanced the mission?** Identify which completed nodes moved the needle and why.
2. **What was friction?** Note process issues, tooling gaps, or spec ambiguities that slowed work.
3. **What should change?** One concrete adjustment for the next cycle (not a laundry list).

If any finding is worth preserving beyond this session, save it as a lesson:

```
Write: ${PROJECT_DIR}/memory/lessons_cycle_<N>.md
---
name: lessons-cycle-<N>
description: Retrospective from cycle <N>
type: project
---

<finding>

**Why:** <root cause>
**How to apply:** <when to use this insight>
```

Keep this lightweight — 2-3 minutes max. The goal is a short feedback loop, not a ceremony.

### 3. Propose

Steps 1-2 are strategic phases — **phase gates** apply. Text only, no tool calls.

Step 3 is tier-aware — the phase gate lifts for Tier 1/2 actions:

Either:
- **New nodes**: If the observation surfaced opportunities, propose them as tree additions. Classify each proposed node by autonomy tier (see `dispatch-decision.md`):
  - **Tier 1/2**: Auto-add to tree (`coord node create`) and proceed to step 4 without confirmation.
  - **Tier 3**: Present to operator and wait for confirmation before adding.
  - **Mixed**: Add Tier 1/2 immediately, hold Tier 3 for confirmation. Do not hold Tier 1/2 waiting for Tier 3 resolution.
- **Existing nodes**: If pending nodes are ready, classify by autonomy tier:
  - **Tier 1/2**: Proceed directly to step 4 (dispatch) without confirmation.
  - **Tier 3**: Ask one focused question before dispatching.
  - **Mixed**: Dispatch Tier 1/2 immediately, hold Tier 3 for confirmation.
- **No actionable nodes**: If the next move is entirely ambiguous or strategic (all Tier 3), ask one focused question and wait for operator input.

#### Content Flow: Dispatch Content Nodes

If the MATCH checkpoint produced a matched signal that warrants a content node and WIP capacity is available:

1. **Propose content node**: Include in the proposal alongside system nodes. Content nodes are regular goal tree nodes — use the same proposal format. Include the demand signal source in the node description for traceability.

2. **Drop stale signals**: During proposal, review unmatched signals. If any are no longer relevant (operator judgment), note them for pruning. Signals are only dropped by explicit operator decision, never automatically.

3. **Standard dispatch**: Content nodes dispatch via the same workspace mechanism as system nodes — no special handling.

### 4. Dispatch

If there are ready nodes (new or existing), enter the execute-tree loop:

```
Read: operations/execute-tree.md
execute_tree(tree_id, project_dir, project_branch)
```

If no nodes are ready and the conversation produced no new work, say so and wait for operator input.

#### Content Flow: SHIP Awareness

When a content node completes (merged PR containing content):

1. **Publish**: The content goes from merged PR to published via the SHIP pipeline — merge to pfeff.github.io (GitHub Pages). If the site repo doesn't exist yet, the first content node's implementation includes site setup.

2. **Update traceability**: Link the demand signal → artifact → published content in guardian docs. Update GOAL.md if the content project was a tree node.

3. **Release WIP capacity**: Mark the content project complete, freeing capacity for the next content cycle. The next Observe phase can SCAN for new signals.

## Auto-Continue

The execute-tree loop should invoke this operation automatically when:
- All ready nodes are exhausted (no more pending nodes with met dependencies)
- The project is open-ended (not all nodes completed = project complete)

This creates the self-sustaining cycle: execute-tree → nodes exhausted → next-cycle → observe → orient → propose → execute-tree → ...

## Example

```
── Cycle 2 ──────────────────────────────────────

Completed: B (land stale PRs), C (close workspace)
Remaining: D (tree update endpoint) — pending, E (KPIs) — pending
No blocked nodes.

We just cleared process debt — stale PRs landed, workspace closed.
Highest leverage now: E (KPIs) gives us a measurement framework
before taking on more feature work. D is a small AC enhancement
that unblocks tree lifecycle management.

Both are independent. Dispatching D as subagent, E inline (needs
conversation).

── Dispatch Round ───────────────────────────────
```

## Integration Points

- **Called by**: execute-tree (on ready-set exhaustion in open-ended mode), `/project:next` command, operator saying "next"/"continue"
- **Calls**: `coord tree show`, execute-tree
- **References**: status.md (for full observation when delta is insufficient), orient.md (for deep strategic alignment when drift detected)
