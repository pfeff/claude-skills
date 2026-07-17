# Acceptance / Objective review — depth / proportionality rule

Grounded in the review-architecture design note (signed off
2026-07-08). Consumed alongside `checklist.md` and
`verification-map.md`: before applying the 3-axis checklist,
determine **how much** of it applies to this work product. Today
every PR that reaches the Acceptance review (`l1-review`) or
Objective review (`l2-review`) gets the full ladder; this file
introduces the notion of *depth* the doctrine otherwise lacks.

This file is additive doctrine. It does not rename the review
layers or their marker tokens — see `checklist.md` for the
existing Change/Acceptance/Objective review vocabulary, unchanged.

## Change classes

| Class | Definition | Depth |
|---|---|---|
| **Docs/config-only** | Diff touches only `*.md`, lint-only config (`*.yml`/`*.yaml` with no workflow logic), no doctrine-interpreted file | **Change review only** |
| **Small self-constituent** | Single skill/operation directory touched, ≤ `small_change_max_lines` changed lines (git diff --stat), no new or modified cross-skill contract (no producer/consumer artifact-path change per `verification-map.md`'s doctrine-class sub-checklist item 1), does not touch any surface in the Load-bearing surfaces list below | **Change review only** |
| **Standard** | Everything not in the two classes above and not load-bearing (multi-file, cross-skill, or over the line-count threshold) | **Change + Acceptance review** |
| **Load-bearing** | Touches any surface in the Load-bearing surfaces list below, regardless of size | **Change + Acceptance + Objective review (full ladder)** |

**Standard is its own middle tier**, not folded into either end
bucket. This is a deliberate three-way split, not a two-bucket
shorthand: a multi-file, non-load-bearing change gets Acceptance
review without needing the full ladder. (Design note §6.1.)

## Load-bearing surfaces

Touching **any** of these forces the full ladder (Change +
Acceptance + Objective review), regardless of diff size:

1. **Billing invariant** — any change to tick-delivery mechanism
   (`ct`, `tmux send-keys`) or that introduces `claude -p`/Agent
   SDK/`CronCreate`/`RemoteTrigger` scheduling on the supervision
   path.
2. **Supervision doctrine** — `lN-lifecycle-doctrine`,
   `l1-supervisor`/`l2-supervisor` role contracts,
   `references/supervision.md` under `l1-supervise`/`l2-supervise`.
3. **Tick delivery** — `bin/ct`, cron-tickler registry entries,
   `operations/tick.md` / `operations/adjust-cadence.md`.
4. **Review doctrine itself** — `lN-review-doctrine` SKILL.md,
   `checklist.md`, `verification-map.md` (the 3-axis rubric,
   verdict vocabulary, posting protocol).
5. **Marker/posting-protocol contract** — `<!-- review:metadata
   -->` / `<!-- l1-review:metadata -->` / `<!-- l2-review:metadata
   -->` schema or parsing logic; the dual-surface posting
   discipline.
6. **Cross-skill artifact contracts** — any producer/consumer path
   pair per `verification-map.md`'s doctrine-class sub-checklist
   item 1.
7. **Security/permissions surface** — `.claude/settings.json`,
   hooks, permission gates.
8. **Published host-agnosticism-sensitive surfaces** — anything
   `verification-map.md`'s doctrine-class sub-checklist item 6
   already treats as blocking-on-leak.
9. **Event-triggered review-dispatch path** — `lN-review-doctrine`
   `references/dispatch-procedure.md`, including its "Billing
   invariant" section (the requirement that Step 2's dispatch use
   an interactive Agent-tool subagent, never `claude -p`/Agent
   SDK/a GitHub Action/`CronCreate`/`RemoteTrigger`).

## Thresholds (overridable defaults)

The size threshold for the Small self-constituent class is a
**named, overridable-default parameter**, not hardcoded into the
prose above:

| Parameter | Default | Meaning |
|---|---|---|
| `small_change_max_lines` | `40` | Maximum changed lines (`git diff --stat`) for the Small self-constituent class. |
| `small_change_max_dirs` | `1` | Maximum number of distinct skill/operation directories touched for the Small self-constituent class. |

These are placeholder starting values (design note §6.2), accepted
at sign-off as reasonable defaults, not as validated thresholds. A
future PR may retune either value without a design revisit — that
is the point of naming them as parameters here rather than folding
the numbers into prose.

## See also

- `checklist.md` — the 3-axis checklist this depth rule gates.
- `verification-map.md` — the doctrine-class sub-checklist items 1
  and 6 referenced above.
