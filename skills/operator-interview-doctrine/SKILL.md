---
name: operator-interview-doctrine
description: Shared doctrine reference for operator-interview skills. Holds the question taxonomy (context-free questions first, then funnel), the ask-vs-default rule gated on reversibility, the adaptive-depth rubric, stop conditions, AskUserQuestion batch rules, the spec-note schema, and the sign-off protocol. This skill has no operations — it is reference content read by `/operator-interview` (and any caller that elicits a spec from an operator) at interview time. Never inline this doctrine into the consumer skills themselves — operator-confirmed rules must persist in one place.
allowed-tools:
  - Read
version: 1.0.0
---

# operator-interview-doctrine — shared operator-interview doctrine

This skill is a **doctrine-only reference**. It defines what an operator interview
*is* — how to elicit a specification from a human operator without over-asking or
under-asking. The actual interview skill (`operator-interview`) is a thin executor
that loads this doctrine at interview time and applies it.

All the doctrine lives in this file's body so it is deliverable by name (invoke the
skill; the rendered body enters context). If you find yourself about to add an
interview rule by editing the `operator-interview` skill, **edit this file
instead** — that is the doctrine-drift failure mode this split exists to prevent.

## Invariants

The interview **calibrates asking to ambiguity**. An LLM's built-in bias is to
under-ask — to assume a plausible answer and proceed silently. This doctrine exists
to counteract that bias: where a decision is irreversible or genuinely ambiguous,
**ask**; where it is reversible and low-impact, apply a recommended default and
record it as overridable. Neither silent assumption nor reflexive over-elicitation
is acceptable.

The interview separates **what/why (the spec) from how (the plan)**. The spec
captures the problem, the decisions, the requirements, and the acceptance criteria.
It does NOT prescribe implementation. Planning is a downstream activity over a
signed-off spec.

A spec is authority-bearing only when the operator has **signed off**. Build and
dispatch are gated on frontmatter `status: signed-off`; a `draft` spec confers no
build authority. Sign-off binds to the spec **as signed** — a material change to a
signed-off spec revokes that authority until the operator re-signs (see the sign-off
protocol's re-sign rule).

---

## Question taxonomy

### Context-free questions first

Before any topic-specific question, ask the **context-free questions** (Gause &
Weinberg): questions whose answers frame every later answer, regardless of the
topic. The two load-bearing ones:

- **The real reason.** "What is the real problem this solves?" — the surface
  request is often a proposed solution, not the underlying need. Elicit the need.
- **What success is worth.** "What is solving this worth — and how will we know it
  worked?" — establishes the value and the shape of the acceptance criteria.

Context-free questions are asked **as prose**, open-ended, before the structured
batches. They are not multiple-choice; their job is to surface the operator's framing
in the operator's own words.

### Then funnel

After the context-free frame, run the **funnel**:

1. **Broad open** — open-ended questions that let the operator describe the space in
   their own terms.
2. **Probes** — narrower follow-ups that pursue specifics surfaced by the open
   answers (the "tell me more about X" move).
3. **Closed confirmation** — yes/no or pick-one questions that confirm a specific
   understanding before it is written into the spec.

Funnel direction is **broad → narrow**, never the reverse. Do not open with a closed
question; you will anchor the operator and miss the framing.

### Neutral, non-leading wording

Every question is worded **neutrally**. Do not embed the answer you expect, do not
signal a preferred option through tone or ordering, do not ask "don't you think we
should X?" Leading questions corrupt the elicited spec — the operator confirms your
assumption rather than stating their need.

---

## Ask-vs-default rule (gated on reversibility)

For every decision the spec must record, classify it by **reversibility** before
deciding whether to ask:

| Decision type | Door | Action |
|---------------|------|--------|
| Low-impact, easily reversed | **two-way door** | Apply the recommended default. Record it in the spec as an **overridable** decision (the operator can change it later at low cost). |
| Irreversible or expensive to reverse | **one-way door** | **Always ask.** Never apply a default for a one-way door, no matter how confident the recommendation. |

Reversibility — not confidence — is the gate. A high-confidence recommendation for a
one-way door still gets asked, because the cost of being wrong is unrecoverable.

When information needed for a decision is **unknown**, mark it `[NEEDS
CLARIFICATION]` in the working spec. **Never silently assume.** A `[NEEDS
CLARIFICATION]` marker is a visible, trackable gap — a silent assumption is an
invisible defect.

---

## Adaptive-depth rubric

The interview runs at one of three depths. Suggest a depth from task size and
reversibility; the operator may override.

| Depth | Suggested when | Shape |
|-------|----------------|-------|
| **quick** | Small task, mostly two-way doors, low ambiguity | Context-free questions + a single confirmation batch |
| **standard** | Moderate task, mixed doors | Full funnel, one or two scoping batches, gap probes |
| **thorough** | Large task, OR any material one-way door, OR high ambiguity | Full funnel, multiple scoping batches, exhaustive gap probing up to the clarification cap |

**One-way doors pull depth up.** Even a small task that contains an irreversible
decision is suggested at `standard` or `thorough`, because the irreversible decision
must be asked and confirmed.

The suggested depth is presented to the operator and is **overridable** — the
operator's chosen depth wins.

---

## Stop conditions

Over-elicitation destroys value: every extra question past the point of usefulness
costs the operator's attention and signals the interviewer cannot judge sufficiency.
Stop when **either** holds:

- **~70% of needed info.** Stop once roughly 70% of the information needed to write a
  buildable spec is gathered. The remaining gaps are recorded as `[NEEDS
  CLARIFICATION]` or as overridable defaults — they do not block sign-off if the
  operator accepts them.
- **Saturation.** Stop when answers stop adding information — when new questions
  return restatements of what is already known. Saturation is a signal that the
  productive interview is over regardless of the 70% estimate.

Whichever fires first ends elicitation. Continuing past a stop condition is
over-elicitation.

---

## AskUserQuestion usage rules

Structured questions go through `AskUserQuestion`. The batch rules:

- **≤4 questions per batch.** Do not exceed four questions in a single
  `AskUserQuestion` call.
- **≤4 options per question.** Do not exceed four options for any one question.
- **Every option carries a recommended default.** Exactly one option per question is
  marked as the recommended default, so the operator can accept the recommendation
  with minimal effort. A question with no recommended default violates the ask-vs-
  default rule — the interviewer is supposed to have a recommendation.

Context-free questions and broad-open funnel questions are asked **as prose**, not
through `AskUserQuestion` — they are open-ended and have no option set. Reserve
`AskUserQuestion` for scoping batches and closed confirmation.

---

## Spec-note schema

The interview produces a **spec note** written to the operator's Obsidian vault via
the `obsidian-notes` skill. The schema:

### Frontmatter

| Field | Value |
|-------|-------|
| note type / tag | `spec` (tag `#spec`) |
| `status` | `draft` during the interview → `signed-off` after operator sign-off → back to `draft` on a material change (re-sign) |
| `signed_off` | the sign-off date (set when `status` becomes `signed-off`; cleared when a material change resets `status` to `draft`) |
| `supersedes` | wiki-link to a prior spec this one replaces, when applicable |

### Body sections

| Section | Content |
|---------|---------|
| **Problem / Why** | The real problem (from the context-free questions) and what solving it is worth. |
| **Decisions** | Each recorded decision, marked as asked-and-confirmed or as an overridable default (per the ask-vs-default rule). |
| **Requirements** | Each requirement is **singular** (one requirement per entry), **measurable**, and carries a **named verification method** — `test`, `demo`, or `inspect`. |
| **Acceptance Criteria** | In **EARS** form: `WHEN <trigger> THEN system SHALL <response>`. Use `SHALL CONTINUE TO` for regression-locks (behavior that must not break). |
| **Traceability** | Links to Jira / PR(s) / related `[[notes]]` — **only when relevant**. Omit the section (or the line) when N/A; do not write empty placeholders. |
| **Deferred / assumptions** | Deferred scope and recorded assumptions, including every `[NEEDS CLARIFICATION]` the operator chose to defer. |

The spec ends with an **end-to-end verification step** — a single named check that
exercises the whole deliverable, distinct from the per-requirement verification
methods.

The canonical worked example is the spec note that this component's own build
produced:
`Notes/2026/06/2026-06-30-operator-interview-spec.md` in the host's Obsidian vault.
Match its shape.

---

## Sign-off protocol

1. **Playback.** Before asking for sign-off, play the assembled spec back to the
   operator — Problem/Why, Decisions, Requirements, Acceptance Criteria, and any
   `[NEEDS CLARIFICATION]` still open. Playback is the operator's last chance to
   correct before the spec becomes authority-bearing. Playback is sent as its own
   message and **ends with the played-back spec content** — it does not end with a
   question, and it does not carry the sign-off ask.
2. **Explicit sign-off.** The sign-off ask is a **separate, subsequent turn**: a
   single, standalone question — e.g. "Do you sign off on this spec?" — asked on its
   own. Never bundle it with "or anything to change first?", never append it to the
   playback message, never combine it with any other ask. If the operator raises a
   change during or after playback, handle that change as its own turn — replay the
   affected section if needed — before returning to the standalone sign-off ask; do
   not try to cover both "any changes?" and "sign off?" in one compound question.
   The operator must explicitly sign off. Silence, "looks fine," or a non-answer is
   NOT sign-off. Until explicit sign-off, the spec stays `status: draft`.
3. **Promote.** On explicit sign-off, set frontmatter `status: signed-off` and
   `signed_off: <date>`. Only then does the spec confer build authority.
4. **Gate.** Build and dispatch consumers read `status` from frontmatter and proceed
   only on `signed-off`. A `draft` spec is not a build authorization.
5. **Re-sign on material change.** Sign-off binds to the spec as it read when signed.
   A **material change** — any edit to **Decisions**, **Requirements**, or
   **Acceptance Criteria** — to a `signed-off` spec revokes sign-off: reset
   frontmatter `status: draft` and clear `signed_off` at the moment the change is
   written, then run the protocol again from playback (step 1) before the spec
   regains build authority. Non-material edits — typo/formatting fixes, added
   traceability links, clarifying prose that changes no decision, requirement, or
   criterion — do **not** trigger re-sign. When unsure whether a change is material,
   treat it as material and re-sign; the cost of an unnecessary re-sign is one
   confirmation, the cost of a missed one is a build against an unratified spec.

---

## When this doctrine is wrong

If a rule above is wrong for the current iteration, **fix it here** via a PR against
this skill. Do not patch the rule inside `operator-interview` — that skill is a pure
executor of this doctrine. Doctrine edits land on a branch and ship as a versioned
doctrine update.

## See also

- `operator-interview` skill — executes this doctrine: runs the funnel, writes the
  spec note, and drives the sign-off protocol.
- `obsidian-notes` skill — CLI surface for the spec-note write (`create`,
  `property:set`, `append`) and the non-blocking failure contract.
- `planning-workflow` skill — the downstream consumer: planning operates over a
  `signed-off` spec (what/why) to produce a plan (how).
