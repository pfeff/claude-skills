---
name: kb-lint
description: "Report-only health check over the knowledge base's Derived zone (reading Shared concept notes for connection candidates). Surfaces inconsistent/contradictory data, orphan notes, missing data web search could impute, and candidate new connections. Findings are report-only — any auto-fix is confined to Derived and reversible; Human/Shared issues are proposals only. Operator-invoked via /lint. Use to audit KB health after compiling."
argument-hint: "[blank to lint the whole Derived zone]"
allowed-tools:
  - Read
  - Edit
  - Bash
  - Grep
  - Glob
  - WebSearch
version: 0.1.0
---

# KB Lint

On-demand health check over the LLM Knowledge Base (SPEC §2.6). Reports issues; the
operator applies them. The only autonomous writes allowed are reversible fixes confined to
the Derived zone — Human and Shared findings are surfaced as proposals only (INV-1).

> **Scaffold:** behavior is not yet implemented. The findings pass is built in the kb-lint
> task, TDD against AC-6.1…AC-6.3.

## Billing posture

`/lint` is **operator-invoked and interactive** → subscription billing pool. No scheduled
pass; same rationale as `/compile` (SPEC §6, CLAUDE.md billing guard).

## What it reports (SPEC §2.6)

- Inconsistent / contradictory data across Derived notes.
- Orphan notes (no backlinks).
- Missing data that a web search could impute.
- Candidate new connections / articles (must surface ≥1 actionable candidate on a
  non-trivial vault — AC-6.3).

## Invocation

```
/lint                  # health-check the Derived zone
```

## Execution

1. Load the operation: `Read(${CLAUDE_PLUGIN_ROOT}/skills/kb-lint/operations/lint.md)`
2. Execute it.
3. Emit the findings report; apply only reversible Derived-zone auto-fixes, surface the rest as proposals.

## Integration Points

- **kb-core** — `${CLAUDE_PLUGIN_ROOT}/skills/kb-core/scripts/kb_core.py` (`classify_zone` for the INV-1 write guard).
- **QMD** — the vault search CLI, for connection-candidate discovery.
- **obsidian-notes skill / host config** — vault path resolution; reads (and Derived-only fixes).
- **kb-compile** — produces the Derived/Shared content this skill audits.

## See Also

- `SPEC.md` §2.6 (lint contract) — workspace.
- `skills/kb-compile`.
