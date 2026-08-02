# Write Note Operation

Record a **compliant** note into the vault from a cloud session and commit it to a dedicated
`cloud/<date>-<topic>` branch for the operator to merge. Never writes to `main`; never touches
`_meta/`.

## Prerequisites

`operations/setup.md` has run: `OBSIDIAN_VAULT_PATH` points at a clone, and
`_meta/agent-contract.md` + `_meta/vocabulary.md` are loaded. `VC=` below is the compliance
script:

```bash
VC="${CLAUDE_PLUGIN_ROOT}/skills/vault-cloud/scripts/vault_compliance.py"
```

## Steps

1. **Gather the note's fields.** From the request and conversation, determine:
   - `type` — **required**, one of `_meta/vocabulary.md`'s `type` values (`reference`, `zettel`,
     `decision`, `moc`, `spec`, `meeting`, `person`, `review`, `lesson-learned`,
     `session-journal`). Pick the closest existing type; do **not** invent one.
   - `title` — human title (becomes the `# H1` and the slug).
   - `area` / `project` / `status` — optional; if used, must be vocabulary values. `status`
     defaults to `active`.
   - `tags` — optional, freeform (new topical tags are fine).
   - `date` — resolved **now**, `YYYY-MM-DD`. There is no Templater here; compute it:
     `date=$(date +%Y-%m-%d)`.
   - `body` — the markdown body (below the `# H1`).

   Ask the operator only for what you genuinely can't infer (especially `type` when ambiguous).

2. **Build the frontmatter and validate — before writing.** Use the compliance script so
   quoting and vocabulary checks are mechanical, not hand-rolled:

   ```bash
   python3 - "$OBSIDIAN_VAULT_PATH" <<'PY'
   import sys, os, datetime
   sys.path.insert(0, os.path.join(os.environ["CLAUDE_PLUGIN_ROOT"], "skills/vault-cloud/scripts"))
   import vault_compliance as vc
   vault = sys.argv[1]
   vocab = vc.parse_vocabulary(open(f"{vault}/_meta/vocabulary.md").read())
   fields = {                          # <-- fill these in from step 1; illustrative values only
       "type": "reference",
       "area": "workflow",
       "project": "",
       "status": "active",
       "date": datetime.date.today().isoformat(),   # resolved now — never a frozen literal
       "tags": ["example"],
   }
   violations = vc.validate_frontmatter(fields, vocab)
   if violations:
       print("VIOLATIONS:", *violations, sep="\n  ")
       sys.exit(1)
   slug = vc.slugify("<title here>")
   path = vc.note_path(fields["date"], slug)
   print("PATH:", path)
   print(vc.emit_frontmatter(fields))
   PY
   ```

   - **Any violation → stop and fix** (usually an out-of-vocabulary `type`/`area`/`project`).
     The contract forbids inventing those values; resolve with the operator, don't force it.
   - Use the printed `PATH:` and frontmatter block for the write. (In practice you may call the
     script inline / via a small Python snippet rather than templating this heredoc — the point
     is: emit via `vault_compliance`, don't hand-write YAML, so a `: ` or `#` in the title can't
     silently break the `---` block.)

3. **Write the file** at `$OBSIDIAN_VAULT_PATH/<PATH>` with the emitted frontmatter, then a
   blank line, then `# <title>`, then the body. Create the `YYYY/MM/` directory if needed. This
   is the only write target — no other file, and never under `_meta/`, `DevOps Documentation/`,
   or `Confluence/`.

4. **Commit to a dedicated branch.** Isolate cloud writes from the local Obsidian app's working
   copy — branch off fresh `main`, never commit to `main` directly:

   ```bash
   cd "$OBSIDIAN_VAULT_PATH"
   git fetch origin main --quiet
   TOPIC="<short-kebab-topic>"                 # e.g. the slug, or the batch's theme
   BRANCH="cloud/$(date +%Y-%m-%d)-$TOPIC"
   git checkout -B "$BRANCH" origin/main
   git add "<PATH>"
   git commit -q -m "notes(cloud): <title>"
   ```

   Batching several notes in one session? Put them all on one `cloud/<date>-<topic>` branch with
   one commit each, rather than a branch per note.

5. **Push, with bounded retry.** Network is external; retry on failure with backoff
   (2s, 4s, 8s, 16s), up to 4 times:

   ```bash
   git push -u origin "$BRANCH"
   ```

   If push fails because the vault was added `read`-only, re-add with `access: "push"` (the
   `add_repo` tool) and retry.

6. **Report** to the operator: the note path, the branch name, and that it awaits their merge
   into `main` — e.g.
   `[vault-cloud] wrote 2026/08/2026-08-02-<slug>.md on branch cloud/2026-08-02-<topic>; merge into main when ready.`
   Offer to open a PR only if the operator asks.

## Compliance checklist (self-verify before reporting)

- [ ] `type` present and a vocabulary value; `area`/`project`/`status` are vocabulary values or absent.
- [ ] Frontmatter emitted via `vault_compliance.emit_frontmatter` (quoted scalars), not by hand.
- [ ] Path is `YYYY/MM/YYYY-MM-DD-<slug>.md` with a resolved date (no `<% … %>`).
- [ ] Wrote nothing under `_meta/`, `DevOps Documentation/`, or `Confluence/`; reorganized nothing.
- [ ] Landed on a `cloud/<date>-<topic>` branch, not `main`.
