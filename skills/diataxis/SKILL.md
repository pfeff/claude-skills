---
name: diataxis
description: Project documentation using the Diataxis methodology. Scaffold docs structure, write documentation by type, or audit existing docs. Use when the user wants to create, organize, or improve documentation.
argument-hint: "[scaffold|write|audit] [optional context]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - AskUserQuestion
  - Task
version: 0.1.0
auto-load-triggers:
  - "write documentation"
  - "create docs"
  - "document this"
  - "add a tutorial"
  - "write a how-to"
  - "reference docs"
  - "README"
  - "docs folder"
  - "organize documentation"
---

# Diataxis Documentation Skill

Implements the [Diataxis](https://diataxis.fr/) documentation framework (also known as Divio) for organizing and writing project documentation.

## Core Concepts

The Diataxis framework categorizes documentation into four types based on two axes:

|                    | **Learning** | **Working** |
|--------------------|--------------|-------------|
| **Practical**      | Tutorials    | How-to guides |
| **Theoretical**    | Explanation  | Reference |

### The Four Types

1. **Tutorials** - Learning-oriented, hands-on lessons
   - Goal: Help a beginner achieve basic competence
   - Form: A lesson with exercises
   - Analogy: Teaching a child to cook

2. **How-to Guides** - Task-oriented, problem-solving steps
   - Goal: Show how to solve a specific problem
   - Form: A series of steps
   - Analogy: A recipe in a cookbook

3. **Reference** - Information-oriented, technical descriptions
   - Goal: Describe the machinery
   - Form: Dry, accurate description
   - Analogy: Encyclopedia article

4. **Explanation** - Understanding-oriented, conceptual discussions
   - Goal: Illuminate a topic
   - Form: Discursive explanation
   - Analogy: An article on culinary history

## Invocation

```
/claude-skills:diataxis                    # Interactive — asks what you want to do
/claude-skills:diataxis scaffold           # Create docs folder structure
/claude-skills:diataxis write              # Write a new document (interactive)
/claude-skills:diataxis write tutorial     # Write a tutorial
/claude-skills:diataxis audit              # Audit existing docs
```

## Execution

When this skill is invoked:

**Step 1**: Parse operation from `$ARGUMENTS`

| Argument pattern | Operation |
|-----------------|-----------|
| `scaffold` | Load `operations/scaffold.md` |
| `write [type]` | Load `operations/write.md` |
| `audit` | Load `operations/audit.md` |
| Empty or unclear | Ask user which operation |

**Step 2**: Load the appropriate operation file

```
Read(file_path: "${CLAUDE_PLUGIN_ROOT}/skills/diataxis/operations/<operation>.md")
```

**Step 3**: Execute the operation

**Step 4**: Report results

## Operations

### Scaffold

**File**: `operations/scaffold.md`
**When**: User wants to create a docs structure for a project

Creates the standard Diataxis directory structure with README templates.

### Write

**File**: `operations/write.md`
**When**: User wants to write new documentation

Guides through writing a document of the appropriate type with structure templates.

### Audit

**File**: `operations/audit.md`
**When**: User wants to analyze existing documentation

Scans existing docs and categorizes them, identifies gaps and misplacements.

## Directory Structure Created

```
docs/
├── README.md              # Documentation index
├── tutorials/
│   └── README.md          # Tutorial guidelines
├── how-to/
│   └── README.md          # How-to guidelines
├── reference/
│   └── README.md          # Reference guidelines
└── explanation/
    └── README.md          # Explanation guidelines
```

## References

- `references/framework.md` — Detailed Diataxis framework explanation
- `references/templates.md` — Templates for each documentation type
- `references/anti-patterns.md` — Common mistakes and how to avoid them

## Auto-Loading

This skill should be loaded proactively when the user:

- Asks to write, create, or add documentation
- Mentions tutorials, how-to guides, reference docs, or explanations
- Wants to organize or restructure existing docs
- Creates a new project and needs documentation structure
- Asks about documentation best practices
- Writes or edits files in a `docs/` directory

**Trigger phrases**:
- "write documentation", "create docs", "document this"
- "add a tutorial", "write a how-to guide"
- "reference documentation", "API docs"
- "organize the docs", "restructure documentation"
- "README", "docs folder", "documentation structure"

Load the skill early to ensure documentation follows Diataxis principles from the start.

## See Also

- [Diataxis Documentation](https://diataxis.fr/)
- `/claude-skills:compound` — Document solutions (pairs with how-to guides)
