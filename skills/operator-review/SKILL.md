---
name: operator-review
description: >
  Present a completed change to the human operator to prove it solves the problem
  and obtain sign-off, in a working session. Fires when work is ready for the
  operator's decision — "get my sign-off", "present it for approval", "present it
  in chunks", "use the interview tool", "review these with me". Drives decisions
  through AskUserQuestion (selectable options), chunked for large items, each with
  a recommended default.
version: 1.2.0
allowed-tools:
  - AskUserQuestion
  - Bash
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
1. **Produce the Sign-off brief.** This is a required, non-skippable
   precondition — no Step-3 AskUserQuestion for a merge/sign-off decision may
   open until this brief has been emitted in full, as prose, in the chat. Four
   parts, in order:
   - **Problem** — the problem the change targets, sourced from the spec/task,
     PR body Summary/Context, linked issues, or operator-correction memory,
     *not* a restatement of the change's title — and its acceptance criteria:
     the bar the change must clear. A change with no discoverable motivating
     problem is not ready to present; surface that gap rather than papering
     over it.
   - **What the change does, in plain language** — what merging actually does
     to the world on the normal path and on the failure/edge path. Plain
     language, not a reviewer's-eye technical restatement.
   - **Intent reconciliation** — an explicit judgment: does the diff resolve
     *that* problem, or has it drifted / been superseded / gone stale? State
     any honest caveat (e.g. a partial slice of a larger objective).
   - **Evidence** — the original defect reproduced-then-caught, tests passing,
     real catches/behavior, and the agent-review verdicts from `/review`
     (+ `/l1-review`/`/l2-review`), linking their markers — presented
     explicitly as evidence for the conformance/process/objective axes,
     **not** as the reconciliation itself. Keep it proportionate to the
     change.

   **Anti-pattern:** presenting agent-review verdicts (CLEAN/BLOCKING) in
   place of a problem→intent reconciliation is the "here is a diff, approve
   it" failure the Goal forbids. Verdicts are evidence for one axis; they are
   never the reconciliation. If the brief's Problem / plain-summary /
   Intent-reconciliation parts are not emitted, the sign-off ask is premature.
2. **Drive decisions through AskUserQuestion, not prose** — gated behind the
   Sign-off brief above. The operator decides from selectable options. One
   decision per question; batch related ones per the AskUserQuestion batch
   rules in `operator-interview-doctrine`; every question carries exactly one
   recommended default, placed first.
3. **Chunk large items for approval** (e.g. a full spec: Problem+Decisions /
   Requirements+Acceptance / Deferred+E2E), approving each chunk before the final
   explicit sign-off.
4. **Honor sign-off:** explicit sign-off confers authority; "looks fine"/silence
   does not. On sign-off, record it and route the approval per **Approval
   discipline** below; otherwise hold as draft.
5. **Record each decision immediately** (TaskUpdate/TaskCreate) before acting.

## Approval discipline (account-aware, two-party)

Sign-off authorizes an approval; it does not let the agent *record* one. A PR
merges under a genuine two-party review, so:

- **The agent is barred from recording approvals.** A GitHub approval
  (`gh pr review --approve`) is an **operator** action, taken by the operator
  from the correct account (`! gh pr review --approve`). The agent presents and
  gets sign-off; it never runs the approve itself. Merging an
  already-approved PR (including as its author) is fine — recording the
  approval is not.
- **A PR author cannot approve their own PR.** The approval must come from the
  *other* account. **Verify the author first** (`gh pr view <n> --json author`);
  never assume the account mapping — a wrong guess yields GitHub's "Can not
  approve your own pull request". Route the approval to whichever account is
  not the author.

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
