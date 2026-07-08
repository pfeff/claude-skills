---
name: kb-lessons-bridge
description: Bridges reading-derived workflow insights into the self-improvement loop. Reads a kb-compile output note (project:knowledge-base, type:reference/zettel) or a Knowledge Intake synthesis note's "## Workflow implications" / "## Candidate actions" sections, filters for process/workflow-relevant insights (discarding general domain knowledge), and emits them as REC-ID blocks in the exact schema self-improvement already scans — written to a Generated/*Lesson*.md note so `/claude-skills:self-improvement` picks them up unchanged. Use when a reading note surfaces "we should change how we work" insights that would otherwise dead-end at operator grooming, or when the user says "bridge this reading to lessons-learned" / "turn this KB note into RECs" / "route this Workflow Implications section into self-improvement."
allowed-tools:
  - Read
  - Write
  - Grep
  - Glob
  - Bash
  - AskUserQuestion
version: 1.0.0
---

# kb-lessons-bridge — reading → REC bridge

## The gap this closes

Two loops exist and don't talk to each other:

- **Reading → knowledge**: `kb-capture → kb-compile` turns highlighted Readwise sources into
  vault notes (`type: reference` / `type: zettel`, `project: knowledge-base`). CoS's Knowledge
  Intake mode also writes synthesis notes with `## Workflow implications` and
  `## Candidate actions` sections.
- **Experience → process improvement**: `lessons-learned → self-improvement → skillify`. But
  `self-improvement`'s *only* input is lessons-learned documents — it globs
  `Generated/*Lesson*.md` and regex-scans for `#### REC-\d+:` blocks. It never looks at KB notes.

Reading-derived workflow implications currently dead-end at operator grooming. This skill is
the missing pipe: it does not reimplement `lessons-learned`'s Five-Whys discussion or
`self-improvement`'s scan/analyze/apply cycle — it only produces a **drop-in** lessons-learned
note so those two skills work on reading-derived insight exactly as they already work on
session-derived insight.

## Trigger

**Standalone / explicit invocation only.** This skill is never auto-wired to the end of
`kb-compile` or CoS Knowledge Intake — it runs only when explicitly invoked (natural-language
request or a future `/kb-lessons-bridge` command). Chaining it automatically would remove the
confirm-before-write gate's meaning (see Steps 4) and is out of scope for this skill.

## Schema this must match (verified against source, not assumed)

Read directly from `self-improvement/operations/scan-recommendations.md` (Step 2 extraction
regex) and `lessons-learned/operations/single-session-analysis.md` (body template):

- **Discovery glob**: `ls -1t "$OBSIDIAN_VAULT_PATH"/Generated/*Lesson*.md` — the output
  filename **must contain the literal substring `Lesson`**.
- **REC block regex** (`self-improvement` extracts on this exact pattern):
  ```
  #### REC-(\d+): (.+)
  **Category**: (.+)
  **Effort**: (.+)
  **Impact**: (.+)
  ```
  followed by a `**Target**:` line, free-text description, a `**Implementation**:` line, and a
  `---` separator before the next REC. Category must be one of `Workflow | Commands |
  Utilities | Skills` to survive `self-improvement`'s Phase-3 category filter (Documentation /
  User Practices / External Tools get excluded there).
- **Frontmatter** (per `lessons-learned`'s Phase 4): tags **must** include both
  `generated_note` and `lessons_learned`; `keywords:` as capitalized, space-separated
  wikilinks. Do not invent new tags — pull the vocabulary from the `obsidian-notes` skill.
- **Filename**: `Generated/YYYYMMDDHHmm-Lessons Learned - {topic}.md` — same pattern
  `lessons-learned` itself uses.
- **REC numbering is per-note, not global** — `self-improvement` scans `#### REC-\d+:` within
  each lessons file independently, so a bridge-generated note numbering `REC-001, REC-002, ...`
  from 1 in its own file is safe even though other lessons-learned notes also start at
  `REC-001`. **Do not add a bridge-specific REC-ID prefix** (e.g. `REC-R1`) — that would break
  the `REC-(\d+)` capture group other tooling relies on. Provenance instead rides the
  **`**Source**:`** line (per-REC) plus a `[[Reading Derived]]` frontmatter keyword
  (note-level) — both additive, neither touches the regex.

Nothing above is reimplemented logic — it is the literal contract the two existing skills
already speak. This skill's only job is to produce a note that satisfies it, sourced from
reading instead of a live session.

## Inputs

One or both of, discovered by **Globbing the vault directly** (never the plugin tree — this
skill has no source data of its own, only the vault does):

1. **A kb-compile output note** — `Notes/YYYY/MM/*.md` with `type: reference` or
   `type: zettel` and `project: knowledge-base` frontmatter (written by `kb-compile`).
2. **A Knowledge Intake synthesis note** — a vault `Reference` note (`type: reference`,
   `area: workflow`) containing `## Workflow implications` and `## Candidate actions` sections.
   CoS's Knowledge Intake mode writes these; the CoS skill itself lives at
   `~/.claude/skills/chief-of-staff`, outside the `claude-skills` plugin tree, so this skill
   never reads CoS's definition — only the vault notes it produces.

If invoked with no argument, ask which note(s) to bridge (or accept a path/title directly).

## Eligibility filter — process/workflow-relevant only

An insight qualifies for a REC **only if** it proposes a change to how Claude/the operator's
system works — mirroring `lessons-learned`'s own Phase 3 INCLUDE/EXCLUDE test:

**INCLUDE** — insight suggests:
- A new or changed skill operation, slash command, or agent behavior
- A workflow/process change (e.g., "always do X before Y")
- A tool-usage pattern or permission-whitelist candidate
- A documentation gap in an existing skill

**EXCLUDE** — insight is:
- General domain knowledge with no workflow-change implication (this is what `kb-compile`
  already captured correctly as a `reference`/`zettel` note — leave it there)
- A one-off fact about the subject matter, not about how work gets done
- Too vague to name a target skill/command/file even approximately

When in doubt, exclude — a missed REC costs nothing (the source note still exists and can be
re-bridged later); a spurious REC pollutes `self-improvement`'s queue.

## Steps

1. **Read the source note(s)**. For a kb-compile note, read the full body (reference/zettel
   notes are short). For a Knowledge Intake note, read only `## Workflow implications` and
   `## Candidate actions` — ignore the rest of the synthesis.
2. **Extract candidate insights** — one per distinct suggested change. Apply the eligibility
   filter above; drop anything that's general knowledge.
3. **For each surviving insight, draft a REC block**:
   - `#### REC-{next-number}: {short title}` (numbered from 1 within this note — see the
     per-note numbering note above; no bridge-specific prefix)
   - `**Category**:` one of `Workflow | Commands | Utilities | Skills`
   - `**Effort**:` Quick / Medium / Complex (estimate)
   - `**Impact**:` HIGH / MEDIUM / LOW
   - `**Target**:` best-guess file path under the `claude-skills` repo (validate it exists per
     `lessons-learned`'s "Validate Target Paths" step — Glob for it; if it doesn't exist, either
     find the nearest real target or note "no existing target — would need a new skill")
   - Body: the insight, framed as a workflow change (not raw domain knowledge)
   - `**Implementation**:` what a PR to `claude-skills` would need to do
   - **`**Source**:` line** (additive — does not break the regex above, which doesn't require
     the block to end after `Implementation`): `[[{source note title}]]` plus the kb-compile
     `source_key` if the origin is a KB note. This is how traceability back to the original
     reading survives even after the insight is folded into an aggregated bridge note.
4. **Show the drafted REC(s) and ask for confirmation** before writing — same safety gate
   `lessons-learned` and `skillify` both use. Let the user cut, merge, or edit any REC.
5. **Write the note** once confirmed. **One bridge note per run**, even when multiple source
   notes were read in step 1 — every REC in the note carries its own `**Source**:` line, so
   batching multiple sources into a single note never loses per-REC traceability.
   - Path: `Generated/YYYYMMDDHHmm-Lessons Learned - Reading Bridge - {topic}.md`
   - Frontmatter: `tags: generated_note, lessons_learned`; `keywords:` wikilinks including
     `[[Lessons Learned]]`, `[[Reading Derived]]` (marks the note's provenance at a glance),
     plus the source topic(s); consider adding `sources:` (list of kb `source_key`s) as an
     extra field for provenance — harmless extra frontmatter, ignored by `self-improvement`'s
     scan.
   - Body: minimal — a one-line "Source" section pointing at the originating note(s), then
     `## Recommendations` with the REC blocks from step 3. Skip Problems/Five-Whys/Positive
     Patterns sections entirely — there's no session to retrospect on, only insight to route.
   - Use the `obsidian-notes` skill's CLI recipes exactly as `lessons-learned` Phase 4 does
     (`property:set` for frontmatter, `append` for body). Fall back to
     `docs/lessons-learned/` if the vault helper is unavailable.
6. **Report** the note path and REC count. Do not run `/claude-skills:self-improvement`
   automatically — that stays a separate, explicit invocation.

## What this is NOT

- Not a reimplementation of `lessons-learned`'s Five Whys or Phase 1-3 discussion — there is no
  live session to retrospect on, only a written note to route.
- Not a reimplementation of `self-improvement`'s scan/analyze/propose/apply cycle — this skill
  stops once the REC note is written.
- Not a bypass of the confirm-before-write step.
- Not a way to sneak general domain knowledge into the improvement queue — that's what
  `kb-compile`'s `reference`/`zettel` notes are for; leave it there.
- Not auto-chained to `kb-compile` or Knowledge Intake — see Trigger above.

## See also

- `kb-compile` — produces one of this skill's two input shapes
- `lessons-learned` — owns the REC-ID schema and Obsidian note conventions this skill mirrors
- `self-improvement` — the consumer; scans `Generated/*Lesson*.md` for `#### REC-\d+:` blocks
- `obsidian-notes` — frontmatter/tag vocabulary and CLI recipes used for the actual write
