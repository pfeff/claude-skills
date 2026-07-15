---
name: decision-rights-doctrine
description: Shared doctrine reference for which decisions an agent MUST escalate to the operator vs may decide autonomously. Holds the two-tier escalation model (Tier 1 hard-escalate, Tier 2 self-check-then-escalate-if-material), the six-category taxonomy (A-F) mined from guardian PRs, the alignment-audit self-check procedure, and the escalation mechanics. This skill has no operations — it is reference content read by any agent facing a decision it is unsure it has the standing to make. Never inline this doctrine into a consumer skill or worker brief — operator-confirmed rules must persist in one place.
allowed-tools:
  - Read
version: 1.0.0
---

# decision-rights-doctrine — shared operator-reserved-decision doctrine

This skill is a doctrine-only reference. It defines which decisions belong to the
operator regardless of who is nominally "driving" a turn, and which an agent may
resolve on its own judgment. It closes a miscalibration observed in mission-session
transcripts: agents absorbing operator-reserved decisions — setting long-term-objective
values, downgrading risk classifications, resolving ambiguous stop-conditions,
finalizing an irreversible action's fuzzy predicate, choosing a blast-radius-bearing
mechanism, or pre-shaping a nominally-independent verdict — without surfacing the call.

Consumers (`dispatch-gate`, `self-verify`, and any agent brief) load this doctrine at
decision time. It has no operations of its own.

## Source of truth

| File | Purpose |
|------|---------|
| `references/taxonomy.md` | The two-tier model, the A-F category taxonomy with one guardian-PR example each, the Tier 2 alignment-audit self-check procedure, and the escalation mechanics ("how to escalate"). |

## Invariants

Every decision an agent faces during a turn falls into exactly one of six categories
(A-F, defined in `references/taxonomy.md`). The categories partition into two tiers:

- **Tier 1 (D, F, B) — MUST-ESCALATE.** The agent does not proceed without an
  operator decision. It surfaces its assessment and the reserved decision, and stops.
- **Tier 2 (A, C, E) — SELF-CHECK THEN ESCALATE-IF-MATERIAL.** The agent runs the
  alignment-audit self-check before proceeding; it escalates only if the check finds
  the element ungrounded in an operator decision/spec AND material.

The tier assignment is fixed by this doctrine — a consumer skill does not re-derive it,
promote a Tier 2 category to "usually fine to skip," or demote a Tier 1 category to
"self-check first." Category-to-tier mapping changes are doctrine edits, landed here.

**Self-recognized escalation carries special force.** If the agent has already flagged
a predicate or decision as ambiguous or reserved earlier in the same turn, it may not
talk itself back down under momentum and resolve it anyway — the earlier flag stands
and the decision routes to the operator (this is the exact failure mode in the
Category D canonical example; see `references/taxonomy.md`).

## When this doctrine is wrong

If a rule in `references/taxonomy.md` is wrong for the current iteration, **fix it
here** via PR against `pfeff/claude-skills`. Do not patch the rule inside a consumer
skill or worker brief — that's the doctrine-drift failure mode this split exists to
prevent.

## See also

- `lN-lifecycle-doctrine` (`references/lifecycle.md`, "Escalation invariant — reality
  vs. manifest") — the adjacent, narrower rule this doctrine generalizes: a child
  whose observed reality disagrees with its frozen task-context/manifest stops and
  reports rather than improvising. That invariant is the manifest-drift instance of
  the broader Category D/Tier 1 principle stated here (fuzzy predicate at the moment
  of an irreversible action) — read this doctrine for the full six-category taxonomy
  the manifest case is one instance of.
- `dispatch-gate` skill, Step 6 ("Frozen manifest (post-dispatch)") — the concrete
  stop-and-report mechanism a dispatched job uses to surface a Tier 1 mismatch to its
  dispatcher.
- `self-verify` skill — checks, as part of its own axis evaluation, that a job did not
  silently absorb a Tier 1 decision instead of escalating it.
