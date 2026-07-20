---
name: self-verify
description: Self-verification capability for dispatched jobs. Before reporting "done," a job invokes this skill to check its own change against the 3-axis review doctrine (Conformance / Process / Objective-Advancement) by composing existing review tooling and tests, then emits a structured annotation artifact. The annotation is evidence for the operator's review — not a gate, not a blocker.
allowed-tools:
  - Bash
  - Read
  - Grep
  - Write
  - Task
version: 1.2.0
---

# self-verify — job self-verification + annotation

A dispatched job invokes this skill **before** reporting "done." The skill runs
the job's own change through the 3-axis doctrine by composing existing review
tooling and tests, then writes a structured annotation to
`.claude/reviews/self-verify-latest.md`. The operator's review session reads
this artifact as evidence rather than trusting a bare "done."

This skill is an **annotation producer only**. It does not gate, block, merge,
open PRs, or integrate with any queue.

## When to invoke

Invoke at the end of the job's work, after all changes are made but before
sending the "done" signal to the operator. Typical trigger: "I've made the
changes, now let me verify before reporting." Per the dispatch brief's
standing instruction (`../dispatch-gate/SKILL.md` Step 5), commit the job's
work to its isolated branch before invoking this skill, so the committed-branch
`/review` path in Step 3 applies instead of the condensed uncommitted-tree
checklist.

## Inputs

Gather these before starting the verification procedure:

| Input | How to obtain |
|-------|---------------|
| Diff of the job's changes | `git diff HEAD` (uncommitted) or `git diff <base>...<branch>` |
| Task context | **PRIMARY**: `.claude/task-context.md` in the worktree (four-field format — see `references/task-context.md`). **FALLBACK** (first hit): `DESIGN.md` in the workspace → `PLAN.md` → dispatch prompt → PR description. |
| Acceptance criteria | Extract from `.claude/task-context.md` "Acceptance test" field if present; otherwise from the fallback task context above. |
| Repo root | Working directory or `--worktree <path>` if operating remotely |

## Procedure

### Step 1 — Get the diff

```bash
# Uncommitted changes:
git diff HEAD

# Branch vs base (for a completed feature branch):
git diff $(git merge-base HEAD origin/main)...HEAD
```

Store as `$DIFF`. If the diff is empty, write an annotation with
`verdict: warn` and note `no changes detected — nothing to verify`.

### Step 2 — Identify work type and run required verification

Detect the work type from the diff's changed file extensions and look up the
required verification steps in the "Work-type → required-verification map" in
`../lN-review-doctrine/SKILL.md`. That map is the single source of truth —
read it at verification time; do not rely on a summary.

For **Claude skills** (doctrine-class), run the "Doctrine-class PR
sub-checklist" from the same doctrine file. Which items apply (doctrine-only
vs executor skill) is defined there; when in doubt, run every item. Item 1
(artifact-path consistency) applies whenever the changed skill reads or writes
another skill's artifact path, regardless of whether those paths are declared
in SKILL.md or in operations/.

Each required step that fails becomes a finding in the annotation. Record
which steps ran and their results as `evidence.tests_run`.

**External-resource steps run bounded.** If a required verification step
shells out to a flaky or slow resource outside the repo's own test/build
toolchain (a third-party API, an OS-integration shell-out such as
AppleScript/iCloud), run it under the hard-cap + kill-on-stall recipe in
`references/bounded-external-waits.md` rather than waiting on it unbounded.
The recipe is also available as a sourceable script,
`scripts/run-bounded-external.sh`, so callers don't have to hand-copy the
function body — `source` it and call `run_bounded_external` directly. A
step the recipe kills (hard-cap or flat-CPU stall) is recorded as
`result: inconclusive`, not `fail` or `skipped` — see that reference for the
full doctrine and the axis-2 verdict mapping.

### Step 3 — Compose /review for code-level findings

Run the repo's `/review` skill against the diff to collect L0 per-line
code-level findings (security, simplicity, architecture, correctness). This
is evidence for Axis 2 — do not duplicate the review logic here.

For a committed branch (the typical case for a completed job):
```
/claude-skills:review <branch-or-PR>
```

For **uncommitted working-tree changes** (code files present in `$DIFF` from
Step 1): do NOT invoke `/claude-skills:review` with no arguments — that skill
runs `git diff $BASE...HEAD` which diffs committed branch history and will see
no uncommitted changes. Instead, perform the review inline:

1. Use `$DIFF` captured in Step 1 (already contains all uncommitted changes).
2. Apply the condensed security / correctness / data-loss checklist from
   `../review/operations/run-review.md` (the same checklist used in
   degraded-mode) directly against `$DIFF`.
3. Write the result to `.claude/reviews/latest.md` yourself using the exact
   frontmatter format from `../review/SKILL.md`:
   ```yaml
   ---
   target: working-tree
   timestamp: <ISO 8601 UTC>
   agents: 1
   degraded: true
   blocking: <count>
   advisory: <count>
   verdict: BLOCKING | CLEAN
   ---
   ```

Read `.claude/reviews/latest.md` after writing it (same as the branch case).

Store the review verdict (`CLEAN` / `BLOCKING`) in `evidence.review_verdict`.
If the review produces a `BLOCKING` verdict, that is a blocking finding in
Axis 2.

**If the repo has no code files** (pure skills/doc change), the review skill
will report no findings. Record `review_verdict: n/a` and note the reason.

### Step 4 — Evaluate the three axes

Using the definitions from `../lN-review-doctrine/SKILL.md`:

#### Axis 1 — Conformance

Does the diff match the task the job was given?

Read acceptance criteria from `.claude/task-context.md` "Acceptance test" field
if present; otherwise fall back to DESIGN.md / PLAN.md / dispatch prompt.

- Is every named acceptance criterion attempted?
- Is the diff within scope (no out-of-scope files touched)?
- Is there obvious WIP/debugging debris (console.log, commented-out code)?
- Minimality: does the diff add the least surface that meets the criteria?
- Did the job self-resolve a Tier 1 decision (see
  `../decision-rights-doctrine/SKILL.md`) instead of escalating it to the
  operator?
- Did the job violate the Pre-Output Classification Gate (global
  `CLAUDE.md`; see `~/.claude/docs/reference/pre-output-classification-gate.md`)
  — i.e. did it commit one of the gate's three named failure modes:
  **silent assumption** (built on an ungrounded guess instead of grounding or
  asking), **buried question** (raised a needs-input gap in prose instead of
  via `AskUserQuestion`), or **proposal-in-limbo** (laid out options and
  ended the turn with nothing decided)? Read the diff and any prose in the
  job's own report for these patterns, not just its final action.

  If found, this is an axis-1 finding (severity per whether it produced a
  wrong/unreviewable result). It is **also** a measurement event, distinct
  from the finding: log it via `~/.claude/hooks/gate-violation-write.sh`
  (piping a JSON record with `session_id`, `violation_type` — one of
  `silent-assumption` | `buried-question` | `proposal-in-limbo` — `reason`,
  and `context_after`) so violation frequency stays queryable across
  sessions in `~/.claude/corrections.jsonl`. This logging step is
  best-effort — if the hook is unavailable, note the missed log in the
  annotation and continue; do not block the self-verify pass on it.

If `.claude/task-context.md` carries an Override annotation (see
`references/task-context.md` "Override annotation") naming unresolved
fields, evaluate those fields as known gaps: Axis 1 verdict is `warn`
with the named gap(s) surfaced. Never treat an unresolved acceptance
test as silently complete, and never collapse to `pass` solely because
a placeholder value is present.

Verdict: `pass` if all criteria attempted + in scope. `fail` if any criterion
unattempted or diff is materially out of scope. `warn` for ambiguous scope.

#### Axis 2 — Process

Did the job follow the required process?

- Required verification steps from Step 2 ran and passed.
- `/review` (Step 3) produced a non-BLOCKING verdict.
- No forced workarounds (skipped hooks, `--no-verify`, `--force`).

Verdict: `pass` if all required steps ran green. `fail` if any required step
failed or was skipped. `warn` if a step could not be evaluated (missing
artifact), **including a step recorded `result: inconclusive`** per
`references/bounded-external-waits.md` — a stalled or capped external-resource
step is never `fail` (it didn't fail, it couldn't complete) and never a
silent `pass`.

#### Axis 3 — Objective Advancement

Does the change make forward progress on the operator's objective?

Read the objective from (first hit wins):
1. `.claude/task-context.md` "Objective" field in the worktree — **when this is
   present, Axis 3 MUST evaluate to `pass` or `fail`; it may not degrade to
   `warn` solely on absence of context**.
2. `GOAL.md` in the workspace.
3. Project `CLAUDE.md` Objective / Task section.
4. Dispatch prompt / task description.

Checks:
- Does the work product close or advance acceptance criteria of the parent
  objective?
- Does it introduce a local-optimum failure (satisfies local task but breaks a
  broader property the operator needs)?
- Would the work product pass an L1 review if one were run?

Verdict: `pass` if forward progress + no local-optimum failures. `fail` if
it regresses the parent objective or introduces a known-bad local optimum.
`warn` only when the objective is unreadable from ALL sources above — surface
as ambiguity, never collapse to `pass`. When `.claude/task-context.md` is
present, `warn` is not an acceptable verdict for this axis.

### Step 5 — Compute overall verdict and write annotation

Apply the verdict rubric from lN-review-doctrine:

| Condition | Verdict |
|-----------|---------|
| Any axis `fail` with any `blocking` finding | `fail` |
| Any axis `fail` with no `blocking` finding | `warn` |
| All axes `pass`, no `blocking` findings | `pass` |
| Any axis `warn`, no axis `fail` | `warn` (never collapse to `pass`) |

Write the annotation to `.claude/reviews/self-verify-latest.md`. See
`references/annotation-schema.md` for the exact format.

```bash
mkdir -p .claude/reviews
# write .claude/reviews/self-verify-latest.md (see annotation-schema.md)
```

After writing, display the annotation body to the operator (without
frontmatter) and then stop. Do not open PRs, merge, or take further action.

## What this skill does NOT do

- Does not gate or block the operator from proceeding.
- Does not open, comment on, or merge PRs.
- Does not integrate with a queue or coordinator.
- Does not re-implement review logic — it composes `/review` and the
  doctrine-class checklist.
- Does not write to any path other than `.claude/reviews/self-verify-latest.md`,
  except the inline-review result written to `.claude/reviews/latest.md` in
  Step 3's uncommitted-change path (standing in for the `/review` skill, which
  owns that path).

## References

- `references/annotation-schema.md` — the annotation file format
- `references/bounded-external-waits.md` — hard-cap + kill-on-stall doctrine
  and recipe for verify steps depending on flaky/slow external resources;
  defines the `inconclusive` outcome
- `scripts/run-bounded-external.sh` — executable copy of that recipe,
  sourceable by any caller instead of hand-copying the function body
- `references/acceptance-demo.md` — acceptance test results (four sample runs, including code changes)
- `references/task-context.md` — task-context convention: four-field format, file location, fallback order
- `../lN-review-doctrine/SKILL.md` — 3-axis doctrine and verification map
- `../review/SKILL.md` — the `/review` skill this composes for code-level findings
- `~/.claude/docs/reference/pre-output-classification-gate.md` (dotfiles) — the
  gate's three failure modes and the `gate-violation-write.sh` measurement
  convention Axis 1 logs into
