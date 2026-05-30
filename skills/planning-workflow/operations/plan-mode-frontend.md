# Plan Mode Front-End

Plan Mode (`EnterPlanMode` → interactive drafting → `ExitPlanMode`) is the
interactive drafting front-end for the planning workflow. It brackets the phase
pipeline: phases 1–7 draft **ephemerally** inside Plan Mode, and only the
post-approval **materialization** step (which also runs phase 8, ADR
propagation) writes the durable `DESIGN.md`/`PLAN.md` and seeds native
`TaskCreate`/`TaskList`.

**Durable docs remain authoritative.** Plan Mode state is ephemeral — it resets
when the user accepts and the session leaves the mode (acceptEdits). Nothing in
Plan Mode is a source of truth. The materialization step is the bridge from the
ephemeral draft to the durable artifacts that ARE authoritative thereafter.

## When

At the start of any planning session, before phase 1 (problem validation), when
the harness exposes Plan Mode (`EnterPlanMode`/`ExitPlanMode` tools available).
If Plan Mode is unavailable, run the pipeline directly and write the durable
artifacts as before — Plan Mode is the front-end, not a hard dependency.

## Flow

```
EnterPlanMode
      │  (session is read-only; no durable writes)
      ▼
┌──────────────────────────────────────────────┐
│ Phases 1–6: interactive drafting              │
│   problem validation → DESIGN.md reconcile →  │
│   fast-path gate → solution search →          │
│   research gating → SpecFlow → detail level   │
│ (research + interview only; nothing written)  │
└──────────────────────────────────────────────┘
      │
      ▼
┌──────────────────────────────────────────────┐
│ Phase 7: assemble the PLAN.md draft body      │
│ (in-memory; the candidate plan + criteria)    │
└──────────────────────────────────────────────┘
      │
      ▼
ExitPlanMode  ──→ present the assembled draft (plan body +
      │            acceptance criteria) for user approval
      │
      ├── rejected / revise → stay in Plan Mode, refine, re-present
      │
      ▼ (approved)
┌──────────────────────────────────────────────┐
│ MATERIALIZATION (durable, authoritative)      │
│  1. Write DESIGN.md updates reconciled in     │
│     phase 2 (durable design record)           │
│  2. Write PLAN.md (phase 7 step 5)            │
│  3. Seed native Tasks: TaskCreate per         │
│     acceptance criterion / phase; TaskList    │
│     to confirm the seeded set                 │
│  4. Run ADR propagation (phase 8)             │
└──────────────────────────────────────────────┘
```

## Steps

### 1. Enter Plan Mode

Call `EnterPlanMode` at session start. While in Plan Mode the drafting phases do
research and interview the user but make **no durable edits** — the plan is held
as the in-progress draft.

### 2. Draft (phases 1–7)

Run the phase pipeline. Phases 1–6 gather context; phase 7 assembles the PLAN.md
draft body and merged acceptance criteria in memory. Do not write `DESIGN.md` or
`PLAN.md` yet.

### 3. Exit Plan Mode for approval

Call `ExitPlanMode` with the assembled draft (plan body + acceptance criteria).
The user approves, or asks for revisions. On revision, refine the draft and
re-present — Plan Mode state is ephemeral, so iterate freely.

### 4. Materialize on approval

Only after approval, write the durable artifacts (this is the authoritative
hand-off):

1. **DESIGN.md** — apply the design updates reconciled in phase 2.
2. **PLAN.md** — write per `operations/plan-generation.md` step 5.
3. **Seed native Tasks** — per `operations/plan-generation.md` step 6:
   `TaskCreate` per acceptance criterion (or phase, for "A Lot" plans), then
   `TaskList` to confirm. The native task store + `PLAN.md` checkboxes are the
   progress mechanism (no `TodoWrite`).
4. **ADR propagation** — run `operations/adr-propagation.md` (phase 8).

After materialization, `DESIGN.md`/`PLAN.md` and the seeded native tasks are the
source of truth. Plan Mode has served its purpose and its ephemeral state is
discarded.
