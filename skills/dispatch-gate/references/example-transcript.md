# Example Transcripts

Illustrative walkthroughs of the two terminal states (ready, refuse).
These are worked examples for onboarding, not recorded babysat dispatch
cycles — per spec decision 8, real sample runs (one clean pass, one
genuine catch) get added here as they occur.

---

## Example A — Ready (clean pass)

**Operator**: "Dispatch a job to add retry-with-backoff to the webhook
sender in `notify/`."

**Gate checks the four fields**:

- Objective — clear: add retry-with-backoff to the webhook sender.
- Acceptance test — missing: no observable done-condition stated.
- Scope — mostly clear: `notify/` only.
- Affected surface — missing: no specific paths named.

**Clarifying pass** (only the two gaps, not a batched form):

> Gate: "What proves this is done — a specific test, or a manual check?"
> Operator: "A new test that kills the webhook endpoint mid-send and
> confirms three retries with exponential backoff before giving up."
>
> Gate: "Which files do you expect touched — just the sender module, or
> also its tests and config?"
> Operator: "`notify/webhook_sender.py` and
> `notify/tests/test_webhook_sender.py`. No config changes."

All four fields now resolved → **ready**.

**Task-context file written** (`.claude/task-context.md` in the target
worktree):

```markdown
# Task Context

**Objective**: Add retry-with-backoff to the webhook sender in `notify/`.

**Acceptance test**: A new test kills the webhook endpoint mid-send and
confirms three retries with exponential backoff before the sender gives up.

**Scope / blast-radius bound**: `notify/` only. No config changes.

**Affected surface**: notify/webhook_sender.py, notify/tests/test_webhook_sender.py
```

Dispatch brief to the job includes the standing instruction: commit to
the isolated branch before invoking `self-verify`.

---

## Example B — Refuse (genuine catch)

**Operator**: "Dispatch a job to clean up the auth module."

**Gate checks the four fields**:

- Objective — ambiguous: "clean up" doesn't say what changes.
- Acceptance test — missing.
- Scope — missing: "the auth module" could mean one file or a whole
  directory tree.
- Affected surface — missing.

**Clarifying pass**:

> Gate: "What does 'clean up' mean here — removing dead code, fixing a
> specific lint category, restructuring, something else?"
> Operator: "Just remove functions nothing calls anymore."
>
> Gate: "Good, that's the objective. What proves it's done — a
> specific check, or just 'no dead functions remain'?"
> Operator: "Not sure yet, haven't looked at what's actually dead."
>
> Gate: "That's fine to leave open for now — but I still need a scope
> bound: which directory or files is 'the auth module'?"
> Operator: "I don't know exactly, whatever's under `auth/` I guess."

Acceptance test remains unresolved (operator hasn't inventoried what's
dead yet) and scope is still loose ("I guess"). This is not a spike —
the operator wants dead-code removal shipped, not findings reported
back — so the spike heuristic doesn't apply.

**Refuse**:

> Gate: "Not ready to dispatch — two fields are still unresolved:
> **Acceptance test** (no way to confirm which functions are dead) and
> **Scope** (`auth/` unconfirmed as the full bound). Want to dispatch
> anyway, or pin these down first?"

**Operator takes the override**: "Dispatch anyway, I'll check the diff
myself."

**Task-context file written with the override recorded**:

```markdown
# Task Context

**Objective**: Remove functions in the auth module that nothing calls anymore.

**Acceptance test**: [unresolved at dispatch — operator to confirm during review]

**Scope / blast-radius bound**: auth/ (unconfirmed as the full bound)

**Affected surface**: auth/

**Override**: Dispatched despite unresolved fields — Acceptance test,
Scope / blast-radius bound. Operator chose "dispatch anyway" during the
clarifying pass on 2026-07-03.
```

This is the "genuine catch" sample for spec decision 8's acceptance
bar: an under-specified real slice, a clarifying dialogue, and a
recorded refuse-then-override outcome.
