# Lint Operation

Report-only health check over the Derived zone (reading Shared for connection candidates)
(SPEC §2.6).

**Scaffold:** this operation defines the contract; the steps below are implemented in the
kb-lint task, TDD against AC-6.1…AC-6.3. Until then it is a specification, not a runnable
procedure.

## Billing guard

Interactive `/lint` only — no scheduled pass (SPEC §6).

## Steps (to implement)

1. **Read the Derived zone** (and Shared concept notes, for connection candidates).
2. **Detect findings:**
   - Inconsistent / contradictory data across Derived notes.
   - Orphan notes (no backlinks).
   - Missing data a web search could impute (use `WebSearch`).
   - Candidate new connections / articles (≥1 actionable on a non-trivial vault, AC-6.3).
3. **Emit a findings report.**
4. **Apply fixes within the write boundary** (INV-1):
   - Auto-fix is allowed **only** in the Derived zone and must be reversible.
   - Human/Shared findings are surfaced as **proposals only** — never edited.
   - Use `kb_core.classify_zone` to enforce the boundary before any write.

## Acceptance Criteria (SPEC §2.6)

AC-6.1 (report emitted; no Human/Shared edit), AC-6.2 (auto-fix confined to Derived +
reversible; Shared/Human proposals only), AC-6.3 (≥1 actionable connection candidate).

## Integration Points

- `kb_core.classify_zone` — `${CLAUDE_PLUGIN_ROOT}/skills/kb-core/scripts/kb_core.py`
- QMD — vault search CLI for connection candidates
- `obsidian-notes` skill — vault path resolution; reads and Derived-only fixes
