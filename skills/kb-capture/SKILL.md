---
name: kb-capture
description: "Capture / ingest bridge for the LLM Knowledge Base. Stages work-relevant Readwise Reader documents into the vault's raw/ queue for later /kb-compile. A doc is captured iff it has ≥1 highlight (notes count) AND is work-relevant, OR carries the kb tag (unconditional override). Capture never mutates the Derived/Shared/Human zones and is idempotent. Use when ingesting Reader sources into the knowledge base."
argument-hint: "[blank for full inbox sweep, or a Reader doc id/url]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Grep
  - Glob
  - AskUserQuestion
version: 0.1.0
---

# KB Capture

Implements the capture / ingest stage of the LLM Knowledge Base workflow (SPEC §2.1).
Eligible Readwise Reader documents land in the vault's `raw/` staging queue with their
origin metadata and highlights/notes intact, ready for `/kb-compile`.

> **Status:** complete. The deterministic core is implemented and unit-tested in `kb-core`
> (`is_eligible`, `source_key` — AC-1.2/1.3/1.4/1.6/1.7). The Readwise read and `raw/`
> write are agent-orchestrated per `operations/capture.md` (Readwise MCP + `obsidian-notes`
> CLI), and the full capture→compile→lint flow was verified end-to-end against a live vault.

## Capture-eligibility predicate (SPEC §2.1)

A Reader doc is captured iff **either**:

- **(A) Default path** — has ≥1 highlight (*notes count as highlights*) **AND** an LLM
  judges it work-relevant scored against `WORK-DOMAINS.md`. AI/LLM content is relevant
  only when tied to engineering/agent workflows, tooling, MCP, or infra automation.
- **(B) Tag override** — carries the `kb` tag → captured unconditionally (no highlight
  required, topic irrelevant).

## raw/ staging convention

`raw/` is a subtree of the **Obsidian vault** (not this repo). Vault location is resolved
per-host via the `obsidian-notes` skill / host config — never hardcoded. Each captured
source is one raw artifact preserving URL, author, capture date, and highlights/notes
unmodified. Re-capturing the same source is a no-op (keyed via `kb_core.source_key`).

## Invocation

```
/kb-capture            # sweep the Reader inbox for eligible docs
/kb-capture <doc>      # capture a specific Reader doc id/url
```

## Execution

1. Load the operation: `Read(${CLAUDE_PLUGIN_ROOT}/skills/kb-capture/operations/capture.md)`
2. Execute it.
3. Report which sources were staged into `raw/` (and which were skipped, with the gate that skipped them).

## Integration Points

- **Readwise Reader** — source documents (MCP `reader_*` tools / export API).
- **kb-core** — `${CLAUDE_PLUGIN_ROOT}/skills/kb-core/scripts/kb_core.py` (`CAPTURE_TAG`, `source_key`, zone guard).
- **obsidian-notes skill / host config** — resolves the vault path; performs vault writes.
- **WORK-DOMAINS.md** (workspace) — the §2.1 work-relevance reference.
- **kb-compile** — consumes the `raw/` queue this skill fills.

## See Also

- `SPEC.md` §2.1 (workspace) — the capture contract and acceptance criteria.
- `skills/kb-compile` — the next stage.
