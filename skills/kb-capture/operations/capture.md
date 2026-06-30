# Capture Operation

Stage eligible Readwise Reader documents into the vault's `raw/` queue (SPEC §2.1).

**Scaffold:** this operation defines the contract; the steps below are implemented in the
kb-capture task, TDD against AC-1.1…AC-1.7. Until then it is a specification, not a runnable
procedure.

## Inputs

- Optional: a specific Reader doc id/url. Blank → sweep the Reader inbox.

## Steps (to implement)

1. **Enumerate candidate Reader docs** — the named doc, or the inbox sweep set.
2. **Evaluate the eligibility predicate** per source (SPEC §2.1):
   - Path A: `highlight_count + notes_count >= 1` AND LLM work-relevance judgment against
     `WORK-DOMAINS.md` passes (AI/LLM content relevant only when tied to engineering/agent
     automation).
   - Path B: source carries the `kb` tag → eligible unconditionally (overrides path A).
   - Skip otherwise.
3. **Idempotency guard** — compute `kb_core.source_key(source)`; if a raw artifact with that
   key already exists, skip (AC-1.6).
4. **Write the raw artifact** into the vault `raw/` subtree via the `obsidian-notes` skill,
   preserving URL, author, capture date, and highlights/notes unmodified (AC-1.1).
5. **Zone safety** — never write outside `raw/`; never touch Derived/Shared/Human notes (AC-1.5).

## Acceptance Criteria (SPEC §2.1)

AC-1.1 (staged with metadata/highlights), AC-1.2 (no-highlight/no-notes skipped),
AC-1.3 (notes count), AC-1.4 (irrelevant skipped unless tagged), AC-1.5 (zones untouched),
AC-1.6 (idempotent), AC-1.7 (tagged with zero highlights/notes captured).

## Integration Points

- `kb_core.source_key`, `kb_core.CAPTURE_TAG` — `${CLAUDE_PLUGIN_ROOT}/skills/kb-core/scripts/kb_core.py`
- `obsidian-notes` skill — vault path resolution + writes
- `WORK-DOMAINS.md` (workspace) — relevance reference
