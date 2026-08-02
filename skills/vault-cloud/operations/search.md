# Search Operation

Find notes in the vault from a cloud session. **Lexical only** — this is ripgrep over the
clone, not QMD hybrid search.

## The one caveat, stated up front

QMD's semantic retrieval (BM25 + vector + reranker + HyDE) needs the `.smart-env/` embeddings
and `.obsidian/` config, both of which are **gitignored and never leave the Mac**. From the
cloud you get lexical matching only. When you report results, say so once — e.g.
`[vault-cloud] lexical (ripgrep) search — semantic/QMD retrieval is not available from the cloud`
— so the operator knows a miss might be a vocabulary mismatch, not an absent note.

## Steps

1. **Confirm setup ran** — `OBSIDIAN_VAULT_PATH` is exported and points at a clone
   (`operations/setup.md`).

2. **Choose the search shape.** Prefer the dedicated `Grep` tool for interactive use; the CLI
   forms below are for scripted/compound queries. Exclude `.git` and (optionally) the large
   `Readwise/` plugin dump unless the query is about a captured source.

   - **Full-text (body + frontmatter):**
     ```bash
     rg -i --type md -g '!.git' "<query>" "$OBSIDIAN_VAULT_PATH"
     ```
   - **By frontmatter field** (e.g. all `reference` notes for the job search). Match your
     vault's *actual* value casing — the live vault carries project values like `Job Search`
     (spaced/title-case) even where `_meta/vocabulary.md` documents `job-search`; grep the note
     you know exists first to see the real spelling, or use a case-insensitive `-i`:
     ```bash
     rg -li --type md -U '(?s)^---.*\btype:\s*reference\b.*\bproject:\s*job.search\b.*?^---' \
        "$OBSIDIAN_VAULT_PATH"
     ```
     Simpler single-field forms are usually enough:
     ```bash
     rg -l --type md '^type:\s*reference' "$OBSIDIAN_VAULT_PATH"     # by type
     rg -l --type md '^\s*-\s*terraform\s*$' "$OBSIDIAN_VAULT_PATH"  # by a block-list tag
     rg -l --type md 'tags:\s*\[[^]]*\bai\b' "$OBSIDIAN_VAULT_PATH"  # by a flow-list tag
     ```
   - **Recency:** notes are dated in their path, so sort by path for "latest":
     ```bash
     rg -l --type md 'project:\s*autoresearch' "$OBSIDIAN_VAULT_PATH" | sort | tail -10
     ```

3. **Rank and read.** ripgrep has no relevance score; rank by your own judgment (title match >
   frontmatter match > body match; more recent path > older). Read the top few with `Read`
   before answering — do not answer from filenames alone.

4. **Report** the matches as `path — one-line why-it-matched`, with the lexical-only caveat from
   the top. If nothing matched, suggest a broader/synonym query rather than concluding the note
   doesn't exist (lexical search is synonym-blind — the exact thing semantic search would have
   caught).

## Notes

- The vault has ~1,900 notes; `Readwise/` alone is ~1,200 verbatim source dumps. Bound noisy
  queries with `-g '!Readwise/**'` unless you're searching captured highlights.
- This operation is read-only. It never writes and never needs push access.
