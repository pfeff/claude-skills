---
name: compound
description: "Document a solved problem as a searchable solution note in the tcetra Obsidian vault. Writes type: solution notes with structured frontmatter so QMD hybrid search can route future agents to the fix."
argument-hint: "[short problem description or blank for interactive]"
allowed-tools:
  - Read
  - Bash
  - AskUserQuestion
version: 0.2.0
---

# Compound Skill

Captures a single solved problem as a dated note in the tcetra Obsidian vault (`type: solution`). Fast and focused — not a retrospective. Use `/claude-skills:lessons-learned` for session-level retrospectives.

## Core Concepts

**Single-problem focus**: Unlike `/claude-skills:lessons-learned` (session retrospective), `/claude-skills:compound` documents one solved problem at a time. Lightweight, focused, fast.

**QMD-first discoverability**: Notes are written to the tcetra vault and indexed by QMD's hybrid BM25 + vector + reranker pipeline. Retrieval entry point: `qmd query "<intent>" -c tcetra`. Post-filter with `tags: [solution]` or `type: solution` to scope to compound notes. `related:` wiki-links and `keywords:` frontmatter surface note-graph routing.

**Schema**: Frontmatter contract is defined in DESIGN.md of the compound-obsidian task workspace and pre-filled by the vault's `Templates/Solution.md`. Fields: `type`, `date`, `problem_type`, `severity`, `module`, `repo`, `project`, `tags`, `keywords`, `related`.

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

**Step 3**: Report the vault path and confirm QMD index was refreshed

## Operations

### Document Solution (Default)

**File**: `operations/document-solution.md`
**When**: User invokes `/claude-skills:compound` to capture a solved problem

**Quick summary**: Gather problem context, generate frontmatter, write to vault via Obsidian CLI, run `qmd update`.

## Output

Creates a solution note at:
```
Notes/YYYY/MM/YYYY-MM-DD-<slug>.md
```
in the tcetra Obsidian vault (`/mnt/c/Users/mpfefferle/Documents/Obsidian/tcetra`). Vault content is not committed to a git repo.

## Integration Points

- **Vault template**: `Templates/Solution.md` — pre-fills `type: solution`, `date`, and body skeleton
- **obsidian-notes skill**: Write path — Obsidian CLI create/property:set/append recipe
- **QMD**: `qmd update` after write; `qmd query "<intent>" -c tcetra` for retrieval
- **lessons-learned**: For session retrospectives — the two skills are complementary, not overlapping

## Retrieval (Finding Past Solutions)

**Primary**: `qmd query "<natural-language intent>" -c tcetra`

Returns top-3 results by default via hybrid BM25 + vector + reranker with HyDE expansion. The `-c tcetra` flag is host-specific (TCETRA host); for portability, consult `~/.claude/hosts/TCETRA.md` for the collection name, binary path, and vault directory.

**Query phrasing tip**: avoid "obsidian" as a term in queries — HyDE expands it toward the gemstone rather than the app, degrading results. Phrase queries around the problem domain: `cli property set silent failure` rather than `obsidian cli property set issue`.

**Filter to solution notes**: QMD has no native frontmatter filter. Post-filter results by inspecting the returned note's frontmatter for `type: solution`, or grep the returned paths:

```bash
qmd query "<intent>" -c tcetra | grep -l 'type: solution' 2>/dev/null
```

Alternatively, search by `solution` tag in the frontmatter of returned paths:
```bash
for path in $(qmd query "<intent>" -c tcetra --format paths); do
  grep -q 'tags:.*solution' "$path" && echo "$path"
done
```

**Keep the index current**: `qmd update` runs after every `/compound` write (Step 8 of the operation). `init-workspace` also runs `qmd update` at workspace setup. Manual refresh: `qmd update` (incremental, fast no-op when nothing changed).

**Degraded fallback** (if QMD is unavailable): grep the vault for `type: solution` in frontmatter:
```bash
grep -rl 'type: solution' /mnt/c/Users/mpfefferle/Documents/Obsidian/tcetra/Notes/
```
Do not advertise this as the primary path — it skips semantic matching.

## See Also

- `/claude-skills:lessons-learned` — Session retrospective
- `/claude-skills:self-improvement` — Apply recommendations to skills
- `~/.claude/hosts/TCETRA.md` — QMD binary, collection, vault, and index paths
