# /l1-review — Run operation

Executes one L1-review against a single L0 PR. Load this file
when `/l1-review <PR>` is invoked.

## Reviewer independence (mandatory)

Per the doctrine `checklist.md` "Reviewer independence" section,
the axis evaluation **must run in a fresh independent verifier
context** — never in the context that authored or supervised the
L0 work. This operation therefore does the axis walk (steps 6–9)
inside a spawned verifier sub-agent that receives **only** the work
product (PR/diff + posted artifacts) and L1's parent objective; the
invoking context prepares inputs, spawns the verifier, then records
and posts the verdict the verifier returns. Self-critique in the
authoring/supervising context is **not** a valid L1-review. Step 5
spawns that verifier.

## Required input

`<PR>` — PR number, `owner/repo#N`, or branch name. Resolved to
`(owner, repo, number)` in step 1.

## Steps

### 5. Spawn the independent verifier

The axis walk (steps 6–9) runs in a **fresh independent verifier
context**, not in this context. Spawn a sub-agent (Task/Agent tool)
that receives **only**:

- The loaded doctrine references from step 2.
- The work product: the PR JSON and diff from step 3
  (`/tmp/l1-review-pr-${pr_number}.json`, `.diff`) plus the posted
  L0 `<!-- review:metadata -->` marker it will read in step 7 — the
  PR/diff and its posted artifacts, nothing more.
- The detected work type from step 4.
- L1's parent objective, resolved by the priority ladder in step 8.

Do **not** pass the authoring/supervising conversation trace, the
L0 session's reasoning, or any rationale for how the work was
produced. The verifier grades the artifact as an outside reader,
which is the whole point of running in an independent context
window (doctrine `checklist.md` "Reviewer independence").

The verifier executes steps 6–9 (the three axes and the overall
verdict) against those inputs and returns the per-axis verdicts,
the finding list, and the computed overall verdict. This invoking
context then records (step 10), posts (step 11), and returns
(step 12) that verdict — it does **not** re-grade. If the verifier
cannot be spawned, **abort**: `review aborted: cannot spawn
independent verifier — L1-review must not self-grade in the
authoring context`. Do not fall back to grading in place.

### 6. Walk axis 1 — Conformance

Inputs:
- Task as given to L0: read in this priority order.

Apply the checklist axis-1 checks (scope, acceptance-criteria
coverage, debug/WIP signatures). Emit findings per the schema.
Compute axis-1 verdict.

### 9. Write the artifact

Path: `.claude/reviews/l1-latest.md` relative to the **L1's
workspace** (the working directory from which `/l1-review` was
invoked).
