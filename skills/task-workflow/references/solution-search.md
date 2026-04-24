# Solution Search Reference

QMD-based hybrid search over the Obsidian vault. Used by `init-workspace` (step 9) and available to any skill needing to surface prior notes.

Per DD4 (`DESIGN.md` in the qmd-retrieval workspace), the Obsidian vault is the single retrieval source. Per-repo `docs/solutions/` trees are no longer searched here — they remain in place as read-only historical artifacts (see `MIGRATION.md`).

## Invocation

```bash
timeout 60 qmd query "<query-text>" -c "$QMD_COLLECTION"
```

- `<query-text>` — typically the issue/ticket title + description, joined with a period. Truncate to ~2000 chars for sanity.
- `-c "$QMD_COLLECTION"` — scopes the search to one indexed collection. The collection name is per-host config, set in the DD6 host file (e.g. `tcetra` on WSL, a different name on other hosts).
- No further flags. The plain `qmd query <text>` form runs hybrid BM25 + vector with auto-expansion and HyDE by default.
- 60-second hard timeout — current CPU-only reranking can run long. Revisit when QMD GPU acceleration lands (tracked separately).

## Output Shape

QMD writes a stream to stdout. Each result is a block:

```
qmd://<collection>/<path>:<line> #<hash>
Title: <human-readable title>
Score:  <pct>%

@@ -<start>,4 @@ (<before> before, <after> after)
<excerpted context>
```

Extract the **first 3** `qmd://` URIs in document order. For each, capture the title line and score on the two following lines. That's "top-3".

## Parameters (Phase 4a baseline)

| Parameter | Value | Rationale |
|---|---|---|
| `k` | 3 | Matches retrieval-benchmark gate (AC3: top-3 must surface the correct note in ≥4/5 historical queries). |
| HyDE | on (default) | AC4: at least one benchmark case is a semantic-only match where HyDE is load-bearing. |
| Query shape | `<title>. <description>` | Captures both explicit identifiers (title) and context clues (description body) for the hybrid retriever. |

## Fail-Open Behaviour

Per DD4, solution search never blocks workspace setup and never falls back to grep over `docs/solutions/`.

| Failure | Response |
|---|---|
| `qmd` binary not on PATH | Log `QMD not installed — skipping retrieval`; continue. |
| `QMD_COLLECTION` unset | Log `QMD collection not configured for this host — skipping retrieval`; continue. |
| Non-zero exit / timeout | Log stderr tail; continue. |
| Empty result set | Not a failure — treat as "no matches". |

## Reporting

In the caller's summary output, include:

- Query string actually sent (quoted, truncated).
- Collection queried.
- Top-3 URIs, titles, and scores. If fewer than 3, report what was returned.
- `No existing notes surfaced.` if zero results.
- `QMD skipped: <reason>` on fail-open.

## See Also

- `BENCHMARK.md` in the qmd-retrieval workspace — fixed 5-query benchmark gating this integration.
- `DESIGN.md` DD1/DD4 — rationale for local hybrid retrieval over OpenAI-embedding skills and for vault-only retrieval.
- `bench-run.sh` in the qmd-retrieval workspace — reference invocation pattern (top-3 URI extraction via `grep -oE 'qmd://tcetra/[^: ]+' | awk '!seen[$0]++' | head -3`).
