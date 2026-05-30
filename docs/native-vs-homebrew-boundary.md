# Native ↔ Homebrew Boundary — Routing Rules for Skill Authors

Author-facing guidance for deciding **when to reach for a native Claude Code
primitive vs. the homebrew orchestration backbone** when writing or evolving a
skill in this repo.

> **Source of truth.** Every rule below is derived from the FROZEN design
> decisions **D1–D9** in the parent design doc
> (`agent-modernization` /
> `claude-agents-explore-updating-workflows/DESIGN.md`). Nothing here is
> invented — D-decision citations appear in each row. If a decision changes,
> change it there first, then reflect it here.

## Guiding principle: evolve the inner loop, keep the outer loop

Native Claude Code has caught up on the **inner loop** — search, planning,
parallel sub-tasks, worktree isolation, background execution. It has **not**
caught up on the **outer loop** — long-lived orchestration across sessions,
scheduled supervision sweeps, durable hierarchical goal trees, multi-repo
coordination.

Therefore: **graft native primitives into the inner loop; retain the homebrew
backbone for the outer loop.**

## 1. KEEP / ADOPT map (native ↔ homebrew boundary)

Each row states the layer, the component, whether it is **KEPT** homebrew or
the work is **ADOPTED** onto a native primitive, the native primitive used (if
any), and the governing D-decision.

| Layer | Component | Disposition | Native primitive | Decision |
|-------|-----------|-------------|-------------------|----------|
| Outer | goal-tree durable state (`GOAL.md`) | **KEEP** homebrew | — (no native durable tree) | D6 |
| Outer | L1/L2 supervisor sweeps | **KEEP** homebrew | — (Routines/teams can't nest or hold a durable tree) | D2, D6, D7 |
| Outer | `ct` cron-tickler (WSL2 heartbeat) | **KEEP** homebrew | — (Routines are idle-only / require machine on) | D5 (provisional) |
| Outer | tmux `send-keys` inter-agent IPC | **KEEP** homebrew | — (agent-teams mailbox is flag-gated, flat, non-resumable) | D1 |
| Outer | `~/src/work/<epic>/<task>/<repo>` multi-repo layout | **KEEP** homebrew | — (native worktree isolation is single-repo only) | D3 |
| Inner | search-heavy steps | **ADOPT** native | `Explore` subagent | D2 |
| Inner | review fan-out (`mbp:review`) | **ADOPT** native | parallel specialist subagents | D2, D6 |
| Inner | parallel file-mutating subagents (intra-repo) | **ADOPT** native | `isolation:'worktree'` | D3 |
| Inner | planning front-end | **ADOPT** native | Plan Mode → materialize to `DESIGN.md`/`PLAN.md` | D4 |
| Inner | task tracking | **MIGRATE** | `TodoWrite` → native `TaskCreate`/`TaskList` | D4 |
| Inner | bounded fan-out steps (audit/review/migrate/research) | **ADOPT** native | Workflows as the engine | D6, D8 |
| Inner | within-session autonomous drive (auto-advance / ralph) | **ADOPT** native | `/goal` (authoritative gate stays homebrew) | D9 |

**Reading the map.** A KEEP row means there is **no native equivalent that
preserves a load-bearing property** (cross-session durability, scheduled
heartbeat, nested supervision, or multi-repo coordination) — so the homebrew
mechanism stays. An ADOPT/MIGRATE row means the native primitive is a strict
improvement *inside a single session* and slots in under the existing skill
without disturbing the backbone.

### A-lane-dependent surface (DO NOT fabricate)

The exact *sites* where the inner-loop ADOPT rows were applied are produced by
the in-flight **A-lane** and are not yet landed. They are stubbed here; a
follow-up cycle fills them once A merges.

- **Exact skills/call-sites where `Explore` delegation was adopted** —
  `TODO-pending-A.1`.
- **Exact `isolation:'worktree'` call-sites** — `TODO-pending-A.2`.
- **Named workflow files in `.claude/workflows/`** (the converted
  `analyze-project` / `mbp:review` / `deep-research` engines) —
  `TODO-pending-A.4`.

## 2. Workflow ↔ goal-tree routing rule (D6)

When a piece of work is fan-out-shaped, decide the **engine** with this rule:

**Use a Workflow** when the work is:

- **single-session** — it completes within one session (Workflow state lives in
  script vars / file artifacts; resume is same-session only), **and**
- **bounded fan-out / fan-in** — decompose → fan out subagents → synthesize, no
  inter-agent mailbox needed (caps: ≤16 concurrent / 1000 total agents), **and**
- **ephemeral-OK** — no human sign-off mid-run; nothing must survive session end
  beyond the file artifacts it writes.

**Use a goal tree** (`mbp:goal-tree`, feeding `mbp:task-workflow`) when the work
needs any of:

- **cross-session durability** — progress must survive `/clear`, `/resume`, and
  session restarts (lives in `GOAL.md` / the coordinator), **or**
- **scheduled supervision** — `ct`-driven L1/L2 sweeps drive it over time, **or**
- **multi-repo dispatch** — work spans repos under
  `~/src/work/<epic>/<task>/<repo>`, **or**
- **human checkpoints** — a review/sign-off gate sits mid-flow (e.g. the
  `<!-- l1-review:metadata -->` checkpoint), **or**
- **nested L{N} layers** — a true supervisor tree (L2 → L1 → L0).

**Caveat (D6).** A workflow simulates *structure* (it can recurse to any depth,
spawning sibling leaf agents per node) but not *supervision semantics* — it is a
single deterministic pass, not a loop over time (D8). So a decomposition small
enough to finish in one session is **simpler as a Workflow than a full goal
tree**; reach for the goal tree only when one of the durable/scheduled/multi-repo/
gated/nested properties above is actually required.

## 3. `/goal` auto-advance usage (D9)

`/goal` is the **within-session autonomous driver** for an L0 worker (and an
attended L1 working session): it sets a completion *condition*, and after each
turn a fast model checks whether the condition holds and, if not, auto-starts
another turn with no operator prompt. It replaces the homebrew within-session
loops (`implement → validate → commit → next` auto-advance, ralph-wiggum). Pair
it with `-p` headless mode for unattended single-node execution under external
`ct`/L1 supervision. The turn/time bound (`or stop after N turns`) is the safety
valve.

**The authoritative completion gate remains the homebrew tool-based
complete-check.** `/goal`'s evaluator is **transcript-only** — it judges what
Claude surfaced in conversation and **does not call tools** (it cannot run
`gh pr list`, scrape `<!-- l1-review:metadata -->`, or check git). It therefore
**must not** be the source of truth for "node done." The L1 tick's tool-based
complete-check stays the authoritative gate; `/goal` is only the child's
self-drive, and the L1 check is the external verification.

> **Practical note.** Have the child print `gh`/test results into the transcript
> so `/goal`'s evaluator sees real evidence — but the authoritative "done"
> verdict still belongs to the supervisor's tool-based check, never to `/goal`.

## Related

- Parent decisions: `claude-agents-explore-updating-workflows/DESIGN.md` (D1–D9).
- `skills/goal-tree/SKILL.md` — the outer-loop orchestrator this boundary
  governs.
