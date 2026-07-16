---
name: lN-review-doctrine
description: Shared doctrine reference for the Acceptance and Objective review skills (l1-review, l2-review). Holds the 3-axis checklist (Conformance, Process, Objective Advancement), the reviewer-independence and reviewer-worktree-discipline invariants, the work-type → required-verification map consumed by axis 2, the finding/verdict schema, and the self-PR posting caveat. This skill has no operations — it is reference content read by `/l1-review` and `/l2-review` at review time. Never inline this doctrine into the l1-review or l2-review skills themselves — operator-confirmed rules must persist in one place.
allowed-tools:
  - Read
version: 1.6.0
---

# lN-review-doctrine — shared Acceptance/Objective review doctrine

This skill is a doctrine-only reference. It defines what an
Acceptance or Objective review *is*, regardless of which layer runs
it. The actual review skills (`l1-review`, `l2-review` — the
Acceptance and Objective review executors) are thin executors that
load this doctrine at review time and apply it at their layer.

## Source of truth

| File | Purpose |
|------|---------|
| `references/checklist.md` | Role, reviewer-independence invariant, reviewer-worktree-discipline invariant, the 3-axis checklist, finding schema, verdict rubric (incl. the single-vocabulary deprecation of APPROVE/REJECT/ESCALATE), artifact format, posting protocol, local-artifact rule. |
| `references/verification-map.md` | Work-type → required-verification map consumed by axis 2 (Process), plus the doctrine- and workflow-class sub-checklists. |
| `references/depth-rule.md` | Depth/proportionality rule — the change-class table, the load-bearing surfaces list, and the overridable size-threshold parameters that determine how much of the checklist applies to a given work product. |

## Invariants

An Acceptance or Objective review **never re-runs** `/review`.
Code-level correctness, security, simplicity, and architecture
review is the Change review's (L0's `/review`) job; the
Acceptance/Objective review skill consumes the verdict the Change
review posts to the PR (the `<!-- review:metadata -->` marker — the
cross-operator artifact, not the gitignored local
`.claude/reviews/latest.md`) as evidence for axis 2.

An Acceptance or Objective review **always evaluates against the
reviewing layer's parent objective**, not the reviewed layer's task
description. This is the recursive lever; see checklist.md axis 3
for what to read to determine the reviewing layer's objective.

An Acceptance or Objective review **runs in an independent context
window** — a fresh verifier that sees only the work product plus
the reviewing layer's parent objective, never the authoring trace.
See checklist.md *Reviewer independence*.

An Acceptance or Objective review **operates read-only on the
worktree** — never `stash`, `checkout`, `reset`, `restore`, `clean`,
`rebase`, or switch branches in the review worktree, even
temporarily. See checklist.md *Reviewer worktree discipline* for
the non-mutating recipe for inspecting other revisions.

## When this doctrine is wrong

If a rule in `references/` is wrong for the current iteration,
**fix it here** via PR against `pfeff/claude-skills`. Do not patch
the rule inside `l1-review` or `l2-review` — that's the
doctrine-drift failure mode this split exists to prevent.

## See also

- `lN-lifecycle-doctrine` — the parallel lifecycle doctrine; its
  `pr-open → fixing → merged` states drive when an Acceptance or
  Objective review runs.
- `l1-review` skill — executes this doctrine as the Acceptance
  review (N=1).
- `l2-review` skill — executes this doctrine as the Objective
  review (N=2).
- `mbp/review` (plugin) — the Change review's (L0's) per-line
  review skill; its output is read by axis 2 of an Acceptance or
  Objective review. Out of scope for changes here.
