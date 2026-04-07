---
name: obsidian-notes
description: Create and manage Obsidian notes using the official Obsidian CLI (v1.12+) and organizational conventions. Uses CLI for properties, tags, search, and link-safe operations. Creates machine-generated notes in the Generated/ folder with proper frontmatter formatting. Load this skill BEFORE writing any note to ensure correct filename format (YYYYMMDDHHmm-Title.md) and frontmatter conventions.
version: 2.0.0
---

# Obsidian Notes

Create machine generated notes in the designated `Generated/` folder in the Obsidian vault.
Read any existing notes from anywhere in the vault to assist with note creating and coding projects.

## Configuration

**Vault Paths by Hostname**:

| Hostname | Vault Path |
|----------|------------|
| mbp2018 | `/Users/matt/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obisian` |
| TCETRA* | `/mnt/c/Users/mpfefferle/Documents/Obsidian/tcetra` |

Use `hostname` command to determine which path to use.

## CLI Prerequisites

The Obsidian CLI (v1.12+) provides link-safe operations and native property management.

**Setup:**
1. Obsidian 1.12 or later required
2. Enable CLI: Settings > General > Command line interface > Register CLI
3. Obsidian must be running for CLI commands to work

**Key benefits:**
- `move` preserves internal links automatically
- `property:set` handles YAML frontmatter correctly
- `search` uses Obsidian's search engine
- `backlinks` and `orphans` for vault analysis

See `references/cli.md` for complete command reference.

## Proactive Loading

**Always load this skill before writing to Obsidian paths.** This ensures correct filename format and frontmatter conventions.

| Trigger | Action |
|---------|--------|
| Writing to `Obsidian/Generated/` | Load this skill first |
| Writing to vault path (e.g., `/mnt/c/.../Obsidian/tcetra/`) | Load this skill first |
| Creating symlink to Obsidian vault | Load this skill before writing notes |

**Key conventions to verify**:
- Filename: `YYYYMMDDHHmm-Title.md` (not task ID or arbitrary names)
- Required tag: `generated_note`
- Date/month as wikilinks: `"[[YYYY-MM-DD]]"`

## Note Types

### 1. Date-Based Work Notes

Date-based notes are provided by the user and are not generated.
The structure defined below is for reference when reading the notes.

**Purpose**: Document work completed on programming tasks, including architectural decisions, implementation details, and technical choices.

**Location**: `Notes/YYYY/MM/`

**File naming**: `DDHHmm-Title.md`

- DD: Day (01-31)
- HH: Hour (00-23)
- mm: Minute (00-59)
- Title: Descriptive title using hyphens

**Example**: `Notes/2025/09/161948-Hybrid-Semantic-Search-Algorithm.md`

**Frontmatter template**:

```yaml
---
tags:
  - [primary_topic]
  - [secondary_topic]
  - [technology/methodology]
  - [note_type]
date: "[[YYYY-MM-DD]]"
month: "[[YYYY-MM]]"
---
```

**Structure**:

```markdown
# [Title matching filename]

## Overview

[2-3 sentence summary of work completed, decisions made, or implementation approach]

## [Additional sections as needed]

- Technical details
- Architectural decisions
- Implementation notes
- Challenges and solutions
- References and links
```

**Key practices**:

- Use liberal wikilinks `[[keyword]]` to connect to keyword notes
- Link to related concepts, technologies, and methods
- These notes serve as source material for future permanent notes
- Tags should be snake_case and descriptive

### 2. Legacy Notes (Johnny Decimal System)

**Read-only**: JD notes are legacy and should not be created, extended, or modified.

**Location**: `M99 Personal Notes/`, `DevOps Documentation/`

**File naming**: `XX.YY Title.md` format (e.g., `10.05 Project Management.md`)

## Common Operations

### CLI Operations (Preferred)

Use CLI commands when Obsidian is running for link-safe operations:

**Search notes:**
```bash
obsidian search query="term"
obsidian search query="[tag:generated_note]"
obsidian search query="term" format=json
```

**Read note content:**
```bash
obsidian read file="Generated/202601160804-DO-351-Investigation"
```

**Manage properties:**
```bash
obsidian properties file="Note Name"
obsidian property:set name=status value=active file="Note"
obsidian property:set name=date value=2026-03-05 type=date file="Note"
```

**Tag operations:**
```bash
obsidian tags                    # List all tags
obsidian tags counts sort=count  # Tags sorted by frequency
obsidian tag name=generated_note verbose  # Tag info with file list
```

**Move notes (preserves links):**
```bash
obsidian move file="Note" to=Archive/
```

**Daily notes:**
```bash
obsidian daily                   # Open today's note
obsidian daily:append content="Text to add"
```

### Create Machine-generated Note

Use direct file write for full note content (CLI `create` has limited content support).

- Create notes in `Generated/` folder
- **Filename format**: `YYYYMMDDHHmm-Title.md`
  - Example: `202601160804-DO-351-Investigation.md`
  - Use current date/time when creating
  - Title should be descriptive using hyphens (no spaces in filename)
- Content of the note must reflect the instructions given by the user.
- Follow appropriate note type structure and frontmatter standards.
- Do not:
  - Editorialize
  - Create excessive, redundant, or irrelevant content
  - Create content that cannot be verified, is speculative, or justified by known facts.

**Frontmatter template**:

```yaml
---
tags:
  - generated_note
date: "[[YYYY-MM-DD]]"
month: "[[YYYY-MM]]"
keywords:
  - [relevant_keywords]
---
```

## Frontmatter Standards

### Tags vs Keywords

**Tags** (frontmatter `tags:` field):
- Metadata for filtering and categorization in Obsidian
- Used for search, queries, and graph filtering
- Controlled vocabulary to ensure consistency

**Keywords** (frontmatter `keywords:` field):
- Wikilinks to concept/topic notes: `"[[Keyword]]"`
- Create navigable connections in the vault
- Used only in machine-generated notes

**Wikilinks** (inline `[[term]]`):
- Semantic connections within note body
- Link to related concepts, technologies, people
- Create the knowledge graph

### Tag Categories

**Required Tags:**
| Note Type | Required Tag |
|-----------|--------------|
| Machine-generated | `generated_note` |
| Date-based work | `technical_note` |
| Permanent | `permanent_note` |
| Meeting | `meeting_note` |
| Literature | `literature_note` |
| Lessons learned | `lessons_learned` |

Tags are limited to note types listed above. Do not create new tags. Use keywords for topic-specific terms.

### Suggested Keywords

Use these as wikilink keywords in the `keywords:` frontmatter field (pick 1-3 relevant):
- **Domain**: `"[[Machine Learning]]"`, `"[[Software Architecture]]"`, `"[[Web Development]]"`, `"[[Data Science]]"`, `"[[Distributed Systems]]"`, `"[[Information Retrieval]]"`
- **Methodology**: `"[[Zettelkasten]]"`, `"[[Semantic Search]]"`, `"[[API Design]]"`, `"[[Testing Strategy]]"`
- **Technology**: `"[[Python]]"`, `"[[TypeScript]]"`, `"[[PostgreSQL]]"`, `"[[React]]"`, `"[[Docker]]"`, `"[[Terraform]]"`

### Date Links

- Always use wikilink format: `"[[YYYY-MM-DD]]"`
- Include month link: `"[[YYYY-MM]]"`
- Use quotes around date wikilinks in YAML

## Linking Strategy

- **Liberal linking**: Link generously to keyword and concept notes using `[[wikilinks]]`
- **Keywords as notes**: Topics, technologies, and methods become their own notes
- Use Obsidian wiki-link syntax for all cross-references

## File Organization

```
Vault/
├── Notes/YYYY/MM/
│   └── DDHHmm-Title.md (user-created, date-based work notes)
├── Generated/
│   └── YYYYMMDDHHmm-Title.md (machine-generated notes - write here)
├── DevOps Documentation/ (legacy JD system - read-only)
└── Keywords/ (keyword pages - read-only)
```

## Guidelines

- Use current date/time for generated note timestamps
- Maintain consistency in tag vocabulary (snake_case)
- Use descriptive, searchable titles
- Link generously to keywords using `[[wikilinks]]`

## CLI vs Direct File Operations

### Use CLI When:
- Searching notes (`search`)
- Managing properties/frontmatter (`property:set`)
- Moving/renaming files (preserves links)
- Checking backlinks, orphans, deadends
- Working with daily notes
- Querying tag usage (`tag name=x verbose`)

### Use Direct File Write When:
- Creating notes with full content
- Complex multi-line frontmatter
- Bulk batch operations
- Obsidian is not running

## Additional Resources

This skill includes supplementary reference files:

- **references/cli.md**: Complete Obsidian CLI command reference
- **references/templates.md**: Complete note templates and concrete examples
- **references/johnny_decimal.md**: Detailed guide for Johnny Decimal system integration
- **scripts/note_helper.py**: Utility for generating timestamps and filenames
