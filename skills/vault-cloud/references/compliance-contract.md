# Cloud compliance contract

What makes a cloud-written note "compliant," and why the rules live in the vault rather than
here.

## The vault owns the contract

The vault ships two machine-readable files that define compliance:

- **`_meta/agent-contract.md`** — the rules: notes go at `YYYY/MM/YYYY-MM-DD-slug.md` (slug
  lowercase-hyphenated, 2–5 words); don't invent `type`/`area`/`project` values without approval;
  new topical tags are fine; don't move/rename/reorganize existing notes; don't create or modify
  `_meta/`; don't create folders outside `YYYY/MM/` and `_attachments/`.
- **`_meta/vocabulary.md`** — the canonical field values: `type` (required, single-value),
  `area`/`project`/`status` (optional, single-value), `tags` (optional, multi-value, freeform).

**These live files are the source of truth, read fresh every run.** `vault_compliance.parse_vocabulary`
parses `_meta/vocabulary.md` from the clone rather than hardcoding values in this repo, for one
concrete reason: the vocabulary drifts. At the time of writing, the live vault already carries
`project: Job Search` (title case, spaced) on real notes where `vocabulary.md` documents
`job-search` (kebab). Hardcoding either would be wrong somewhere. The vault's files win; this
skill tracks them.

## What the cloud path must reproduce that the local CLI did for free

On the Mac, the `obsidian` CLI + Templater + property registry handled these. In the cloud they
are this skill's responsibility:

| Local mechanism | Cloud equivalent |
|---|---|
| Templater resolves `<% tp.date.now() %>` | Emit a **resolved** `date: YYYY-MM-DD` computed at write time |
| Property registry keeps frontmatter well-formed | `emit_frontmatter` quotes every risky scalar (`: `, `#`, `[`, leading `@`, bool/number lookalikes) — the local `fm-emit.py` discipline |
| CLI rejects unknown properties | `validate_frontmatter` checks `type`/`area`/`project`/`status` against the parsed vocabulary |
| `obsidian create path=…` enforces the path scheme | `note_path` builds `YYYY/MM/YYYY-MM-DD-slug.md` and rejects a non-ISO date |

## What is deliberately *not* reproduced

- **QMD/semantic search.** The embeddings and `.obsidian` config are gitignored — cloud search
  is lexical. Not a compliance issue, but a capability gap called out in `operations/search.md`
  and `docs/obsidian-vault-cloud-access.md`.
- **Link/backlink graph maintenance, MOC routing, Dataview/Bases views.** A cloud note can
  include `[[wikilinks]]` in its body and frontmatter (they're just text), but this skill does
  not rebuild indexes or MOCs — that happens when the note reaches the live vault. Keep cloud
  notes self-contained; leave graph curation to the local side.

## Relationship to the local writers

`compound` and `kb-capture` write the same note *shape* from the Mac via the `obsidian-notes`
CLI. This skill is their cloud-only mirror: same schema, same vocabulary, different transport
(git instead of the CLI) and different landing (a `cloud/*` branch instead of the live vault).
If the vault schema changes, both paths inherit it from `_meta/` — neither should be updated by
editing a hardcoded copy.
