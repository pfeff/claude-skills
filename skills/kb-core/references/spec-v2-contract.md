# KB SPEC v2 — reconstructed contract

**Provenance.** This file reconstructs the surviving content of the original `SPEC.md` v2
design doc for the LLM Knowledge Base skills (kb-capture, kb-compile, kb-lint, kb-core). That
doc lived in the `~/src/work/llm-kb/` workspace, which was torn down without archiving — it
was never committed to this repo and is unrecoverable. Its numbered section structure (§1,
§2.1, §2.2, §2.6, §6, …) that the four skills historically cited is lost along with it.

What survives is the design summary and acceptance-criteria checklist preserved in the body of
[PR #123](https://github.com/pfeff/claude-skills/pull/123) (`feat(kb): LLM knowledge-base
skills (capture, compile, lint)`, merged 2026-07-01), reproduced verbatim below. This is now
the durable, in-repo home for that content — anchored on AC-ids (which the four skills already
cite inline) rather than the unrecoverable §N labels.

## Design (SPEC v2)

The vault is already a **flat, frontmatter-routed, agent-authored** KB (session journals,
investigations, references; Dataview/MOC routing) — not a folder-zoned, mostly-human vault.
So the workflow feeds that KB in its own idioms rather than building a protected parallel wiki.

- **Ownership:** KB-owned (free-edit) vs off-limits (`DevOps Documentation/`, `Confluence/`,
  out-of-scope notes). **Edit safety is git + review** (the vault is version-controlled), not
  an in-note fence.
- **Reuse the vault schema:** `type: reference`/`zettel`/`moc`, `sources:` provenance,
  `project: knowledge-base` routing. Only `raw/` (`type: kb-raw`) is KB-specific.
- **Billing:** `/kb-compile` and `/kb-lint` are interactive-only (subscription pool) — never
  cron/`claude -p`/Agent SDK.

## Acceptance criteria (verified)

Capture (AC-1.1–1.7): staged with metadata, highlight/notes gate, tag override, writes only
`raw/`, idempotent. Compile (AC-2.1–2.6, AC-3.1): summaries linked from concepts, idempotent,
update-in-place dedup, bounded writes (off-limits untouched), `type:`+`sources:` provenance +
MOC routing, `Keywords/` cross-link, valid links/frontmatter. Lint (AC-6.1–6.3): report-only,
auto-fix confined to KB-owned notes, surfaces connection candidates. Deferred: AC-4.x (Q&A —
QMD already solves it), AC-5.x (refile).

## What's NOT reconstructed

The original §N numbering, and any §N content beyond the design bullets and AC checklist above
(e.g. worked examples, prose elaboration under a given §), did not survive in PR #123's body
and is not represented here. Do not treat the absence of a §N label as a gap to fill —
skill citations should anchor on the AC-ids above, not on reconstructed section numbers.
