# Solution Search

Surfaces prior knowledge from the Obsidian vault before planning so the plan doesn't re-solve problems already captured. Used by `planning-workflow` to produce a "Prior Solutions" section for the plan.

Per DD4 (qmd-retrieval workspace), retrieval runs through QMD hybrid search over the Obsidian vault. Per-repo `docs/solutions/` trees are no longer consulted here — they remain as read-only historical artifacts.

The QMD search runs **out-of-context in a delegated `Explore` subagent** (Task tool, `subagent_type: Explore`). The planning session does not invoke `qmd query` directly; it dispatches the subagent and consumes the compiled "Prior Solutions" section the subagent returns. This keeps the QMD result stream and parsing scratch out of the planning context window.

## Parameters

- `query_terms` (required): Problem-describing text — typically the issue/task title plus the first paragraph of its DESIGN.md. A single string, not a list.

## Execution Steps

### 1. Delegate the QMD search to an `Explore` subagent

Spawn a single Task tool agent with `subagent_type: Explore`. The subagent runs the canonical QMD protocol out-of-context and returns the finished "Prior Solutions" section — the planning session does not run `qmd` itself.

Pass the subagent a prompt that carries `query_terms` and instructs it to:

- Follow the canonical protocol in `../../task-workflow/references/solution-search.md`:
  - Build `query_text` as a shell variable (safe from issue-body injection), sanitize control chars and QMD-grammar-hostile chars, truncate to 2000 bytes.
  - Invoke `timeout 60 qmd query "$query_text" -c "$QMD_COLLECTION"`.
  - Parse the first 3 `qmd://…` URIs with their Title and Score lines.
- Apply the fail-open rules from the reference doc (QMD binary missing, `$QMD_COLLECTION` unset, timeout, empty result set — each logs a reason and continues; nothing blocks planning).
- Compile and return **only** the "Prior Solutions" section in the exact schema below — no QMD result stream, no parsing scratch.

Format the Task prompt as:

```
<task>
Run the past-solution QMD search for a planning session and return the compiled
"Prior Solutions" section. Do NOT return the raw qmd result stream — only the
finished section.
</task>

<query-terms>
{query_terms}
</query-terms>

<protocol>
Follow the canonical protocol in skills/task-workflow/references/solution-search.md
(invocation, output shape, and the fail-open table). Build query_text in a shell
variable, sanitize it, run `timeout 60 qmd query "$query_text" -c "$QMD_COLLECTION"`,
and extract the first 3 qmd:// URIs with their Title and Score.
</protocol>

<output-schema>
{the "Prior Solutions" schema from step 2 below, including the empty/skipped variant}
</output-schema>
```

If the `Explore` subagent fails to return (dispatch error, subagent unavailable), treat it as a fail-open case: log `QMD skipped: solution-search subagent unavailable` and continue with the "No prior notes surfaced" output. Planning never blocks on retrieval.

### 2. Consume the returned section

The subagent returns the compiled section directly. Use it verbatim as the "Prior Solutions" context for downstream phases — do not re-run the search.

The subagent produces a summary section for the plan in this schema:

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

The subagent includes the fail-open reason (`QMD skipped: <reason>`) only if the search was skipped, not when it ran successfully but matched nothing.

## Output

The compiled "Prior Solutions" section, ready to be included as context in the planning workflow. Downstream phases (research gating, plan generation) use this to calibrate depth.

## Error Handling

All failure modes route through the fail-open table in `../../task-workflow/references/solution-search.md` — planning never blocks on retrieval. A failed or unavailable `Explore` subagent is itself a fail-open case (see step 1): log the reason and emit the "No prior notes surfaced" output.
