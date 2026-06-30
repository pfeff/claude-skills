---
name: operator-interview
description: "Interview an operator to elicit a buildable specification, then write it as a signed-off spec note in the host's Obsidian vault. Runs a hybrid funnel — context-free open questions, AskUserQuestion scoping batches with recommended defaults, gap probes, a bounded clarification gate, playback, and explicit sign-off. Build and dispatch are gated on frontmatter status: signed-off. Use when the operator invokes /operator-interview <topic> or needs a spec elicited before planning or building."
argument-hint: "<topic>"
allowed-tools:
  - Read
  - Bash
  - AskUserQuestion
version: 1.0.0
---

# Operator Interview

Elicits a specification from a human operator and writes it as a `type=spec` note in
the host's Obsidian vault. The interview applies the shared doctrine — question
taxonomy, ask-vs-default-by-reversibility, adaptive depth, stop conditions, and the
sign-off protocol — and is a thin executor of it.

This skill **separates what/why from how**: it produces a spec (problem, decisions,
requirements, acceptance criteria), not a plan. Planning is downstream
(`planning-workflow`) over a `signed-off` spec.

## Doctrine

The interview rules live in one place — load them at interview time, do not inline:

```
Read(file_path: "${CLAUDE_PLUGIN_ROOT}/skills/operator-interview-doctrine/SKILL.md")
```

If you find yourself about to add an interview rule here, add it to the doctrine
instead.

## Invocation

```
/operator-interview <topic>
```

`<topic>` seeds the interview subject. If blank, the first context-free question
elicits the subject.

## Execution

When this skill is invoked:

**Step 1** — Load the doctrine (above) and the run operation:

```
Read(file_path: "${CLAUDE_PLUGIN_ROOT}/skills/operator-interview/operations/run-interview.md")
```

**Step 2** — Execute the interview per `operations/run-interview.md`, applying the
doctrine throughout.

**Step 3** — Report the created spec note path and its final `status`.

## Operations

### Run Interview (Default)

**File**: `operations/run-interview.md`
**When**: Operator invokes `/operator-interview <topic>`.

**Quick summary**: Ask the context-free questions as prose; run the funnel via
AskUserQuestion scoping batches (each option carries a recommended default); probe
gaps and mark unknowns `[NEEDS CLARIFICATION]`; run the bounded clarification gate
(cap ~5, writing each answer back before asking the next); stop at ~70% / saturation;
play the spec back; obtain explicit sign-off; write the spec note via the
`obsidian-notes` skill and promote `status` to `signed-off`.

## Output

Creates a spec note at:

```
<vault>/Notes/<YYYY>/<MM>/<YYYY-MM-DD>-<slug>.md
```

`<vault>` is resolved by the `obsidian-notes` skill from the host config. Frontmatter
carries note type/tag `spec`, `status` (`draft` → `signed-off`), `signed_off`, and
`supersedes` (when applicable). Build and dispatch consumers gate on `status:
signed-off`.

## Integration Points

- **Doctrine**: `operator-interview-doctrine` skill — the single home for the
  question taxonomy, ask-vs-default rule, adaptive-depth rubric, stop conditions,
  AskUserQuestion batch rules, spec-note schema, and sign-off protocol.
- **Obsidian-notes skill**: `~/.claude/skills/obsidian-notes/SKILL.md` — CLI surface
  (`create`, `property:set`, `append`) used for the spec-note write, plus the
  non-blocking failure contract.
- **Host config**: `~/.claude/hosts/<hostname>.md` `## Obsidian` section — vault path,
  CLI binary.
- **Downstream**: `planning-workflow` skill consumes a `signed-off` spec to produce a
  plan (how).

## See Also

- `operator-interview-doctrine` skill — the doctrine this skill executes.
- `obsidian-notes` skill — CLI surface for the spec-note write.
- `planning-workflow` skill — downstream planning over a signed-off spec.
