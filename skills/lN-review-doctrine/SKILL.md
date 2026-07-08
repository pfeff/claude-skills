---
name: lN-review-doctrine
description: Shared doctrine reference for L{N}-review skills (l1-review, l2-review). Holds the 3-axis checklist (Conformance, Process, Objective Advancement), the work-type → required-verification map consumed by axis 2, the finding/verdict schema, and the self-PR posting caveat. This skill has no operations — it is reference content read by `/l1-review` and `/l2-review` at review time. Never inline this doctrine into the l1-review or l2-review skills themselves — operator-confirmed rules must persist in one place.
allowed-tools:
  - Read
version: 1.2.1
---

# lN-review-doctrine — shared L{N}-review doctrine

This skill is a doctrine-only reference. It defines what L{N}-review
*is*, regardless of N. The actual review skills (`l1-review`,
`l2-review`) are thin executors that load this doctrine at review
time and apply it at their layer.

## Source of truth

| File | Purpose |
|------|---------|
| `references/checklist.md` | Role, reviewer-independence invariant, the 3-axis checklist, finding schema, verdict rubric (incl. the single-vocabulary deprecation of APPROVE/REJECT/ESCALATE), artifact format, posting protocol, local-artifact rule. |
| `references/verification-map.md` | Work-type → required-verification map consumed by axis 2 (Process), plus the doctrine- and workflow-class sub-checklists. |

## Invariants

L{N}-review **never re-runs** `/review`. Code-level correctness,
security, simplicity, and architecture review is L0's `/review`
job; the L{N}-review skill consumes the verdict L0 posts to the PR
(the `<!-- review:metadata -->` marker — the cross-operator
artifact, not the gitignored local `.claude/reviews/latest.md`) as
evidence for axis 2.

L{N}-review **always evaluates against L{N}'s parent objective**,
not L{N-1}'s task description. This is the recursive lever; see
checklist.md axis 3 for what to read to determine L{N}'s objective.

L{N}-review **runs in an independent context window** — a fresh
verifier that sees only the work product plus L{N}'s parent
objective, never the authoring trace. See checklist.md *Reviewer
independence*.

## When this doctrine is wrong

If a rule in `references/` is wrong for the current iteration,
**fix it here** via PR against `pfeff/claude-skills`. Do not patch
the rule inside `l1-review` or `l2-review` — that's the
doctrine-drift failure mode this split exists to prevent.

## See also

- `lN-lifecycle-doctrine` — the parallel lifecycle doctrine; its
  `pr-open → fixing → merged` states drive when an L{N}-review runs.
- `l1-review` skill — executes this doctrine at N=1.
- `l2-review` skill — executes this doctrine at N=2.
- `mbp/review` (plugin) — L0's per-line review skill; its output
  is read by axis 2 of L{N}-review. Out of scope for changes
  here.
