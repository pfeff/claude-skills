---
name: lN-lifecycle-doctrine
description: Shared doctrine reference for child-session lifecycle management at every supervision layer. Defines the generic child state machine (spawned→working→complete→retired, context-pressure axis, edge states), per-state entry/act/exit rules, complete-check guards, teardown discipline, idle-fleet handling, inter-actor inbox-on-nudge delivery (ac_message_send/ac_inbox_query/ac_ack; send-keys = wake nudge only), and per-layer executor bindings for l1-supervise (child=L0) and l2-supervise (child=L1). This skill has no operations — it is reference content read by l1-supervise and l2-supervise at tick time. Never inline this doctrine into the supervise skills themselves.
allowed-tools:
  - Read
version: 1.2.0
---

# lN-lifecycle-doctrine — shared child-session lifecycle doctrine

This skill is a doctrine-only reference. It defines child-session
lifecycle management generically — applicable at any supervision
layer in a multi-layer agent tree (L2 supervises L1, L1 supervises
L0). The actual supervision skills (`l1-supervise`, `l2-supervise`)
are thin executors that load this doctrine at tick time and apply it
at their layer.

`version: 1.2.0` reconciles two forked tracks into one source of
truth: the canonical monolithic 1.1.0 and the runtime split 1.0.0.
The reconciled body is a superset of both — see `references/lifecycle.md`.

## Source of truth

| File | Purpose |
|------|---------|
| `references/lifecycle.md` | Generic state machine, per-state rules, complete check, teardown guards, idle-fleet handling (incl. confirmed-idle auto-stop + idle-and-blocked), context-pressure axis, inter-actor inbox-on-nudge delivery, interactive-menu answering, platform constraints + scoped agent-team pattern, and per-layer executor bindings. |

## Invariants

**Recursive ownership.** Each supervisor owns the lifecycle of its
direct children — L2 owns L1, L1 owns L0. No layer auto-stops its
*children*; the parent always decides. A supervisor MAY auto-stop
its **own** tick loop once its fleet is confirmed idle.

**Doctrine-only, no inlining.** This skill has no operations.
`l1-supervise` (child=L0) and `l2-supervise` (child=L1) Read
`references/lifecycle.md` at tick time and never inline its content.

**No-nesting + durability is the real platform limit** — not
"a layer is always a session." Substrate (session / subagent /
Workflow / agent team) is chosen per layer within that limit; only
the durable multi-session tree must be separate sessions.

**Termination is the supervisor retiring the child**, gated on all
teardown guards (never-teardown-own-session, PR merged/abandoned,
no-unpushed, no-dirty-tracked, and — for objective-scoped children —
an objective-accept marker).

## When this doctrine is wrong

If a rule in `references/` is wrong for the current iteration,
**fix it here** via PR against `pfeff/claude-skills`. Do not patch
the rule inside `l1-supervise` or `l2-supervise` — that is the
doctrine-drift failure mode this split exists to prevent.

## See also

- `lN-review-doctrine` — the parallel review doctrine; lifecycle
  doctrine's `pr-open → fixing → merged` states reference the
  review-cycle states defined there.
- `goal-tree` `references/layer-model.md` — canonical "what can be a
  layer" platform constraint and tree-depth → layer mapping.
- `l1-supervise` skill — executes this doctrine at N=1 (child=L0).
- `l2-supervise` skill — executes this doctrine at N=2 (child=L1).
