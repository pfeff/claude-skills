---
name: dispatch-gate
description: Dispatch-readiness gate for background jobs. Before the operator launches a background agent (worktree job, subagent, or cross-repo dispatch), this skill checks the privacy gate (public destination + sensitive context?), verifies the four slice-complete criteria — objective, acceptance test, scope/blast-radius bound, affected surface — runs a short clarifying dialogue on any gap, and writes the .claude/task-context.md the job will run against. Invoke when the operator asks to dispatch background work, or via /dispatch-gate.
allowed-tools:
  - Bash
  - Read
  - Write
version: 1.0.0
---

# dispatch-gate — dispatch-readiness gate

Before any background job is launched (a worktree agent, a subagent, a
cross-repo dispatch), this skill checks that the dispatch slice is
complete, resolves gaps through a short clarifying dialogue, and writes
`.claude/task-context.md` for the job to run against.

This skill only **checks and writes context** — it does not launch
anything. Launching stays manual (babysat phase); see "What this skill
does NOT do" below.

## When to invoke

Invoke when the operator asks to dispatch background work, or via
`/dispatch-gate` — before the job is launched, not after. A skill
cannot force its own invocation; the trigger discipline is closed by a
pointer in the operator's `~/.claude/CLAUDE.md`, not by anything in this
file.

## Inputs

- The operator's stated intent for the background job (freeform —
  whatever has been said so far about what the job should do).
- Whether the target repo/worktree already exists locally (check with
  `git -C <path> rev-parse --git-dir` or `test -d <path>`).

## Procedure

### Step 0 — Privacy gate

Before checking task readiness, verify that this dispatch does not
silently leak sensitive context to public channels. This is a policy gate,
independent of task readiness — it must pass before proceeding to Step 1.

**Trigger**: Does the job target a public destination AND include access
to sensitive context?

- If no (private destination, or no sensitive data): proceed to Step 1.
- If yes (public destination AND sensitive data): **Stop and ask the
  operator** for explicit approval before proceeding. Record the operator's
  decision in the task-context file's Privacy Gate Annotation (see
  `references/privacy-gate.md` format).
- If operator declines: do not dispatch. No task-context file is written.

**Details**: See `references/privacy-gate.md` — it defines public
destinations (GitHub public repos, published docs, shared Slack), sensitive
context (financial, health, private URLs, vault excerpts), the dispatcher's
decision logic, and the annotation format.

### Step 1 — Check the four slice-complete criteria

Evaluate what's known against the four fields:

1. **Objective** — what the job is trying to achieve.
2. **Acceptance test** — the observable condition that proves it done.
3. **Scope / blast-radius bound** — what the job may touch.
4. **Affected surface** — paths, skills, or system boundaries touched.

Apply the fill heuristics (spike work, user-facing-surface work) from
`../self-verify/references/task-context.md` "Fill heuristics" — do not
re-derive them here; that file is the single home of the format and its
heuristics.

If all four are already unambiguous from what the operator has said,
skip to Step 4 (ready).

### Step 2 — Clarifying pass

If any field is missing or ambiguous, raise it conversationally — a
short freeform dialogue, not a batched form. Ask only about the actual
gap; do not re-ask about fields already clear. Follow-ups chase the
specific ambiguity until it resolves or the operator declines to
resolve it.

The dialogue always terminates in a binary:

- **ready** — every field is now resolved, or
- **refuse** — a gap remains after the operator has had the chance to
  resolve it.

Never dispatch-then-ask: do not write the task-context file or hand off
a launch instruction while a field is still unresolved.

### Step 3 — Refuse path

If a gap remains after the clarifying pass:

1. Name the specific missing/ambiguous field(s) — not a generic "more
   detail needed."
2. Offer an explicit "dispatch anyway" override.
3. If the operator declines the override: stop here. No
   `.claude/task-context.md` is written.
4. If the operator takes the override: proceed to Step 4, but append an
   **Override annotation** below the four fields, naming which field(s)
   were unresolved — using the annotation format defined in
   `../self-verify/references/task-context.md` ("Override annotation").
   This is appended content, not a fifth field; the four-field schema
   is unchanged. This is the only path where the file is written with a
   known gap — recording it is what makes overrides countable. Frequent
   overrides are a calibration signal that the criteria are
   miscalibrated, not a reason to skip recording.

The override is always available — the gate must never stall work.
Exploratory spikes are a legitimate work class handled by the spike
fill heuristic, not by this override path.

### Step 4 — Ready path: determine target and write or emit

- **Target worktree/repo already exists** (dispatching from inside the
  target repo, or an existing worktree): write
  `.claude/task-context.md` in the target worktree, using the
  four-field format defined in
  `../self-verify/references/task-context.md` — point at that format,
  do not duplicate it here. If Step 3's override applies, append the
  Override annotation below the four fields (not a field — see the
  annotation format in that same reference).
- **Cross-repo dispatch where the target repo/worktree doesn't exist
  yet**: do NOT provision a worktree or branch. Instead emit the
  **target path spec** — target repo, intended branch name, intended
  worktree location — and instruct the operator/launcher to place the
  `.claude/task-context.md` file once the worktree exists.
  Auto-provisioning is deferred to a later increment.

### Step 5 — Standing dispatch-brief instruction

Whatever brief accompanies the launch (verbal instruction, or text
alongside the task-context file), include this standing instruction:
**commit to your isolated branch before invoking self-verify.** This
makes the full multi-agent `/review` path in
`../self-verify/SKILL.md` (the committed-branch case) apply, instead of
the condensed inline checklist for uncommitted changes. The operator
gate remains on merge, not on commit — branch commits are cheap.

**Teardown-blocking**: also include, as part of the same standing
instruction, that the job's `/review` verdict must be posted to the
PR — as a dual-surface `<!-- review:metadata -->` marked comment, per
the posting protocol in
`../lN-review-doctrine/references/checklist.md` (both `gh pr review
<PR> --comment --body-file <post-body>` and `gh pr comment <PR>
--body-file <post-body>`) — **before the job's worktree is removed**.
In self-merge flows, the marker must be posted before merging, too.
The job confirms the marker actually landed (e.g. `gh pr view <PR>
--json reviews,comments`) before tearing down; a verdict that only
exists in the job's local `.claude/reviews/latest.md` cache does not
satisfy this — that cache is gitignored and is deleted with the
worktree, leaving no cross-operator evidence on the PR.

## What this skill does NOT do

- Does not launch agents or start the background job.
- Does not provision worktrees or branches.
- Does not queue work or manage an end-of-turn drain.
- Does not merge branches or open PRs.
- Does not change the `.claude/task-context.md` schema — new judgment
  is added as a fill heuristic in
  `../self-verify/references/task-context.md`, never as a new field.
  The Step 3 Override note is appended content below the four fields
  (an annotation), not a field — see the "Override annotation" format
  in that same reference.

## References

- `../self-verify/references/task-context.md` — the four-field format
  and fill heuristics this skill fills in; single home, not duplicated
  here.
- `references/privacy-gate.md` — privacy-gate procedure (Step 0), definition
  of public destinations and sensitive context, and Privacy Gate Annotation
  format.
- `references/example-transcript.md` — illustrative ready and refuse
  dialogue transcripts.
- `references/sample-runs.md` — real recorded dispatch-gate cycles
  (ready and refuse), with dates and outcomes.
- `../self-verify/SKILL.md` — reads the task-context file this skill
  writes; its "When to invoke" section states the commit-then-self-verify
  contract this skill's Step 5 depends on.
- `../lN-review-doctrine/references/checklist.md` — "Posting protocol"
  section this skill's Step 5 teardown-blocking check depends on: the
  dual-surface `<!-- review:metadata -->` marker format and the
  `gh pr review --comment` / `gh pr comment` posting commands.
