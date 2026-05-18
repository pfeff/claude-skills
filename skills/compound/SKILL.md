---
name: compound
description: "Document a solved problem as a searchable solution note in the host's Obsidian vault. Captures a single fix with YAML frontmatter for QMD-based agent discovery; delegates the file write to the obsidian-notes skill."
argument-hint: "[short problem description or blank for interactive]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - AskUserQuestion
version: 0.2.0
---

# Compound Skill

Captures a solved problem as a `type=solution` note in the host's Obsidian vault, using the vault's `Solution` template. Notes are discovered by future agents via QMD hybrid search (BM25 + vector + reranker) over the vault.

## Core Concepts

**Single-problem focus**: Unlike `/claude-skills:lessons-learned` (session retrospective), `/claude-skills:compound` documents one solved problem at a time. Lightweight, focused, fast.

**Vault-resident**: Notes live in the Obsidian vault, not in any repository's `docs/`. The actual file write is delegated to the `obsidian-notes` skill (CLI-first); vault location is resolved per-host from `~/.claude/hosts/<hostname>.md`.

**Schema**: Solution notes use the vault's `Solution` template. Frontmatter fields, body sections, and the `type=solution` vocabulary are defined in `$OBSIDIAN_VAULT_PATH/Templates/Solution.md`.

## Invocation

```
/claude-skills:compound                          # Interactive — asks what you solved
/claude-skills:compound timeout in auth flow     # Pre-seeded with problem context
```

## Execution

When this skill is invoked:

**Step 1**: Load operation details

```
Read(file_path: "${CLAUDE_PLUGIN_ROOT}/skills/compound/operations/document-solution.md")
```

**Step 2**: Execute the operation interactively

**Step 3**: Report the created note path in the vault

## Operations

### Document Solution (Default)

**File**: `operations/document-solution.md`
**When**: User invokes `/claude-skills:compound` to capture a solved problem.

**Quick summary**: Gather problem context, generate frontmatter, write a `type=solution` note via the `obsidian-notes` skill using the vault's `Solution` template.

## Output

Creates a solution note at:

```
<vault>/Notes/<YYYY>/<MM>/<YYYY-MM-DD>-<slug>.md
```

`<vault>` is resolved by the `obsidian-notes` skill from the host config.

## Integration Points

- **Vault Solution template**: `<vault>/Templates/Solution.md` — frontmatter schema (`type`, `date`, `problem_type`, `severity`, `module`, `repo`, `project`, `tags`, `keywords`, `related`) and body sections (Problem, Symptoms, Root Cause, Solution, Prevention).
- **Obsidian-notes skill**: `~/.claude/skills/obsidian-notes/SKILL.md` — CLI surface (`create`, `property:set`, `append`) used for the write, plus the non-blocking failure contract.
- **Host config**: `~/.claude/hosts/<hostname>.md` `## Obsidian` section — vault path, CLI binary.
- **Retrieval**: QMD hybrid search over the vault — `skills/task-workflow/references/solution-search.md` defines the canonical query protocol used by `init-workspace`, `planning-workflow`, and other read-side callers.
- **Lessons-learned bridge**: Phase 3d of `/claude-skills:lessons-learned` may invoke `/claude-skills:compound` for problems with concrete, reusable fixes.

## See Also

- `/claude-skills:lessons-learned` — Session retrospective; bridges to `/claude-skills:compound` for concrete fixes.
- `/claude-skills:self-improvement` — Apply recommendations to skills.
- `obsidian-notes` skill — CLI surface for vault writes.
