# Task-Context Convention

The self-verify skill reads task context from `.claude/task-context.md` in the
worktree root. This file is the **primary** source for Axis 1 (acceptance
criteria) and Axis 3 (objective advancement) evaluation.

## File location

```
<worktree-root>/.claude/task-context.md
```

## Who writes it

The **dispatcher** writes this file at dispatch time — before the background job
starts work. self-verify only READS it; it never writes or updates this file.
Do not build any dispatcher automation on the verifier side — the write step
belongs entirely to the dispatching layer.

## Four-field format

```markdown
# Task Context

**Objective**: <one sentence — what this job is trying to achieve>

**Acceptance test**: <one sentence — the observable condition that proves it done>

**Scope / blast-radius bound**: <one sentence — what this job may touch; explicit
exclusions if relevant>

**Affected surface**: <comma-separated list of paths, skill names, or system
boundaries this job touches>
```

These four fields are the **dispatch-readiness contract** — the same four-line
slice the dispatcher uses to confirm the job is ready to run. Writing them to
`.claude/task-context.md` makes that contract durable and readable by self-verify
at completion time without requiring the dispatch prompt to still be in context.

## Fill heuristics

The four-field schema does not change to express work-class judgment —
that judgment lives in how the dispatcher fills the existing fields.
These heuristics are consumed by `dispatch-gate` when it writes this
file; future needs extend the heuristics below, not the schema.

- **Spike heuristic.** For exploratory intent (a spike), frame the
  Acceptance test field as "findings reported back / what we'll know
  afterward" rather than a shipped-code condition, and set the Affected
  surface field to a throwaway branch or read-only exploration. A spike
  card is self-consistent without any extra flag — `self-verify` judges
  it against whatever acceptance test is actually written, spike or not.
- **Docs-in-surface heuristic.** When the job touches a user-facing
  surface (a skill, an API, a schema), list the affected doc in the
  Affected surface field alongside the code it documents — do not add a
  separate docs field. A user-facing change with no doc listed in
  Affected surface is a clarifying-pass question for the dispatcher, not
  a silent gap.

## Override annotation

When `dispatch-gate` Step 3 records an operator override (dispatching
despite an unresolved field), it appends an annotation **below** the
four fields — never a fifth field. The schema stays exactly four
fields; this is appended content, not schema.

Format — a blockquote paragraph appended after the four-field block:

```markdown
> **Override** (unresolved: <comma-separated field names>): <one-sentence
> reason the operator gave for dispatching anyway>, <date>.
```

Example:

```markdown
> **Override** (unresolved: Acceptance test, Scope / blast-radius bound):
> operator chose "dispatch anyway" during the clarifying pass, 2026-07-03.
```

`self-verify` Axis 1 reads this annotation when present: the named
fields are evaluated as known gaps, not silently treated as complete
(see Axis 1 in `../SKILL.md`).

## Annotation stacking order

`dispatch-gate` may append more than one annotation below the four
fields (Override, Privacy Gate, Metered Sign-off) when more than one
gate fires on the same dispatch. When it does, annotations stack in the
order the gates ran — each remains its own blockquote paragraph appended
below the four fields, never a fifth field.

## Fallback order when absent

If `.claude/task-context.md` is not present, self-verify falls back to the
following chain for both the objective and acceptance criteria (first hit wins):

1. `DESIGN.md` in the workspace root
2. `PLAN.md` in the workspace root
3. The dispatch prompt (available only in the same session; degrades to `warn` if
   not in context)

**When task-context is absent AND no fallback is reachable**, Axis 3 degrades to
`warn` because the objective is not reliably readable. When `.claude/task-context.md`
IS present, Axis 3 must evaluate to `pass` or `fail` — it may not degrade to
`warn` solely on absence of context.

## Example

```markdown
# Task Context

**Objective**: Add a task-context convention to the self-verify skill so
dispatched jobs can surface their objective to the verifier without relying on
an in-session dispatch prompt.

**Acceptance test**: `.claude/task-context.md` is the primary Axis 1 and Axis 3
source in SKILL.md; when present, Axis 3 produces pass/fail not warn; a
reference doc exists at `skills/self-verify/references/task-context.md`;
acceptance-demo.md records a code-change run with populated review_verdict.

**Scope / blast-radius bound**: Only `skills/self-verify/` and `.claude/` in the
worktree may be modified. No other skill, script, or docs directory is in scope.

**Affected surface**: skills/self-verify/SKILL.md,
skills/self-verify/references/task-context.md,
skills/self-verify/references/acceptance-demo.md,
.claude/task-context.md,
.claude/reviews/self-verify-latest.md
```
