---
name: improvement-loop
description: Persistent interactive host for the split-screen self-improvement loop. Runs the improvement pane's wake cycle — drain the /skillify queue, mine the working session's transcript delta past a high-water mark, classify lessons, draft PR-gated improvements, update the pending index, and set backoff. Use when hosting the improvement pane, on a ct tick, at a session boundary, or when the operator asks to run the loop or "what's pending?".
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - AskUserQuestion
version: 1.0.0
---

# Improvement Loop — loop host

The improvement pane's host skill. It does **not** fork a new concept: it is a
persistent interactive host for the existing `lessons-learned` (analysis) and
`self-improvement` (apply-as-PR) machinery, with `loop-optimizer` grading the
loop itself (DESIGN R7). This skill owns the *cadence, mining, queue, and PR
plumbing*; the judgment about what a lesson means and how to fix it stays in
those skills.

## Billing invariant (hard constraint, R8)

This pane is an **interactive Claude TUI session in tmux, ticked by `bin/ct`
via `send-keys`** — the subscription pool. Never convert it to `claude -p`, the
Agent SDK, GitHub Actions, `CronCreate`/`RemoteTrigger`, or any scheduled cloud
agent. See `~/.claude/improvement/load-bearing.md` and `~/.claude/CLAUDE.md` →
"Claude Code Billing".

## State directory (`~/.claude/improvement/`)

- `queue/` — one Markdown file per `/skillify` lesson entry (frontmatter:
  `source_session`, `source_cwd`, `type: lesson|new-skill`, `subtype?`,
  `timestamp`, `status: pending`).
- `processed/` — queue entries archived after a cycle handles them.
- `state.json` — `high_water_marks` (per transcript), `backoff`
  (`{level, next_interval_seconds}`), `pairing`
  (`{improvement_target, working_session:{session_id,cwd,tmux_target}, resolved_at}`).
- `pending.md` — open improvement-PR index (see `pending` operation).
- `load-bearing.md` — the R5 never-auto-merge list.

Helper scripts live in `~/.claude/bin/` (from dotfiles): `skillify-capture`,
`resolve-working-session`, `improvement-mine-delta`, `improvement-backoff`,
`improvement-pending`, `improvement-loop-register`.

## Invocation

| Arguments | Operation |
|-----------|-----------|
| (none) or `wake` | Run the full wake cycle (below) |
| `pending` / "what's pending?" | Show the pending-PR index; do not run a cycle |

## Wake cycle

Run these in order. Keep it lean — an idle wake must stay near-zero cost and do
**no proactive make-work** (R3).

### 0. Resolve the pair (R6)

Determine this pane's own tmux target (`tmux display-message -p '#S:#I.#P'`),
then resolve/cache the working session:

```bash
~/.claude/bin/resolve-working-session --self "<own-target>"
```

- Exit 0 → `working_session` cached in `state.json`; also record this pane's
  target as `pairing.improvement_target` (so `/skillify` nudges land here):
  ```bash
  jq --arg t "<own-target>" '.pairing.improvement_target=$t' \
     ~/.claude/improvement/state.json > /tmp/imp.$$ && mv /tmp/imp.$$ ~/.claude/improvement/state.json
  ```
- Exit 3 (ambiguous) → ask the operator once with `AskUserQuestion` which
  session is the working pane, then write the choice into
  `pairing.working_session` and proceed. It is cached; do not ask again.
- Exit 2 (none) → no working session live; skip mining (queue may still have
  entries), and this counts toward an empty cycle for backoff.

### 1. Drain the queue

```bash
ls -1 ~/.claude/improvement/queue/*.md 2>/dev/null
```

Read each pending entry. These are explicit `/skillify` captures — treat them
as high-signal (the operator asked for them).

### 2. Mine the transcript delta (R1, delta-only)

```bash
~/.claude/bin/improvement-mine-delta
```

Emits only transcript lines past the high-water mark and advances the mark
(never re-reads history). Exit 10 = empty delta. Do not pass `--peek` in a real
cycle — the mark must advance so the same content is never mined twice.

### 3. Classify (the four lesson types)

For queued entries and mined delta, identify lessons of these types (reuse the
`lessons-learned` analysis lens — load its skill if you need the rubric):

- **operator corrections** — redirects, rephrasing, reverts
- **repeated friction** — retries, permission prompts, failed commands, duplicate lookups
- **solved novel problems** — candidates for compound/solution notes or new skills
- **automation gaps** — manual operator sequences a skill/hook/script could do

Discard noise. A `new-skill` queue entry is a direct candidate for a new skill.

### 4. Draft PR-gated improvements (R4)

For each actionable lesson, hand off to the `self-improvement` machinery to
generate the concrete change, then open a PR:

1. Map the target surface → repo/path via `references/surface-repo-map.md`.
2. **Load-bearing check**: cross-reference `~/.claude/improvement/load-bearing.md`.
   If touched, the PR **must** carry the `load-bearing` label and is never
   auto-merged — flag it for operator discussion (R5).
3. Create a feature branch in the target repo's worktree, apply the change,
   open a PR. **No direct pushes to main/master, no auto-merge.**
4. Quote or link the originating queue entry / mined lesson in the PR body so
   the change is traceable to its source.

Batch-when-idle: draft as work arrives; the operator reviews on their cadence.

### 5. Update the pending index & archive entries

- Record each opened PR in the index (mark load-bearing PRs with `--load-bearing`):
  ```bash
  ~/.claude/bin/improvement-pending add --pr <url> --repo <repo> \
    --surface "<surface>" --title "<title>" --source "<queue entry or 'delta'>" [--load-bearing]
  ```
- Move handled queue entries to `~/.claude/improvement/processed/`:
  ```bash
  mkdir -p ~/.claude/improvement/processed && mv <entry> ~/.claude/improvement/processed/
  ```

### 6. Set backoff (R3)

- **Empty cycle** — no queue entries AND empty transcript delta (mine exit 10)
  AND nothing drafted:
  ```bash
  ~/.claude/bin/improvement-backoff empty
  ```
- **Actionable cycle** — anything processed or drafted:
  ```bash
  ~/.claude/bin/improvement-backoff reset
  ```

Then reschedule the next `ct` tick to the new interval (the pane was registered
with `improvement-loop-register`, ct id `improvement-loop`):

```bash
ct reschedule improvement-loop "$(~/.claude/bin/improvement-backoff show)"
```

This is the whole cadence: an empty cycle lengthens the wait, an actionable one
tightens it. `ct` delivers the next wake via `send-keys` (subscription pool);
this skill never invokes a metered wake path.

### Report

End with a one-paragraph cycle summary: queue drained (N), delta lines mined
(N), lessons classified by type, PRs drafted (with load-bearing flags), and the
new backoff interval.

## `pending` operation

Answer "what's pending?" instantly from the index — do not run a cycle:

```bash
~/.claude/bin/improvement-pending list
```

Reconcile when convenient: for any indexed PR now merged/closed on GitHub, drop
it with `~/.claude/bin/improvement-pending close --pr <url>` (this is the "index
updated when a PR is closed" path). Summarize the open PRs, highlighting any
load-bearing (⚑) ones awaiting discussion.

## Progressive disclosure

- `references/surface-repo-map.md` — surface→repo routing + load-bearing check.
- Load `lessons-learned` / `self-improvement` skills on demand for their rubrics
  and apply mechanics.

## See also

- `/skillify` (dotfiles command) — the working-pane capture that feeds `queue/`.
- `lessons-learned`, `self-improvement` — the hosted analysis/apply machinery.
- `loop-optimizer` — grades this loop (actionable-vs-quiet wake ratio, PR merge
  vs revert rate).
