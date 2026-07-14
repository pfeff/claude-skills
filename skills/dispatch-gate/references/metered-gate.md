# Metered-Work Gate: Billing-Pool Sign-Off

## Overview

Before the four slice-complete criteria are checked, the metered-work gate
classifies the job's **billing pool**: does it run entirely on the
subscription pool, or does it invoke a metered runtime? If metered, the
operator must give **explicit sign-off**, recorded before dispatch, because
metered spend has no per-operation cap and no rollover protection.

This gate exists because a background job's billing exposure is not visible
from its stated objective alone — a job whose brief reads as ordinary
background work can still fire hundreds of metered invocations internally
(e.g. a benchmark or eval harness that calls out to `claude -p` in a loop).
The classification has to be made explicitly, not inferred from vibes.

## Trigger Condition

The gate always runs — every dispatch gets classified as subscription or
metered. There is no "skip" case the way there is for the privacy gate;
the only question is which bucket the job falls in.

## Classification

**Subscription** (no extra cost, covered by the interactive plan):

- Interactive `claude` TUI sessions
- Claude.ai, Cowork
- In-session `Agent`-tool subagents (foreground or background) launched
  from an interactive session — these still deliver work via the
  session's own interactive context
- Tick delivery via `tmux send-keys` into an interactive pane (the
  L0/L1/L2 supervision fleet's mechanism)

**Metered** (API list rates, per-user cap, no rollover — billed against the
metered credit pool):

- `claude -p` / `claude --print` (headless invocation)
- The Agent SDK, called directly or from a script
- GitHub Actions (or any other CI runner) that invokes Claude
- `/schedule`, `CronCreate`, `RemoteTrigger`, or any other harness-native
  scheduled agent
- An eval/benchmark harness that spawns any of the above internally —
  the harness's own framing (e.g. "run the skill-creator benchmark") does
  not exempt it if it fires `claude -p` under the hood

**The test is behavioral, not a fixed tool list**: does the job, anywhere
in its execution path, invoke a metered runtime? The bullets above are
canonical examples, not the full enumeration — if a new tool or harness
turns out to call `claude -p`/the Agent SDK/Actions internally, it is
metered even if it isn't named here.

**When uncertain**: default to metered and ask. A false "subscription"
classification is the failure mode this gate exists to prevent; a false
"metered" classification just costs one confirmation question.

## Procedure

### Placement in dispatch-gate

This check runs as **Step 0.5** — after the privacy gate (Step 0) and
before the four slice-complete criteria (Step 1). Billing-pool exposure is
a policy gate, independent of both privacy and task readiness.

### Dispatcher behavior

1. **Classify**: walk the job's stated approach (and any harness/skill it
   invokes) against the Classification section above.
2. **If subscription**: proceed to Step 1. No annotation needed.
3. **If metered**:
   - Stop and tell the operator plainly: "This job invokes [metered
     runtime/harness] — that runs on the metered credit pool, not the
     subscription. Metered spend has **no per-operation cap and no
     rollover** if unused. Do you approve dispatching it?"
   - **Operator must approve explicitly** before the gate proceeds to
     Step 1. Silence or an ambiguous "sure, go ahead" on an unrelated
     question does not count — the sign-off must be a direct answer to
     the metered-cost question.
   - If approved: record the sign-off as a checkbox-style line in the
     four-field criteria discussion and as a Metered Sign-off Annotation
     in `.claude/task-context.md` (see format below).
   - If declined: do not dispatch. No `.claude/task-context.md` is
     written. Suggest a workaround (see Failure Cases).

### Metered Sign-off Annotation

When the operator approves a metered dispatch, record the decision in
`.claude/task-context.md` immediately below the four fields (same
placement as the Override and Privacy Gate annotations — stacked in the
order the gates ran, if more than one applies).

Format:

```markdown
> **Metered Sign-off** (runtime: <metered runtime/harness name>): operator
> approved metered spend (no cap, no rollover) on <date>.
```

Example:

```markdown
> **Metered Sign-off** (runtime: skill-creator benchmark, invokes `claude -p`):
> operator approved metered spend (no cap, no rollover) on 2026-07-13.
```

This annotation makes the sign-off durable and reviewable by `self-verify`
and the human review layer, the same way the Override and Privacy Gate
annotations do.

## Failure Cases

### Case 1: Operator declines sign-off

- Do not proceed with the dispatch.
- Do not write `.claude/task-context.md`.
- Suggest a workaround: reframe the job to stay on the subscription pool
  (e.g. run the benchmark's cases through an in-session `Agent`-tool
  subagent instead of a `claude -p` loop), or scope it down so the
  metered call count is small enough for the operator to approve at a
  known cost.

### Case 2: Dispatcher misjudges the classification

- **Default to metered and ask** when unsure whether a harness invokes a
  metered runtime internally — the cost of a false-metered confirmation
  is one question; the cost of a false-subscription miss is uncapped,
  unapproved spend.
- Example: "The job runs 'the skill-creator benchmark' — does that spawn
  `claude -p` internally?" — if unknown, ask the operator or check the
  harness's source before classifying it subscription.

### Case 3: Metered invocation discovered mid-job

- **Policy**: a job dispatched as subscription must not switch to a
  metered runtime mid-flight without stopping and getting sign-off first.
- Responsibility: the job's own author is accountable for recognizing a
  metered call before making it, not after.
- The metered-work gate is a **dispatch-time guard**, not a runtime
  monitor — it cannot catch a mid-job pivot itself, but a job that pivots
  to a metered runtime without sign-off is a process failure the
  self-verify/review layer should flag.

## Relationship to Other Gates

- **dispatch-gate Step 0** (privacy gate): policy gate — "are we allowed
  to publish this?"
- **dispatch-gate Step 0.5** (this check): policy gate — "which billing
  pool does this land on, and did the operator approve it?"
- **dispatch-gate Steps 1–5** (existing): task-readiness gate — "is the
  task well-specified?"
- **self-verify** (review layer): catches any metered-gate violations that
  slipped through (mis-classified job, missing sign-off); flags them for
  operator review pre-merge.

All applicable gates must pass. They are independent of each other.

## Calibration & Updates

If the dispatcher frequently misclassifies jobs, or if operators find the
sign-off question is firing on jobs that turn out to be pure subscription
work:

- Adjust the Classification section above with the new example, keeping
  the underlying test ("does it invoke a metered runtime?") unchanged.
- This reference doc is the living definition of what counts as metered
  in this system — maintain it as tools and harnesses evolve.

## References

- `../SKILL.md` Step 0.5 — where this gate is invoked in dispatch-gate
  workflow
- `privacy-gate.md` — sibling policy gate (Step 0), same
  placement and annotation pattern
- `../../self-verify/references/task-context.md` — "Override annotation"
  section, the shared placement convention (appended below the four
  fields, never a fifth field) this gate's annotation follows
- `../../self-verify/SKILL.md` — review layer that catches any
  violations
