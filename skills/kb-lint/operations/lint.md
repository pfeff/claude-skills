# Lint Operation

Report-only health check over the Derived zone (reading Shared for connection candidates)
(SPEC §2.6).

The safety-critical deterministic core is implemented and unit-tested in `kb_core`
(`is_autofix_allowed` — the INV-1 write boundary, AC-6.2; `find_orphans` — AC-6.3 input).
Findings generation (inconsistencies, missing data, connection candidates) is
agent-orchestrated here; a live run on the real vault is exercised by the demo task.

## Billing guard

Interactive `/kb-lint` only — no scheduled pass (SPEC §6).

## Steps (to implement)

1. **Read the Derived zone** (and Shared concept notes, for connection candidates).
2. **Detect findings:**
   - Inconsistent / contradictory data across Derived notes.
   - Orphan notes (no backlinks) — `kb_core.find_orphans(adjacency)` over the Derived/Shared link graph.
   - Missing data a web search could impute (use `WebSearch`).
   - Candidate new connections / articles (≥1 actionable on a non-trivial vault, AC-6.3).
3. **Emit a findings report.**
4. **Apply fixes within the write boundary** (INV-1):
   - Before ANY write, gate on `kb_core.is_autofix_allowed(frontmatter, path)` — it returns
     True only for Derived-zone notes. Auto-fix must be reversible.
   - Human/Shared findings (where the guard returns False) are surfaced as **proposals
     only** — never edited.

## Acceptance Criteria (SPEC §2.6)

AC-6.1 (report emitted; no Human/Shared edit), AC-6.2 (auto-fix confined to Derived +
reversible; Shared/Human proposals only), AC-6.3 (≥1 actionable connection candidate).

## Integration Points

- `kb_core.classify_zone` — `${CLAUDE_PLUGIN_ROOT}/skills/kb-core/scripts/kb_core.py`
- QMD — vault search CLI for connection candidates
- `obsidian-notes` skill — vault path resolution; reads and Derived-only fixes
