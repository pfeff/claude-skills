# Reformulation Direction — dispatch-when-ripe (provisional)

> **Status: provisional / direction-setting.** This note records the agreed reformulation *direction*
> for this skill. It changes **no behavior** — every operation and reference still works exactly as
> before. It exists so live consumers and future cycles read the new framing before the functional
> changes land. The functional changes are **staged** (see the gates below); nothing here removes or
> alters existing functionality.

## The true purpose

This skill's true purpose is **dispatch-when-ripe**: hold a decomposition (objective → nodes +
dependencies) and hand a node to a driver/workspace **when its dependencies clear**. It is the
**planner/dispatcher** — *structure + ripeness*, not progress-tracking and not session-driving.

It drifted into two roles it should shed:

1. **An elaborate todo-list / progress tracker** — per-node progress narratives and evaluation
   machinery that accreted while it was doing driver duty.
2. **A forced L1-driver** — the OODA auto-advance loop (`execute-tree` / `next-cycle`) that drives a
   session turn-by-turn toward completion. This "doesn't quite fit" the planner.

## Where the driving goes

The L1-driver role moves to the **durable, event-woken driver** (spec: `../durable-driver/
DRIVER-SPEC.md`, this stack-steward effort). That driver is the executor-completer: it sleeps at
≈zero tokens, wakes on a real signal (inbox message, dependency finishing, PR merging), advances one
unit, and routes completion through an **L2 accept-marker** rather than a transcript check. With the
driver as the real driver, this skill returns to ripe-dispatch and stops driving.

## What this preserves (D6 — do not destroy)

`docs/native-vs-homebrew-boundary.md` (D6) KEEPS this skill as homebrew because native Claude Code has
**no durable cross-session tree, no nested L{N} supervision, no scheduled heartbeat, no multi-repo
dispatch**. Ripe-dispatch **is** that durable decomposition + dependency graph. The reformulation
splits one overloaded homebrew skill into two homebrew pieces (planner here + durable driver) and
moves **none** of the load-bearing durability/nesting/heartbeat/multi-repo properties to a native
primitive.

## Staging (gates — nothing fires yet)

- **Now (additive):** this note.
- **Operator-gated:** rename to end the `/goal` collision (candidate: `dispatch-tree`; final name is
  L2's call and requires operator confirmation) via a deprecation shim so live `/goal-tree` loads do
  not break.
- **Gated on the durable-driver build:** excise the driving loop (`execute-tree` monitor/evaluate/
  advance + entangled evaluation bloat, `next-cycle`, `orient`, drive tails of `dispatch-node` /
  `start-project` / `discuss-dispatch`) **only once the driver replaces it**; retire the rename shim
  only once live consumers have re-grounded.

Full spec, file-by-file classification, migration, and the L1/L2 role+launcher rewrite live in the
stack-steward lane's `REFORM.md`.
