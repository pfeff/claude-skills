# /handoff — Rehydrate operation

Re-ground a fresh, zero-context session from an existing handoff document, reconciling it against live state. Invoked by `/handoff rehydrate`.

## Steps

1. **Resolve and read the handoff file.** Apply the discovery rule in `references/protocol.md` (override → nearest existing). This operation does **not** create a file: if steps 1–2 of discovery find nothing, error clearly — `no handoff document found under <root>; run /handoff to create one` — and stop.

2. **Reconcile against live state** per `references/protocol.md` § Staleness reconciliation. Trust the world over the doc:
   - `git branch --show-current` vs frontmatter `branch`.
   - `git status` / `git log --oneline -10` vs the doc's `Current state` and `Work completed`.
   - If a `GOAL.md` or coordinator tree exists, cross-check status claims (`coord tree show <id>` when available).
   - Note whether `updated` is stale relative to recent commits.

3. **Emit a concise re-grounding summary** — not a dump of the whole file:
   - **Goal** (verbatim, 2–3 sentences).
   - **Current state** as reconciled (the doc's claim, corrected where live state disagrees).
   - **Top next step** (the first item from `Next steps`).
   - **Staleness flags**: every divergence found in step 2, stated explicitly (`handoff says X; git shows Y — may be stale`). If none, say so.

4. **Hand control back.** Do **not** auto-act on the next step. Surface the summary and let the operator/role decide. Rehydration re-grounds; it does not drive.

## Failure modes

- **No handoff file found** — clear error (step 1), exit without side effects.
- **Doc present but unparseable / missing frontmatter** — read what is legible, report that the doc is malformed, and still surface whatever sections are recoverable. Recommend a fresh `/handoff` write.
- **Not in a git repo** — skip git reconciliation; reconcile only against `GOAL.md`/`coord` if present, and note that branch/commit divergence could not be checked.
