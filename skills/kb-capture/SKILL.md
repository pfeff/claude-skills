---
name: kb-capture
description: "Capture / ingest bridge for the LLM Knowledge Base. Sweeps Readwise HIGHLIGHTED sources (the operator highlights-then-archives, so highlights — not the inbox — are the signal) into the vault's raw/ queue for later /kb-compile; kb-tagged docs are captured unconditionally. A source is captured iff it has ≥1 highlight (notes count) AND is work-relevant, OR carries the kb tag; the work-relevance gate is host-scoped and opt-in (default: capture everything). Capture writes only under raw/ (never off-limits zones) and is idempotent. Use when ingesting highlighted reading into the knowledge base."
argument-hint: "[blank to sweep highlighted sources, or a Reader doc id/url]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Grep
  - Glob
  - AskUserQuestion
version: 0.5.0
---

# KB Capture

Implements the capture / ingest stage of the LLM Knowledge Base workflow (SPEC §2.1).
Eligible Readwise sources land in the vault's `raw/` staging queue with their origin metadata
and highlights/notes intact, ready for `/kb-compile`.

> **Status:** complete, plugin-hybrid. The deterministic core is implemented and unit-tested
> in `kb-core` (`is_eligible`, `source_key`, `highlights_fingerprint`, `new_highlights` —
> AC-1.2/1.3/1.4/1.6/1.7) and, for Path A, in `kb-capture`'s own `readwise_folder`
> (`collect_sources` and its primitives — `book_id`/highlight/metadata extraction, dated
> append-section aggregation, both backlink forms, gen1/gen2 duplicate handling). The vault
> reads/writes are agent-orchestrated per `operations/capture.md`. Idempotency is
> content-aware, not existence-only: a source that gains highlights after its first capture
> is folded into the existing `raw/<key>.md` on the next sweep instead of being skipped
> forever (`operations/capture.md` § Re-sync vs. skip).

> **Plugin-hybrid (2026-07-18, operator-signed-off):** Path A (the highlight sweep) no
> longer polls Readwise via MCP. The community "Readwise Official" Obsidian plugin is now
> the sole system that talks to Readwise; it syncs into the vault's local `Readwise/` folder,
> and this skill reformats/filters from that folder into `raw/` instead — closing the
> double-capture risk a live audit found (51/51 `raw/` sources had duplicated into the
> plugin's folder). `book_id` stays the identity key throughout; `kb-compile` is unchanged.
> Path B (the `kb`-tag override) still uses a narrow Readwise MCP query, because Readwise
> never exports a zero-highlight source into the plugin's folder at all. See
> `operations/capture.md` § Second Readwise pipeline, and
> `Notes/2026/07/2026-07-17-readwise-double-capture-audit-plugin-hybrid.md` for the audit and
> design this implements.

## What it sweeps

The operator's workflow is **highlight → archive**, so highlighted sources (not the inbox)
are the keeper signal. The default sweep enumerates every source in the Readwise Official
plugin's local **`Readwise/` vault folder** — already pre-filtered to highlighted sources,
since Readwise's export only emits sources that have highlights — *not* `location="new"` and
*not* a live `readwise_list_highlights` poll. See `operations/capture.md` step 1.

## Capture-eligibility predicate (SPEC §2.1)

A source is captured iff **either**:

- **(A) Default path** — has ≥1 highlight (*notes count as highlights*) **AND** is
  work-relevant. **The work-relevance gate is host-scoped and opt-in — default OFF.** A
  host only has the criterion below applied if it explicitly sets
  `KB_CAPTURE_WORK_RELEVANCE_GATE=on` (environment, or in its own
  `~/.claude/hosts/<hostname>.md` — the same host-config opt-in convention `goal-tree` uses
  for `GOAL_TREE_BACKEND`, see `skills/goal-tree/lib/env-detection.md`). **On any
  unconfigured or gate-off host, `work_relevant` is always `True`** — every source with
  ≥1 highlight/note is eligible, topic irrelevant. This default-off shape is deliberate: an
  unconfigured or personal host must never silently start filtering out non-work reading
  just because this gate exists (see `operations/capture.md` step 2 for the resolution
  steps). **Work-relevance criterion (applies only on gate-ON hosts — home vs. job/work
  reading):** relevant when the source is about software engineering, AI/agent tooling,
  MCP, or infra/DevOps automation — the operator's standing professional domains. Not
  relevant when it's personal/home reading (health, hobbies, general news, fiction, etc.)
  with no tie to those domains. Judge against the source's own title/highlights, not the
  topic in the abstract — a general-audience article the operator highlighted for
  engineering reasons still counts.
- **(B) Tag override** — carries the `kb` tag → captured unconditionally (no highlight
  required, topic irrelevant, gate state irrelevant).

## raw/ staging convention

`raw/` is a subtree of the **Obsidian vault** (not this repo). Vault location is resolved
per-host via the `obsidian-notes` skill / host config — never hardcoded. Each captured
source is one raw artifact preserving URL, author, capture date, and highlights/notes
unmodified. Re-capturing an unchanged source is a no-op (keyed via `kb_core.source_key`,
compared via `kb_core.highlights_fingerprint`); a source whose highlights changed since its
last capture is updated in place (`kb_core.new_highlights`) rather than skipped.

## Invocation

```
/kb-capture            # sweep highlighted sources (bounded to a recent window)
/kb-capture <doc>      # capture a specific Reader doc id/url
```

## Execution

1. Load the operation: `Read(${CLAUDE_PLUGIN_ROOT}/skills/kb-capture/operations/capture.md)`
2. Execute it.
3. Report which sources were staged into `raw/` (and which were skipped, with the gate that skipped them).

## Integration Points

- **Readwise Official plugin `Readwise/` folder** — highlighted sources (primary, Path A); no
  MCP call, read via `obsidian-notes`/`Glob`+`Read`.
- **Readwise MCP `reader_*` tools** — `kb`-tag override only (Path B — Readwise never exports
  a zero-highlight source into the plugin's folder, so this path can't move to the folder).
- **kb-capture's `readwise_folder`** — `${CLAUDE_PLUGIN_ROOT}/skills/kb-capture/scripts/readwise_folder.py`
  (`collect_sources` and its primitives) — parses the plugin folder for Path A.
- **kb-core** — `${CLAUDE_PLUGIN_ROOT}/skills/kb-core/scripts/kb_core.py` (`CAPTURE_TAG`, `is_eligible`, `source_key`, `is_writable`, `highlights_fingerprint`, `new_highlights`).
- **obsidian-notes skill / host config** — resolves the vault path; performs vault writes.
- **kb-compile** — consumes the `raw/` queue this skill fills; unchanged by this rearchitecture.

## See Also

- `skills/kb-core/references/spec-v2-contract.md` (AC-1.1–1.7 — capture contract and
  acceptance criteria).
- `skills/kb-compile` — the next stage.
