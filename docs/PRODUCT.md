# Agent-Coordinator: Product Brief

## Vision

The operating system for autonomous software engineering — where agents manage agents, loops optimize loops, and humans operate at the altitude where they add the most value.

## Mission

Agent-Coordinator (AC) provides the coordination, evaluation, and observability infrastructure that enables nested autonomous agent loops to execute, improve, and scale — replacing manual project management with spec-driven, self-correcting dispatch pipelines. It serves agent orchestrators at every layer of the stack, from L0 task execution through L2+ strategic planning.

---

## Personas

### 1. The L1 Orchestrator Agent

**Who**: An AI agent (Claude Code in a tmux or container session) operating at Layer 1 — responsible for decomposing functional specs into dispatchable L0 tasks, evaluating outputs, and deciding what to retry, adjust, or advance.

**Demographics**: Runs 24/7 in a control session. Has full API access to AC. Reads goal trees, dispatches containers, reviews PRs, updates node status. No direct human interaction during normal operation.

**Primary JTBD**: *When I receive a batch of ready nodes from the goal tree, I want to dispatch them to L0 agents with clear specs and evaluate their outputs against acceptance criteria, so I can advance the tree without human intervention.*

**Pain points**:
- Spec elaboration is manual — compressed L2 instructions require human translation into dispatchable specs
- No structured way to detect standing rule violations across PRs without parsing CLAUDE.md
- Container dispatch still has reliability gaps (race conditions, iteration log bugs) that pull humans into L0
- MCP race condition (hermes_mcp SSE) makes programmatic AC interaction unreliable

**Unexpected insight**: The L1 agent's quality is measured by how *few* times it needs to interview a human. Every question is a spec failure.

**Product fit**: AC is the L1 agent's primary tool — goal trees, node dispatch, evaluation telemetry. But AC currently requires the L1 to work *around* infrastructure gaps rather than through clean abstractions.

---

### 2. The L0 Worker Agent

**Who**: An AI agent (Claude Code in a Ralph container) executing a single technical task — write code, run tests, produce a PR. Receives a spec, works autonomously, terminates with finished/did-not-finish.

**Demographics**: Ephemeral. Lives for 30-60 minutes in a container. Has no memory between runs. Receives all context via injected spec and cloned repo.

**Primary JTBD**: *When I'm dispatched with a task spec and a repo, I want to plan, implement, test, and produce a PR that satisfies the acceptance criteria, so the L1 evaluator accepts my output on first pass.*

**Pain points**:
- Specs sometimes lack sufficient context (context_depth flag not wired)
- No structured way to report "blocked" status back to L1 — just terminates with did-not-finish
- Iteration logs were silently discarded until C.3.12, making forensic debugging impossible
- Container workspace staleness when host worktrees are used (volume-based dispatch not yet landed)

**Unexpected insight**: The L0 agent doesn't care about AC directly — it interacts with files injected into its workspace. AC is invisible infrastructure. The quality of the *spec* is the L0's entire experience of the product.

**Product fit**: AC shapes L0 experience indirectly through spec quality, container setup, and result extraction. The product surface for L0 is the dispatch contract, not the API.

---

### 3. The Human Operator (Ascending)

**Who**: A software engineer who started as the hands-on-keyboard coder (L0), is currently operating primarily at L1 (reviewing PRs, writing specs, monitoring dispatches), and is actively working to operate at L2+ (defining objectives, evaluating initiative outcomes).

**Demographics**: Solo operator. Deep context on the system. Uses tmux, CLI tools, GitHub. Evaluates agent output by reading diffs and checking acceptance criteria. Time-constrained — wants agents to handle execution so they can focus on direction.

**Primary JTBD**: *When I define a project objective, I want agents to decompose it into tasks, execute them, evaluate outputs, and advance without me entering the execution environment, so I can focus on strategy and only intervene when the system encounters genuinely novel situations.*

**Pain points**:
- Constantly pulled back into L0/L1 by infrastructure failures (container bugs, MCP race conditions)
- No real-time visibility into L0 execution without tmux attach (output streaming not landed)
- Standing rules exist as prose — enforcement is aspirational until C.3.2 machinery is exercised at scale
- AC dashboard exists but isn't the primary monitoring interface — still uses tmux + CLI
- Cycle evaluation is manual and time-consuming; ~70% of time spent on infra debugging vs. content work

**Unexpected insight**: The human's *operating altitude* is the primary meta-indicator of system success. If the operator is pulled down to lower layers, the system has a structural problem — regardless of how many features it has.

**Product fit**: AC is the tool that should make altitude ascent possible. Today it provides the data structures (goal trees, nodes, status) but not yet the automation (dispatch, evaluate, advance) that would let the human stay at L2+.

---

## Jobs to Be Done

### Core Jobs (Served)

| Job | Persona | Current Solution | Satisfaction |
|-----|---------|-----------------|-------------|
| Decompose objectives into a dependency-ordered task tree | Human / L1 | Goal tree API + GOAL.md | Medium — works but manual node creation |
| Track task status across parallel agent work | Human / L1 | AC node status + GOAL.md sync | Medium — requires CLI/API, dashboard underused |
| Dispatch work to containerized agents | L1 / Human | dispatch-container.sh + Ralph | Low — reliability gaps, race conditions |
| Evaluate agent output against spec | L1 | execute-tree step 4e (LLM judge) | Medium — works for per-task criteria, standing rules new |
| Record immutable audit trail | Human | Trace logs, finish.jsonl | Medium — data collected but rarely consumed for decisions |

### Underserved Jobs

| Job | Persona | Gap |
|-----|---------|-----|
| Monitor L0 execution in real time without entering L0 | Human / L1 | No output streaming from container to AC (C.3.11 pending) |
| Detect blocked/stuck agents and surface to L1 | L1 / Human | No "blocked" signal from L0 (C.3.16 pending) |
| Auto-advance tree when nodes complete | L1 | execute-tree exists but isn't wired as an automated pipeline |
| Elaborate compressed L2 instructions into L0-ready specs | L1 | No spec-elaboration protocol (C.3.13 placeholder) |
| Measure system health across layers (not just per-task) | Human | Control plane is conceptual, not instrumented |
| Run experiments with different parameters and compare | Human / L1 | No A/B dispatch or epoch comparison tooling |

### Missing Jobs (Future)

| Job | Persona | Why It Matters |
|-----|---------|---------------|
| Self-optimize dispatch parameters based on telemetry | L1 (autonomous) | Currently all parameter tuning is human-driven |
| Detect and respond to structural degradation across layers | Control Plane | Flagged in DECISIONS.md as empirical catalog (C.3.3) |
| Manage multiple concurrent projects with shared resources | Human / L2 | Single-project focus today; multi-project coordination unaddressed |
| Onboard new repos/domains without human hand-holding | L1 | Taskfile + gates.md require manual setup per repo |

---

## Value Propositions

### vs. Raw Git + Manual Coordination

**Who**: Solo developer or small team running AI agents on coding tasks.

**Why**: Without AC, you're the L1 — manually dispatching, monitoring tmux sessions, reading diffs, deciding what's next. Your altitude is permanently L0/L1.

**What before**: Mental model of task dependencies. Copy-paste specs into agent prompts. Poll terminal sessions. Read PRs one at a time. Track progress in your head or a text file.

**How**: AC provides goal trees (structured dependency tracking), spec-driven dispatch (agents get specs, not ad-hoc prompts), automated evaluation (LLM judges output against criteria), and telemetry (decisions grounded in data, not vibes).

**What after**: Dependencies are explicit. Dispatch is a single API call. Evaluation is automated and auditable. You operate at L1+ instead of L0.

**Alternatives**: GitHub Projects (no agent dispatch), Linear (no evaluation), Jira (no agent-native interface) — all designed for humans assigning work to humans.

### vs. Existing Agent Orchestration Frameworks (CrewAI, AutoGen, LangGraph)

**Who**: Teams building multi-agent systems.

**Why**: Existing frameworks focus on *agent composition* (chain agents into workflows). AC focuses on *agent coordination* (manage what agents work on, evaluate whether they succeeded, decide what happens next). Composition is a solved problem; coordination at scale is not.

**What before**: Agents wired together in code. No separation between "what to work on" and "how to work." No evaluation beyond "did the chain complete?" No standing rules or spec-driven contracts.

**How**: AC separates the *what* (goal trees, specs, acceptance criteria) from the *how* (dispatch strategies, container/tmux/subagent). Evaluation is a first-class concept — not "did it run" but "did it meet the spec." Failure is a normal control signal, not an exception.

**What after**: Work is structured as trees with dependency-ordered dispatch. Evaluation catches correct-but-wrong output. The system improves between iterations because telemetry feeds back into parameter tuning.

**Alternatives**: CrewAI (composition, no evaluation), AutoGen (conversation-based, no spec contracts), LangGraph (state machines, no project-level coordination).

---

## Core Capabilities (Mapped to JTBD)

| Capability | Jobs Served | Current State |
|------------|------------|---------------|
| **Goal Trees** — Hierarchical task decomposition with dependency tracking, status transitions, node dispatch | Decompose objectives, track status, auto-advance | Functional. Node CRUD, dependency resolution, status machine. Missing: auto-advance pipeline, layer-aware depth encoding |
| **Spec-Driven Dispatch** — L1 writes specs, L0 receives them via container/workspace injection, results flow back | Dispatch work, elaborate specs | Partially functional. Container dispatch works E2E (C.2.9 proved). Reliability gaps remain. Spec elaboration protocol not codified |
| **Evaluation Engine** — LLM-as-judge evaluates output against per-task criteria + standing rules | Evaluate output, enforce rules | Functional for per-task criteria. Standing rules detection landed (C.3.2). Metric pipeline operating-practice gap (C.3.6) |
| **Telemetry & Observability** — finish.jsonl, evaluation.json, iteration logs, exit summaries | Audit trail, measure health, inform decisions | Schema defined. Collection inconsistent (operating-practice gap). No dashboarding or alerting. Output streaming pending |
| **Container Lifecycle** — Docker volume creation, repo cloning, spec injection, timeout enforcement, result extraction | Dispatch to containers, time-box execution, extract results | Early. Volume-based workspaces designed but not landed. Host-directory dispatch proven but fragile |
| **MCP Interface** — Unified JSON-RPC tools for all layers to interact with AC | Programmatic coordination | Deployed. hermes_mcp SSE race condition blocks reliable use from Claude Code. Works for sequential manual calls |

---

## Roadmap Themes

### Theme 1: Reliable L0 Autonomy (Current — Cycle 3)

*Goal: Human never enters L0 environment during normal operation.*

- Volume-based workspaces (eliminate staleness, race conditions)
- Fix iteration log race condition (C.3.23)
- Wire /finish and /review into container loop (C.3.20)
- Dispatch prompt template enforces task-workflow (C.3.21)
- L0 blocked-signal to L1 (C.3.16)
- Walk-away exercise as standard cycle validation (C.3.9)

**Success metric**: Container dispatch success rate > 80%. Human L0 entries per cycle = 0.

### Theme 2: L1 Automation Pipeline (Next — Cycle 4)

*Goal: L1 agent runs the dispatch→evaluate→advance loop without human prompting.*

- Auto-advance: node completes → evaluate → merge/reject → dispatch next ready node
- Output streaming from container to AC (C.3.11)
- L1 review process as mandatory gate (C.3.19)
- Metric pipeline wired into close-out flow (C.3.6)
- Standing rules exercised at scale

**Success metric**: Batch of 3+ nodes dispatched and evaluated without human intervention. L1 interview rate < 1 per batch.

### Theme 3: L2→L1 Boundary (Cycle 4-5)

*Goal: Human issues compressed instructions; L1 autonomously produces dispatchable specs.*

- L2→L1 boundary research (C.3.1)
- Spec-elaboration protocol (C.3.13)
- L2 I/O contract (C.3.14)
- Tree depth encodes layer ownership (C.3.22)

**Success metric**: Human writes one-sentence objective; tree is decomposed and executed without human re-entering L1.

### Theme 4: Control Plane & System Health (Ongoing)

*Goal: Structural health monitoring that flags problems before humans notice them.*

- Empirical control plane action catalog (C.3.3, ongoing)
- Layer health metrics (dispatch success rate, cycle time, interview frequency per layer)
- Anomaly detection: human operating altitude regression, evaluation pass-rate degradation
- Process control charts with empirical limits

**Success metric**: Control plane surfaces a structural issue before the human operator detects it independently.

### Theme 5: Multi-Project & Multi-Operator (Future)

*Goal: AC coordinates work across projects and teams, not just one operator's tree.*

- Resource-aware dispatch (agent capacity, cost budgets)
- Cross-project standing rules and shared knowledge base
- Operator roles and scoped auth
- Multi-tree coordination (shared dependencies across projects)

**Success metric**: Two independent projects share an AC instance with isolated goal trees and coordinated resource allocation.

---

## Relationship to Autoresearch

The autoresearch loop formalization (tree #5) and the "Jira for Agents" coordinator (tree #4) are not separate products — they are the same product viewed from different angles.

**Tree #4 (Jira for Agents)** built the *infrastructure*: goal trees, node dispatch, status tracking, API endpoints. It answered "how do we manage agent work?"

**Tree #5 (Autoresearch Formalization)** built the *theory*: uniform layer template, spec-driven evaluation, standing rules, parameter/hyperparameter/standing-rule scoping, interview-as-failure. It answered "how do autonomous loops self-correct and improve?"

**The synthesis**: AC is the runtime that implements the loop theory. Goal trees are the data structure. Spec-driven dispatch is the N+1→N contract. Evaluation is the control loop. Telemetry is the feedback signal. Standing rules are the persistent architectural constraints.

The autoresearch project itself is AC's first and most demanding customer. Every cycle produces both product improvements (PRs to claude-skills, agent-coordinator) and operational insights (lessons-learned, standing rules, decision records). The product evolves *because* it's being used to manage its own development — the outer loop optimizes the inner loop that builds the outer loop.

This recursive self-improvement is not a curiosity — it's the core product thesis. AC's value compounds precisely because the same evaluation→adjustment→re-dispatch cycle that builds software also improves the system that builds software. The human's job is to ascend: operate at higher layers over time, pushing the automation boundary downward. Operating altitude is the metric.
