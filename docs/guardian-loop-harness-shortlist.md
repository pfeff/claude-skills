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
| **Hermes Agent (Nous Research)** | OSS model-agnostic personal-agent harness | Cron-native, `SKILL.md`-compatible, local-vault-native, subagents for parallel workstreams. The Guardian loop becomes scheduled cron jobs that attach `cadence-goals`. Anchor (operator asked to start here). *Not* the internal `hermes_mcp` / Agent-Coordinator. |
| **Deterministic harness on Claude Agent SDK** | Bespoke thin harness | Loop control flow is *code*; model called per-slice as a subordinate step. Directly targets C1. |
| **Codex CLI swap** | CLI coding agent | Same skills/vault substrate, different runtime. Sync target already exists → cheapest A/B. |
| Gemini CLI / opencode / Aider | CLI coding agents | Same class as Codex; deferred — one CLI A/B (Codex) is enough signal for now. |
| LangGraph / Temporal-style engine | Durable workflow engine | Heavier; overlaps the "deterministic harness" idea. Fold into finalist B rather than run separately. |

Three finalists carry the shortlist. The rest are explicitly deferred (logged so we don't
pretend the scan was exhaustive when it wasn't): the CLI peers collapse into the one Codex
A/B, and the workflow-engine option collapses into the deterministic-harness spike.

---

## Shortlist — 3 Finalists to Prototype

### Finalist A — Hermes Agent (Nous Research) *(anchor — start here)*

**What it is:** An open-source, **model-agnostic agent harness** from Nous Research — a
long-running personal assistant that runs in the terminal, desktop, IDEs, and messaging
platforms. **Not** the Hermes LLMs and **not** your internal `hermes_mcp`/Agent-Coordinator.
One-line install; a **gateway daemon** hosts a **built-in cron scheduler**, a **`SKILL.md`**
skills system, and a persistent **memory** layer (`MEMORY.md` + FTS5 cross-session search).
It is shaped for exactly this shape of work: recurring, unattended, personal-assistant tasks
over your own files and skills.

**How it scores against the pains:**
- **C1 (execute-don't-edit): Better, configurable — not fully structural.** A cron tick
  *"launches a fresh `AIAgent` session per due job, optionally injects attached skills,
  executes the prompt to completion, delivers the response"* — the job's mandate is to
  **execute the tick, not refactor the loop**. You can harden further: Hermes lets you
  *"write Python scripts that call tools via RPC, collapsing multi-step pipelines into
  zero-context-cost turns"* — encode the control flow as a script where the model only fills
  bounded steps (the same lever as Finalist B, but native). Caveat: within a session the
  agent still has latitude, so drift is *reduced*, not eliminated by construction — measure it.
- **C2 (fidelity): Medium-strong.** Isolated per-job sessions with a fixed prompt + attached
  skill narrow the surface for misreading. **No native LLM-judge gate** (unlike your AC), so
  add a validation step (`self-verify` / the `cadence-goals` Light Validation checklist) as
  the tick's final skill.
- **C3 (autonomy): Strongest of the three.** Native cron: natural language *or* cron syntax
  (`0 6 * * *`), intervals (`every 2h`), ISO timestamps; the gateway ticks every 60s, runs
  due jobs unattended, and delivers to origin / local files / Telegram / Discord / email.
  The daily→weekly→monthly cadence maps 1:1 onto cron jobs. This directly kills the
  handholding pain.
- **C4 (parallel): Medium.** Parallelism is via **spawned isolated subagents / scripted RPC
  pipelines *within* a session** — **not** cron fan-out (cron jobs run sequentially;
  workdir jobs serialize deliberately). Parallel-lane execution is achievable but you design
  it (a subagent per active lane), it isn't free.
- **C5 (cost): Good.** Model-agnostic (`hermes model`, no lock-in) → run cheaper models per
  job; isolated bounded-context sessions keep per-tick cost predictable.
- **C6 (maintenance): Good.** Maintained OSS, one-line install, `hermes setup` — far less
  than bespoke code. Cost: you run the gateway daemon.
- **C7 (KB / skills): Strong.** Skills are **`SKILL.md` + YAML frontmatter, agentskills.io-
  compatible** — *"existing SKILL.md files ... integrate directly without modification"*;
  `cadence-goals` should port nearly as-is (Claude-only frontmatter like `allowed-tools` is
  ignored, not fatal). Runs **locally** against the Obsidian vault as files → vault stays
  source of truth; Hermes' memory is additive. **No cloud KB migration required.**

**Spike plan:**
1. Install Hermes; point it at a provider via `hermes model` (Anthropic, or a cheaper model
   to test cost).
2. Drop `cadence-goals` (and its refs) into `~/.hermes/skills/`; confirm it loads unmodified.
3. Create a cron job for one tick — e.g. `0 6 * * *` "run the daily Guardian OODA tick" —
   attaching `cadence-goals`, workdir = the vault, deliver = local file + Telegram.
4. Parallel test: extend the tick to spawn a subagent per active lane.
5. Add a validation skill (`self-verify` / Light Validation) as the final step before
   note write-back.

**Pass/fail:**
- ✅ A week of daily ticks runs unattended; `cadence-goals` loaded unmodified; note
  write-backs correct.
- ✅ **Zero unrequested edits to loop machinery** — the tick executes, doesn't refactor skills.
- ✅ Multi-lane tick runs lanes concurrently via subagents.
- ❌ Within-session drift still rewrites the loop, or cron sessions need babysitting > once/week.

**Risks:** within-session latitude means C1 is mitigated, not guaranteed. No native judge —
validation must be added. Parallelism needs design, not just config. You run a persistent
daemon. (`SKILL.md` compatibility, cron model, and subagent behavior confirmed against the
Hermes docs — see Sources.)

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

Run the spikes in this order — anchor first (operator's call, and it's the lowest-build
"real harness" that tests the whole loop natively), cheap A/B in parallel, bespoke fallback
last:

1. **A (Hermes)** — **start here.** ~an afternoon to install + wire one cron tick with
   `cadence-goals` attached. Tests C1/C2/C3/C7 together against the actual loop.
2. **C (Codex A/B)** — run in parallel; near-zero cost. Answers the cheap question: is any
   residual drift the *runtime* or the *architecture*?
3. **B (deterministic SDK harness)** — only if A (and C) still drift on C1. It's the
   guaranteed-structural but highest-build fallback — and note Hermes' scripted-RPC-pipeline
   mode can achieve much of B *without leaving Hermes*, so reach for a full bespoke harness
   only if that in-Hermes lever also proves insufficient.

**Choose by:** the finalist that eliminates C1 (execute-don't-edit) and C2 (fidelity) events
in its spike week **and** stays inside the cost ceiling **and** needs no more than occasional
maintenance. Expected outcome given the criteria weights: **Hermes is the likely winner for
the personal loop** — cron + `SKILL.md` + local-vault + model-agnostic delivers most of the
requirements out of the box at low build cost. Fall through to Hermes' scripted-pipeline mode,
then to a bespoke SDK harness (B), only if measured within-session drift proves the agent
still can't be trusted to execute-not-edit.

**KB note:** All three run against the **local** Obsidian vault; **none require cloud KB
migration** — Hermes accesses the vault as local files. Keep cloud migration as an option
only if you later want Hermes' remote backends (Modal, Daytona, Vercel Sandbox) to run ticks
off-machine.

---

## Open Questions

- **Within-session drift (the load-bearing unknown for A):** does a fixed cron prompt +
  attached skill actually stop Hermes editing the loop, or does within-session latitude still
  let it wander? This is what the A spike must measure — it decides whether Hermes alone wins
  or whether you fall through to its scripted-pipeline mode / a bespoke SDK harness.
- **Validation gate for A:** Hermes has no native LLM-judge. Is `self-verify` / the
  `cadence-goals` Light Validation checklist as the tick's final skill sufficient, or is a
  separate judge pass needed?
- **Parallelism need:** do cadence lanes genuinely need concurrent execution, or is
  sequential-with-subagents fine? (Cron itself runs jobs sequentially.)
- **`cadence-goals` port fidelity:** confirm the skill loads and behaves under Hermes with
  Claude-only frontmatter (`allowed-tools`, `allowed-prompts`) ignored — verify no silent
  behavior change.
- **Crash recovery:** does a missed/failed tick need durable resume, or is best-effort +
  next-tick reconciliation enough? (Hermes cron re-ticks; confirm failure semantics.)
- **Vault write contract:** parallel subagent lanes writing periodic notes need a merge/lock
  discipline so concurrent write-backs don't clobber (`cadence-goals` prefers additive edits
  — encode that as a harness invariant).

---

## Sources

- [Hermes Agent — Nous Research (GitHub)](https://github.com/NousResearch/hermes-agent)
- [Hermes Agent docs](https://hermes-agent.nousresearch.com/docs/)
- [Hermes Agent — official site (memory, skills, cron)](https://hermes-agent.ai/)
- [Sébastien Dubois — Hermes Agent overview](https://www.dsebastien.net/hermes-agent/)
- [agentskills.io specification](https://agentskills.io/specification)
- Internal: `docs/PRODUCT.md` (Agent-Coordinator / `hermes_mcp` — the *different* Hermes),
  `skills/cadence-goals/SKILL.md`, `skills/planning-workflow/` (the WIP SDLC applied here).
