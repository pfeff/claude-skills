---
name: lN-lifecycle-doctrine
description: Shared doctrine reference for child-session lifecycle management at every supervision layer. Defines the generic child state machine (spawned→working→complete→retired, context-pressure axis, edge states), per-state entry/act/exit rules, complete-check guards, teardown discipline, idle-fleet handling, and per-layer executor bindings for an L1 supervision launcher (child=L0) and an L2 supervision launcher (child=L1). This skill has no operations — it is reference content a supervision executor loads at tick time and applies at its layer. Never inline this doctrine into the executor skills themselves.
allowed-tools:
  - Read
version: 1.1.0
---

# lN-lifecycle-doctrine — shared child-session lifecycle doctrine

This skill is a **doctrine-only reference**. It defines child-session lifecycle
management generically — applicable at any supervision layer in a multi-layer
agent tree (L2 supervises L1, L1 supervises L0). A supervision **executor**
(e.g. an `l1-supervise` launcher with child=L0, or an `l2-supervise` launcher
with child=L1) is a thin loop that loads this doctrine at tick time and applies
it at its own layer.

All the doctrine lives in this file's body so it is deliverable by name (invoke
the skill; the rendered body enters context). If you find yourself about to add a
lifecycle rule by editing an executor skill, **edit this file instead** — that is
the doctrine-drift failure mode this split exists to prevent.

## Platform constraints — what can be a layer

The hard platform limit is **no-nesting + durability**, not "a layer is always a
session." Three verified facts about the agent platform bound what a layer can be:

1. **Subagents cannot spawn subagents.** An Agent-tool subagent is strictly
   depth-1 — only a top-level session or a Workflow script may spawn agents. So a
   subagent is a leaf helper within one session, never a *dispatching* layer.
   - **Lifecycle implication:** a supervisor cannot delegate supervision to a
     subagent that itself spawns workers. The per-tick observation subagent is
     one-shot — it observes the fleet and **reports back**; it does **not** spawn
     the next layer.
2. **Agent-team teammates cannot spawn subagents; no nested teams.** A team is
   exactly ONE flat level (lead + teammates); teammates cannot spawn their own
   teams or subagents. You therefore cannot run L2→L1→L0 as live nested teams — a
   team models ONE attended layer, not the multi-deep tree.
3. **The loop depends on ~0% live conversation context and ~100% durable disk
   state + stateless re-grounding ticks.** Nothing is carried in memory between
   ticks; every tick re-reads doctrine + a fresh pane capture + the sweep log +
   the goal tree / coordinator + live PR state. The only thing that must stay
   alive is the heartbeat (until a sanctioned confirmed-idle auto-stop removes
   it); panes are live but gracefully re-groundable. Ephemerality of teams /
   `/clear` is **not fatal** — the child rebuilds from its `CLAUDE.md` alone (see
   **State-preserving design**).

### What can be a layer (substrate is a choice)

Constraints 1–2 bound *nesting*, not *substrate*. Within the no-nesting +
durability limit, the substrate for a child is chosen **per layer and use case**:

- **L0 (leaf task):** a real session / container, an Agent-tool **subagent**
  (worktree-isolated when it must produce its own PR), or a **Workflow** —
  whichever fits the task.
- **One L1 + its L0 workers (a single attended burst):** separate sessions, *or*
  an **agent team** (lead = L1, teammates = L0 — one flat level; see below).
- **The durable multi-session L2→L1→L0 tree** — and any layer that dispatches a
  *child dispatching layer* — **must** be separate sessions coordinated by the
  heartbeat scheduler. This is the **only** hard "must be a session" case: a
  subagent/teammate can neither spawn the next dispatching layer nor
  persist/self-supervise across sessions.

(Canonical "what can be a layer" treatment: the goal-tree
`references/layer-model.md` *Platform constraint* section.)

### Agent-teams as an inner engine (optional, flag-gated)

Where the platform offers agent-teams, a SINGLE attended layer may be modeled as
one team: the layer's **lead** (re-grounded from disk) runs its **workers as
teammates** (e.g. `L1 = lead, L0 workers = teammates`). One team = one flat level
= one attended layer. This is NOT workers-as-subagents (subagents are depth-1 and
cannot be steered), and NOT a way to nest layers.

What it buys for the attended burst: mid-task steering of a worker, plan-approval
gating (a native L{N}-review checkpoint), a shared task list, and richer
lead↔worker IPC — replacing pane `send-keys` plumbing for the in-session case.

Scope boundary (load-bearing): ADOPT the team **only as the inner engine of a
single attended working session for ONE layer** — a per-tick team that re-grounds
from disk, runs the supervised burst, writes results to disk/PRs, and tears down.
KEEP the homebrew heartbeat + durable state + the multi-layer tree (separate
per-layer sessions). The boundary is **heartbeat + state + nesting vs. one
attended burst** — not "persistence vs. ephemeral." Adopt this live only when the
platform's experimental agent-teams capability is enabled in the environment;
otherwise this section documents the pattern for when it is.

---

## Recursive ownership principle

**Each supervisor owns the lifecycle of its direct children.**

- L2 owns L1 lifecycle: L2 starts, monitors, clears, and retires L1s.
- L1 owns L0 lifecycle: L1 starts, monitors, clears, and retires L0s.

No layer auto-stops its *children*. When a child has no remaining work the
supervisor emits an **idle-fleet** signal and its parent decides whether to stop
that child. This is recursive: L1 reports idle-fleet → L2 decides; L2 reports
idle-fleet → operator decides.

A supervisor MAY, however, **auto-stop its own tick loop** once its fleet is
*confirmed idle* for `auto_stop_idle_ticks` consecutive ticks — see **Idle-fleet
signal** below. This bounds the otherwise-unbounded idle escalation loop; it stops
the supervisor itself, never its children.

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
concrete spawn op lives in the L2 supervision launcher's reference,
*Spawn-on-new-objective*).

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
AC" block in the L1's PLAN.md** (a coordinator node field when the coordinator is
live). The L1 is spawned with this block. Full machine-checkability is **not**
required — the terminal gate is an **L2 acceptance judgment** over the AC plus
the evidence the L1 surfaces, not a strict machine predicate (see
*Objective-accept marker* under **Teardown guards**).

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
frozen         same cursor anchor above the prompt for 2+ consecutive ticks
abandoned      no PR, no commits, no working signal for `abandoned_ticks` (default 5) ticks
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
| `frozen` | Same cursor anchor above the prompt for 2+ ticks | Supervisor: emit `frozen: <child> N ticks` in sweep report; escalate if 1 shell still running | Anchor changes; or operator decision |
| `abandoned` | No PR, no commits, no `working` signal for `abandoned_ticks` ticks; or PR closed without merge | Supervisor: report to parent | Operator decision |
| `context-pressure` | Child context ≥ `clear_threshold` AND safe-break gate passes | Supervisor: issue `/clear` to child; re-deliver prompt NEXT tick | Child clears → `working` (next tick) |
| `context-maxed` | Child context ≥ 84% AND safe-break gate fails this tick | Supervisor: emit `context-critical: <child> at <N>%` in sweep report; skip delivery | Safe-break gate passes (future tick or operator resolves) |

---

## Complete check

A child is `complete` when **all four** hold simultaneously:

1. **Leaf PR merged or closed.** The child's branch has a merged or closed PR:
   `gh pr list --repo <repo> --head <branch> --state all --json number,state -q '.[] | select(.state=="MERGED" or .state=="CLOSED") | .number'`
   returns a result.

2. **No unpushed commits.** `git -C <worktree> log @{u}.. --oneline` is empty. If
   `@{u}` fails because no upstream is configured, treat the child as NOT complete
   (unknown push state = cannot confirm).

3. **No dirty tracked files.** `git -C <worktree> status --porcelain` has no lines
   with a tracked-file indicator. Untracked `.claude/` entries (`?? .claude/...`)
   are acceptable. Any other status line means the child has unsaved work and is
   NOT `complete`.

4. **CLEAN l{N-1}-review marker present.** The PR must have a
   `<!-- l{N-1}-review:metadata -->` comment with `verdict: CLEAN` (see
   "Integration with lN-review-doctrine" below). If the PR was merged without this
   marker, the child is NOT `complete` — emit `review-missing: <child> PR <N>` and
   route to parent.

The tick **subagent reports** `complete`; it does NOT perform teardown. The
subagent emits `new-state: complete <child-session>` in the sweep report. The
**supervisor** performs teardown on the next action cycle.

---

## Teardown guards

Before teardown, the supervisor MUST verify all guards:

1. **Never teardown own session.** The child's session name MUST differ from the
   supervisor's own session. (Applies at every layer.)
2. **Leaf PR is merged or abandoned** — not draft, not open.
3. **No unpushed commits** (complete-check condition 2).
4. **No dirty tracked files** (complete-check condition 3).
5. **Supervisor has accepted the objective outcome** (objective-scoped children
   only — e.g. child = L1). The supervisor has made an acceptance judgment over
   the child's objective AC + surfaced evidence and written a durable
   **objective-accept marker** (see below). For a non-objective-scoped child
   (e.g. an L0 leaf, where the CLEAN review marker + merge IS the acceptance),
   this guard is satisfied by guards 2–4 plus complete-check condition 4.

If any guard fails: **do not proceed**. Emit `teardown-blocked: <child> —
<reason>` and escalate to parent.

### Objective-accept marker (the supervisor retires the child; the child does not self-terminate)

Termination is **the supervisor retiring the child**, not the child
self-destructing. For an objective-scoped L1:

1. The L2 makes its **acceptance judgment** over the objective's AC + the L1's
   surfaced evidence (per `lN-review-doctrine` axis 3 / the l2-review verdict).
2. On accept, the L2 writes a **durable accept-marker the L1 can poll** — a
   per-tree record keyed by objective-id (or the coordinator node "accepted"
   field when the coordinator is live). It survives `/clear` and is readable by
   the L1 between ticks, so the L1 can observe its own retirement is sanctioned.
3. The L2 then runs teardown — it owns the L1's lifecycle (*Recursive ownership*
   above) and **never tears down its own session**.

This appends to the existing teardown guards (PRs merged ∧ no-unpushed ∧
no-dirty-tracked) the final gate **+ the supervisor has accepted the objective
outcome**. The accept-marker is what guard 5 verifies. The concrete write +
retire mechanics live in the L2 supervision launcher's reference
(*Accept-marker and retire*).

### Heartbeat teardown (retiring a child that runs its own heartbeat)

A child that is itself a supervisor (e.g. an L1, which runs its own supervision
heartbeat) carries durable heartbeat state. Retiring it MUST also tear that down:
remove its heartbeat entry and **archive** its per-instance config/state. This is
distinct from the confirmed-idle auto-stop / `--stop` (which preserves the state
for restart) — retirement closes the objective, so the heartbeat state is
archived, not preserved. See the per-layer **L2 binding** below for the concrete
sequence.

---

## Workspace-isolation invariant

State-mutating work — file edits, scripts that write files, and
measurement/build scripts that touch the repo — runs in a dedicated worktree (or
throwaway clone), **never the primary working clone**. A script that would mutate
a clone whose tree is dirty (uncommitted changes present) MUST refuse and abort
rather than proceed.

**Why:** the primary clone holds operator and other-actor work-in-progress.
Mutating it from a child session corrupts that WIP (dirty tree, surprise
autostash) and breaks the worktree-per-child isolation the lifecycle states above
rely on. Refusing on a dirty tree protects work the mutating actor cannot see.

---

## Idle-fleet signal

When the child has **no remaining work** — all leaf PRs merged, all its own
children retired, no open PRs — the supervisor emits:

```
idle-fleet: <child-session> — all work complete; no open PRs; no active children
```

### Confirmed-idle auto-stop

A supervisor SHALL **auto-stop its own tick** when its fleet is **confirmed idle**
for `auto_stop_idle_ticks` (default 3) consecutive ticks, instead of escalating
indefinitely.

**Confirmed idle** means exactly one of:
- **empty registry** (no children at all), OR
- **all children `complete`/`retired`** with no open PRs.

A mid-cycle healthy fleet, a `context-pressure` child, or a `frozen` child is
**NOT** idle. Any non-idle tick **resets the consecutive-idle counter to 0**. The
counter counts confirmed-idle ticks regardless of how the tick is classified for
cadence purposes.

**Behavior by consecutive-idle count:**
- Counts `1 .. auto_stop_idle_ticks − 1`: emit the `idle-fleet` signal to the
  parent as before (L1 → L2; L2 → operator). Do **not** auto-stop.
- Count `auto_stop_idle_ticks` (the Nth consecutive confirmed-idle tick): emit a
  final escalation line
  ```
  auto-stop: fleet confirmed idle for <N> consecutive ticks
  ```
  then stop the supervisor's **own** heartbeat entry and exit. The operator
  restarts supervision with the layer's supervise launcher.

The auto-stop targets the supervisor's **own** tick loop only — never a child.
Teardown of children remains governed by the complete-check and teardown guards
above.

Recursive pattern (pre-threshold idle ticks):
- L1 includes idle-fleet lines in its sweep report → L2 decides.
- L2 includes idle-fleet lines in its sweep report → operator decides.

---

## Context-pressure axis

### Detecting context level

At each tick, for each child, the supervisor captures the child's pane and
extracts the context percentage from the bottom rows. If the extraction yields
empty, record `ctx_pct=null` for this tick. A representative capture+extract:

```bash
ctx_pct="$(tmux capture-pane -t "$TARGET" -p -S -20 2>/dev/null \
  | grep -oE '[0-9]+%' | tail -1 | tr -d '%' || echo "")"
```

### Safe-break gate

A `/clear` is issued ONLY when **all** of the following are true for that child's
pane (captured fresh this tick, bottom rows):

- No ongoing-turn spinner line.
- No `still running` line (running tool).
- No `esc to interrupt` line (active agent turn).
- No numbered-options prompt or `Do you want to proceed?` line.
- Pane content above the prompt is settled (not mid-tool-output burst).

**Frozen-spinner exception**: if the spinner text matches the previous tick's
recorded `spinner_text` value for this child (same text, same session, consecutive
ticks), treat the child as idle for `/clear` purposes — the spinner is frozen, not
active. The safe-break gate passes despite the visible spinner.

### Threshold values

| Name | Default | Config key | Behavior |
|------|---------|-----------|---------|
| `clear_threshold` | 50 | `clear_threshold` | Auto-clear when `ctx_pct ≥ clear_threshold` AND gate passes |
| `context_critical` | 84 | hardcoded | Surface `context-critical`; skip delivery; never auto-compact |
| `auto_stop_idle_ticks` | 3 | `auto_stop_idle_ticks` | Auto-stop own tick after N consecutive confirmed-idle ticks. Absent key → 3 |

Per-instance config (one file per supervised tree/layer):

```yaml
clear_threshold: 50      # integer 0-100; default 50
cron_interval: 300       # seconds; default varies by layer
cron_backoff: 600        # seconds; backoff interval for idle periods
abandoned_ticks: 5       # integer; ticks of no-working-signal before abandoned
auto_stop_idle_ticks: 3  # integer ≥1; consecutive confirmed-idle ticks before auto-stop
```

Keys absent from config → use defaults. File absent → all defaults.

### Auto-clear procedure

When `ctx_pct ≥ clear_threshold` AND safe-break gate passes:

1. Send `/clear` to the child pane as two separate keystrokes (chaining the Enter
   with `&&` causes it to be treated as paste continuation, not a submit):
   ```bash
   tmux send-keys -t "$TARGET" -l -- "/clear"
   sleep 0.3
   tmux send-keys -t "$TARGET" Enter
   ```
2. Record `cleared_at=<iso8601>` in the sweep for this child.
3. Re-deliver the tick prompt on the **next** cron fire (not immediately — the
   child needs one turn to restore context from its `CLAUDE.md`).

### State-preserving design

After `/clear` the child rebuilds from its `CLAUDE.md` alone:
- `CLAUDE.md` MUST contain standing rules, current task/objective, escalation
  points, and handoff conditions.
- The sweep log (last N ticks) preserves the supervision history and is available
  for context restoration.
- No other state injection is required from the supervisor. The child's
  `CLAUDE.md` is the authoritative persistent memory across `/clear` events.
- Any **task-list binding** (e.g. a `CLAUDE_CODE_TASK_LIST_ID` env var) is part of
  the durable state that must survive `/clear`. Such a binding is read only at
  process startup, so it is restored by putting it in the launching process env
  and recording it canonically (per-instance config + the project `CLAUDE.md`). A
  session-start recovery hook can detect an unset binding after `/clear` and
  surface the persisted ID + relaunch step; it cannot mutate the live process env.

### Context tracking in sweep reports

Per tick per child, record in the sweep log:
- `ctx_pct`: integer or `null`.
- `spinner_text`: the current spinner verb line from the pane, or `null`.

Sweep report includes:
- Per-child classification row includes `ctx=<N>%`.
- `ctx_delta_per_tick`: running average of `ctx_pct` change over the last M=5
  ticks. Computed from the sweep log.
- Approaching-threshold warning when
  `ctx_pct + ctx_delta_per_tick * 3 ≥ clear_threshold`: emit
  `approaching-threshold: <child> at <N>%, Δ=<D>%/tick, projected ~<K> ticks`.

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
| Stop supervision | — | ✓ on parent decision, or self-stop on the Nth confirmed-idle tick |

Destructive actions (teardown, `/clear`, stop) NEVER originate from inside the
subagent. The subagent observes and reports; the supervisor acts.

---

## Per-layer executor bindings

### L1 binding (an l1-supervise executor runs this doctrine with child=L0)

| Property | L1 value |
|----------|---------|
| Child type | L0 workspace session |
| `complete` trigger | L0's leaf PR merged/closed + no-unpushed + no-dirty-tracked |
| Teardown method | Close the workspace → kill the child session → remove the child worktree |
| `/clear` target | L0's agent REPL pane |
| Parent receives reports | L2 |

### L2 binding (an l2-supervise executor runs this doctrine with child=L1)

| Property | L2 value |
|----------|---------|
| Child type | L1 supervisor session |
| `complete` trigger | L1's objective AC met (per the Objective + AC block) **AND** L2 has accepted the outcome (objective-accept marker written) |
| Teardown method | Stop the L1's supervision tick against its tree-id (removes its heartbeat entry); **archive** the L1's heartbeat state (move it to a retired location); remove the L1 from the L2's session registry |
| `/clear` target | L1's agent REPL pane |
| Parent receives reports | Operator |

---

## Integration with lN-review-doctrine

The lifecycle states `pr-open → fixing → merged` integrate with the
`lN-review-doctrine` review cycle:

- **`pr-open`**: supervisor invokes `/l{N-1}-review <PR>` (see
  `lN-review-doctrine` for the 3-axis evaluation protocol).
- **`fixing`**: supervisor dispatches child to address NEEDS-WORK / BLOCKING
  findings and re-run review. Review must reach CLEAN before transitioning to
  `merged`.
- **`merged`**: the `<!-- l{N-1}-review:metadata -->` block on the PR with
  `verdict: CLEAN` is the authoritative signal the review cycle completed.

The review-marker gate is enforced by complete-check condition 4 above —
`merged → complete` requires a CLEAN marker. The integration section defines the
signal format; condition 4 is the enforcement point.

---

## When this doctrine is wrong

If a rule here is wrong for the current iteration, **fix it here** via a PR
against this skill. Do not patch the rule inside an executor (`l1-supervise` /
`l2-supervise`) — that is the doctrine-drift failure mode this split exists to
prevent. Doctrine edits land via PR on a branch.

## See also

- `lN-review-doctrine` — the parallel review doctrine; the lifecycle
  `pr-open → fixing → merged` states reference the review-cycle states defined
  there.
- `goal-tree` `references/layer-model.md` — canonical "what can be a layer"
  platform constraint and the tree-depth → layer mapping.
- An `l1-supervise` executor runs this doctrine at N=1 (child=L0); an
  `l2-supervise` executor runs it at N=2 (child=L1).
