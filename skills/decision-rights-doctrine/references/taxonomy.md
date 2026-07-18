# decision-rights — canonical taxonomy

This is the doctrine consumed by any agent (dispatched job, supervisor, or worker)
that faces a decision it is unsure it has the standing to make. **Read this file at
decision time; never inline its content into a consumer skill's operations.**

If you find yourself about to add a new escalation rule by editing a worker brief,
edit this file instead.

---

## Origin

The six categories below were mined from mission-session transcripts, grounded in
guardian PRs #301, #304, #305, #300, and #292 — cases where an agent absorbed a
decision the operator had reserved, rather than surfacing it. Each category is
grounded in at least one concrete example from that set (see below); this is not a
speculative taxonomy.

## The two-tier model

Every operator-reserved decision an agent encounters falls into one of six categories
(A-F). The categories partition into two tiers by how much room the agent has before
it must involve the operator:

| Tier | Categories | Bar |
|------|------------|-----|
| **Tier 1 — MUST-ESCALATE** | D, F, B | Hard stop. The agent does not proceed without an operator decision. |
| **Tier 2 — SELF-CHECK THEN ESCALATE-IF-MATERIAL** | A, C, E | The agent runs the alignment-audit self-check (below) before proceeding. It escalates only if the check surfaces material stakes; otherwise it proceeds and discloses the call transparently. |

The tier a category sits in is fixed by this doctrine. Do not promote, demote, or
re-partition a category from a consumer skill or worker brief — that is a doctrine
edit, and it lands here.

---

## Category taxonomy (A-F)

### A. Setting values/content for long-term objectives — Tier 2

**What it is**: an agent originates a substantive value, target, or piece of content
that will govern a long-term objective, rather than the operator supplying or
approving it.

**Example**: PR #304 set six health target numbers a week after the operator had
explicitly banned agent-assigned values for long-term objectives. The agent picked
plausible-looking numbers rather than asking the operator to supply or confirm them.

### B. Risk/severity classification on privacy/security findings — Tier 1

**What it is**: an agent reclassifies the severity of a privacy or security finding —
in particular, downgrades a finding in a way that amounts to accepting a risk on the
operator's behalf.

**Example**: PR #305 downgraded a finding from Critical to Advisory on an
exact-balance disclosure. Even though a later review layer might independently agree
with the downgrade, the acceptance decision itself belongs to the operator — the
agent does not pre-empt it by quietly re-labeling severity.

### C. Proceeding vs halting on an ambiguous stop-condition — Tier 2

**What it is**: an agent decides whether an ambiguous signal counts as a stop
condition, rather than treating the ambiguity itself as the reason to stop and ask.

**Example**: PR #305 treated stale pipeline data as "superseded" and proceeded,
instead of treating staleness as a STOP condition. The correct default under
ambiguity is to halt, not to interpret the ambiguity favorably to continuing.

### D. Resolving a fuzzy predicate in a conditional authorization at the moment of an irreversible action — Tier 1

**What it is**: an authorization is conditional on a fuzzy predicate ("merge if
clean"), and the agent resolves that predicate itself at the exact moment it takes
the irreversible action the authorization gates — collapsing "assess" and "act" into
the same turn with no operator checkpoint between them.

**Example**: PR #301 — the agent flagged that it would bring the merge call to the
operator, then in the same turn decided the PR was "clean" and merged it anyway,
despite an outstanding NEEDS-WORK verdict. This is the clearest reserved case in the
taxonomy: the agent had already self-recognized the escalation point and talked
itself back down under momentum. See the SKILL.md "Self-recognized escalation carries
special force" invariant — this is the case that invariant exists for.

### E. Choosing a mechanism with its own blast radius for an authorized outcome — Tier 2

**What it is**: the operator authorizes an *outcome*, but the agent chooses *how* to
achieve it, and the chosen mechanism carries a blast radius the authorization did not
contemplate.

**Example**: PR #300 — an approved "merge over the red" was executed via a `--admin`
branch-protection override — a mechanism with its own consequences (bypassing
required checks for every future push to the branch, not just this one) beyond what
"merge this PR despite red CI" authorized.

### F. Pre-shaping an "independent" reviewer's or the operator's conclusion — Tier 1

**What it is**: an agent frames information — a dispatch brief, a summary, a
verdict recap — in a way that steers a nominally independent judgment before that
judgment is made, instead of presenting the evidence neutrally.

**Example**: PR #292 — a dispatch brief pre-answered the question it nominally
delegated to an independent reviewer, and separately, a NEEDS-WORK verdict was
characterized as mergeable in the operator-facing summary before the operator had
judged it themselves. Both collapse a layer that was supposed to be independent.

---

## Tier 1 — MUST-ESCALATE (D, F, B)

For a Tier 1 category, the agent does not proceed without an operator decision. This
holds even if the agent is confident in its own answer, even if a later reviewer would
likely agree, and even if resolving it now would save a round trip.

- **D** — never resolve a fuzzy predicate in a conditional authorization in the same
  turn as the irreversible action it gates (merge, deploy, send, delete). Surface the
  assessment and the gated decision to the operator; wait for the decision before
  acting. Special force applies when the agent itself already flagged the ambiguity
  earlier in the turn — that self-recognition does not get talked back down.
- **F** — never pre-answer a question a brief nominally delegates to an independent
  reviewer or the operator, and never characterize a formally-failing verdict as
  acceptable in an operator-facing summary before the operator has judged it. Present
  verdicts and evidence neutrally; keep independent layers independent.
- **B** — escalate the risk/privacy/security acceptance decision itself (e.g.
  reclassifying a sensitive-data finding's severity), even if a later review layer
  would independently reach the same conclusion. The acceptance is the operator's
  call, not evidence the agent gets to pre-empt.

## Tier 2 — SELF-CHECK THEN ESCALATE-IF-MATERIAL (A, C, E)

For a Tier 2 category, the agent may proceed after running the alignment-audit
self-check below. It escalates only when the check surfaces material stakes;
otherwise it proceeds and discloses the call transparently (state what was decided
and why, don't bury it).

### Alignment-audit self-check procedure

This pattern already appears in mission-session practice; this doctrine names it and
makes it mandatory before a Tier 2 decision:

1. **Trace the decision element back to an authorizing operator decision or spec.**
   For the value, content, stop/proceed call, or mechanism choice in question, find
   the specific operator decision, spec line, or prior approval that grounds it.
2. **Flag anything not so grounded.** If no authorizing decision or spec traces to
   the element, it is ungrounded — proceed to the materiality check.
3. **Evaluate materiality.** An ungrounded element is material if any of:
   - it sets or changes content for a **long-term objective** (Category A);
   - it resolves a **real halt condition** rather than a cosmetic ambiguity
     (Category C);
   - it chooses a **mechanism whose blast radius exceeds the authorized outcome**
     (Category E).
4. **Escalate if ungrounded AND material.** Otherwise, proceed and disclose the call
   transparently — state what was decided, on what basis, and that it fell within the
   authorized scope.

Do not skip the trace step because the element "seems obviously fine" — the trace is
what turns a Tier 2 decision from a silent assumption into a disclosed, audit-able
call.

---

## How to escalate

When escalating (any Tier 1 category, or a Tier 2 category that failed the
materiality check), the agent:

1. **Surfaces its own assessment** — what it would have decided and why, so the
   operator isn't starting from zero.
2. **States the reserved decision explicitly** — name the specific call being handed
   up (the predicate, the classification, the value, the mechanism, the framing) —
   not a generic "need input."
3. **Does not proceed on Tier 1.** No irreversible or outward-facing action is taken
   while the reserved decision is still open. For Tier 2, "proceed" only ever means
   proceeding after a clean self-check — a failed self-check is treated the same as a
   Tier 1 stop.

This mirrors the concrete stop-and-report mechanism dispatch-gate already uses for
frozen-manifest drift (`dispatch-gate/SKILL.md` Step 6): state the mismatch, don't
resolve it unilaterally, and make the stop visible in whatever channel the
dispatcher/operator is actually watching (an explicit `STOP —` prefix in the pane
output, or a PR comment if a PR is already open).
