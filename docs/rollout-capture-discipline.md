# Rollout Capture & Finish Gate — Discipline for the agent-modernization Rollout

Author-facing guidance for **how agent-modernization rollout work is captured and
gated before it ships**. Companion to
[`docs/native-vs-homebrew-boundary.md`](./native-vs-homebrew-boundary.md) (the
routing/boundary rules); this doc covers the *process* around landing those docs,
not the routing decisions themselves.

> **Scope.** This is a docs-only discipline note. The rollout it describes goes
> live only via the operator-gated **CUTOVER** — landing a doc on the lane PR is
> not the same as activating it against the live fleet.

## The finish gate (DDD step 5b)

The repo follows documentation-driven development: **documentation is updated
alongside code, not after**, and the `/finish` workflow verifies it. Concretely,
`/finish` **step 5b** verifies that every *affected doc* was updated before the PR
is considered finishable; missing doc updates are flagged.

Applied to the agent-modernization rollout, the **affected docs** that the finish
gate checks are:

- `docs/native-vs-homebrew-boundary.md` — the native↔homebrew KEEP/ADOPT map,
  the Workflow↔goal-tree routing rule, and `/goal` usage (the C.1 boundary doc).
- The **A-lane surface stubs** inside that boundary doc
  (`TODO-pending-A.1` / `A.2` / `A.4`) — these must be filled, or remain honestly
  stubbed, as the A-lane surface lands; they are tracked, not silently dropped.
- This **capture-discipline doc** — the rollout/finish process itself.

A rollout change is not "finished" until each affected doc above is updated (or its
stub is consciously preserved with the pending marker).

## The capture discipline

Rollout work is **journaled in Obsidian via the `obsidian-notes` skill — never by
freehand-writing the vault.**

Each lane cycle produces a **journal-note evidence artifact** in the vault:

- A per-cycle **decision note** records the cycle's scoping decision and outcome
  (e.g. the C.1-cycle note that records the scoped-dispatch decision and the
  CLEAN `/l1-review` verdict).
- A **rollout/capture note** records what the rollout has shipped so far, the
  boundary at a glance, and how it is captured and gated.

These notes are the **capture-SC evidence** for the lane — the evidence is the
journal-note link, not a PR. Each follow-up cycle adds its own evidence note
rather than overwriting prior ones.

## Regression gate (cutover)

Before CUTOVER, the **outer-loop regression proof** must show that grafting the
adopted native primitives into the inner loop did **not regress** the homebrew
outer-loop capabilities (cross-session durability, scheduled supervision, durable
goal trees, multi-repo coordination).

That regression proof is produced by **node B.3** (a different lane) and is **not
yet landed**. It is referenced here as a rollout done-criterion but the evidence
does not exist yet:

- **Outer-loop regression proof** — `TODO-pending-B.3`.

> Per the capture discipline, this is left as an explicit pending stub — the
> regression result and its evidence link are **not fabricated**. A follow-up
> cycle fills it once B.3 lands.

## Related

- [`docs/native-vs-homebrew-boundary.md`](./native-vs-homebrew-boundary.md) —
  the native↔homebrew routing/boundary rules this rollout ships.
- Parent spec: `claude-agents-explore-updating-workflows/SPEC.md` (§0 rollout/
  capture discipline; §2 SC-docs) and `DESIGN.md` (D1–D9, D7).
