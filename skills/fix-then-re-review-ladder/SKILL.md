---
name: fix-then-re-review-ladder
description: Recovery loop driving a PR (or reviewed work product) from a NEEDS-WORK/findings-attached verdict back to CLEAN. Triggers when a /review, /l1-review, or /l2-review verdict is not CLEAN and the operator wants it resolved. Triages findings into fix-now vs operator-waivable, dispatches ONE scoped fix agent (sole-finisher on the branch/worktree, no rescoping), then re-runs the tier-appropriate ladder (/review -> /l1-review -> /l2-review) against the NEW HEAD, looping fix->re-review until clean or a residual is reported. Produces the clean state operator-review then presents. Invoked by `pr-review-fanout` on a needs-work verdict, or standalone.
version: 1.1.0
allowed-tools:
  - Task
  - AskUserQuestion
  - TaskUpdate
---

# fix-then-re-review-ladder — recover NEEDS-WORK to CLEAN

Middle stage of the three-skill review pipeline: `pr-review-fanout` (bulk-runs
the ladder across PRs and routes needs-work verdicts here) -> **this skill**
(recovers a PR to CLEAN) -> `operator-review` (presents the clean result for
human sign-off). This skill is a pure executor of the doctrine in
`lN-review-doctrine` — it does not invent verdict schema or marker format, it
reads and re-triggers what already exists.

## Goal

Drive a PR whose posted review verdict is `NEEDS-WORK` or `BLOCKING` back to
`CLEAN` at the tier that failed, then hand off to `operator-review`.

For delivery, acknowledgement, monitoring, and the coordinator's completion
contract, follow [Review Handoff](../review/operations/handoff-review.md).
The coordinator retains ownership through the fix and independent re-review;
a dispatch alone is not completion.

## Prerequisite

A posted review marker at some tier — `<!-- review:metadata -->` (Change/L0),
`<!-- l1-review:metadata -->` (Acceptance/L1), or `<!-- l2-review:metadata -->`
(Objective/L2) — carrying a `NEEDS-WORK` or `BLOCKING` verdict. Read the
marker per the "How the next layer reads the artifact" procedure in
`../lN-review-doctrine/references/checklist.md`: reviews API first,
issue-comment mirror as fallback, `sha`-matched against current HEAD (never
bare most-recent-wins — see that doctrine's "Marker currency" section).
Never trust a local `.claude/reviews/*.md` cache as the source of truth —
it is per-host and not readable across operators.

## Steps

1. **Identify tier + current HEAD.** The failing marker names its `level`
   (0/1/2 -> Change/Acceptance/Objective) and its `sha` field — the exact
   revision it reviewed. Compare against the live remote PR head SHA, not
   `git rev-parse HEAD` in a potentially outdated checkout: a verdict — CLEAN
   included — whose marker `sha` differs from that remote head is **stale**. Treat a stale marker as if no review ran at
   that tier and restart the ladder against current HEAD rather than
   trusting it.
2. **Extract findings** from the posted marker's body — the per-axis
   Conformance/Process/Objective sections for L1/L2, the Blocking/Advisory
   sections for L0 — read fresh from the PR comment (per the Prerequisite),
   not from a local cache.
3. **Triage** each finding into **fix-now** (a real defect: any `blocking`
   finding, or a `warning`/`info` finding that is actually a correctness or
   scope-mismatch problem) vs **advisory/waivable** (a `warning`/`info`
   finding the operator may accept as-is). Apply the operator's existing fix
   authorization and explicit limits: proceed with already-authorized fixes
   without another permission round. Do not override an explicit "don't touch X"
   restriction merely because a finding concerns X. Surface only unresolved
   scope/waiver decisions via one `AskUserQuestion` batch, with a recommended
   default per decision. An advisory finding is never silently waived.
   A finding that is **structurally unfixable
   pre-merge** (e.g. a check that only runs on the default branch) is neither
   fixed nor waived by this step — document it as a known residual now; do
   not hack around it later to force a green re-review.
4. **Assign ONE scoped fix agent.** Reuse the existing implementation worker
   when it owns this PR. Send the verified artifact and scoped acceptance criteria
   directly and observe its acknowledgement per Review Handoff. Only when no
   suitable worker exists, dispatch one through `dispatch-gate`, right-sized
   (Sonnet by default; escalate the model only for a load-bearing/doctrine-class
   surface). The fix agent is the **sole finisher** on the branch/worktree for
   this iteration — no parallel fix agents against the same PR, and no
   rescoping or redesign beyond what the triaged fix-now findings require.
   Unlike a reviewer, the fix agent is **not** bound by the reviewer
   read-only-worktree discipline in `checklist.md` ("Reviewer worktree
   discipline") — that constraint exists to protect a work product under
   independent evaluation; the fixer IS the author on its own branch, in its
   own worktree, and editing and committing there is exactly its job. If the
   branch has diverged from main, the fix agent rebases/resolves as part of
   its scoped fix; a divergence beyond a mechanical rebase is an escalation
   condition (below), not something to force through.
5. **Push.** The fix agent pushes its commit(s) to the PR's branch so the PR
   updates in place. Verify the remote PR head and record that exact SHA via
   `TaskUpdate`. Monitor the assigned worker through this result; do not ask the
   operator to carry findings or status between agents.
6. **Re-run the SAME tier** that failed, against the new HEAD, via a **fresh
   independent agent** — a new context window with no authoring trace of the
   fix, per the doctrine's reviewer-independence rule in `checklist.md`
   ("Reviewer independence"). This skill dispatches that agent; it does not
   run `/review`/`/l1-review`/`/l2-review` itself. The re-review posts its
   marker per the doctrine's find-or-update-by-marker protocol (update the
   existing comment for that marker type in place). Read back the marker and
   verify its SHA against the remote head; a pre-fix review verdict never counts
   toward the new HEAD. If the head moved again, re-review before claiming CLEAN.
7. **Loop or exit:**
   - New verdict `CLEAN` -> stop looping; hand off to `operator-review`
     (its Prerequisite is all tier-warranted markers posted; this loop's
     exit condition is what makes them CLEAN by the time of handoff).
   - New verdict `NEEDS-WORK`/`BLOCKING` while below the escalation limits ->
     back to step 2, triage the new marker. This includes the first unchanged
     re-review; a second consecutive no-progress attempt escalates as below.
   - An escalation condition below is met -> **stop**, do not loop further;
     surface to the operator.

## Escalation — stop, don't loop forever

Escalate instead of dispatching another fix agent when any of:

- **No forward progress**: two consecutive re-reviews (each after its own fix
  attempt) show no resolved findings and no materially narrowed failure
  conditions. Overlap alone is not a stall; narrowed findings continue within
  the iteration budget.
- **Iteration budget exhausted**: 3 fix -> re-review iterations complete
  against this PR without reaching `CLEAN`. Default; an overridable parameter
  recorded here, not hardcoded doctrine — retune via a follow-up PR if it
  proves wrong in practice.
- **Unfixable-pre-merge residual**: a fix-now finding is structurally
  unfixable before merge (step 3) — document it, escalate rather than force
  a hack to get a green re-review.
- **Branch divergence beyond a mechanical rebase**: the fix agent reports a
  conflict it cannot resolve as sole finisher.
- **Triage ambiguity**: the `AskUserQuestion` response doesn't resolve the
  fix-now/waivable split (e.g. the operator wants to discuss rather than
  pick) and a second round doesn't close it either.

On escalation, report the tier, the residual findings, the iteration count,
and what was tried — to the operator, or (when invoked by `pr-review-fanout`)
back into that skill's per-PR tracking — and stop. Do not dispatch another
fix agent past an escalation; a human decision is required to proceed.

## Edge Cases

- **Fix surfaces genuinely new findings** the original review never saw ->
  loop (step 7, second bullet). This alone is not an escalation — only "no
  forward progress" or "budget exhausted" (above) force a stop.
- **Operator waives an advisory finding** -> record the waiver via
  `TaskUpdate` and proceed without a fix for that item; never silently drop
  it from the eventual report.
- **Structurally unfixable pre-merge finding** -> document, escalate; never
  hack around it to force a passing re-review.
- **Fix conflicts with main** -> the sole-finisher fix agent rebases; if that
  fails, escalate (branch-divergence condition above).
- **Duplicate fix agent dispatched on the same PR** (e.g. a race from a
  second invocation) -> keep the one already in flight as sole finisher and
  stop the other; two fix agents must never commit to the same branch
  concurrently.
- **Stale marker** -> always check the marker's `sha` field against current
  HEAD before trusting any verdict, CLEAN included (step 1). This holds on
  either posting surface — a stale `BLOCKING` event left behind on the
  append-only reviews API by a since-superseded re-review never survives
  this check (`lN-review-doctrine`'s "Marker currency").
- **Relationship to `operator-review`**: this skill produces the clean state
  `operator-review`'s Prerequisite consumes. It does not itself seek operator
  sign-off on the change's content — the only operator interaction here is
  the fix-now/waivable triage in step 3.

## What this skill does NOT do

- Does not itself run `/review`, `/l1-review`, or `/l2-review` — it dispatches
  agents that do, and reads the markers those agents post.
- Does not merge, approve, or post the final sign-off — that is
  `operator-review`.
- Does not run more than one fix agent at a time against the same PR.
- Does not loop past an escalation condition without a human decision.

## See also

- `pr-review-fanout` — dispatches this skill on a needs-work verdict from its
  bulk ladder run across multiple PRs; this skill reports its outcome back
  into that skill's per-PR tracking when invoked from it.
- `operator-review` — the next pipeline stage; its Prerequisite is the CLEAN
  state this skill produces.
- `lN-review-doctrine` (`references/checklist.md`) — the verdict/finding
  schema, the marker-emission template, the find-or-update-by-marker
  protocol, and the reviewer-independence / reviewer-worktree-discipline
  rules the agents this skill dispatches must follow.
