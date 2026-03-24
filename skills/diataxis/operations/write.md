# Write Operation

**When**: User wants to write new documentation following Diataxis principles.

## Purpose

Guides the user through writing a document of the appropriate type, providing structure templates and enforcing type-specific guidelines.

## Execution

### Step 1: Determine Document Type

Parse `$ARGUMENTS` for document type:

| Argument | Type |
|----------|------|
| `tutorial` | Tutorial |
| `how-to`, `howto`, `guide` | How-to guide |
| `reference`, `ref` | Reference |
| `explanation`, `explain`, `concept` | Explanation |

**If no type specified**, ask:

```
What type of documentation are you writing?

1. Tutorial - Teaching a beginner through hands-on steps
2. How-to guide - Solving a specific problem
3. Reference - Describing technical details
4. Explanation - Explaining concepts and context
```

### Step 2: Gather Context

Ask for minimal required context based on type:

**Tutorial**:
- What will the reader build/learn?
- What prerequisites are needed?
- Target audience experience level?

**How-to Guide**:
- What problem does this solve?
- What's the end goal?

**Reference**:
- What component/API/feature?
- Does existing code need to be read?

**Explanation**:
- What concept or question?
- What's the scope?

### Step 3: Load Type-Specific Template

Read template guidance:

```
Read(file_path: "${CLAUDE_PLUGIN_ROOT}/skills/diataxis/references/templates.md")
```

### Step 4: Check for Existing Docs Structure

```
Glob(pattern: "docs/**/*.md")
```

If Diataxis structure exists, use appropriate directory. Otherwise, create it or use a flat docs/ folder.

### Step 5: Generate Document

Create the document with type-appropriate structure.

#### Tutorial Template

```markdown
# [Tutorial Title]: [What You'll Build]

Learn how to [outcome] by building [concrete thing].

## What You'll Learn

- [Skill 1]
- [Skill 2]
- [Skill 3]

## Prerequisites

- [Requirement 1]
- [Requirement 2]

## Step 1: [First Action]

[Brief context - one sentence max]

[Concrete instruction]

```[language]
[code to write/run]
```

[Expected result]

## Step 2: [Second Action]

[Continue pattern...]

## What You've Built

[Summary of accomplishment]

[Screenshot or output if applicable]

## Next Steps

- [Related tutorial]
- [How-to guide for common task]
- [Reference for deeper details]
```

#### How-to Guide Template

```markdown
# How to [Accomplish Task]

[One sentence describing what this guide helps you do]

## Prerequisites

- [What you need before starting]

## Steps

### 1. [First Step]

[Action to take]

```[language]
[command or code]
```

### 2. [Second Step]

[Continue pattern...]

## Verification

[How to confirm it worked]

## Troubleshooting

### [Common Issue 1]

[Solution]

### [Common Issue 2]

[Solution]

## See Also

- [Related how-to]
- [Reference docs]
```

#### Reference Template

```markdown
# [Component/API Name]

[One-line description]

## Overview

[Brief technical summary]

## [Section based on component type]

### [Item Name]

**Type**: `[type]`
**Default**: `[default value]`

[Description]

**Example**:

```[language]
[usage example]
```

## Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `param1` | `string` | Yes | [Description] |
| `param2` | `number` | No | [Description] |

## Return Value

[Type and description]

## Errors

| Code | Meaning |
|------|---------|
| `ERROR_1` | [Description] |

## See Also

- [Related reference]
- [Explanation of concept]
```

#### Explanation Template

```markdown
# [Concept/Topic]

[Opening question or statement that frames the discussion]

## Background

[Context - why this exists, historical perspective]

## [Main Concept]

[Core explanation]

### [Sub-topic 1]

[Detailed exploration]

### [Sub-topic 2]

[Detailed exploration]

## Alternatives Considered

[Other approaches and why this one was chosen]

## Implications

[What this means for users/developers]

## Further Reading

- [Related explanation]
- [External resource]
```

### Step 6: Determine File Location

1. Map type to directory:
   - Tutorial → `docs/tutorials/`
   - How-to → `docs/how-to/`
   - Reference → `docs/reference/`
   - Explanation → `docs/explanation/`

2. Generate filename from title (lowercase, hyphenated)

3. Write file

### Step 7: Validate Against Type Guidelines

After writing, check:

| Type | Check | Warning if violated |
|------|-------|---------------------|
| Tutorial | No decision points? | "Tutorials should guide, not offer choices" |
| Tutorial | Has concrete steps? | "Missing hands-on steps" |
| How-to | Single task focus? | "How-to guides should focus on one problem" |
| How-to | No teaching? | "Move explanations to Explanation docs" |
| Reference | No instructions? | "Reference should describe, not instruct" |
| Reference | Consistent format? | "Format should match other reference docs" |
| Explanation | Addresses why? | "Explanation should focus on understanding" |

### Step 8: Report Results

```
Created: docs/[type]/[filename].md

Type: [Type] (learning/working × practical/theoretical)
Guidelines followed: [checklist]

Consider linking from:
- docs/README.md
- Related [other type] docs
```

## Interactive Mode

If user provides partial content (e.g., "I want to document the authentication flow"):

1. Identify the most appropriate type
2. Ask clarifying questions to narrow down
3. Offer to structure existing notes into proper format
