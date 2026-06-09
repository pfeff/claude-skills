# /handoff — Write operation

Capture the current session's state into a durable handoff document. Invoked by `/handoff` (no `rehydrate` argument), optionally with a focus hint.

## Inputs

| Arg | Default | Notes |
|-----|---------|-------|
| focus hint (free text) | none | Biases emphasis; does not change the schema |

## Steps

1. **Resolve the handoff file path.** Apply the discovery rule in `references/protocol.md` (override → nearest existing → default `<root>/HANDOFF.md`). Compute `<root>` as `git rev-parse --show-toplevel 2>/dev/null || pwd`.

2. **Gather live state.** Run the git commands from `references/protocol.md` § Live-state gathering (`branch --show-current`, `status --porcelain`, `diff --stat`, `log --oneline -10`). These are ground truth for the frontmatter and the `Current state` / `Files affected` sections. Outside git, record `branch: none`.

3. **Read the existing doc if present.** When discovery found an existing handoff file, read it first. You are updating **cumulatively** — preserve still-relevant `Failed approaches` and `Key decisions` entries even if the current turn did not touch them. Do not blank a section just because it is quiet this turn.

4. **Compose the document** per `references/schema.md`:
   - Stamp frontmatter: `type: handoff`, `project` (workspace/repo slug), `updated` = `date +%Y-%m-%dT%H:%M:%S%z`, `session` (name/id or `unknown`), `branch` (from step 2), `status: active`.
   - Fill every body section. Honor the composition rules: **specific over narrative** (paths, `file:line`, symbols, commands), **no secrets**, **reference don't duplicate**.
   - Apply the focus hint (if any) by weighting depth toward that area — not by dropping other sections.

5. **Write to disk.** Use the Write tool to write the resolved path. **Never just display the doc** — a handoff that lives only in chat defeats the purpose.

6. **Offer the CLAUDE.md rehydration trigger.** Per `references/protocol.md` § Rehydration trigger:
   - Check the nearest `CLAUDE.md` (project root, then `.claude/CLAUDE.md`) for an existing re-read line (`grep` for an idempotency match — e.g. `re-read .*HANDOFF`).
   - If none is present, **offer** to append (do not silently edit):
     `> After any /clear or compaction, re-read ./HANDOFF.md before acting.`
   - If the operator declines, or a matching line already exists, skip — never add a duplicate.

7. **Report.** Emit the written path and a one-line reminder to **review the doc before `/clear`**. Do not clear or compact from this operation.

## Failure modes

- **Missing `references/schema.md` or `references/protocol.md`** — fail loud; do not improvise a schema. Recover from git history.
- **Not in a git repo** — proceed with `<root>` = cwd and `branch: none`; the git-derived sections carry only what is observable.
- **Discovery override points at an unwritable path** — surface the error and stop; do not silently fall back to a different location.
