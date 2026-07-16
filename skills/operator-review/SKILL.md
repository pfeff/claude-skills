---
name: operator-review
description: >
  Present a completed change to the human operator to prove it solves the problem
  and obtain sign-off, in a working session. Fires when work is ready for the
  operator's decision — "get my sign-off", "present it for approval", "present it
  in chunks", "use the interview tool", "review these with me". Drives decisions
  through AskUserQuestion (selectable options), chunked for large items, each with
  a recommended default.
version: 1.1.0
allowed-tools:
  - AskUserQuestion
  - TaskCreate
  - TaskUpdate
---

# operator-review — prove the change and get operator sign-off

## Goal
Prove to the operator that the change **solves the stated problem in a reasonable
way** — enough for them to sign off with confidence. This is not "here is a diff,
approve it"; it is problem → evidence → decision.

## Prerequisite
**All agent reviews warranted by the change's tier are complete** and their markers
posted:
- **`/review`** (Change-level) — always;
- **`/l1-review`** (Acceptance) and **`/l2-review`** (Objective) — as the change's
  tier requires (per the proportional-depth review model).

The human review sits *on top of* that evidence — do not present for operator
sign-off until the tier's agent reviews are done and posted.

## Steps
1. **Restate the problem** the change targets (from the spec/task) and its
   acceptance criteria — the bar the change must clear.
2. **Show it solves the problem, reasonably.** Lead with evidence: the original
   defect reproduced-then-caught, tests passing, real catches/behavior, and the
   agent-review verdicts from `/review` (+ `/l1-review`/`/l2-review`), linking their
   markers. Keep it proportionate to the change.
3. **Drive decisions through AskUserQuestion, not prose** — the operator decides
   from selectable options. One decision per question; batch related ones per the
   AskUserQuestion batch rules in `operator-interview-doctrine`; every question
   carries exactly one recommended default, placed first.
4. **Chunk large items for approval** (e.g. a full spec: Problem+Decisions /
   Requirements+Acceptance / Deferred+E2E), approving each chunk before the final
   explicit sign-off.
5. **Honor sign-off:** explicit sign-off confers authority; "looks fine"/silence
   does not. On sign-off, record it and proceed; otherwise hold as draft.
6. **Record each decision immediately** (TaskUpdate/TaskCreate) before acting.

## Edge Cases
- **Over-menuing:** if the operator wants discussion not a pick, they'll say
  "clarify" — ask what to clarify, then reshape. Don't force a menu.
- **"Backlog"/"do it later" = defer:** file it and continue; no review menu for it.
- **Relationship to siblings:** `operator-interview` *elicits* a spec (what/why);
  `verify`/`demo` *exercise* the change; this action *presents produced work +
  evidence for the operator's decision*.

## See also
- `operator-interview` — elicits a spec (what/why) before the work exists.
- `verify` / `demo` — exercise the change to produce the evidence this action presents.
