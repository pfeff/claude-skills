---
name: kb-capture
description: "Capture / ingest bridge for the LLM Knowledge Base. Sweeps work-relevant Readwise HIGHLIGHTED sources (the operator highlights-then-archives, so highlights — not the inbox — are the signal) into the vault's raw/ queue for later /kb-compile; kb-tagged docs are captured unconditionally. A source is captured iff it has ≥1 highlight (notes count) AND is work-relevant, OR carries the kb tag. Capture writes only under raw/ (never off-limits zones) and is idempotent. Use when ingesting highlighted reading into the knowledge base."
argument-hint: "[blank to sweep highlighted sources, or a Reader doc id/url]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Grep
  - Glob
  - AskUserQuestion
version: 0.3.0
---

# KB Capture

Implements the capture / ingest stage of the LLM Knowledge Base workflow (SPEC §2.1).
Eligible Readwise Reader documents land in the vault's `raw/` staging queue with their
origin metadata and highlights/notes intact, ready for `/kb-compile`.

> **Status:** complete. The deterministic core is implemented and unit-tested in `kb-core`
> (`is_eligible`, `source_key`, `highlights_fingerprint`, `new_highlights` —
> AC-1.2/1.3/1.4/1.6/1.7). The Readwise read and `raw/` write are agent-orchestrated per
> `operations/capture.md` (Readwise MCP + `obsidian-notes` CLI), and the full
> capture→compile→lint flow was verified end-to-end against a live vault. Idempotency is
> content-aware, not existence-only: a source that gains highlights after its first capture
> is folded into the existing `raw/<key>.md` on the next sweep instead of being skipped
> forever (`operations/capture.md` § Re-sync vs. skip).

> **Follow-up (deferred):** the vault also runs the community "Readwise Official" Obsidian
> plugin, which does its own content-level sync into a `Readwise/` folder — a second,
> currently disconnected pipeline from this MCP-based sweep. Rearchitecting kb-capture into a
> hybrid (plugin owns sync mechanics; kb-capture only filters + reformats from the plugin's
> folder into `raw/`) needs the plugin's live synced-note schema inspected against a real
> vault and is out of scope here. See `operations/capture.md` § Second Readwise pipeline for
> the reconciliation approach landed now (shared `book_id` identity) vs. what's deferred.

## What it sweeps

The operator's workflow is **highlight → archive**, so highlighted sources (not the inbox)
are the keeper signal. The default sweep enumerates the **Readwise highlights library**
(grouped by source), *not* `location="new"`. See `operations/capture.md` step 1.

## Capture-eligibility predicate (SPEC §2.1)

A source is captured iff **either**:

- **(A) Default path** — has ≥1 highlight (*notes count as highlights*) **AND** an LLM
  judges it work-relevant scored against `WORK-DOMAINS.md`. AI/LLM content is relevant
  only when tied to engineering/agent workflows, tooling, MCP, or infra automation.
- **(B) Tag override** — carries the `kb` tag → captured unconditionally (no highlight
  required, topic irrelevant).

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

- **Readwise** — highlighted sources via `readwise_list_highlights` (primary); Reader docs via `reader_*` tools (kb-tag override / named input).
- **kb-core** — `${CLAUDE_PLUGIN_ROOT}/skills/kb-core/scripts/kb_core.py` (`CAPTURE_TAG`, `is_eligible`, `source_key`, `is_writable`, `highlights_fingerprint`, `new_highlights`).
- **obsidian-notes skill / host config** — resolves the vault path; performs vault writes.
- **WORK-DOMAINS.md** (workspace) — the §2.1 work-relevance reference.
- **kb-compile** — consumes the `raw/` queue this skill fills.

## See Also

- `skills/kb-core/references/spec-v2-contract.md` (AC-1.1–1.7 — capture contract and
  acceptance criteria).
- `skills/kb-compile` — the next stage.
