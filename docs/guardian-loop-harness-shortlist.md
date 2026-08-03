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
| C1 | **Faithful execution** | The #1 failure. Tasked with *running* a tick, the agent must do the work — not substitute *editing the loop/machinery* for executing it. **Note the distinction from C10:** the pain is "editing *instead of* executing," **not** improvement itself. | ★★★ |
| C2 | **Instruction fidelity** | Misreading the spec is failure #2. Spec-driven dispatch + an evaluation gate (judge output vs. acceptance criteria) catches "correct-but-wrong." | ★★★ |
| C3 | **Autonomy (low handholding)** | Must run a tick unattended and report done/blocked without babysitting. | ★★★ |
| C4 | **Parallel dispatch** | Cadence model runs 3–4 active lanes; harness must fan out, not serialize. | ★★ |
| C5 | **Cost ceiling** | A persistent/high-frequency loop can't blow up spend. | ★★ |
| C6 | **Low-maintenance** | Operator won't hand-maintain fragile bespoke orchestration. | ★★ |
| C7 | **KB compatibility** | Must work against the Obsidian knowledge base. Migrating the KB to the cloud is acceptable if it buys reliability. | ★★ |
| C8 | **Billing fit + model portability** | A persistent loop wants *predictable* cost (a flat **token-inclusive** subscription beats metered), but the subscription must permit *unattended* use, and the harness should hot-swap models across vendors (cheap model for routine ticks, strong model for synthesis). See the Analysis of Alternatives below. | ★★ |
| C9 | **Remote control** | Drive/monitor/steer the loop away from the desk — **mobile first**, web second. For an unattended loop you want to be pinged and able to approve/redirect from your phone. | ★★ (mobile ≫ web) |
| C10 | **Controlled self-improvement** *(desirable)* | The harness should get **better at executing** over time — capturing procedures from *successful* runs as reusable skills — ideally in a **separate, gateable** phase so learning never comes at the cost of executing the current tick. **Operator wants this.** | ★★ |

**Design insight — and a correction.** Pains #1/#2 are *not* "use a smarter model" problems;
they are **execution-discipline** problems: the agent must *do the tick*, not wander into
rewriting the machinery. But **execution discipline (C1) and self-improvement (C10) are
different axes, not opposites.** An earlier draft of this doc conflated them and wrongly
penalized Hermes' learning loop as if it *were* the C1 failure. It isn't: "improving how you
execute, from traces, after the turn" is the desirable thing; "editing the loop instead of
executing it" is the failure. A harness scores well when it **keeps execution faithful (C1)
*and* learns in a separate, controllable phase (C10)** — which, per its docs, is exactly what
Hermes is built to do (see Category Comparison).

---

## Candidate Landscape (scan)

| Candidate | Class | One-line |
|-----------|-------|----------|
| **Hermes Agent (Nous Research)** | OSS **personal-agent harness** | Cron-native, `SKILL.md`-compatible, local-vault-native, self-improving loop, Nous Portal subscription. The Guardian loop becomes cron jobs attaching `cadence-goals`. Anchor (operator asked to start here). *Not* the internal `hermes_mcp` / Agent-Coordinator. |
| **OpenClaw** | OSS **personal-agent harness** (same class as Hermes) | Near-identical primitives; **static human-authored `SKILL.md`** (control-plane-first) → best default fit for the execute-don't-edit pain. 24+ channels, ClawHub marketplace. Co-anchor. See Category Comparison. |
| **Deterministic harness on Claude Agent SDK** | Bespoke thin harness | Loop control flow is *code*; model called per-slice as a subordinate step. Directly targets C1. |
| **Codex CLI swap** | CLI coding agent | Same skills/vault substrate, different runtime. Sync target already exists → cheapest A/B. |
| opencode | CLI coding agent (model-agnostic) | Strongest model-agnostic coding CLI; but coding-shaped, not cron-native, and the Anthropic-subscription block applies. Deferred behind the Codex A/B. |
| Gemini CLI / Aider | CLI coding agents | Same class as Codex; deferred — one CLI A/B (Codex) is enough signal for now. |
| Letta / Khoj / QwenPaw | Personal-agent peers | Letta = memory framework (assemble-it-yourself); Khoj = KB-adjacent Obsidian second-brain; QwenPaw = niche. See Category Comparison. |
| LangGraph / Temporal-style engine | Durable workflow engine | Heavier; overlaps the "deterministic harness" idea. Fold into finalist B rather than run separately. |

The shortlist is carried by the **personal-agent harness class** (Hermes + OpenClaw) plus the
deterministic SDK harness and the Codex A/B. The rest are explicitly deferred (logged so we
don't pretend the scan was exhaustive): the CLI peers collapse into the one Codex A/B, the
workflow-engine option collapses into the deterministic-harness spike, and the personal-agent
peers (Letta/Khoj/QwenPaw) are noted in the Category Comparison but not prototyped.

---

## Shortlist — 3 Finalists to Prototype

### Finalist A — Personal-agent harness: Hermes **and** OpenClaw *(anchor — start here)*

> **Read with the [Category Comparison](#category-comparison--personal-agent-harnesses-not-coding-clis).**
> Finalist A is really the *personal-agent harness class*, with two leaders. **Hermes leads:**
> it executes each tick to completion (faithful — C1) *and* self-improves in a separate,
> gateable phase (C10) — the learning loop you actually want — plus the unique Nous Portal
> subscription (C8). **OpenClaw** is the alternative for the *opposite* preference: static
> human-authored `SKILL.md`, **no** autonomous learning — maximal determinism at the cost of a
> loop that never improves itself. Prototype both (shared `SKILL.md` substrate); default
> expectation is Hermes-first.

**What it is (Hermes):** An open-source, **model-agnostic agent harness** from Nous Research — a
long-running personal assistant that runs in the terminal, desktop, IDEs, and messaging
platforms. **Not** the Hermes LLMs and **not** your internal `hermes_mcp`/Agent-Coordinator.
One-line install; a **gateway daemon** hosts a **built-in cron scheduler**, a **`SKILL.md`**
skills system, and a persistent **memory** layer (`MEMORY.md` + FTS5 cross-session search).
It is shaped for exactly this shape of work: recurring, unattended, personal-assistant tasks
over your own files and skills.

**How it scores against the pains:**
- **C1 (faithful execution): Aligned.** A cron tick *"launches a fresh `AIAgent` session per
  due job, optionally injects attached skills, executes the prompt to completion, delivers the
  response"* — the job's mandate is to **execute the tick**, and skill changes happen in a
  *separate* background review **after** the turn, not mid-execution. So the agent does not
  substitute loop-editing for doing the work. The **write-approval gate**
  (`skills.write_approval: true`) stages every skill write in `~/.hermes/pending/skills/` for
  sign-off if you want eyes on changes. You can harden execution further with scripted RPC
  pipelines (bounded steps), but you don't *need* to — faithful execution is the default.
- **C10 (controlled self-improvement): Yes — the reason to prefer Hermes.** Procedural memory
  captures workflows from *successful* runs; the background review reads execution traces to
  learn *why* something worked. Leave the gate open for autonomous learning, or on to review
  each change. This is the desirable "gets better over time" loop — distinct from, and not in
  tension with, C1.
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
1. Install Hermes. **Billing = direct provider keys (decided).** Register **Anthropic, OpenAI,
   and xAI** API keys via `hermes model` (each as a native provider; secrets land in
   `~/.hermes/.env`). Set a **cheap model** as the default for routine ticks and a **strong
   model** for weekly synthesis, and confirm `/model` hot-swaps between vendors. **Set a hard
   spend/usage limit on each provider console** (Anthropic, OpenAI, xAI) — with direct keys
   there's no single OpenRouter cap, so the per-provider limits *are* the cost ceiling (C5).
2. Drop `cadence-goals` (and its refs) into `~/.hermes/skills/`; confirm it loads unmodified.
3. Create a cron job for one tick — e.g. `0 6 * * *` "run the daily Guardian OODA tick" —
   attaching `cadence-goals`, workdir = the vault, deliver = local file + Telegram.
4. Parallel test: extend the tick to spawn a subagent per active lane.
5. Add a validation skill (`self-verify` / Light Validation) as the final step before
   note write-back.
6. Start with **`skills.write_approval: true`** so the first week's self-improvement changes
   stage in `~/.hermes/pending/skills/` for you to review; once the learning looks trustworthy,
   open the gate for autonomous improvement (C10).

**Pass/fail:**
- ✅ A week of daily ticks runs unattended; each tick **executes to completion**; note
  write-backs correct.
- ✅ **The tick does the work** — no case of the agent editing the loop *instead of* running it
  (C1). Any self-improvement appears as *staged, reviewable* skill changes, not as skipped work.
- ✅ Staged improvements are *useful* — the loop measurably gets better at a recurring tick (C10).
- ✅ Multi-lane tick runs lanes concurrently via subagents.
- ❌ Cron sessions need babysitting > once/week, or staged skill changes are consistently noise.

**Risks:** no native LLM-judge — validation must be added. Parallelism needs design, not just
config. You run a persistent daemon. (Faithful-execution timing, the write-approval gate,
`SKILL.md` compatibility, cron model, and subagents all confirmed against the Hermes docs —
see Sources.)

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

## Category Comparison — Personal-Agent Harnesses (not coding CLIs)

Finalist A (Hermes) isn't a lone product — it's one instance of a **general-purpose
personal-agent harness** class distinct from the coding-CLI "Coding Nation" harnesses
(Claude Code, Codex, opencode). This class is defined by: a **gateway daemon**, **`SKILL.md`
skills**, **`cron` scheduling**, a **messaging gateway** (chat-app control), **file-backed
memory**, **local-first**, and **model-agnostic** provider config. The Guardian loop *is* a
personal-agent workload, so this is the category that actually fits — and the choice within
it matters more than the choice against the coding CLIs.

**The two leaders — Hermes and OpenClaw — are near-identical in primitives** (Hermes even
imports OpenClaw skills into `~/.hermes/skills/openclaw-imports/`). They diverge on how they
treat *learning* — and, correcting an earlier draft, that difference now favors **Hermes**,
because controlled self-improvement (C10) is **desirable**, not a liability.

### Hermes vs OpenClaw — head to head

| Axis | **Hermes (Nous Research)** | **OpenClaw** (fmr. ClawdBot/MoltBot) |
|------|----------------------------|--------------------------------------|
| **C1 — faithful execution** | **Aligned.** A cron tick loads the attached skill and **executes to completion**; skill changes are a *separate* background review **after** the turn — the agent does *not* stop executing to rewrite the loop. Optional **write-approval gate** (`skills.write_approval: true`) stages every skill write in `~/.hermes/pending/skills/` for human sign-off. So execution stays faithful *and* is protectable. | **Aligned, by a blunter route.** Static human-authored `SKILL.md`; the agent executes what you wrote. Determinism via *no* learning at all. |
| **C10 — controlled self-improvement** *(desired)* | ✅ **Yes — its defining strength.** Procedural memory: captures workflows from successful runs, a background review reads execution traces to learn *why*, and the write-approval gate makes it autonomous-or-eyes-on. This is the learning loop the operator wants. | ❌ **No.** Static skills don't learn; every improvement is a manual `SKILL.md` edit by you. |
| **Skills** | `SKILL.md` / agentskills.io; human-authored **+ self-refined (gateable)** | `SKILL.md`; **static, human-authored**; **ClawHub** marketplace (larger ready-made ecosystem) |
| **`cadence-goals` port** | Loads as-is | Loads as-is (same `SKILL.md` substrate) |
| **Cron** | Built-in (`~/.hermes/cron/jobs.json`) | Built-in (`cron/jobs.json`) |
| **Messaging / mobile (C9)** | ~9 channels | **24+ channels** (Discord, iMessage, Matrix, Teams, Signal, Slack, Telegram, WhatsApp, Zalo…) — *even stronger* mobile-first story |
| **Model hot-swap (OpenAI/Anthropic/xAI/Gemini)** | Native, 40+ providers | Native (OpenAI, Anthropic, xAI/Grok, Gemini, OpenRouter, Kilo Gateway, Mistral, Groq, Cerebras, custom proxies) |
| **Billing (C8)** | **Nous Portal — token-inclusive, cross-vendor subscription** (unique), or OpenRouter/keys | **BYO metered key** — no first-party token-inclusive subscription; OpenRouter/Kilo consolidate multi-provider but stay metered |
| **Memory** | Procedural + facts, self-improving (`MEMORY.md` + FTS5) | File-backed explicit memory (Markdown/YAML under `~/.openclaw`) |
| **Maturity** | Newer; the self-improvement loop is the pitch | **Most mature OSS option** in this class; large community |

**The decisive trade for *your* pains (corrected):** the earlier draft treated Hermes'
self-improvement as if it *were* your #1 pain. It isn't. Your pain was Claude Code **editing
the loop instead of executing it** — a *failure to execute*. Hermes' learning is the opposite:
it **executes the tick to completion, then improves separately and gateably** (C1 ✅). And
since you *want* the loop to get better over time (C10), **Hermes' self-improvement is a
feature you're buying, not a risk you're tolerating** — with the write-approval gate as the
safety valve if a change ever looks wrong. That flips the recommendation: **Hermes leads**
(faithful execution + desired, controllable learning + the unique **Nous Portal**
token-inclusive cross-vendor subscription, C8). **OpenClaw becomes the alternative for the
opposite preference** — if you'd rather have *zero* autonomous learning and every change be a
manual edit (maximal determinism, at the cost of the loop never improving itself). So:
**prototype both** — they share the `SKILL.md` substrate so the `cadence-goals` port is done
once and dropped into each — but the default expectation is now Hermes-first.

### Other peers in the category (noted, lower priority)

- **Letta (MemGPT lineage)** — memory-first agent *framework/server*, strong persistent
  memory + proactive reach-outs, but more a developer framework than a turnkey cron+messaging
  harness. Closer to Finalist B (you assemble the loop) than to Hermes/OpenClaw.
- **Khoj** — self-hosted "second brain" with **native Obsidian/markdown** search. Not a loop
  harness, but **KB-adjacent**: could serve the vault as a retrieval layer *behind* whichever
  harness wins (relevant to C7). Worth keeping in view for the knowledge-base side, not as a
  runner of the loop.
- **QwenPaw** and similar messaging-channel assistants — niche/ecosystem-specific (Qwen);
  no advantage over Hermes/OpenClaw for this use case. Not pursued.

*(Category facts corroborated across multiple write-ups; treat vanity metrics like star counts
in those posts as unverified — the architecture claims are consistent, the numbers are not.)*

---

## Analysis of Alternatives — Billing & Model Portability (C8)

Two questions, because they interact: **(1)** does the harness let you run on a flat
**subscription**, or does an unattended loop force **API/usage billing?** **(2)** can it
**hot-swap models across OpenAI / Anthropic / xAI / Gemini** (so routine ticks use a cheap
model and synthesis uses a strong one)?

The headline: **these two goals normally conflict — but Hermes resolves them.** Every
*first-party* subscription (Claude Max, ChatGPT Plus/Pro) is **single-vendor** *and*
officially steered away from unattended automation. The only **cross-vendor subscription**
that is *designed* for unattended agent use is **Nous Portal**, which Hermes uses natively.

> **What counts as a "subscription" here (token-inclusive):** the flat fee must *cover the
> model tokens/usage*, not just grant access to the harness software. A free/OSS harness
> (Hermes, opencode) with **bring-your-own metered API key** is *not* a subscription for this
> purpose — the tokens are still pay-per-use. Qualifying token-inclusive subscriptions:
> **Nous Portal** (tokens across 300+ models bundled), **Claude Max** (Anthropic tokens
> bundled), **ChatGPT Plus/Pro** (OpenAI usage bundled). The harness's own price (all the
> finalists' software is free/OSS) is orthogonal — C8 is about *who bundles the tokens*.

### Billing model — can it run unattended on a token-inclusive subscription?

| Harness | Subscription option | Unattended/cron on that subscription? | Metered/API path |
|---------|---------------------|----------------------------------------|------------------|
| **Hermes** | **Nous Portal** — flat, OAuth, **cross-vendor** (Claude/GPT/Gemini/Grok + 296 more) | **Yes — purpose-built.** Nous Portal is the *recommended* way to run this unattended agent; no ToS gray area. | OpenRouter (one metered key, all vendors) or direct provider keys |
| Codex CLI | ChatGPT Plus/Pro (OpenAI only) | Interactive-oriented; usage is capped to 5-hour windows and **OpenAI steers automation → API key**. | OpenAI API (metered) |
| Claude Code (baseline) | Claude Pro/Max (Anthropic only) | **Gray.** Max covers *personal, on-device* headless cron, but **exporting OAuth tokens to a server is prohibited** and Anthropic recommends API for automation. | Anthropic API (metered) |
| opencode | Can piggyback Claude Pro/Max, OpenAI, Gemini OAuth | **No for Anthropic** — Anthropic **explicitly prohibits** routing Max through non-Claude-Code harnesses (it flagged this as harness-spoofing). Fragile in general. | Per-provider keys / OpenRouter / Vercel AI Gateway (metered) |
| Bespoke SDK (Finalist B) | None | n/a | Anthropic (or via gateway) API — metered |

### Model hot-swapping — OpenAI ↔ Anthropic ↔ xAI ↔ Gemini

| Harness | Cross-vendor hot-swap | How |
|---------|-----------------------|-----|
| **Hermes** | **Native, all four.** | `hermes model` (setup/OAuth), `/model` mid-session, `config.yaml` default, and per-cron-job model attach. Vendors reached via **Nous Portal** (all four in one subscription) *or* **OpenRouter** (all four, one metered key). |
| opencode | **Native, all four.** | Config routing across 75+ providers; **Vercel AI Gateway** unifies OpenAI/Anthropic/Google/xAI. Strong model-agnostic CLI — but coding-agent shaped, not cron-native, and the Anthropic-subscription block above applies. |
| Codex CLI | **No.** | OpenAI models only (local models via `--oss`). |
| Claude Code | **No.** | Anthropic models only. |
| Bespoke SDK | Possible, **but you build it** | Point the SDK at OpenRouter / Vercel AI Gateway and implement routing yourself. |

### What this means for the Guardian loop

- **The cost ceiling (C5) is best served by a flat subscription** — a hard, predictable
  monthly number that a persistent multi-tick loop can't blow past. Among all candidates,
  only **Nous Portal (via Hermes)** offers a flat subscription that is *both* cross-vendor
  *and* sanctioned for unattended use. This is a genuine, specific reason to prefer Hermes
  beyond the cron/skills fit already established.
- **First-party subscriptions are a trap for this use case.** Claude Max and ChatGPT look
  cheaper per month, but (a) each locks you to one vendor's models — no hot-swap — and
  (b) both vendors point unattended/headless/cron workloads at **API billing**, and Anthropic
  actively prohibits the third-party-harness and token-export paths. A Guardian loop on Max
  is tolerable only as *personal, on-device* cron, and even then it's rate-limited and
  off-label.
- **OpenRouter is the pragmatic metered middle ground.** One key, all four vendors, hard
  spend caps, native to both Hermes and opencode. Not flat-rate, but predictable-with-a-cap
  and fully hot-swappable — the natural fallback if you don't want a Nous subscription.
- **Hot-swap earns its keep in this loop specifically:** route routine daily ticks to a cheap
  model and the weekly/monthly synthesis to a strong one — per-cron-job model attach makes
  that a config choice, not a code change. Only the model-agnostic harnesses (Hermes,
  opencode, or a bespoke SDK you wire yourself) can do it.

### New open questions this raises

- **Nous Portal limits & privacy:** any flat plan has throughput/rate caps — could a
  multi-lane parallel tick hit them? And prompts route through Nous's gateway (a dependency
  and a data-path consideration for a personal vault). Confirm caps + data policy before
  committing the loop to it.
- **Model quality via gateway:** verify the specific Claude/GPT/Gemini/Grok versions exposed
  through Nous Portal match what you'd get direct, for the synthesis-critical ticks.

---

## Remote Control — Mobile-First, Web-Second (C9)

For an unattended loop, "remote control" means: get **pinged** when a tick finishes or needs
a decision, and **steer it from your phone** (approve, redirect, ask a question) without
sitting at the terminal. Priority: **mobile first, web second.**

| Harness | Mobile (priority 1) | Web (priority 2) | Shape |
|---------|---------------------|------------------|-------|
| **Hermes** | **Best.** Native **messaging gateway** to ~20 platforms you already have on your phone — **Telegram, WhatsApp, Signal, iMessage, SMS, Slack, Discord, Teams, email, ntfy…** You *command the loop bidirectionally* by DM and cron *delivers results to the same channels*. One memory across all of them; allowlist + DM-pairing access control. | Browser is a first-class channel; a **Channels** page configures the gateway from the browser (pluggable auth: user/pass, OIDC, refresh-token rotation). | **Chat-native, bidirectional.** No bespoke app — you already carry the client. Fits a headless loop that pings you and takes replies. |
| Claude Code (baseline) | **Good but Max-only preview.** *Remote Control* mirrors a **local interactive session** to the Claude iOS/Android app — approve permissions, get pinged, steer. | claude.ai/code mirrors the same session in-browser; conversations sync across devices. | Syncs a **running interactive session**, not a headless cron loop. Great for babysitting; not a fire-and-forget loop controller. |
| Codex CLI | **Good, host-tied.** Codex in the **ChatGPT mobile app** (iOS/Android) remote-controls a Codex session on a **Mac** host — reviews, approvals, **model switching**, task mgmt. QR-code pairing; Windows host "coming soon". | Codex cloud / web console. | Phone as remote for a **desktop-hosted** session; OpenAI-only, macOS-host-bound today. |
| opencode | **Weak.** TUI-centric; no first-party mobile remote control. | Web share/preview only. | Not built for phone-driven operation. |
| Bespoke SDK (Finalist B) | **DIY.** You'd wire a Telegram/ntfy bot yourself — which is exactly the free, built-in capability Hermes hands you. | DIY. | Another reason the bespoke route is last: you rebuild what Hermes ships. |

**Verdict (C9):** **Hermes wins the mobile-first axis decisively** — and it's the *right shape*
for this use case, because the Guardian loop is meant to run headless and *reach out to you*,
which is precisely what a messaging-gateway agent does (loop runs on a cadence → pings your
Telegram/Signal → you reply to approve or redirect). Claude Code and Codex offer real mobile
control but of an **interactive desktop session**, which is the model you're trying to move
*away* from. This is a third independent reason Hermes leads, alongside cron/skills fit (C3/C7)
and token-inclusive cross-vendor subscription (C8).

**Spike addition (folds into the Hermes spike):** wire one messaging channel (Telegram is the
quickest) during the Hermes trial; set the daily tick's `deliver:` target to it and confirm
you can (a) receive the tick summary on your phone and (b) reply to steer the next tick. Pass
= you ran a full day's loop from your phone without opening a terminal.

---

## Decision Rubric (after the spikes)

Run the spikes in this order — anchor first (operator's call, and it's the lowest-build
"real harness" that tests the whole loop natively), cheap A/B in parallel, bespoke fallback
last:

1. **A (personal-agent harness) — start here; lead with Hermes, spike OpenClaw alongside.**
   Port `cadence-goals` once (shared `SKILL.md`), drop it into each, wire one cron tick + one
   Telegram channel. **Lead with Hermes** — it gives faithful execution (C1) *and* the desired
   self-improvement loop (C10) *and* Nous Portal (C8); run it first week with the
   **write-approval gate on** to watch what it learns, then open the gate. Run **OpenClaw**
   alongside as the *maximal-determinism / no-learning* comparison. ~an afternoon each; together
   they test C1/C2/C3/C7/C9/C10 against the real loop.
2. **C (Codex A/B)** — run in parallel; near-zero cost. Answers the cheap question: is any
   residual drift the *runtime* or the *architecture*?
3. **B (deterministic SDK harness)** — only if *both* harnesses fail C1 (the agent skipping
   work to edit the loop). Highest-build fallback — and Hermes' scripted-RPC-pipeline mode (or
   an OpenClaw skill that scripts the flow) can achieve much of B *without* leaving the harness,
   so reach for a full bespoke build only if that in-harness lever also fails.

**Choose by:** the finalist that keeps C1 (faithful execution) and C2 (fidelity) clean in its
spike week **and** delivers useful self-improvement (C10) **and** stays inside the cost ceiling
**and** needs no more than occasional maintenance. Expected outcome given the criteria weights:
**Hermes is the front-runner.** All of cron + `SKILL.md` + local-vault + model-agnostic +
mobile-first remote control (C3/C7/C9) is shared by *both* Hermes and OpenClaw. The two
load-bearing splits both favor Hermes:
- **C10 (self-improvement, desired):** **Hermes wins** — it executes each tick faithfully *and*
  learns from successful runs in a separate, gateable phase. OpenClaw has *no* learning loop.
- **C8 (billing):** **Hermes wins** — Nous Portal is the only token-inclusive cross-vendor
  subscription sanctioned for unattended use.
- **C1 (faithful execution):** **both are aligned** — Hermes via execute-to-completion +
  post-turn review + write-approval gate; OpenClaw via static skills. So C1 is *not* the
  differentiator it appeared to be in the earlier draft.

So: **take Hermes** unless its spike shows the agent actually skipping work to edit the loop
(it shouldn't, per the docs) or the staged self-improvements are noise. **OpenClaw is the
fallback** for a maximal-determinism / no-learning preference, on metered OpenRouter with a
spend cap. Bespoke SDK harness (B) only if *both* fail C1.

**Billing decision (spike): direct provider keys.** Reuse existing **Anthropic + OpenAI + xAI**
API accounts, keys registered directly in Hermes. Chosen over OpenRouter for **0% overhead and
the best privacy** (prompts go straight to each provider — no aggregator in the data path, which
matters for a personal vault). Trade-off accepted: **three keys/bills and no single cap**, so a
**hard spend limit is set on each provider console** to hold the cost ceiling (C5). Reference on
the paths considered:

| Path | Overhead vs. direct | Cap | Data path | Verdict |
|------|--------------------|-----|-----------|---------|
| **Direct keys (chosen)** | **0%** | per-provider limits (3) | straight to provider | ✅ spike billing |
| OpenRouter — credits | ~5.5% on top-ups | one hard cap | via aggregator | fallback if 3 caps annoy |
| OpenRouter — BYOK | ~5% on usage | your provider bills | via aggregator | reuse keys + one dashboard |
| Nous Portal | flat subscription | flat ceiling | via Nous gateway | **production** option if Hermes wins |

Subscriptions (Claude Max / ChatGPT / Grok / Cursor) are **out** — locked to first-party apps,
off-label or prohibited for a third-party unattended harness. Nous Portal stays deferred to the
production decision (pending its limits/privacy check in Open Questions).

**KB note:** All three run against the **local** Obsidian vault; **none require cloud KB
migration** — Hermes accesses the vault as local files. Keep cloud migration as an option
only if you later want Hermes' remote backends (Modal, Daytona, Vercel Sandbox) to run ticks
off-machine.

---

## Open Questions

- **Faithful execution in practice (C1):** the docs say a tick executes to completion and
  improvement is a *separate, post-turn* phase — confirm in the spike that no tick ever skips
  the work to edit the loop. (Expected to pass; verify rather than assume.)
- **Are the staged improvements useful (C10)?** With `write_approval` on, review the first
  week's staged skill changes: are they genuine gains at recurring ticks, or noise? This
  decides how quickly to open the gate for autonomous learning.
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
- **Write-approval workflow ergonomics:** approving staged skills from `~/.hermes/pending/skills/`
  should itself be doable from mobile (C9) — confirm the gate can be worked from a messaging
  channel, not only the terminal, so self-improvement review doesn't pull you back to the desk.
- **OpenClaw billing under load:** with no token-inclusive subscription, price a month of the
  real cadence on OpenRouter (metered) to confirm it stays inside the cost ceiling.

---

## Sources

- [Hermes Agent — Nous Research (GitHub)](https://github.com/NousResearch/hermes-agent)
- [Hermes Agent docs](https://hermes-agent.nousresearch.com/docs/)
- [Hermes Agent — AI Providers (Nous Portal, OpenRouter, billing)](https://hermes-agent.nousresearch.com/docs/integrations/providers)
- Self-improvement / write-approval gate (C1 vs C10): [Hermes Skills System doc](https://hermes-agent.nousresearch.com/docs/user-guide/features/skills) · [The Self-Improvement Agent in Hermes: A Deep Dive](https://akjamie.github.io/post/2026-05-29-self-improvement-agent-deep-dive/)
- Category (personal-agent harnesses): [OpenClaw Docs](https://docs.openclaw.ai/) · [OpenClaw (GitHub)](https://github.com/openclaw/openclaw) · [OpenClaw model providers](https://github.com/openclaw/openclaw/blob/main/docs/concepts/model-providers.md) · [Hermes vs OpenClaw — Turing Post](https://www.turingpost.com/p/hermes) · [Anatomy of an Agent: Claude Code, OpenClaw, Hermes](https://medium.com/design-bootcamp/the-anatomy-of-an-agent-what-lives-inside-claude-code-openclaw-and-hermes-agent-41cc467f42a6) · [Best open-source personal AI assistants (Letta, Khoj, QwenPaw)](https://www.vellum.ai/blog/best-open-source-personal-ai-assistants)
- [Hermes Agent — official site (memory, skills, cron)](https://hermes-agent.ai/)
- [Sébastien Dubois — Hermes Agent overview](https://www.dsebastien.net/hermes-agent/)
- [agentskills.io specification](https://agentskills.io/specification)
- Billing/model portability: [Codex CLI pricing & auth (ChatGPT sign-in vs API key)](https://inventivehq.com/blog/codex-cli-pricing-explained) · [Codex ChatGPT login vs API key](https://www.toolcolumn.com/learn/codex-chatgpt-vs-api-access) · [OpenCode providers](https://opencode.ai/docs/providers/) · [Claude Code headless & ToS](https://autonomee.ai/blog/claude-code-terms-of-service-explained/) · [Claude Max vs API](https://runapi.ai/claude-max-vs-api)
- Remote control (C9): [Hermes Messaging Gateway](https://hermes-agent.nousresearch.com/docs/user-guide/messaging/) · [Claude Code Remote Control (Anthropic, mobile)](https://www.helpnetsecurity.com/2026/02/25/anthropic-remote-control-claude-code-feature/) · [Codex in the ChatGPT mobile app](https://9to5mac.com/2026/05/14/openai-brings-codex-control-to-chatgpt-for-iphone-and-android/) · [Codex remote connections](https://developers.openai.com/codex/remote-connections)
- Internal: `docs/PRODUCT.md` (Agent-Coordinator / `hermes_mcp` — the *different* Hermes),
  `skills/cadence-goals/SKILL.md`, `skills/planning-workflow/` (the WIP SDLC applied here).
