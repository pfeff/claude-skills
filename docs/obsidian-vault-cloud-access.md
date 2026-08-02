# Recording & accessing the Obsidian vault from cloud sessions

**Status:** decisions resolved; implemented as the `vault-cloud` skill (grep search, dedicated-branch writes). See "Open decisions" for the resolutions.
**Date:** 2026-08-02.
**Context:** the vault is a private GitHub repo (push-capable from cloud sessions). The concrete
`<owner>/<repo>` is operator config, supplied via `OBSIDIAN_VAULT_REPO` — never hardcoded in this
published plugin.

## Problem

Every vault-touching skill in this repo — `compound`, `kb-capture`/`kb-compile`/`kb-lint`,
`lessons-learned`, `operator-interview`, `medical-records`, `self-improvement` — reaches the
vault the same way: it sources `~/.claude/skills/obsidian-notes/scripts/host-config.sh`, which
resolves `OBSIDIAN_CLI` / `OBSIDIAN_VAULT` / `OBSIDIAN_VAULT_PATH` from
`~/.claude/hosts/<hostname>.md`, then drives a macOS-local `obsidian` CLI (Templater, the
property registry, `base:query`, QMD search) that talks to the live Obsidian app.

A **cloud session** (Claude Code on the web) has none of that: no Mac, no local vault, no
`obsidian-notes` skill, no host file, no CLI binary, no `.obsidian` config. So today every one
of those skills hits its prerequisite guard and degrades to "obsidian-notes unavailable —
skipped." From the cloud you can neither record notes into the vault nor search it.

What a cloud session **does** have: git. The vault is a 12 MB / ~1,900-note repo that clones in
seconds, and the session's git proxy can push to it.

## What git gives you for free

The vault is plain markdown + YAML frontmatter. Once cloned, two of the three needs are native:

- **Search (read):** `ripgrep`/`Grep`/`Read` over the clone. Frontmatter is greppable, so
  "notes with `type: reference` and `project: Job Search`", "everything tagged `#terraform`",
  and full-text body search all work with no tooling beyond what the session already has.
- **Recording (write):** create `YYYY/MM/YYYY-MM-DD-slug.md`, `git add/commit/push`.

The vault even ships its own **machine-readable compliance contract**, so "compliant" is not a
guess:

- `_meta/agent-contract.md` — the rules (path scheme `YYYY/MM/YYYY-MM-DD-slug.md`, don't invent
  `type`/`area`/`project` values, new topical tags OK, don't reorganize or touch `_meta/`).
- `_meta/vocabulary.md` — the canonical field values (`type` required single-value from a fixed
  list; `area`/`project`/`status` constrained; `tags` freeform).

## The three real gaps (cloud ≠ local)

1. **No `obsidian` CLI.** The templates use Templater (`<% tp.date.now() %>`), the CLI enforces
   the property registry, and some keys can only be written a specific way (the reason
   `fm-emit.py` exists locally). A cloud writer must emit **resolved** frontmatter directly
   (real date, quoted scalars) and self-validate against `_meta/vocabulary.md`.
2. **No semantic search.** `.obsidian/` and `.smart-env/` are gitignored, so the QMD collection
   and embeddings live only on the Mac. **Cloud search is lexical (ripgrep), not hybrid
   BM25+vector.** This is a real, bounded degradation — good enough for "find the note about
   X", not a substitute for QMD's HyDE/rerank retrieval.
3. **Auth + write-conflict.** Pushing needs credentials (confirmed available via the session's
   git proxy). More importantly, the **local Obsidian app is the vault's primary writer** and
   carries uncommitted churn (Readwise plugin, smart-env). A cloud push straight to `main`
   races the local working copy. Cloud writes need pull-before-push and some isolation so they
   never clobber local state.

## Options

### Option 1 — Contract-only (documentation, no new code)
Point cloud agents at the vault's own `_meta/` files: clone, read the contract, hand-write
resolved-frontmatter notes, ripgrep to search, push to a branch. Cheapest. **Risk:** every
session re-derives frontmatter by hand — exactly the silent-corruption class `fm-emit.py` was
built to prevent (a bare `: ` or `#` in a title breaks the `---` block).

### Option 2 — A dedicated cloud skill (recommended)
A new skill in this repo (e.g. `vault-cloud`) that owns the whole cloud lifecycle:
- **resolve + clone** the vault repo (via `add_repo`), expose `OBSIDIAN_VAULT_PATH`;
- **compliant-note writer** — emits resolved frontmatter, validates `type`/`area`/`project`
  against `_meta/vocabulary.md`, quotes scalars (the `fm-emit.py` discipline, ported);
- **search** — a ripgrep operation over frontmatter + body, with the QMD-unavailable caveat
  surfaced explicitly;
- **safe commit/push** — pull-first, isolation per the decision below, never touches `_meta/`
  or reorganizes (per the contract).

Self-contained, testable, lands entirely in this repo, and directly answers "write compliant
notes + search from the cloud." Build it behind the **same env contract** the local skills use
(`OBSIDIAN_VAULT_PATH` etc.) so it can later become the git-backed backend of Option 3 with no
rework.

### Option 3 — Make the existing skills cloud-aware (host abstraction)
Give the `obsidian-notes` host contract a **git-backed backend**: a cloud `host-config` variant
that sets `OBSIDIAN_VAULT_PATH` to a clone and points `OBSIDIAN_CLI` at a shim reimplementing
`create`/`read`/`append`/`property:set`/`search` as file+git operations. Then `compound`,
`kb-*`, `lessons-learned`, `operator-interview` all "just work" from cloud with no per-skill
change. **Highest leverage**, but the `obsidian-notes` skill lives on the Mac, not in this repo
— so this is cross-repo work, and faithfully reproducing the CLI verbs is the most effort/risk.
Best done *after* Option 2 proves the git-backed primitives.

## Recommendation

Build **Option 2** now, designed behind the local skills' env contract so it upgrades into
Option 3's backend later. Fold Option 1 in by *referencing* the vault's `_meta/` contract as the
single source of truth rather than duplicating the vocabulary here (it drifts — the live vault
already has `project: Job Search` where `vocabulary.md` says `job-search`; the vault's files
win).

## Open decisions (operator)

1. **Search fidelity.** Accept lexical-only (ripgrep) cloud search, or invest in cloud-side
   embeddings so semantic retrieval works from the cloud too? (An existing similarity-search
   project could seed this.) **Resolved:** start with grep; revisit semantic later after
   analysis, without committing to a technology yet.
2. **Write isolation.** How should cloud writes land so they don't race the local Obsidian app?
   **Resolved: (a) dedicated branch** `cloud/<date>-<topic>`, operator/local merges — safest,
   keeps `main` clean. (Considered and not chosen: (b) a `raw/`-style cloud-inbox folder on
   `main`; (c) straight to `main`, pull-first.)

## Constraints to preserve

- **Billing (KB SPEC v2).** `/kb-compile` and `/kb-lint` are interactive-only (subscription
  pool) — never cron/`claude -p`/Agent SDK. Interactive cloud sessions are fine; an *automated*
  cloud path must not reopen this.
- **Off-limits subtrees.** `kb_core.OFF_LIMITS` = `DevOps Documentation/`, `Confluence/`; plus
  the contract's "never write `_meta/`, never reorganize." The cloud writer inherits all of it.
