# Solution Search Reference

QMD-based hybrid search over the Obsidian vault. Used by `init-workspace` (step 9) and available to any skill needing to surface prior notes.

Per DD4 (`DESIGN.md` in the qmd-retrieval workspace), the Obsidian vault is the single retrieval source. Per-repo `docs/solutions/` trees are no longer searched — they remain in place as read-only historical artifacts.

## Invocation

Always build the query text in a shell variable first, then pass it as a double-quoted argument. **Never** inline issue/ticket content directly into the command — issue bodies are attacker-controlled and embedded quotes or backticks would break out of the command string.

```bash
# Safe: variable expansion is one argument, regardless of contents.
query_text="<title>. <first paragraph of DESIGN.md>"   # built + sanitized by the caller
timeout 60 qmd query "$query_text" -c "$QMD_COLLECTION"
```

Sanitization (caller responsibility): strip control characters (`\n \r \t`) and QMD-grammar-hostile characters (backtick, `$`, backslash) before passing the text through. Truncate to ~2000 chars.

`$QMD_COLLECTION` is per-host config, set in the host file (`~/.claude/hosts/<hostname>.md`); each host selects its own collection name.

No other flags. The plain `qmd query <text>` form runs hybrid BM25 + vector with auto-expansion and HyDE by default. A 60-second hard timeout is mandatory — reranking can run long on CPU-only hosts; CUDA-offloaded hosts still benefit from the bound.

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

Parameters are fixed: top-3, HyDE on, hybrid retrieval. No tunable knobs at this layer; tune via query text composition, not CLI flags.

## Fail-Open Behaviour

Per DD4, solution search never blocks workspace setup and never falls back to grep over `docs/solutions/`.

| Failure | Response |
|---|---|
| `qmd` binary not on PATH | Log `QMD not installed — skipping retrieval`; continue. |
| `QMD_COLLECTION` unset | Log `QMD collection not configured for this host — skipping retrieval`; continue. |
| Non-zero exit / timeout | Log a truncated, control-char-stripped stderr tail (≤512 chars); continue. |
| Empty result set | Not a failure — treat as "no matches". |

## Reporting

In the caller's summary output, include:

- Query string actually sent (quoted, truncated to ~120 chars).
- Collection queried.
- Top-3 URIs, titles, and scores. If fewer than 3, report what was returned.
- `No existing notes surfaced.` if zero results.
- `QMD skipped: <reason>` on fail-open.

Output-parsing grep pattern (collection-neutral):

```bash
grep -oE 'qmd://[^/]+/[^: ]+' /tmp/qmd-prior.out | awk '!seen[$0]++' | head -3
```

## See Also

- `operations/init-workspace.md` step 9 — the canonical caller (builds query, persists top-3 into DESIGN.md `## Prior Context (QMD)`).
- DD1 / DD4 in the qmd-retrieval DESIGN.md — rationale for local hybrid retrieval and vault-only retrieval.
