# Lint Operation

Report-only health check over the KB notes (reading the wider vault for connection
candidates) (SPEC v2 §2.6).

The deterministic guards are implemented and unit-tested in `kb_core` (`is_kb_owned` — the
auto-fix boundary, AC-6.2; `is_writable` — the INV-1 off-limits floor; `find_orphans` — AC-6.3
input). Findings generation (inconsistencies, missing data, connection candidates) is
agent-orchestrated here.

## Billing guard

Interactive `/kb-lint` only — no scheduled pass (SPEC v2 §6).

## Steps

1. **Read the KB notes** — the `project: knowledge-base` summaries/concepts (and the wider
   vault, read-only, for connection candidates).
2. **Detect findings:**
   - Inconsistent / contradictory data across KB notes.
   - Orphan notes (no backlinks) — `kb_core.find_orphans(adjacency)` over the KB link graph.
   - Missing data a web search could impute (use `WebSearch`).
   - Candidate new connections / articles (≥1 actionable on a non-trivial vault, AC-6.3).
3. **Emit a findings report.**
4. **Check git-backed state fresh, this run** — call `kb_lint_git.is_git_backed(vault_path)`
   against the vault's actual path. Do this every invocation; never cache the result or carry
   forward a prior run's or prior session's determination. If it returns `False`, auto-fix is
   disabled entirely for this run — every finding, including on KB-owned notes, is surfaced as
   a proposal only (skip step 5).
5. **Apply fixes within the boundary** (INV-1) — only reachable when step 4 returned `True`:
   - A fix may be written **only** when `kb_core.is_writable(path)` (not off-limits) and
     `kb_core.is_kb_owned(frontmatter, path)` (a KB-authored note) both hold. Auto-fix is
     reversible (git) because step 4 just verified the vault is git-backed.
   - Every other finding — on off-limits zones, on human/other-agent notes the KB doesn't own,
     or (per step 4) when the vault isn't git-backed — is surfaced as a **proposal only**,
     never edited.

## Acceptance Criteria (SPEC v2 §2.6)

AC-6.1 (report emitted; nothing outside KB-owned notes edited), AC-6.2 (auto-fix confined to
KB-owned notes + reversible; other findings proposal-only), AC-6.3 (≥1 actionable connection
candidate).

## Integration Points

- `kb_core.is_kb_owned`, `kb_core.is_writable`, `kb_core.find_orphans` —
  `${CLAUDE_PLUGIN_ROOT}/skills/kb-core/scripts/kb_core.py`
- `kb_lint_git.is_git_backed` — `${CLAUDE_PLUGIN_ROOT}/skills/kb-lint/scripts/kb_lint_git.py`
  (re-checked fresh every run; gates whether step 5 is reachable at all)
- QMD — vault search CLI for connection candidates
- `obsidian-notes` skill — vault path resolution; reads and KB-owned fixes
