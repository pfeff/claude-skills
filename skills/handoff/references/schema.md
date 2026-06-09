# Handoff document schema

The durable contract for the handoff doc. Read at `write` time to compose, and at `rehydrate` time to parse. Every section below is mandatory in the output — emit the heading even when the content is "none" (an empty section is signal: it says the author checked).

## File format

A single Markdown file with YAML frontmatter followed by the body sections.

### Frontmatter

```yaml
---
type: handoff
project: <slug>            # short project/workspace identifier
updated: <ISO-8601>        # stamped by the skill at every write (date +%Y-%m-%dT%H:%M:%S%z)
session: <name-or-id>      # session name/id if known, else "unknown"
branch: <git branch>       # from `git branch --show-current`, or "none" outside git
status: active             # active | superseded
---
```

- `updated` is **always** re-stamped on write — it is the staleness anchor `rehydrate` compares against.
- `branch` is captured from live git at write time so `rehydrate` can detect a branch mismatch.

### Body sections (in order)

```markdown
# Handoff — <project>

## Goal
The objective in 2–3 sentences. Why this work exists and what "done" looks like.

## Work completed
What is done, each item with its rationale (the *why*, not just the *what*).
Use checkboxes or a short list. Reference commits where useful.

## Failed approaches
What was tried and **why it failed** — the highest-value, hardest-to-reconstruct
section. One line per dead end. This is what stops the next session re-litigating
a path already ruled out. If genuinely none: "None yet."

## Current state
What works, what's broken, test/CI status. The honest snapshot — name failing
tests and known-bad areas explicitly.

## Next steps
The immediate actions, **specific**: `file:line`, function name, exact command.
Prioritized; the top item is the single most important thing to do next. Vague
next steps ("continue the refactor") are a defect — name the file and the change.

## Files affected
Created / modified / referenced, as paths. Lets the next session open the right
files without re-discovering them.

## Key decisions
Choices made plus reasoning. The decisions a fresh session must not silently undo.

## Gotchas / open questions
Non-obvious discoveries, assumptions, unresolved questions, blockers awaiting an
operator or external answer.
```

## Composition rules

- **Specific over narrative.** Paths, symbols, line numbers, commands — not prose summaries.
- **Cumulative, not destructive.** On rewrite, preserve still-relevant `Failed approaches` and `Key decisions`; do not blank them just because the current turn did not touch them.
- **No secrets.** Never write tokens, credentials, or other sensitive values into the doc — reference where they live instead.
- **Reference, don't duplicate.** When durable detail already lives in `DESIGN.md`/`GOAL.md`/a PR, link to it rather than copying it in.
