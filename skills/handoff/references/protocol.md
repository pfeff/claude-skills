# Handoff protocol — discovery, timing, reconciliation

Shared procedure for both operations. The document schema itself lives in `schema.md`.

## Discovery rule (where the handoff file lives)

Host-agnostic. Resolve the handoff file path in this order — first match wins:

1. **Explicit override.** If `$HANDOFF_FILE` is set in the environment, or an explicit path argument was passed, use it verbatim.
2. **Nearest existing doc.** Search, in order, for an existing file at:
   - `<root>/HANDOFF.md`
   - `<root>/.claude/HANDOFF.md`
   - `<root>/docs/HANDOFF.md`

   where `<root>` is the git top-level (`git rev-parse --show-toplevel`), falling back to the current working directory when not in a git repo.
3. **Default write target.** When none exists (write only), create `<root>/HANDOFF.md`.

`rehydrate` errors clearly when steps 1–2 find nothing ("no handoff document found under <root>; run `/handoff` to create one"). `write` proceeds to step 3.

Compute `<root>` once: `git rev-parse --show-toplevel 2>/dev/null || pwd`.

## When to hand off

Trigger `write` at a **clean boundary you choose**, before context is force-managed for you:

- Approaching the context limit (the dominant trigger) — write *before* an auto-compaction fires, not after.
- Before an intentional `/clear` at a task boundary.
- End of a work session you intend to resume later.
- Handing work to another operator, or to another session/agent (human→AI, AI→AI).
- Checkpointing significant progress worth not losing.

Do **not** reach for it on quick one-off questions, and note it does not solve within-a-single-turn token limits.

## Live-state gathering (write)

Capture ground truth from the environment rather than trusting recollection:

```bash
git branch --show-current
git status --porcelain
git diff --stat
git log --oneline -10
```

Outside a git repo, record `branch: none` and skip the git-derived sections' specifics.

## Staleness reconciliation (rehydrate)

The anti-hallucination step. A handoff doc can drift from reality between sessions; trust the world over the doc, and surface the gap:

1. Read the doc's frontmatter `branch` and `updated`, and its `Current state` / `Files affected`.
2. Compare against live state:
   - `git branch --show-current` vs frontmatter `branch`.
   - `git status` / recent `git log` vs the doc's claimed `Current state` and completed work.
   - If a `GOAL.md` or a coordinator tree exists for the project, cross-check node/status claims (`coord tree show <id>` when available).
3. For each divergence, **flag it explicitly** rather than repeating the doc's value:
   `handoff says branch <X>; git shows <Y> — handoff may be stale (updated <ts>).`
4. If `updated` is old relative to recent commits, note the doc may predate current work.

## Rehydration trigger in CLAUDE.md

Compaction can preserve a *reference* to the handoff file while dropping its *content* — the model knows the doc exists but no longer has it. Closing that loop requires a re-read instruction in persistent project memory (`CLAUDE.md` reloads every session and survives compaction).

On `write`, check the nearest `CLAUDE.md` (project root, then `.claude/CLAUDE.md`) for an existing re-read line. If absent, **offer** (do not silently insert) to append one line:

```
> After any /clear or compaction, re-read ./HANDOFF.md before acting.
```

This is a stable *instruction*, not volatile state — it is compatible with a "no volatile state in CLAUDE.md" discipline. The check must be idempotent: never add a second copy if the line (or an equivalent) is already present.
