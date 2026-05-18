# Solution Search

Surfaces prior knowledge from the Obsidian vault before planning so the plan doesn't re-solve problems already captured. Used by `planning-workflow` to produce a "Prior Solutions" section for the plan.

Per DD4 (qmd-retrieval workspace), retrieval runs through QMD hybrid search over the Obsidian vault. Per-repo `docs/solutions/` trees are no longer consulted here — they remain as read-only historical artifacts.

## Parameters

- `query_terms` (required): Problem-describing text — typically the issue/task title plus the first paragraph of its DESIGN.md. A single string, not a list.

## Execution Steps

### 1. Run the QMD search

Follow the canonical protocol in `../../task-workflow/references/solution-search.md`:

- Build `query_text` as a shell variable (safe from issue-body injection), sanitize control chars and QMD-grammar-hostile chars, truncate to 2000 bytes.
- Invoke `timeout 60 qmd query "$query_text" -c "$QMD_COLLECTION"`.
- Parse the first 3 `qmd://…` URIs with their Title and Score lines.

Fail-open rules from the reference doc apply (QMD binary missing, `$QMD_COLLECTION` unset, timeout, empty result set — each logs and continues; nothing blocks planning).

### 2. Compile findings

Produce a summary section for the plan:

```markdown
## Prior Solutions

### Relevant notes (top 3)
1. [<Title>](<qmd://... URI>) — score <pct>%
2. [<Title>](<qmd://... URI>) — score <pct>%
3. [<Title>](<qmd://... URI>) — score <pct>%

### Assessment
<brief statement: how much prior knowledge applies to this task, which note is the strongest match, whether a clear prior fix exists>
```

If QMD returned zero results, or fail-open skipped the search:

```markdown
## Prior Solutions

No prior notes surfaced for this task.
```

Include the fail-open reason (`QMD skipped: <reason>`) only if the search was skipped, not when it ran successfully but matched nothing.

## Output

The compiled "Prior Solutions" section, ready to be included as context in the planning workflow. Downstream phases (research gating, plan generation) use this to calibrate depth.

## Error Handling

All failure modes route through the fail-open table in `../../task-workflow/references/solution-search.md` — planning never blocks on retrieval.
