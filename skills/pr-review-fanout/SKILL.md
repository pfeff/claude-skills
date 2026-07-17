---
name: pr-review-fanout
description: Run the L1/L2 agent-review ladder across multiple open PRs concurrently instead of serially. Triggers when 2+ open PRs each need /l1-review and /l2-review before human review. Dispatches one delegated review agent per PR (each runs /l1-review then /l2-review sequentially, reading the posted L0 /review marker as evidence), collects verdicts, routes clean vs needs-work. Does not itself run /review, /l1-review, or /l2-review.
allowed-tools:
  - Task
  - SendMessage
  - TaskUpdate
version: 1.1.0
---

# pr-review-fanout — bulk L1/L2 review-ladder fanout

Runs the L1/L2 agent-review ladder (`/l1-review` then `/l2-review`) across
several open PRs **concurrently** instead of one at a time. This skill is
the first stage of a three-skill review pipeline that hands off by name:
`pr-review-fanout` (this skill) enumerates and dispatches, `operator-review`
receives clean PRs for human sign-off, and `fix-then-re-review-ladder`
recovers needs-work PRs back to clean.

This skill is a **dispatcher only**. It never runs `/review`, `/l1-review`,
or `/l2-review` itself — those are the province of the delegated review
agent it launches per PR, per `lN-review-doctrine`'s reviewer-independence
rule (each review must run in a fresh context window, not the dispatcher's).

## When to invoke

Invoke when 2 or more open PRs each need `/l1-review` and `/l2-review`
before they're ready for human review. A single PR needing the ladder
should just run it directly — this skill's value is the fanout across
several PRs at once, not a wrapper around a single review.

## Procedure

### Step 1 — Enumerate candidate PRs

List open PRs and, for each, read the posted markers (per
`lN-review-doctrine/references/checklist.md`'s "Posting protocol" —
canonical read surface is the reviews API, `gh pr view <n> --json
reviews,comments`). A PR is a candidate when:

- it carries a posted L0 `<!-- review:metadata -->` marker with verdict
  `CLEAN` (a `BLOCKING` L0 verdict means the PR isn't ready for L1/L2 at
  all — skip it, it needs L0 fix-up first), and
- it has **no** `<!-- l1-review:metadata -->` / `<!-- l2-review:metadata
  -->` marker, or an existing one is **stale** (posted against a SHA older
  than the PR's current HEAD — a marker against an old SHA does not cover
  the current diff and must be re-run).

For a PR flattened as a self-constituent (per the doctrine's self-
constituent-flattening rule), resolve its L2 constituents to their own
posted markers rather than re-deriving them here.

### Step 2 — Dispatch one review agent per PR, in parallel

For each candidate PR, dispatch a single delegated review agent (via the
Task tool). Brief each agent with:

- the PR number/branch and its existing worktree path — do **not** have
  it provision a new worktree; it operates on the PR's own,
- the instruction to run `/l1-review` then `/l2-review`, **sequenced**
  (l2-review's axis 2 evidence is the l1-review marker, so l1 must post
  first),
- the **read-only-worktree discipline** from
  `lN-review-doctrine/references/checklist.md`: no `stash`, `checkout`,
  `reset`, `restore`, `clean`, `rebase`, or branch switch in the PR's
  worktree — inspect prior revisions with `git show`/`git diff`/`git log
  -p` or a separate throwaway worktree instead, never the worktree under
  review,
- the requirement to verify the advisory count (warning + info, per the
  checklist's "Advisory = warning + info" rule) actually matches what's in
  the composed post body before posting either marker, and
- both markers must land dual-surface (PR review **and** issue-comment
  mirror, find-or-update by marker token) exactly as
  `lN-review-doctrine/references/checklist.md`'s "Marker emission
  template" and "Posting protocol" specify — copy those templates
  verbatim, do not hand-roll the YAML.

Dispatch all candidate PRs' agents in the same round (one Task call per
PR, sent together) rather than one at a time — that is the entire point
of fanout over the serial alternative.

### Step 3 — Track per-PR state

Maintain one `TaskUpdate` row per PR in flight, moving it through:
`dispatched -> l1-posted -> l2-posted -> routed`. A row that stalls
(no state change across a reasonable interval) is a candidate for the
duplicate-agent or usage-limit handling below — check it before assuming
it's still healthy.

### Step 4 — Collect verdicts as they land

Read results **as each agent finishes**, not by waiting for the whole
batch. A PR whose ladder is fastest should route immediately rather than
queuing behind a slower sibling.

### Step 5 — Route on the collected verdict

- **Clean** (both `/l1-review` and `/l2-review` posted `CLEAN`) — hand off
  to `operator-review`, **one PR at a time**. Do not batch multiple clean
  PRs into a single operator-review pass; the operator reviews them
  sequentially even though the ladder ran concurrently.
- **Needs-work** (either layer posted `NEEDS-WORK` or `BLOCKING`) — hand
  off to `fix-then-re-review-ladder`, which triages findings, dispatches a
  scoped fix, and re-runs the ladder against the new HEAD.

Neither handoff skill's doctrine is inlined here — this skill names them
as the routing target and stops; each owns its own procedure.

### Step 6 — Conflict resolution: duplicate agents on one PR

If two dispatched agents end up working the same PR (a re-dispatch after
what looked like a stall, a retry that raced the original), do not let
both post. Pick **one sole-finisher** — the agent that is further along
the ladder (has already posted a marker) wins; if neither has posted yet,
the one dispatched first wins — and stop the other via `TaskStop` (or the
equivalent cancel path) before it can post a duplicate or conflicting
marker. Record the resolution in that PR's `TaskUpdate` row.

### Step 7 — Usage-limit kills: resume, don't re-dispatch

If a dispatched agent is killed mid-review by a usage limit, **resume the
same agent** via `SendMessage` rather than dispatching a fresh one. A
fresh dispatch has no memory of which marker (if any) the killed agent
already posted, and re-running `/l1-review`/`/l2-review` from scratch
risks a duplicate or contradictory marker on the same PR — the
find-or-update-by-marker mechanics make same-type re-posts idempotent,
but only if the resuming agent knows what it already did, which a fresh
agent does not.

## Local-cache concurrency (resolves backlog #22)

`/l1-review` and `/l2-review` each write a local scratch file
(`.claude/reviews/l1-latest.md`, `.claude/reviews/l2-latest.md`) inside
the PR's own worktree before posting. Running several review agents
concurrently across different PRs raised the question of whether those
local files could clobber each other.

**Resolution: the posted dual-surface marker is the canonical
cross-operator evidence; the local cache is not, so concurrent writes to
it are harmless by construction** — this is existing `lN-review-doctrine`
doctrine (checklist.md: "The local `.claude/reviews/l<N>-latest.md` file
is the L{N}'s own record; another operator ... cannot read that file. All
cross-operator evidence ... flows through the PR comment"), not a new
mechanism this skill introduces. Two things make this concrete instead of
merely theoretical:

1. **Per-PR path isolation already holds in the normal case.** Each PR
   under review has its own worktree directory (this skill dispatches
   agents onto existing per-PR worktrees, never a shared one — see Step
   2), so `.claude/reviews/l<N>-latest.md` for PR A and PR B are
   physically different files on disk. Cross-PR clobber requires two
   agents sharing one worktree, which only happens in the duplicate-agent
   case (Step 6) — and that case is resolved by stopping all but the
   sole-finisher, not by scoping the cache path.
2. **Nothing downstream reads the local cache across agents.** `.claude/reviews/`
   is gitignored (repo-wide `.gitignore`); no consumer — not
   `operator-review`, not `fix-then-re-review-ladder`, not a higher-layer
   review — reads it. They all read the posted marker. A clobbered or
   stale local file changes nothing about what the next stage sees.

No additional cache-scoping mechanism (e.g. a PR-numbered cache path) is
introduced by this skill — it would add surface without changing what any
consumer actually reads.

## Edge cases

- **Shared local-cache clobber under concurrency** — see "Local-cache
  concurrency" above: harmless, because canonical evidence is the posted
  marker.
- **Usage-limit resume** — see Step 7: resume via `SendMessage`, never
  re-dispatch fresh.
- **Cross-PR file collisions** — see Step 6: one sole-finisher per PR,
  the rest are stopped.
- **Flattened self-constituent PRs** — see Step 1: resolve to the
  constituent's own posted markers rather than re-deriving a verdict.
- **Stale marker** — an existing l1/l2 marker posted against a SHA older
  than the PR's current HEAD does not count as done (Step 1); the ladder
  re-runs against current HEAD.
- **L0 not clean** — a PR whose L0 `/review` verdict is `BLOCKING` is not
  a candidate at all (Step 1); it needs L0 fix-up before L1/L2 apply.

## What this skill does NOT do

- Does not run `/review`, `/l1-review`, or `/l2-review` itself — it only
  dispatches agents that do.
- Does not present clean PRs to the operator — that's `operator-review`.
- Does not triage findings or dispatch fixes for needs-work PRs — that's
  `fix-then-re-review-ladder`.
- Does not mutate any PR's worktree — dispatched agents operate
  read-only, per `lN-review-doctrine`'s worktree discipline.
- Does not introduce a new local-cache scoping mechanism — the existing
  marker-is-canonical doctrine already makes local-cache concurrency a
  non-issue (see "Local-cache concurrency" above).

## References

- `../lN-review-doctrine/references/checklist.md` — the 3-axis doctrine,
  the read-only-worktree discipline, and the "Marker emission
  template"/"Posting protocol" sections this skill's Step 2 points
  dispatched agents at verbatim.
- `../operator-review/SKILL.md` — receives clean PRs, one at a time
  (Step 5).
- `fix-then-re-review-ladder` — receives needs-work PRs (Step 5); recovers
  a PR from NEEDS-WORK/BLOCKING back to CLEAN by triaging findings,
  dispatching one scoped fix agent, and re-running the ladder against the
  new HEAD.
- `../lN-review-doctrine/references/dispatch-procedure.md` — the direct
  single-PR path this skill's "When to invoke" points to instead of this
  skill (event-triggered from PR creation). Converges on the same two
  downstream skills above.
