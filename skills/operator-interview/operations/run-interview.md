# Run Interview

The default operation for `/operator-interview <topic>`. Elicits a buildable spec
from the operator and writes it as a signed-off spec note. Applies the
`operator-interview-doctrine` throughout — load that doctrine before running this
operation.

## Parameters

- `topic` (optional): the interview subject. If blank, step 1 elicits it.

## Execution Steps

### 1. Context-free framing (prose)

Ask the **context-free questions** as prose (not AskUserQuestion), per the doctrine's
question taxonomy:

- The **real reason** — "What is the real problem this solves?" Elicit the underlying
  need, not the proposed solution.
- **What success is worth** — "What is solving this worth, and how will we know it
  worked?" This frames the value and the shape of the acceptance criteria.

These answers frame everything downstream. Capture them as the working
**Problem / Why**.

### 2. Suggest depth

From task size and reversibility, suggest an adaptive depth (`quick` / `standard` /
`thorough`) per the rubric. Any material one-way door pulls the suggestion up. Present
the suggested depth to the operator; the operator's choice overrides.

### 3. Funnel — broad open (prose)

Ask broad, open-ended questions that let the operator describe the space in their own
terms. Neutral, non-leading wording. Listen for the decisions the spec must record and
the gaps that need probing.

### 4. Funnel — scoping batches (AskUserQuestion)

Run scoping via `AskUserQuestion` batches. Per the doctrine's batch rules:

- ≤4 questions per batch.
- ≤4 options per question.
- Every question's option set includes exactly one **recommended default**.

For each decision, apply the **ask-vs-default rule gated on reversibility**:

- **Two-way door** (low-impact, reversible): you MAY apply the recommended default and
  record it in the spec as an overridable decision — still surface it in a batch so the
  operator can override cheaply.
- **One-way door** (irreversible): you MUST ask; never default it, regardless of
  confidence.

Run as many batches as the chosen depth warrants (one for `quick`, one–two for
`standard`, multiple for `thorough`).

### 5. Gap probes

Probe the specifics surfaced by the open answers (the "tell me more about X" move).
For any decision whose information is **unknown**, mark it `[NEEDS CLARIFICATION]` in
the working spec. **Never silently assume.**

### 6. Bounded clarification gate

Resolve the open `[NEEDS CLARIFICATION]` markers through a **bounded** clarification
gate:

- **Cap at ~5 clarification questions.** Do not exceed roughly five — over-elicitation
  destroys value.
- **Write each answer back before asking the next.** Update the working spec with each
  clarification's answer before posing the next question, so the spec always reflects
  what is known and the next question is informed by the last answer.
- **Honor the stop conditions.** Stop the gate when ~70% of needed info is gathered OR
  answers saturate (stop adding information), whichever fires first. Any markers the
  operator chooses to defer are recorded in **Deferred / assumptions**, not forced to
  resolution.

### 7. Assemble the working spec

Compose the spec body per the doctrine's spec-note schema:

- **Problem / Why** — from steps 1 and 3.
- **Decisions** — from step 4; each marked asked-and-confirmed or overridable default.
- **Requirements** — each **singular**, **measurable**, with a named verification
  method (`test` / `demo` / `inspect`).
- **Acceptance Criteria** — EARS form: `WHEN <trigger> THEN system SHALL <response>`;
  `SHALL CONTINUE TO` for regression-locks.
- **Traceability** — Jira / PR(s) / related `[[notes]]` only when relevant; omit when
  N/A.
- **Deferred / assumptions** — deferred scope, recorded assumptions, and any deferred
  `[NEEDS CLARIFICATION]`.
- End the spec with a single **end-to-end verification step** that exercises the whole
  deliverable.

### 8. Playback

Play the assembled spec back to the operator — Problem/Why, Decisions, Requirements,
Acceptance Criteria, and any still-open `[NEEDS CLARIFICATION]`. This is the
operator's last chance to correct before the spec becomes authority-bearing.

### 9. Write the draft note

Write the spec note via the `obsidian-notes` skill (CLI-first; never freehand
`Write`/`Edit` to the vault). Read `~/.claude/skills/obsidian-notes/SKILL.md` for the
CLI surface and the non-blocking failure contract.

1. Source the host-config helper to resolve `OBSIDIAN_CLI` / `OBSIDIAN_VAULT`.
2. Probe the target path for collision (`read path=…`); increment the slug/`-NN-`
   prefix if taken.
3. Create the note from the vault `Reference` template (the spec note's frontmatter
   shape — `type: reference`, `tags`, `status`).
4. Set frontmatter via `property:set` (pass `type=` on every call): note type/tag
   `spec` (add `spec` to `tags`, `type=list`), `status=draft` (`type=text`), and
   `supersedes` (`type=text`) when this spec replaces a prior one.
5. `append` the body sections composed in step 7.

### 10. Explicit sign-off and promote

Obtain **explicit** operator sign-off per the doctrine's sign-off protocol. Silence,
"looks fine," or a non-answer is NOT sign-off — the note stays `status: draft` until
the operator explicitly signs off.

On explicit sign-off, promote via `property:set`:

- `status=signed-off` (`type=text`)
- `signed_off=<date>` (`type=date`)

Only then does the spec confer build authority. Build and dispatch consumers gate on
`status: signed-off`.

### 11. Re-sign on material change

When editing an already `signed-off` spec, apply the doctrine's re-sign rule. A
**material change** — any edit to the Decisions, Requirements, or Acceptance Criteria
sections — revokes sign-off. At the moment the change is written, reset the
frontmatter via `property:set`:

- `status=draft` (`type=text`)
- clear `signed_off` (`property:set signed_off= type=date`, i.e. empty value)

Then re-run the protocol from playback (step 8) → explicit sign-off (step 10) before
the spec regains build authority. Non-material edits (typo/formatting fixes, added
traceability links, prose that changes no decision/requirement/criterion) do not
trigger re-sign; when unsure, treat the change as material and re-sign.

## Output

The spec note path and its final `status`. On sign-off, `status: signed-off` with
`signed_off` set; otherwise `status: draft` with the open `[NEEDS CLARIFICATION]`
markers recorded in Deferred / assumptions.

## Error Handling

| Condition | Behavior |
|-----------|----------|
| Operator declines to answer a context-free question | Record the gap as `[NEEDS CLARIFICATION]`; proceed — do not assume. |
| Clarification gate hits the ~5 cap with markers open | Stop; record the remaining markers in Deferred / assumptions; proceed to playback. |
| Stop condition fires before all decisions are resolved | Stop elicitation; record open markers as deferred; do not over-elicit. |
| Operator does not explicitly sign off | Leave `status: draft`; report the note path and that build authority is not granted. |
| Obsidian CLI write fails | Per the obsidian-notes non-blocking failure contract: emit the `[obsidian-notes] <output>` warning and report the failure; do not silently claim success. |
