---
name: vault-cloud
description: "Record and search the Obsidian vault from a cloud session (Claude Code on the web), where the macOS-local obsidian CLI is unavailable but the vault is reachable as a git repo. Clones the configured vault repo (OBSIDIAN_VAULT_REPO), searches it with ripgrep (lexical — QMD/semantic search stays on the Mac), and writes vocabulary-compliant notes that it commits to a dedicated cloud/<date>-<topic> branch for the operator to merge. Use in cloud/web/container sessions that lack the local vault. Not for the Mac — there the obsidian-notes CLI and compound/kb-* skills already own vault I/O."
argument-hint: "[search <query> | write <note description> | setup]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - AskUserQuestion
version: 0.1.0
---

# Vault Cloud

Read and write the Obsidian vault from a **cloud session** using git as the transport.

## When this applies

Use this skill only when the local vault is **not** reachable — i.e. a Claude Code on the web /
container / cloud session with no macOS Obsidian app, no `obsidian` CLI, no
`~/.claude/hosts/<hostname>.md`. On the Mac, the `obsidian-notes` CLI and the skills that build
on it (`compound`, `kb-capture`/`kb-compile`/`kb-lint`, `lessons-learned`, `operator-interview`)
already own vault I/O — do not use this skill there.

**How to tell you're in the cloud case:** `~/.claude/skills/obsidian-notes/scripts/host-config.sh`
does not exist (or, sourced, leaves `OBSIDIAN_CLI` unset). That is this skill's trigger.

## What git gives, and what it doesn't

The vault (the repo named in `OBSIDIAN_VAULT_REPO` — see `operations/setup.md`) is plain
markdown + YAML frontmatter and clones in seconds. Once cloned:

- **Read/search works natively** via ripgrep over frontmatter and body.
- **Writing works** by creating `YYYY/MM/YYYY-MM-DD-<slug>.md` and committing.

Two things do **not** cross the git boundary, and this skill is explicit about both:

1. **No semantic search.** `.obsidian/` and `.smart-env/` are gitignored, so the QMD collection
   and embeddings live only on the Mac. **Cloud search is lexical (ripgrep), not hybrid
   BM25+vector.** Good for "find the note about X"; not a substitute for QMD retrieval. (A
   cloud-side semantic option is deliberately unbuilt — see `docs/obsidian-vault-cloud-access.md`
   "Open decisions".)
2. **No `obsidian` CLI.** No Templater (`<% tp.date.now() %>`), no property registry. So a note
   written here must emit **resolved** frontmatter and self-validate against the vault's own
   contract. That is what `scripts/vault_compliance.py` is for.

## Compliance is defined by the vault, not by this skill

"Compliant" means: obeys `_meta/agent-contract.md` (path scheme, don't invent
`type`/`area`/`project` values, don't touch `_meta/`, don't reorganize) and uses only the field
values in `_meta/vocabulary.md`. **Those live files are the source of truth** — this skill reads
them from the clone every run and never hardcodes the vocabulary, because it drifts (see
`references/compliance-contract.md`).

## Execution

Dispatch on the argument (`search`, `write`, or `setup`; blank → ask):

**Step 1 — Setup (always first).** Ensure the vault clone exists and `_meta/` is loaded.

```
Read(file_path: "${CLAUDE_PLUGIN_ROOT}/skills/vault-cloud/operations/setup.md")
```

**Step 2 — Run the requested operation.**

| Operation | File | When |
|-----------|------|------|
| Search | `operations/search.md` | `search <query>` — find notes (lexical) |
| Write note | `operations/write-note.md` | `write <description>` — record a compliant note, commit to a dedicated branch |

## Write isolation (why a branch, not `main`)

The local Obsidian app is the vault's primary writer and carries uncommitted churn (Readwise
plugin, smart-env). Cloud writes therefore land on a dedicated **`cloud/<date>-<topic>`** branch
and are pushed there for the operator to merge — never committed straight to `main`. `write-note`
enforces this.

## Integration Points

- `scripts/vault_compliance.py` — pure, unit-tested primitives: `parse_vocabulary`,
  `slugify`/`note_path`, `emit_frontmatter` (fm-emit quoting discipline), `validate_frontmatter`.
  Tests: `scripts/test_vault_compliance.py` (stdlib `unittest`).
- The vault repo (private; resolved from `OBSIDIAN_VAULT_REPO`, then `add_repo` + clone).
  `_meta/agent-contract.md` and `_meta/vocabulary.md` are the compliance source of truth.
- `docs/obsidian-vault-cloud-access.md` — the design/options doc this skill implements.
- `references/compliance-contract.md` — the cloud-specific rules layered on the vault contract.

## See Also

- `compound`, `kb-capture` — the **local** vault writers this skill mirrors from the cloud.
- `skills/task-workflow/references/solution-search.md` — the QMD search protocol that is *not*
  available from the cloud (the gap this skill's lexical search fills).
