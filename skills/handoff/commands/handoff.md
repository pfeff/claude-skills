# /handoff — session-handoff document

Writes a durable, inspectable handoff document so a fresh session resumes work without inheriting bloated context — the explicit, reviewable alternative to lossy `/compact`. Also rehydrates a fresh session from that document.

## Usage

```
/handoff                       # write/refresh the handoff doc (optional trailing focus hint)
/handoff focus on the X work   # write, weighting depth toward X
/handoff rehydrate             # re-ground a fresh session from the doc
```

## Procedure

This command invokes the `handoff` skill (same plugin). Load it and route on `$ARGUMENTS`:

1. Read `${CLAUDE_PLUGIN_ROOT}/skills/handoff/SKILL.md` to put the hard rules and operation map into context.
2. Route on the first token of `$ARGUMENTS`:
   - `rehydrate` → follow `${CLAUDE_PLUGIN_ROOT}/skills/handoff/operations/rehydrate.md`.
   - anything else → follow `${CLAUDE_PLUGIN_ROOT}/skills/handoff/operations/write.md`, passing the full `$ARGUMENTS` string as the focus hint.
3. The operation resolves the handoff file via the discovery rule and reads `references/schema.md` + `references/protocol.md` to compose or reconcile.

## Does NOT

- Run `/clear` or `/compact` itself — `write` reminds you to review the doc, then you reset manually.
- Auto-act after `rehydrate` — it re-grounds and hands control back.
- Capture knowledge to Obsidian or emit metrics — that is `/finish` and the chief-of-staff End-of-Session Capture. A handoff is ephemeral session state, not durable knowledge.
