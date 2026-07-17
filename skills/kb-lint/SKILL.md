---
name: kb-lint
description: "Report-only health check over the LLM Knowledge Base notes (reading the wider vault for connection candidates). Surfaces inconsistent/contradictory data, orphan notes, missing data web search could impute, and candidate new connections. Findings are report-only — any auto-fix is confined to KB-owned notes and reversible (git); off-limits and non-KB notes are proposals only. Operator-invoked via /kb-lint. Use to audit KB health after compiling."
argument-hint: "[blank to lint the whole KB]"
allowed-tools:
  - Read
  - Edit
  - Bash
  - Grep
  - Glob
  - WebSearch
version: 0.3.0
---

# KB Lint

On-demand health check over the LLM Knowledge Base (SPEC v2 §2.6). Reports issues; the
operator applies them. The only autonomous writes allowed are reversible fixes to KB-owned
notes; findings on off-limits zones or non-KB notes are surfaced as proposals only (INV-1).

> **Status:** the deterministic guards are implemented and unit-tested in `kb-core`
> (`is_kb_owned` — auto-fix confined to KB notes, AC-6.2; `is_writable` — off-limits floor;
> `find_orphans` — AC-6.3 input), plus `kb-lint`'s own `is_git_backed` (re-checked fresh every
> run against the vault's live git state; gates whether auto-fix is reachable at all — see
> `scripts/kb_lint_git.py`). The findings pass is agent-orchestrated per `operations/lint.md`.
> Proposal-only findings (declined within-KB link suggestions, KB<->non-KB cross-links) are
> persisted to a durable `Notes/kb-lint-proposals.md` inbox instead of only printing to the
> transcript; the idempotency-key/dedup logic is implemented and unit-tested in
> `kb-lint/scripts/kb_lint_proposals.py`.

## Billing posture

`/kb-lint` is **operator-invoked and interactive** → subscription billing pool. No scheduled
pass; same rationale as `/kb-compile` (SPEC v2 §6, CLAUDE.md billing guard).

## What it reports (SPEC v2 §2.6)

- Inconsistent / contradictory data across KB notes.
- Orphan notes (no backlinks).
- Missing data that a web search could impute.
- Candidate new connections / articles (must surface ≥1 actionable candidate on a
  non-trivial vault — AC-6.3). Proposal-only candidates (within-KB suggestions kb-lint
  declines to auto-apply, and KB<->non-KB cross-links it can't write) are appended to a
  durable `Notes/kb-lint-proposals.md` inbox, deduped against prior runs.

## Invocation

```
/kb-lint                  # health-check the KB notes
```

## Execution

1. Load the operation: `Read(${CLAUDE_PLUGIN_ROOT}/skills/kb-lint/operations/lint.md)`
2. Execute it.
3. Emit the findings report; apply only reversible fixes to KB-owned notes, surface the rest as proposals.

## Integration Points

- **kb-core** — `${CLAUDE_PLUGIN_ROOT}/skills/kb-core/scripts/kb_core.py` (`is_kb_owned` + `is_writable` for the write guard, `find_orphans` for orphan detection).
- **kb-lint's own scripts** — `${CLAUDE_PLUGIN_ROOT}/skills/kb-lint/scripts/kb_lint_git.py` (`is_git_backed` — re-checked fresh every run, gates auto-apply eligibility); `${CLAUDE_PLUGIN_ROOT}/skills/kb-lint/scripts/kb_lint_proposals.py` (idempotency key, checklist-line rendering, and dedup for the proposals inbox).
- **QMD** — the vault search CLI, for connection-candidate discovery.
- **obsidian-notes skill / host config** — vault path resolution; reads and KB-owned fixes (including the proposals inbox note).
- **kb-compile** — produces the KB notes this skill audits.

## Tests

```
cd skills/kb-lint/scripts && python3 -m unittest test_kb_lint_git test_kb_lint_proposals
```

Stdlib `unittest` (zero-dependency, matches `kb-core/scripts/test_kb_core.py`).

## See Also

- `skills/kb-core/references/spec-v2-contract.md` (AC-6.1–6.3 — lint contract).
- `skills/kb-compile`.
