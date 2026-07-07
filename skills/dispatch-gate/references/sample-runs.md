# Sample Runs

Recorded babysat dispatch-gate cycles — real dates, real project
identifiers, real outcomes. `example-transcript.md` is illustrative
onboarding material; this file is the log of actual runs the gate has
been through, per spec decision 8.

Each entry frames: intent → gate evaluation (which fields resolved or
failed) → outcome → what it demonstrates about the criteria.

---

## 2026-07-03 — Refuse → premise-correction cycle

**Intent**: Dispatch D/HYSA financial-lever work — a background job to
act on a debt-vs-high-yield-savings tradeoff.

**Gate evaluation**: Objective and affected surface looked stated, but
during the clarifying pass on scope the operator surfaced that the
job's premise was invalid — the liquid cash the lever assumed was
available was already earmarked for a home purchase. The HYSA premise
didn't hold once that was on the table.

**Outcome**: Dispatch cancelled before any work launched. No
`.claude/task-context.md` was written. The corrected premise (cash is
earmarked, not free capital) was recorded durably outside the gate
(operator memory), so the same wrong-premise dispatch doesn't recur.

**What it demonstrates**: This is the gate working as designed, not a
failure to dispatch. The clarifying dialogue's job is to surface
exactly this kind of gap — not just missing fields, but a false premise
underneath an otherwise well-formed request — before a job burns cycles
on work built on a bad assumption. It's the "genuine catch" case in
production, not just in `example-transcript.md`'s worked example.

---

## 2026-07-03 — First parallel ready-path dispatches

**Intent**: Two independent slices, both intended to run concurrently
rather than sequentially.

- **(a) V drafts-reformat** — code work, isolated branch
  `sv/v-drafts-reformat`.
- **(b) P pipeline-hygiene** — read-only exploration, no code changes.

**Gate evaluation**: Both slices had all four fields unambiguous from
what the operator had already said — objective, acceptance test, scope,
and affected surface each resolved without a clarifying question.
Both hit the ready path (Step 4) directly.

**Outcome**: Both dispatched and ran concurrently, each against its own
`.claude/task-context.md`. Both returned clean end-to-end — the
read-only slice with findings, the code slice with a commit on its
isolated branch per the Step 5 standing instruction.

**What it demonstrates**: This pairing met the throughput bar that
retired a standing babysitting session — two well-specified,
independent slices running in parallel without the gate adding
clarifying-pass overhead, because the four fields were genuinely
resolved up front. It's the baseline "boring success" case: the gate
adds no friction when the slice actually is complete.

---

## 2026-07-06 — Cross-repo ready path with launcher-carried task-context

**Intent**: Charter-skill dispatch for the improvement-loop work that
became `claude-skills` PR #134.

**Gate evaluation**: All four fields resolved from an interview-decided
spec already in hand — the dispatch hit the ready path with no
clarifying pass needed. The target worktree did not exist yet, so per
Step 4's cross-repo branch, the gate did not provision a worktree or
branch itself. Instead it emitted the target path spec (target repo,
intended branch, intended worktree location) and the task-context
content for the launcher to carry.

**Outcome**: The dispatcher emitted the task-context content inside the
launch instruction. The worker created its own ephemeral worktree and
wrote `.claude/task-context.md` as its first act, using the emitted
content. The worker then committed to its isolated branch, ran
self-verify (PASS on all three axes) per the Step 5 standing
instruction, and opened the PR. The operator gate stayed on merge — no
merge happened as part of this cycle.

**What it demonstrates**: The cross-repo deferred-provisioning path
(Step 4's second branch) works end-to-end when the launcher is
disciplined about carrying the emitted task-context content through to
the worker's first act. It also confirms the Step 5 contract holds
across a repo boundary: commit-before-self-verify and self-verify's
three-axis pass both happened exactly as specified, with no
in-session handholding needed once the spec was interview-decided.

---

## 2026-07-07 — Post-completion doctrine refinement fed back into the gate's world

**Intent**: Not a dispatch — the first accept-queue servicing of a
gated dispatch's completed work (the improvement-loop PR from the prior
entry).

**Gate evaluation**: Not applicable to this skill's own steps, but the
outcome bears directly on Step 5's closing line, "the operator gate
remains on merge, not on commit." Servicing the accept queue produced a
standing operator order: **always review and get approval before
merge** — agent-side self-verify evidence (a PASS verdict) informs the
review, it does not substitute for it.

**Outcome**: The Accept(merge)/Review/Dismiss triad used at
accept-queue time is now explicitly review-then-approve, not
one-click accept on a green self-verify result.

**What it demonstrates**: Step 5's "operator gate remains on merge" was
always true as written, but this cycle is what pinned down what
"remains on merge" means in practice — a human review step gated on
approval, with self-verify output as one input to that review rather
than a bypass. Recorded here because it closes the loop this skill
opens: the gate controls what's ready to dispatch; this cycle
clarified what's required before the resulting work lands.
