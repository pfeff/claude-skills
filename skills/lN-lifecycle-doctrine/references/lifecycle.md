# L{N}-lifecycle-doctrine — Generic Child-Session Lifecycle

This file is the canonical doctrine for child-session lifecycle
management. Both `l1-supervise` (child=L0) and `l2-supervise`
(child=L1) **Read this file at tick time; never inline its content**.

If you find yourself about to add a lifecycle rule by editing a
supervise skill, edit this file instead.

---

## Platform constraints (verified 2026-05-29) — what can be a layer

These are **verified facts** about the agent platform the L{N} loop runs
on — established 2026-05-29, **empirically AND from official docs** (per
D7/D2). They are recorded here so future doctrine and agents don't
re-derive the dead `L1=teammate → L0=subagent` mapping or assume
live-context persistence. They are **established, not speculative**.

The hard platform limit is **no-nesting + durability**, not "a layer is
always a session." Three verified facts bound what a layer can be:

1. **Subagents cannot spawn subagents.** A subagent is strictly ONE level
   deep — only the main conversation or a Workflow script may spawn agents.
   (Empirical: a spawned general-purpose agent had no `Agent`/`Task` tool;
   official docs: *"Subagents cannot spawn other subagents."*) Documented
   nesting escape hatches: chain from the main conversation, Skills, agent
   teams, or Workflows.
   - **Why it matters for L{N}:** a supervisor cannot delegate supervision
     to a subagent that itself spawns workers. The tick subagent is
     one-shot — it observes and reports back; it does **not** spawn L0s.
     But the L0 it dispatches is **not constrained to a session**: per use
     case an L0 may be a tmux session / container, an Agent-tool **subagent**
     (worktree-isolated when it must produce its own PR), or a **Workflow**.
     The hard limit is **no-nesting + durability**, not "sessions only" —
     see *L0 substrate* below.

2. **Agent-team teammates cannot spawn subagents; no nested teams.** A team
   is exactly ONE flat level (lead + teammates); teammates cannot spawn
   their own teams/teammates or subagents. The `L1=teammate → L0=subagent`
   mapping is therefore **dead**.
   - **Why it matters for L{N}:** you cannot run L2→L1→L0 as live nested
     teams. A team models ONE attended layer (a lead + its
     workers-as-teammates), not the 3-deep tree.

3. **The L{N} loop depends on ~0% live conversation context and ~100%
   durable disk state + stateless re-grounding ticks.** Nothing is carried
   in memory between ticks; every tick re-reads doctrine + a fresh
   `tmux capture-pane` + `sweeps.jsonl` + `GOAL.md`/coordinator + live
   `gh pr` state. The only thing that must stay alive is the `ct`
   heartbeat daemon (until the sanctioned **D10 confirmed-idle auto-stop**
   deliberately removes it); tmux panes are live but gracefully
   re-groundable.
   - **Why it matters for L{N}:** the ephemerality of teams / `/clear` is
     **not fatal** — re-ground per tick from durable disk state
     (CLAUDE.md + `sweeps.jsonl` + `GOAL.md` + `gh`/git). See
     **State-preserving design** below, which already establishes that the
     child rebuilds from its CLAUDE.md alone after `/clear`; this section
     adds the explicit "~0% live context / ~100% durable disk" framing.

**Revisit when** agent teams gain nesting and/or scheduled/unattended
execution (per D7) — at which point a fuller native L{N} becomes possible
and constraints 1–2 above may relax.

### L0 substrate is a choice (no-nesting + durability is the real limit)

Constraints 1–2 bound *nesting*, not *substrate*. The hard platform limit is
**no-nesting + durability**; within it, the substrate for a child is chosen
**per layer and use case**:

- **L0 (leaf task):** a tmux session / container, an Agent-tool **subagent**
  (worktree-isolated when it must produce its own PR), or a **Workflow** —
  whichever fits the task.
- **One L1 + its L0 workers (a single attended burst):** separate sessions,
  *or* an **agent team** (lead = L1, teammates = L0 — one flat level; see
  *Scoped agent-team pattern* below).
- **The durable multi-session L2→L1→L0 tree** — and any layer that dispatches
  a *child dispatching layer* — **must** be separate sessions (tmux/container)
  coordinated by the `ct` heartbeat. This is the **only** hard "must be a
  session" case: a subagent/teammate can neither spawn the next dispatching
  layer nor persist/self-supervise across sessions.

(Canonical "what can be a layer" treatment: goal-tree
`references/layer-model.md`, *Platform constraint*.)

---

## Scoped agent-team pattern (D7)

This is the **corrected** mapping that verification surfaced (D7), the
complement to constraint 2 above: the dead `L1=teammate → L0=subagent`
mapping is replaced by modelling **one attended layer as one team**.

### Corrected mapping

Model a SINGLE attended layer as a team: the layer's **lead**
(re-grounded from disk) runs its **workers as teammates**, e.g.
`L1 = lead, L0 workers = teammates`. One team = one flat level = one
attended layer. (NOT workers-as-subagents — see constraint 2.)

### What it buys (over workers-as-subagents) for the attended burst

- **Mid-task steering** — the lead can redirect a teammate while it works;
  subagents cannot be steered once dispatched.
- **`plan_approval` gating** — a teammate's plan can be approved/rejected
  before it proceeds, giving the L{N}-review checkpoint as a **native
  primitive**; subagents cannot be `plan_approval`-gated.
- **Shared task list** across lead + teammates.
- **Richer `SendMessage` IPC** (`message`/`broadcast`/`shutdown_request`/
  `plan_approval_response`) in place of tmux `send-keys`.
- Eliminates tmux/`ct`/session plumbing **for the in-session case**.

### Scope boundary (load-bearing)

ADOPT the team **only as the inner engine of a single attended working
session for ONE layer**: a per-tick team that re-grounds from disk, runs
the supervised burst with `SendMessage`/`plan_approval`, writes results to
disk/PRs, and tears down.

KEEP homebrew for the **heartbeat + durable state + the 3-layer tree**:
`ct` scheduling, `GOAL.md`/`CLAUDE.md`/coordinator/`sweeps.jsonl` state, and
the nesting that comes from separate per-layer sessions.

The boundary is **heartbeat + state + nesting vs. one attended burst** —
NOT "persistence vs. ephemeral."

### 3-layer autonomous tree is UNCHANGED

You **cannot** run L2→L1→L0 as live nested teams: a team is one flat level
and one process cannot be both a teammate and a lead (cross-reference
**Platform constraints** constraint 2 — no nested teams). The autonomous
tree stays tmux `send-keys` + `ct` + separate per-layer sessions.

### Why ephemerality is not fatal

A team's lack of cross-session persistence does not matter here precisely
*because* the loop already re-grounds from disk every tick — a fresh team
is spun up per tick (or per attended working session) and re-grounds from
the same durable disk state. See **Platform constraints** constraint 3
("~0% live context / ~100% durable disk") and **State-preserving design**
below; this section does not restate them.

### Dogfooding gate

D7 dogfooding requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, which is
**NOT set on this host**. This section therefore *documents* the pattern;
adopting it live is **deferred until the operator enables the flag**.

**Revisit when** agent teams gain nesting and/or scheduled/unattended
execution (per D7) — at which point a fuller native L{N} becomes possible.

---

## Recursive ownership principle

**Each supervisor owns the lifecycle of its direct children.**

- L2 owns L1 lifecycle: L2 starts, monitors, clears, and retires L1s.
- L1 owns L0 lifecycle: L1 starts, monitors, clears, and retires L0s.

No layer auto-stops its *children*. When a child has no remaining work
the supervisor emits an **idle-fleet** signal and its parent decides
whether to stop that child. This is recursive: L1 reports idle-fleet → L2
decides; L2 reports idle-fleet → operator decides.

A supervisor MAY, however, **auto-stop its own tick loop** once its fleet
is *confirmed idle* for `auto_stop_idle_ticks` consecutive ticks (D10) —
see **Idle-fleet signal** below. This bounds the otherwise-unbounded idle
escalation loop; it stops the supervisor itself, never its children.

---

## Objective-scoped lifetime (child = L1)

**An L1's lifetime keys on its OBJECTIVE — not its tree, not the mission.**
Three scopes must be kept distinct:

- **Tree** — one dispatch graph (decomposition → all-nodes-complete). The
  shortest scope. **Tree-completion is NOT a teardown trigger.**
- **Objective** — a defined outcome with acceptance criteria, solved by a set of
  L0 activities. **May span more than one tree.** Finite — it has a terminal
  accept state.
- **Mission** — the continuous L∞ vector; never "done."

An objective-scoped L1 is spawned for one objective, heartbeat-drives its L0s to
that objective's AC, and is retired once the objective is accepted. It is **not**
a persistent generic worker or a reusable pool: **new objective → new L1** (the
concrete spawn op lives in the l2-supervise launcher's
`references/supervision.md`, *Spawn-on-new-objective*).

### Reconciliation (supersedes the "mission-immortal L1" framing)

An earlier rule held that an L1's session is *persistent across iteration trees;
do not kill on tree completion.* That rule conflated tree, objective, and
mission. Its **valid kernel is preserved**: tree-completion does NOT retire an
L1 — an objective may legitimately span multiple trees. Its **superseded part**
is the framing of the L1 as a mission-scoped, effectively immortal actor.
Mission continuity is the **supervisor's** concern (L2 / L(top)), realized by
**spawning successive objective-scoped L1s**, not by keeping one L1 alive
forever. Both rules' real concerns survive; only the over-broad
"mission-immortal L1" framing is replaced.

### Where the objective + AC are declared

The objective and its acceptance criteria live in a structured **"Objective +
AC" block in the L1's PLAN.md** (a coord node field when coord is live). The L1
is spawned with this block. Full machine-checkability is **not** required — the
terminal gate is an **L2 acceptance judgment** over the AC plus the evidence the
L1 surfaces, not a strict machine predicate (see *Objective-accept marker*
under **Teardown guards**).

---

## Generic state machine

```
spawned → working → pr-open → fixing → merged → complete → retired
```

Orthogonal context axis:
```
working ←─context-pressure─→ cleared ─→ working (next tick)
```

Edge states (orthogonal to primary path):
```
frozen       same cursor anchor above ❯ for 2+ consecutive ticks
abandoned    no PR, no commits, no working signal for `abandoned_ticks` (default 5) ticks
context-maxed  context ≥ 84% AND safe-break gate fails this tick
```

### State table

| State | Entry trigger | Who acts | Exit |
|-------|--------------|----------|------|
| `spawned` | Supervisor dispatches child (workspace + session created) | — | Child produces first output → `working` |
| `working` | Child is producing tokens or running tools | — (leave it alone) | PR opened / context-pressure / frozen |
| `pr-open` | Child has an open PR for its leaf | Supervisor: invoke `/l{N-1}-review <PR>` | CLEAN → `merged`; NEEDS-WORK → `fixing`; PR closed-without-merge → `abandoned` |
| `fixing` | `/l{N-1}-review` returned NEEDS-WORK or BLOCKING | Supervisor: dispatch child to fix and re-review | Re-review returns CLEAN → `merged` |
| `merged` | Child's leaf PR is merged or closed | — | Complete check passes → `complete` |
| `complete` | All four complete-check conditions met (see below) | Supervisor: perform teardown per binding | Teardown succeeds → `retired` |
| `retired` | Teardown complete | — (terminal state) | n/a |
| `frozen` | Same cursor anchor ABOVE `❯` for 2+ ticks | Supervisor: emit `frozen: <child> N ticks` in sweep report; escalate if 1 shell still running | Anchor changes; or operator decision |
| `abandoned` | No PR, no commits, no `working` signal for `abandoned_ticks` ticks; or PR closed without merge | Supervisor: report to parent | Operator decision |
| `context-pressure` | Child context ≥ `clear_threshold` AND safe-break gate passes | Supervisor: issue `/clear` to child; re-deliver prompt NEXT tick | Child clears → `working` (next tick) |
| `context-maxed` | Child context ≥ 84% AND safe-break gate fails this tick | Supervisor: emit `context-critical: <child> at <N>%` in sweep report; skip delivery | Safe-break gate passes (future tick or operator resolves) |

---

## Complete check

A child is `complete` when **all four** hold simultaneously:

1. **Leaf PR merged or closed.** The child's branch has a merged or
   closed PR: `gh pr list --repo <repo> --head <branch> --state all \
   --json number,state -q '.[] | select(.state=="MERGED" or .state=="CLOSED") | .number'`
   returns a result.

2. **No unpushed commits.** `git -C <worktree> log @{u}.. --oneline`
   is empty. If `@{u}` fails because no upstream is configured, treat
   the child as NOT complete (unknown push state = cannot confirm).

3. **No dirty tracked files.** `git -C <worktree> status --porcelain`
   has no lines with a tracked-file indicator. Untracked `.claude/`
   entries (`?? .claude/...`) are acceptable. Any other status line
   means the child has unsaved work and is NOT `complete`.

4. **CLEAN l{N-1}-review marker present.** The PR must have a
   `<!-- l{N-1}-review:metadata -->` comment with `verdict: CLEAN`
   (see "Integration with lN-review-doctrine" below). If the PR was
   merged without this marker, the child is NOT `complete` — emit
   `review-missing: <child> PR <N>` and route to parent.

The tick **SUBAGENT reports** `complete`; it does NOT perform teardown.
Subagent emits: `new-state: complete <child-session>` in the sweep
report. The SUPERVISOR performs teardown on the next action cycle.

---

## Teardown guards

Before teardown, the supervisor MUST verify all guards:

1. **Never teardown own session.** The child's tmux session name MUST
   differ from the supervisor's own session. (Extension of the existing
   `close-workspace` refuse rule — applies at every layer.)
2. **Leaf PR is merged or abandoned** — not draft, not open.
3. **No unpushed commits** (complete-check condition 2).
4. **No dirty tracked files** (complete-check condition 3).
5. **Supervisor has accepted the objective outcome** (objective-scoped children
   only — e.g. child = L1). The supervisor has made an acceptance judgment over
   the child's objective AC + surfaced evidence and written a durable
   **objective-accept marker** (see below). For a non-objective-scoped child
   (e.g. an L0 leaf, where the CLEAN review marker + merge IS the acceptance),
   this guard is satisfied by guards 2–4 plus complete-check condition 4.

If any guard fails: **do not proceed**. Emit:
`teardown-blocked: <child> — <reason>` and escalate to parent.

### Objective-accept marker (L2 retires; the L1 does not self-terminate)

Termination is **the supervisor retiring the child**, not the child
self-destructing. For an objective-scoped L1:

1. The L2 makes its **acceptance judgment** over the objective's AC + the L1's
   surfaced evidence (per `lN-review-doctrine` axis 3 / the l2-review verdict).
2. On accept, the L2 writes a **durable accept-marker the L1 can poll** — a file
   `~/.config/l2-supervise/<tree-id>/accepted/<objective-id>` (or the coord node
   "accepted" field when coord is live). It survives `/clear` and is readable by
   the L1 between ticks, so the L1 can observe its own retirement is sanctioned.
3. The L2 then runs teardown — it owns the L1's lifecycle (*Recursive ownership*
   above) and **never tears down its own session**.

This appends to the existing teardown guards (PRs merged ∧ no-unpushed ∧
no-dirty-tracked) the final gate **+ the supervisor has accepted the objective
outcome**. The accept-marker is what guard 5 verifies. The concrete write +
retire mechanics live in the l2-supervise launcher's `references/supervision.md`
(*Accept-marker and retire*).

### Heartbeat teardown (retiring a child that runs its own heartbeat)

A child that is itself a supervisor (e.g. an L1, which runs an `l1-supervise`
heartbeat) carries durable heartbeat state. Retiring it MUST also tear that down:
remove its `ct` entry (`ct rm l1-<id>`) and **archive** its config dir
`~/.config/l1-supervise/<id>/`. This is distinct from the S.14 confirmed-idle
auto-stop / `--stop` (which preserves the dir for restart) — retirement closes
the objective, so the heartbeat state is archived, not preserved. See the
per-layer **L2 binding** below for the concrete sequence.

---

## Workspace-isolation invariant

State-mutating work — file edits, scripts that write files, and
measurement/build scripts that touch the repo — runs in a dedicated
worktree (or throwaway clone), **never the primary working clone**. A
script that would mutate a clone whose tree is dirty (uncommitted
changes present) MUST refuse and abort rather than proceed.

**Why:** the primary clone holds operator and other-actor WIP. Mutating
it from a child session corrupts that WIP (dirty tree, surprise
autostash) and breaks the worktree-per-child isolation the lifecycle
states above rely on. Refusing on a dirty tree protects work the
mutating actor cannot see.

---

## Idle-fleet signal

When the child has **no remaining work** — all leaf PRs merged, all
its own children retired, no open PRs — the supervisor emits:

```
idle-fleet: <child-session> — all work complete; no open PRs; no active children
```

### Confirmed-idle auto-stop (D10)

Per **D10**, a supervisor SHALL **auto-stop its own `ct` tick** when its
fleet is **confirmed idle** for `auto_stop_idle_ticks` (default 3)
consecutive ticks, instead of escalating indefinitely. This supersedes the
prior rule that *"the supervisor does NOT auto-stop itself."*

**Confirmed idle** means exactly one of:
- **empty registry** (`no-l1-active` — no children at all), OR
- **all children `complete`/`retired`** with no open PRs, OR
- **idle-and-blocked**: children/lanes still exist, but **no actionable work
  remains** — every pending item is human-gated or otherwise blocked, so no tick
  can advance anything without operator input. Concretely: no child is `working`,
  no ready/dispatchable node is unblocked, no PR is ripe for the supervisor to act
  on (every open PR is awaiting operator merge/approval or another actor), no new
  cycle has opened, and any pending friction/escalation is gated on the operator.
  This is the cadence **floor of STOP**: when quiet *and* nothing is actionable,
  ticking at the ceiling forever is pure waste — stop instead.

A mid-cycle healthy fleet, a `context-pressure` child, or a `frozen` child
is **NOT** idle (those are actionable on a future tick without operator input).
Any non-idle tick **resets the consecutive-idle counter to 0**. The counter
counts confirmed-idle ticks regardless of how the tick is classified for cadence
purposes.

**Behavior by consecutive-idle count:**
- Counts `1 .. auto_stop_idle_ticks − 1`: emit the `idle-fleet` signal to the
  parent as before (L1 → L2; L2 → operator). Do **not** auto-stop.
- Count `auto_stop_idle_ticks` (the Nth consecutive confirmed-idle tick):
  emit a final escalation line naming the **resume trigger** — the operator
  action that re-opens actionable work (e.g. merging a ripe PR, unblocking a
  gated node, opening the next cycle):
  ```
  auto-stop: fleet confirmed idle for <N> consecutive ticks; resume on <resume-trigger>
  ```
  then run `ct rm` on the supervisor's **own** entry
  (`ct rm l1-<tree-id>` / `ct rm l2-<tree-id>`) and exit. Resume happens by the
  operator re-launching supervision with `/l{N}-supervise` once that trigger fires.

The auto-stop targets the supervisor's **own** tick loop only — never a
child. Teardown of children remains governed by the complete-check and
teardown guards above.

Recursive pattern (pre-threshold idle ticks):
- L1 includes idle-fleet lines in its sweep report → L2 decides.
- L2 includes idle-fleet lines in its sweep report → operator decides.

---

## Context-pressure axis

### Detecting context level

At each tick, for each child, the supervisor captures the child's
pane (`tmux capture-pane -t <child-target> -p -S -20`) and extracts
the context percentage:

```bash
ctx_pct="$(tmux capture-pane -t "$TARGET" -p -S -20 2>/dev/null \
  | grep -oE '[0-9]+%' | tail -1 | tr -d '%' || echo "")"
```

If the extraction yields empty, record `ctx_pct=null` for this tick.

### Safe-break gate

A `/clear` is issued ONLY when **all** of the following are true for
that child's pane (captured fresh this tick, bottom 20 rows):

- No `ing…` (U+2026) spinner line (ongoing turn).
- No `still running` line (running tool).
- No `esc to interrupt` line (active agent turn).
- No numbered-options prompt or `Do you want to proceed?` line.
- Pane content ABOVE `❯` is settled (not mid-tool-output burst).

**Frozen-spinner exception**: if the spinner text matches the previous
tick's recorded `spinner_text` value for this child (same text, same
session, consecutive ticks), treat the child as idle for `/clear`
purposes — the spinner is frozen, not active. The safe-break gate
passes despite the visible spinner.

### Threshold values

| Name | Default | Config key | Behavior |
|------|---------|-----------|---------|
| `clear_threshold` | 35 | `clear_threshold` | Auto-clear when `ctx_pct ≥ clear_threshold` AND gate passes. Lowered 50→35 (quota-burn fix): cache reads were 96.9% of tokens vs cache-create 2.5%, so clearing earlier (a few more rebuilds) is strongly net-positive. |
| `context_critical` | 84 | hardcoded | Surface `context-critical`; skip delivery; never auto-compact |
| `auto_stop_idle_ticks` | 3 | `auto_stop_idle_ticks` | Auto-stop own `ct` tick after N consecutive confirmed-idle ticks (D10). Absent key → 3 |

Config file (substitute `1` or `2` for `N` at your layer):
`~/.config/l1-supervise/<tree>.<sub>/config.yml` (L1) or
`~/.config/l2-supervise/<tree>.<sub>/config.yml` (L2)
```yaml
clear_threshold: 35      # integer 0-100; default 35
cron_interval: 300       # seconds; default varies by layer
cron_backoff: 600        # seconds; backoff interval for idle periods
abandoned_ticks: 5       # integer; ticks of no-working-signal before abandoned
auto_stop_idle_ticks: 3  # integer ≥1; consecutive confirmed-idle ticks before auto-stop (D10)
```
Keys absent from config → use defaults. File absent → all defaults.

### Auto-clear procedure

When `ctx_pct ≥ clear_threshold` AND safe-break gate passes:

1. Send `/clear` to the child pane as two separate keystrokes (per the
   established ct-fire split pattern — `&&`-chaining causes the Enter
   to be treated as paste continuation, not a submit):
   ```bash
   tmux send-keys -t "$TARGET" -l -- "/clear"
   sleep 0.3
   tmux send-keys -t "$TARGET" Enter
   ```
2. Record `cleared_at=<iso8601>` in the sweep for this child.
3. Re-deliver the tick prompt on the **next** cron fire (not
   immediately — the child needs one turn to restore context from
   its CLAUDE.md).

### State-preserving design

After `/clear` the child rebuilds from its CLAUDE.md alone:
- CLAUDE.md MUST contain standing rules, current task/objective,
  escalation points, and handoff conditions.
- `sweeps.jsonl` (last N ticks) preserves the supervision history
  and is available for context restoration.
- No other state injection is required from the supervisor. The
  child's CLAUDE.md is the authoritative persistent memory across
  `/clear` events.
- The **task-list binding** (`CLAUDE_CODE_TASK_LIST_ID`) is also part of
  the durable state that must survive `/clear`. Claude Code reads that
  var only at process startup, so the binding is restored by having it
  in the launching process env (the supervise `start.md` writes it to
  the tmuxp `environment:` block + `.envrc`) and is recorded canonically
  at `~/.config/l{1,2}-supervise/<tree-id>/task-list-id` and the project
  `CLAUDE.md` `Task List ID:` field. The `SessionStart` recovery hook
  (`claude/hooks/task-list-recovery.sh`) detects an unset binding after
  `/clear`, surfaces the persisted ID + relaunch step, and repairs the
  record for the next launch — it cannot mutate the live process env.

### Context tracking in sweep reports

Per tick per child, record in `sweeps.jsonl`:
- `ctx_pct`: integer or `null`.
- `spinner_text`: the current spinner verb line from the pane, or `null`.

Sweep report includes:
- Per-child classification row includes `ctx=<N>%`.
- `ctx_delta_per_tick`: running average of `ctx_pct` change over the
  last M=5 ticks. Computed from `sweeps.jsonl`.
- Approaching-threshold warning when `ctx_pct + ctx_delta_per_tick * 3 ≥ clear_threshold`:
  emit `approaching-threshold: <child> at <N>%, Δ=<D>%/tick, projected ~<K> ticks`.

---

## Inter-actor delivery — inbox-on-nudge (S.25)

Cross-session / inter-actor **content** moves over the durable agent-coordinator
**inbox**, not over free-text `send-keys`. The inbox primitive is live in
agent-coordinator (`:4000`): `ac_message_send` (durable enqueue) / `ac_inbox_query`
(drain; unread default) / `ac_ack` (ack after processing), keyed on
`recipient = agents.agent_id`. This section is the **one home** for the rule; both
`l1-supervise` and `l2-supervise` (tick + supervision dispatch) **point** here and do
not restate it.

This closes the two `send-keys`-content failure modes at the doctrine level: **content
clobber** (free-text typed into a pane mid-turn is absorbed into the active buffer / lost)
and **drop-on-busy** (a nudge to a busy pane with no durable queue is dropped).

### The rule

1. **Send via inbox.** Inter-actor *content* — a supervisor addressing a child (a
   task/instruction), a child surfacing to its supervisor, lane↔lane — SHOULD be sent
   durably via `ac_message_send` to the recipient's stable AC agent-id, **not** as free-text
   `send-keys` content. Durable enqueue survives a busy or absent recipient (no pane race, no
   drop-on-busy, no content clobber).

2. **Drain on nudge.** At tick start (a supervise tick) and at the start of a child's turn,
   the actor drains the inbox addressed to its **own** agent-id: `ac_inbox_query` (unread) →
   act on each message → `ac_ack` it. Ack is **idempotent** — the inbox guarantees one
   winner, so a double-drain (e.g. two near-simultaneous nudges) is safe.

3. **send-keys is the wake nudge only.** The tickler's `ct` `--prompt` (a fixed standing
   drive prompt re-sent every interval; see `bin/ct` `fire`) is a benign "you have a turn —
   drain your inbox and proceed" **wake**. Only *content* moves to the inbox; the wake itself
   stays `send-keys` — it is the only way to nudge an idle pane. REPL **control** keystrokes
   (`/clear` — *Auto-clear procedure* above; `/l{N}-supervise --stop`) are control signals,
   not content, and likewise stay `send-keys`.

4. **Fail-soft (AC unreachable).** The drain MUST degrade gracefully and never wedge the
   tick. Mirror the errored-vs-affirmatively-empty distinction the no-ready-work idle gate
   uses for `ac_node_query`: **only a successful `ac_inbox_query` — including the affirmative
   "empty" marker — counts as "no messages".** A query that is **unavailable** (MCP
   unreachable) or **errors** falls through to *proceed without the drain*, emitting one note
   line (`inbox-drain-skipped: AC unreachable`); it does not block the tick and is never
   treated as "inbox empty".

### Agent-id binding (Provisional)

Each actor drains and is addressed by its own **stable AC agent-id**. The rule is stated
abstractly on purpose: this is doctrine, and the concrete id has no live effect until the
staged cutover (below) wires real sends/drains.

- **Provisional recommended binding:** the actor's **tmux session name** — the lowest-surface
  choice, already the operational handle the supervision loop uses to address every pane.
- **Revisit:** confirm against AC's actual agent-registration identity when the cutover wires
  real sends/drains, and bind the concrete id **then**.
- **Rejected:** a tree-scoped `l{N}-<tree-id>` id — it **collides across a multi-L1 fleet**
  (many L1s share `l1-<tree-id>`), so it cannot uniquely address one actor's inbox.

### Division of labor (unchanged invariant)

The **supervisor** drains its own inbox and sends content — these are actions, owned by the
tick procedure (`tick.md`). The **tick subagent** (`supervision.md`) stays
observe-and-report: it does **not** drain or send (its *Subagent self-restraint* already
forbids state writes and scheduling). This preserves the existing destructive-actions-never-
from-the-subagent invariant.

### Live cutover is the staged follow-on (NOT done by adopting this rule)

Adopting this doctrine does **not** remove `send-keys` *content* delivery from the running
path. That live cutover is staged in `~/src/work/layer-pivot/s19-ac-inbox/S19-INBOX.md`
(stages 1–4: dual-write → recipient-drains → cut `send-keys` content → remove dual-write),
each with rollback. Likewise, **wiring a child to actually drain on its turn** (project
`CLAUDE.md` / loop doctrine) is stage 2 of that cutover, not part of stating this rule. This
section lands the *model*; the live re-pointing is separate and stage-gated.

---

## Answering a child's interactive AskUserQuestion (S.26)

When a child's pane is **blocked on an interactive `AskUserQuestion` menu**
(numbered options; possibly multi-question, needing per-question navigation +
a final Submit), the supervisor answers it **through the pane**. The inbox
(*Inter-actor delivery — inbox-on-nudge* above) does **not** cover this case: a
child blocked on an open TUI menu is not at a turn boundary and will not drain
its inbox until the menu is gone. This is the one content case that cannot ride
the inbox.

**Blind menu-key selection over `send-keys` is unreliable — do not use it.**
Arrow/number keys do not register cleanly through the pane, and a multi-question
UI needs per-question navigation plus a final Submit. A blind selection
typically just echoes `^[[C` and nothing submits.

**Canonical procedure — Esc-then-text:**

1. Send `Escape` to the child's pane to **dismiss** the menu:
   ```bash
   tmux send-keys -t "$TARGET" Escape
   ```
2. Send the decision as **plain text**, using the established two-keystroke
   split (per *Auto-clear procedure* — `&&`-chaining makes the Enter a paste
   continuation, not a submit):
   ```bash
   tmux send-keys -t "$TARGET" -l -- "<decision as plain text>"
   sleep 0.3
   tmux send-keys -t "$TARGET" Enter
   ```

The child consumes the text as its next turn and proceeds. State the chosen
answer explicitly (name the option per question) so the child does not re-open
the menu. Like the wake nudge and the `/clear` / `--stop` control keystrokes,
this stays `send-keys` — it is the only channel that reaches a pane blocked on
its own menu.

(Verified 2026-06-01: blind menu-key selection stuck — echoed `^[[C`, nothing
submitted — against both guardian's L2 and the stack-steward L2 driving past
2-question menus; Esc-then-text cleared both.)

---

## Division of labor

| Action | Tick subagent | Supervisor |
|--------|--------------|------------|
| Detect `complete` | ✓ reports | — |
| Perform teardown | — | ✓ acts |
| Detect context-pressure | ✓ reports ctx_pct | — |
| Issue `/clear` | — | ✓ acts |
| Detect frozen | ✓ reports | — |
| Resolve frozen / escalate | — | ✓ escalates to parent |
| Report idle-fleet | ✓ reports | ✓ relays to parent |
| Stop supervision | — | ✓ on parent decision, or self-`ct rm` on the Nth confirmed-idle tick (D10) |

Destructive actions (teardown, `/clear`, stop) NEVER originate from
inside the subagent. The subagent observes and reports; the supervisor
acts.

---

## Per-layer executor bindings

### L1 binding (l1-supervise executes this doctrine with child=L0)

| Property | L1 value |
|----------|---------|
| Child type | L0 workspace session |
| `complete` trigger | L0's leaf PR merged/closed + no-unpushed + no-dirty-tracked |
| Teardown method | `close-workspace <workspace>` → `tmux kill-session -t <session>` → `git worktree remove <path>` |
| `/clear` target | L0's Claude REPL pane |
| Parent receives reports | L2 |

### L2 binding (l2-supervise executes this doctrine with child=L1)

| Property | L2 value |
|----------|---------|
| Child type | L1 supervisor session |
| `complete` trigger | L1's objective AC met (per the Objective + AC block) **AND** L2 has accepted the outcome (objective-accept marker written) |
| Teardown method | Invoke `/l1-supervise --stop` against the L1's tree-id (removes the `l1-<id>` ct entry); **archive** the L1's heartbeat state `~/.config/l1-supervise/<id>/` (move to `~/.config/l1-supervise/.retired/<id>/`); remove L1 from `~/.config/l2-supervise/<tree-id>/l1-sessions` |
| `/clear` target | L1's Claude REPL pane |
| Parent receives reports | Operator |

---

## Integration with lN-review-doctrine

The lifecycle states `pr-open → fixing → merged` integrate with the
`lN-review-doctrine` review cycle:

- **`pr-open`**: supervisor invokes `/l{N-1}-review <PR>` (see
  `lN-review-doctrine` for the 3-axis evaluation protocol).
- **`fixing`**: supervisor dispatches child to address NEEDS-WORK /
  BLOCKING findings and re-run review. Review must reach CLEAN
  before transitioning to `merged`.
- **`merged`**: the `<!-- l{N-1}-review:metadata -->` block on the PR
  with `verdict: CLEAN` is the authoritative signal the review cycle
  completed.

The review-marker gate is enforced by complete-check condition 4 above
— `merged → complete` requires a CLEAN marker. The integration section
defines the signal format; condition 4 is the enforcement point.

---

## When this doctrine is wrong

If a rule here is wrong for the current iteration, **fix it here**
via PR against `pfeff/claude-skills`. Do not patch the rule inside
`l1-supervise` or `l2-supervise` — that is the doctrine-drift
failure mode this split exists to prevent. Doctrine edits land via
PR on a branch.

## See also

- `lN-review-doctrine` — the parallel review doctrine; the lifecycle
  `pr-open → fixing → merged` states reference the review-cycle states defined
  there.
- `goal-tree` `references/layer-model.md` — canonical "what can be a layer"
  platform constraint and the tree-depth → layer mapping.
- An `l1-supervise` executor runs this doctrine at N=1 (child=L0); an
  `l2-supervise` executor runs it at N=2 (child=L1).
