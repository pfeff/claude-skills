# Guardian Loop — Alternative Harness Shortlist

**Status:** WIP (design / shortlist-to-prototype)
**Date:** 2026-08-03
**Owner:** operator (Matt)
**Process:** Applied the WIP SDLC (planning-workflow) — problem validation → criteria →
candidate landscape → shortlist → spike plans → decision rubric.

---

## Problem Validation

**User:** The operator, running the **Guardian** cadence/goals loop — the personal
life-OS built on the `cadence-goals` skill over Obsidian periodic notes
(annual → quarterly → monthly → weekly → daily OODA slices).

**Pain (why confidence in Claude Code as the harness is dropping):**
1. **Fundamentally misreads instructions** — misunderstands the spec it's handed.
2. **Modifies the loop instead of executing it** — the highest-signal failure: given a
   fixed loop to *run*, it drifts into *editing the loop machinery* (skills, notes,
   automation) rather than performing the tick.
3. **Requires too much handholding** — not autonomous enough to run unattended.
4. **Serializes work that should be parallel** — runs lanes/tasks one at a time when the
   cadence model explicitly supports 3–4 concurrent active lanes.

**Current workflow:** Claude Code is the single-agent harness. It loads `cadence-goals`,
reads periodic notes, and executes a tick. The skill is already **runtime-portable by
design** — it has a Codex sync target (`~/.codex/skills/cadence-goals/`) and reads
`~/CODEX.md` / `~/AGENTS.md` / `~/.claude/CLAUDE.md`. So "swap the harness, keep the
substrate" is already an anticipated axis, not a rewrite.

**Success criteria (this deliverable):** A shortlist of **2–3 finalist harnesses**, each
with a spike/prototype plan and pass/fail criteria, so the operator can trial before
committing. Not a final pick; not a full migration plan.

**Validation method:** Confirmed via interview.

---

## Evaluation Criteria

Derived directly from the pains and constraints. Weighted by how load-bearing the pain is.

| # | Criterion | Why it matters | Weight |
|---|-----------|----------------|--------|
| C1 | **Execute-don't-edit separation** | The #1 failure. A harness where the *loop is code the model can't rewrite* structurally prevents meta-drift. | ★★★ |
| C2 | **Instruction fidelity** | Misreading the spec is failure #2. Spec-driven dispatch + an evaluation gate (judge output vs. acceptance criteria) catches "correct-but-wrong." | ★★★ |
| C3 | **Autonomy (low handholding)** | Must run a tick unattended and report done/blocked without babysitting. | ★★★ |
| C4 | **Parallel dispatch** | Cadence model runs 3–4 active lanes; harness must fan out, not serialize. | ★★ |
| C5 | **Cost ceiling** | A persistent/high-frequency loop can't blow up spend. | ★★ |
| C6 | **Low-maintenance** | Operator won't hand-maintain fragile bespoke orchestration. | ★★ |
| C7 | **KB compatibility** | Must work against the Obsidian knowledge base. Migrating the KB to the cloud is acceptable if it buys reliability. | ★★ |

**Design insight:** pains #1 and #2 are *not* "use a smarter model" problems — they are
**control-flow** problems. A more capable single-agent CLI (Claude Code, Codex, Gemini
CLI) still owns its own control flow and can still wander off-spec. The structural fix is
to move loop control *out* of the model and into the harness: the harness owns the loop;
the model only fills in bounded steps against acceptance criteria. Every finalist below is
scored first on C1/C2 for that reason.

---

## Candidate Landscape (scan)

| Candidate | Class | One-line |
|-----------|-------|----------|
| **Hermes / Agent-Coordinator (AC)** | Own spec-driven dispatch system | Goal-tree + container dispatch + LLM-judge; the Guardian loop becomes a goal tree. Anchor candidate (operator asked to start here). |
| **Deterministic harness on Claude Agent SDK** | Bespoke thin harness | Loop control flow is *code*; model called per-slice as a subordinate step. Directly targets C1. |
| **Codex CLI swap** | CLI coding agent | Same skills/vault substrate, different runtime. Sync target already exists → cheapest A/B. |
| Gemini CLI / opencode / Aider | CLI coding agents | Same class as Codex; deferred — one CLI A/B (Codex) is enough signal for now. |
| LangGraph / Temporal-style engine | Durable workflow engine | Heavier; overlaps the "deterministic harness" idea. Fold into finalist B rather than run separately. |

Three finalists carry the shortlist. The rest are explicitly deferred (logged so we don't
pretend the scan was exhaustive when it wasn't): the CLI peers collapse into the one Codex
A/B, and the workflow-engine option collapses into the deterministic-harness spike.

---

## Shortlist — 3 Finalists to Prototype

### Finalist A — Hermes / Agent-Coordinator goal-tree dispatch *(anchor)*

**What it is:** The operator's own AC system, reached via the `hermes_mcp` interface.
Goal trees (dependency-ordered task decomposition), spec-driven L0 dispatch into
containers, LLM-as-judge evaluation against acceptance criteria, telemetry. Per
`PRODUCT.md`, the autoresearch/Guardian work is "AC's first and most demanding customer."

**How it scores against the pains:**
- **C1 (execute-don't-edit): Strong.** The loop lives in the goal-tree structure, not in
  the L0 agent's head. An L0 node receives a spec with acceptance criteria and produces an
  artifact; it has no mandate to rewrite the tree. Meta-drift is structurally out of scope.
- **C2 (fidelity): Strong.** The evaluation engine (LLM judge + standing rules) is a first-
  class gate — "did it meet the spec," not "did it run." This is the direct antidote to
  misreading instructions.
- **C4 (parallel): Strong.** Dispatch of multiple ready nodes is native — the cadence's
  3–4 active lanes map onto parallel L0 nodes.
- **C5 (cost): Weak-to-medium.** Container-per-node + judge passes multiply model calls.
  Needs a budget guard for a daily/weekly cadence.
- **C6 (maintenance): Weak (today).** `PRODUCT.md` flags real reliability gaps — the
  `hermes_mcp` SSE race condition and container-dispatch fragility. This is the risk.
- **C7 (KB): Medium.** L0 runs in a container with an injected workspace; the Obsidian
  vault must be mounted or the relevant slice synced in. Cloud KB migration helps here.

**Spike plan:**
1. Model **one cadence tick** (a single daily OODA slice, or a weekly rebalance) as a small
   goal tree: 2–3 lane nodes + a synthesis node.
2. Dispatch it through Hermes; let the judge evaluate node output against the cadence-note
   acceptance criteria (`cadence-goals` Light Validation checklist makes a natural rubric).
3. Mount/sync the vault slice the nodes need; write results back as periodic-note edits.

**Pass/fail:**
- ✅ Tick completes unattended, nodes ran **in parallel**, judge caught ≥1 off-spec output.
- ✅ Zero unrequested edits to loop machinery (skills/automation) — only note/state writes.
- ❌ SSE race / dispatch flakiness forces manual intervention > once per tick.

**Risks:** Reliability gaps are the operator's own known open work; prototyping Guardian on
AC doubles as dogfooding AC. Cost per tick needs measuring before it runs on a cadence.

---

### Finalist B — Deterministic harness on the Claude Agent SDK

**What it is:** A thin, *code-owned* control loop. A scheduler (launchd/cron, or a durable
step engine if crash-recovery matters) fires each tick; the tick is a hard-coded sequence
(orient → per-lane execute → validate → write-back) implemented with the Claude Agent SDK.
The model is invoked **per bounded step**, never handed the whole loop.

**How it scores against the pains:**
- **C1 (execute-don't-edit): Strongest.** The loop *is* code. The model literally cannot
  rewrite control flow because it never holds it — it only fills in a step's output. This
  is the cleanest structural kill of the #1 pain.
- **C2 (fidelity): Strong.** Each step has a narrow, testable contract; a validation step
  (reuse `self-verify` / cadence Light Validation) gates write-back.
- **C3 (autonomy): Strong.** Scheduler-driven, unattended by construction.
- **C4 (parallel): Strong.** Fan out per-lane calls with async concurrency; the operator
  sets the concurrency budget explicitly.
- **C5 (cost): Strong.** Operator controls exactly how many model calls each tick makes.
- **C6 (maintenance): Medium.** It's bespoke code to own — but *small* and deterministic,
  far less surface than AC's container fleet.
- **C7 (KB): Strong.** Runs locally against the vault directly; no container mount dance.

**Spike plan:**
1. Pick one cadence tick (daily OODA).
2. Write the control flow as code: `orient()` reads periodic notes → `execute_lane()` per
   active lane (parallel) → `validate()` → `write_back()` edits notes.
3. Wrap each model call with the existing skill instructions as the step prompt; run under
   launchd on a daily trigger for a week.

**Pass/fail:**
- ✅ A week of daily ticks runs with **zero** hand-holding and zero loop-machinery edits.
- ✅ Lanes execute concurrently; validation blocks ≥1 bad write-back over the week.
- ❌ Bespoke code needs operator debugging more than once in the week (maintenance fail).

**Risks:** Upfront build cost; you own the code. Mitigant: it's intentionally small, and it
reuses existing skills as step prompts rather than reinventing them.

---

### Finalist C — Codex CLI swap *(cheapest A/B)*

**What it is:** Run the **same** `cadence-goals` skill under Codex instead of Claude Code.
The sync target (`~/.codex/skills/cadence-goals/`) already exists, so this is a runtime
swap with zero substrate change — a controlled A/B on *instruction fidelity* alone.

**How it scores against the pains:**
- **C1/C2:** *Test, don't assume.* Codex is still a single-agent CLI that owns its own
  control flow, so it does **not** structurally fix meta-drift the way A or B do. Its value
  is empirical: does a different runtime *misread and wander less* on the same spec? Cheap
  to find out.
- **C3 (autonomy): Unknown → measured by the spike.**
- **C4 (parallel): Weak.** Same single-agent serialization risk as Claude Code.
- **C5 (cost): Medium**, C6 **High** (nothing new to maintain), **C7 High** (same local vault).

**Spike plan:**
1. Run a week of daily ticks under Codex using the synced skill, unchanged.
2. Log, per tick: instruction-fidelity misses, unrequested loop edits, handholding events,
   serialization instances — the same four pains, counted.
3. Compare head-to-head against a Claude Code baseline week (same ticks).

**Pass/fail:**
- ✅ Meaningfully fewer "modifies the loop" and "misreads spec" events than the Claude Code
  baseline → a different CLI runtime is a low-effort partial win worth keeping.
- ❌ Same drift/serialization profile → confirms the pain is *architectural* (single-agent
  control flow), and the answer is A or B, not "a different CLI."

**Why keep it in the shortlist:** it's the fastest experiment and it *falsifies the cheap
hypothesis* ("maybe it's just Claude Code"). If C fails, that's strong evidence for
investing in A/B; if C succeeds, it buys relief for near-zero cost.

---

## Decision Rubric (after the spikes)

Run the spikes in this order — cheapest-falsifier first, structural fix second, anchor
last (it doubles as AC dogfooding and needs the most setup):

1. **C (Codex A/B)** — 1 week, near-zero cost. Answers: is the pain the *runtime* or the
   *architecture*?
2. **B (deterministic harness)** — the structural fix for C1/C2; likely best cost/maintenance
   fit for a personal cadence loop.
3. **A (Hermes/AC)** — highest ceiling (native parallel + judge), highest setup + current
   reliability risk; prototype once B has validated the execute-don't-edit pattern.

**Choose by:** the finalist that eliminates C1 (execute-don't-edit) and C2 (fidelity) events
in its spike week **and** stays inside the cost ceiling **and** needs no more than occasional
maintenance. Expected outcome given the criteria weights: **B for the near term** (cleanest
structural fix, cheapest to run, local-KB-native), with **A as the scale-up path** once AC's
reliability gaps close — B's deterministic control loop can later dispatch *into* AC nodes
rather than being thrown away.

**KB note:** All three work against the local Obsidian vault today. Only **A** materially
benefits from a cloud KB migration (container workspaces prefer a network-reachable vault);
B and C do not require it, so defer the migration until/unless A becomes the pick.

---

## Open Questions

- **Cost per tick** for A (containers × judge passes) — must be measured in the spike before
  Guardian runs on a real cadence.
- **Crash recovery**: does a missed/failed tick need durable resume (→ pushes B toward a
  Temporal-style step engine) or is best-effort + next-tick reconciliation enough?
- **Vault write contract**: parallel lanes writing periodic notes need a merge/lock
  discipline so concurrent write-backs don't clobber (`cadence-goals` prefers additive edits
  — encode that as a harness invariant).
