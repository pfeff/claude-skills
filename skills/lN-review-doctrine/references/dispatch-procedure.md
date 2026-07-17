# Event-triggered review dispatch (from PR creation)

Consumed by the two PR-completion entry points — `commands/gh-pr-create.md`
(dotfiles) and `task-workflow/operations/finish.md` (this plugin) — so a
newly-opened (or newly-updated) PR gets the depth-rule-proportionate review
chain dispatched immediately, instead of waiting for a manual `/review` or
an L1/L2 supervisor's next tick to notice `pr-open` (see
`lN-lifecycle-doctrine` `references/lifecycle.md`, "Integration with
lN-review-doctrine").

This doctrine does not replace the supervisor-tick trigger — it adds an
earlier one. A supervisor that later observes `pr-open` on this PR will
usually find the review chain already CLEAN (fast-forward past `pr-open`/
`fixing`) or already `fixing` — either way its own dispatch is idempotent
against markers already posted (see "Relationship to `pr-review-fanout`"
below, whose already-CLEAN/non-stale-marker skip covers this case).

## Billing invariant (non-negotiable)

The dispatch in Step 2 below MUST be an **interactive Agent-tool subagent**
launched from the current session (Task tool). It MUST NEVER be `claude -p`
/ `--print`, the Agent SDK, a GitHub Action, `CronCreate`, `RemoteTrigger`,
or any other harness-native scheduled/headless invocation — those move the
work to the metered-credits billing pool instead of the interactive
subscription pool. This procedure (including this invariant) is itself a
load-bearing surface per `depth-rule.md`'s Load-bearing surfaces item 9 —
any change to this file, including one that violates the invariant, forces
the full ladder on itself.

## Procedure

### Step 1 — Classify the change

Apply `depth-rule.md`'s change-class table against `git diff <base>...HEAD
--stat` and the touched paths:

- **Docs/config-only** or **Small self-constituent** -> Change review only.
- **Standard** -> Change + Acceptance review.
- **Load-bearing** (touches any surface in the Load-bearing surfaces list,
  regardless of size) -> Change + Acceptance + Objective review (full
  ladder).

### Step 2 — Dispatch ONE interactive Agent subagent

Dispatch a single Agent-tool subagent (Task tool, same session — see the
billing invariant above) to run the depth-appropriate chain **sequentially**
against this PR, on its existing worktree (do not provision a new one). Run
the dispatch with `run_in_background: true` — the full chain (up to three
review tiers, each with its own multi-minute agent fan-out per `/review`'s
own limits) should not block the PR-creation/finish flow that triggered it.
Background here means *asynchronous within the current interactive
session*, not headless — it is still the same Task tool, same subscription
billing pool; only the caller's wait is non-blocking:

1. **Always**: `/review` (Change tier) — skip only if
   `.claude/reviews/latest.md` already carries a verdict from earlier this
   same session that is fresh (not stale against current HEAD).
2. **If Standard or Load-bearing**: `/acceptance-review` (backward-compat
   alias `/l1-review`), after the Change tier posts `CLEAN`.
3. **If Load-bearing**: `/objective-review` (backward-compat alias
   `/l2-review`), after the Acceptance tier posts `CLEAN`.

A tier that returns `NEEDS-WORK`/`BLOCKING` stops the chain at that tier —
do not run a later tier against work no earlier tier cleared.

Brief the dispatched agent with the PR number/branch, the requirement to
post each tier's marker dual-surface per `checklist.md`'s "Marker emission
template" and "Posting protocol" (copy those templates verbatim, do not
hand-roll the YAML), and the read-only-worktree discipline (`checklist.md`,
"Reviewer worktree discipline").

### Step 3 — Route the outcome

Identical to `pr-review-fanout`'s Step 5:

- **All tier-warranted markers CLEAN** -> hand off to `operator-review` for
  human sign-off (its own Prerequisite is exactly this depth-gated chain).
- **Any tier NEEDS-WORK/BLOCKING** -> hand off to `fix-then-re-review-ladder`
  to recover the PR to CLEAN, then re-route per its own Step 7 exit.

Neither handoff skill's doctrine is inlined here.

## Relationship to `pr-review-fanout`

`pr-review-fanout` is a **bulk** dispatcher — 2+ open PRs needing the ladder
concurrently — and says so explicitly: "A single PR needing the ladder
should just run it directly." This procedure IS that direct single-PR path;
it does not invoke `pr-review-fanout` for a single newly-created PR. Both
paths converge on the same two downstream skills (`operator-review`,
`fix-then-re-review-ladder`), so a PR dispatched from here and later swept
up by a `pr-review-fanout` bulk run (e.g. a supervisor also enumerating it)
behaves identically — `pr-review-fanout`'s Step 1 candidate check
(already-CLEAN / non-stale-marker skip) makes a second dispatch a no-op.

## Draft PRs

Skip dispatch entirely for a PR created with `--draft` — a draft is not yet
ready for review by definition (mirrors `gh-pr-create.md`'s existing
skip-auto-merge-on-draft rule). If the draft is later marked ready without
going back through this procedure, `gh-pr-create.md`'s dispatch-failure
fallback reminder still applies as a backstop.

## Dispatch failure

If the Agent-tool dispatch itself cannot be started (e.g. the Task tool is
unavailable), do not silently skip. Surface the same fallback reminder
`gh-pr-create.md` printed before this procedure existed:

```
Could not dispatch the review chain automatically — this PR has not been
reviewed yet. Run /review before merge, or the merge gate may sit
unresolved until a later session.
```

## See also

- `depth-rule.md` — the change-class table and Load-bearing surfaces list
  this procedure's Step 1 applies.
- `checklist.md` — marker emission template, posting protocol, reviewer
  worktree discipline referenced in Step 2.
- `../pr-review-fanout/SKILL.md` — the bulk counterpart; see "Relationship
  to pr-review-fanout" above.
- `../fix-then-re-review-ladder/SKILL.md` — recovers a NEEDS-WORK/BLOCKING
  verdict from Step 3 back to CLEAN.
- `../operator-review/SKILL.md` — receives a CLEAN chain from Step 3; its
  own Prerequisite states the same depth-gated chain this procedure
  produces.
- `commands/gh-pr-create.md` (dotfiles) — invokes this procedure at PR
  creation (Step 9).
- `task-workflow/operations/finish.md` — invokes this procedure for the
  already-open-PR branch of the PR phase (step 4b).
