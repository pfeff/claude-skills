# Supervision Discipline Reference

Rules every supervisor follows, regardless of layer. A supervisor is any session whose job is to dispatch, monitor, evaluate, and merge subordinate work — L1 over L0, L2 over L1, or an ad-hoc supervisor session managing a child workspace.

Throughout this file:
- **You** = the supervisor reading this.
- **Children** = the sessions you supervise (one layer below).
- **Operator** = the human or higher-layer supervisor that dispatched you.

The rules are the same at every layer; only the identities shift.

## Why This Exists

Supervision loops are uniquely vulnerable to idle burn. Each tick re-injects the system prompt and replays the entire session context. Cached or not, that context grows linearly with session length, so a long-idle loop on Opus can burn $700+/day in cache reads alone before producing a single useful action. A runaway supervisor cannot self-correct — its peer or its parent has to catch it.

Treat ticks as expensive. Self-stop is cheaper than self-continue. Killing a runaway child is cheaper than letting it spin.

## Tick Hygiene — Self-Terminate When Done

**At the start of every tick, ask in order:**

1. **Is the original goal already met?** Subtree complete per source-of-truth, originating PR merged, no operator follow-on assigned → self-terminate. You do not stay running "just in case."
2. **Is there a child to supervise?** No dispatched child + no PR awaiting review + no ready leaf in your scope → idle. Idle means stop, not poll.
3. **Has anything changed?** The last N ticks all returned no actionable signal (no permission prompt approved/rejected, no state-of-truth change, no PR review, no operator input) → self-terminate and ping operator. Default N = 10.

Self-terminate = call `CronDelete` on your own job, confirm with `CronList` that no supervisor cron remains, report to the operator with the cancelled job ID, and stop.

## Cron Hygiene

- **Run `CronList` before any `CronCreate`.** If a supervisor cron already exists, replace it — never stack.
- **One scheduler, never two.** `/loop` and `CronCreate` both fire ticks. Pick one. Stacking doubles tick rate and cost.
- **`CronDelete` is part of "done".** Completing the goal without deleting your cron leaves a leak that ticks until the Claude session exits.

## Polling Discipline

- 5+ consecutive empty polls of the same tmux target → switch to your source of truth (e.g., `ac_node_query`); tmux is reporting noise.
- 10+ same-command, same-empty-result polls in a session → you are spinning; self-terminate.
- A `tmux capture-pane | grep "Do you want"` is a *liveness probe*, not work. Probes alone do not justify another tick.

## Detect Runaway Children

The same idle-burn pathology can hit any loop you supervise. A child that has finished its goal, or a child that has fallen into a polling spiral, will keep burning tokens until something kills it. **You are that something.** Apply the checks above against each active child — not just yourself — every tick.

For each child you supervise, look for:

1. **Goal-vs-state mismatch.** Child's spec is satisfied (state-of-truth says `done`, PR merged, deliverable on disk) but its session is still running → leak. `done` + live pane = kill.
2. **Pane stagnation.** Capture the child's tmux pane twice, separated by ≥30s. Byte-identical output → child is idle. Cross-check the source of truth: if it also shows no recent activity, kill.
3. **Repeated probes.** Child's recent shell history is dominated by a single repeated bash invocation (esp. `tmux capture-pane | grep ...`) → child is spinning. Kill.
4. **Stacked schedulers.** Child has both `/loop` and a cron firing into its session → same bug doubled. Kill the child; redispatch with one scheduler if work remains.
5. **Token-burn signature.** Child's cache-read tokens per turn growing into the hundreds of thousands while output tokens stay near zero (use `ccusage session --json` if available) → stuck in idle replay. Kill.

**Kill action:** `tmux send-keys -t <child-pane> C-c C-c` to interrupt, then close the pane after confirming exit. The child's session-scoped crons auto-cancel on session exit; you do not need (and cannot do) `CronDelete` against another session.

**Don't escalate detection.** Killing a runaway child is the supervisor's job — never punt "is the child stuck" to the operator unless you've already killed it and re-dispatch fails.

## Recursion

These rules are recursive. If you are L1 supervising L0, you apply the runaway-child checks to your L0s. If you are L2 supervising L1, you apply the same checks to your L1s — including detecting that an L1 has fallen into the very pathology this file is preventing. The rules don't change with depth; only the identities do.
