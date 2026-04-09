# Audit Operation

**When**: User wants to analyze existing documentation against Diataxis categories.

## Purpose

Scans existing documentation, categorizes each document by Diataxis type, identifies misclassified or mixed-type documents, and reports gaps.

## Execution

### Step 1: Find Documentation

Scan for documentation files:

```
Glob(pattern: "**/*.md", path: "docs/")
Glob(pattern: "**/*.md", path: "doc/")
Glob(pattern: "README.md")
Glob(pattern: "**/README.md")
```

Also check common documentation locations:
- `docs/`
- `doc/`
- `documentation/`
- Wiki files if present

### Step 2: Analyze Each Document

For each markdown file found, read and classify:

```
Read(file_path: "<doc_path>")
```

**Classification criteria**:

| Type | Signals |
|------|---------|
| **Tutorial** | "learn", "build", step-by-step for beginners, hands-on exercises, "by the end you will" |
| **How-to** | "how to", problem-solving, task-focused, numbered steps, "to accomplish X" |
| **Reference** | API docs, tables of parameters, technical specifications, "returns", "parameters" |
| **Explanation** | "why", conceptual discussion, "background", architecture decisions, comparisons |
| **Mixed** | Multiple types present in one document |
| **Uncategorized** | Doesn't fit clearly (changelog, contributing guide, etc.) |

### Step 3: Detect Quality Issues

For each document, check for:

**Type violations**:

| Issue | Detection | Severity |
|-------|-----------|----------|
| Tutorial with choices | "you can also", "alternatively" | Medium |
| Tutorial missing steps | No numbered/ordered actions | High |
| How-to teaching concepts | Long explanatory paragraphs | Medium |
| How-to multiple problems | Multiple "how to" headings | High |
| Reference with instructions | "first do X, then Y" | Medium |
| Reference inconsistent format | Different structure than peers | Low |
| Explanation too abstract | No concrete examples | Low |
| Mixed document | Multiple types in one file | High |

**Structural issues**:

| Issue | Detection |
|-------|-----------|
| Missing index | No README in docs/ |
| Orphaned docs | Docs not linked from anywhere |
| Dead links | Links to non-existent files |
| Duplicate content | Similar content in multiple places |

### Step 4: Generate Coverage Matrix

Create a matrix showing what documentation exists:

```
Documentation Coverage Matrix
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Component/Feature | Tutorial | How-to | Reference | Explanation
------------------|----------|--------|-----------|-------------
Authentication    |    ✓     |   ✓    |     ✓     |     ○
API               |    ○     |   ✓    |     ✓     |     ○
Configuration     |    ○     |   ○    |     ✓     |     ○
Deployment        |    ✓     |   ✓    |     ○     |     ○

✓ = exists  ○ = missing  △ = partial/needs work
```

### Step 5: Identify High-Priority Gaps

Prioritize missing documentation:

**Critical** (user-facing, high-traffic):
- Getting started tutorial
- Common task how-tos
- API reference

**High** (frequently needed):
- Configuration reference
- Troubleshooting how-tos
- Architecture explanation

**Medium** (nice to have):
- Advanced tutorials
- Edge case how-tos
- Historical context

### Step 6: Generate Report

**Summary**:

```
Documentation Audit Report
==========================

Scanned: [N] documents
Classified:
  - Tutorials:    [N] (target directory: docs/tutorials/)
  - How-to:       [N] (target directory: docs/how-to/)
  - Reference:    [N] (target directory: docs/reference/)
  - Explanation:  [N] (target directory: docs/explanation/)
  - Mixed:        [N] (need splitting)
  - Uncategorized:[N] (changelog, contributing, etc.)

Structure: [Diataxis structure present / Not present]
```

**Issues Found**:

```
Issues (by severity)
--------------------

HIGH:
- [filename]: Mixed types (tutorial + reference) - recommend splitting
- [filename]: How-to guide covers multiple unrelated tasks

MEDIUM:
- [filename]: Tutorial offers choices instead of guiding
- [filename]: Reference includes instructional content

LOW:
- [filename]: Inconsistent heading format
```

**Recommendations**:

```
Recommended Actions
-------------------

1. [HIGH] Split docs/setup.md into:
   - docs/tutorials/getting-started.md (tutorial content)
   - docs/reference/configuration.md (reference content)

2. [HIGH] Create missing docs:
   - docs/tutorials/first-project.md (no getting started tutorial)
   - docs/reference/api.md (API undocumented)

3. [MEDIUM] Move docs/why-we-chose-x.md to docs/explanation/

4. [LOW] Standardize reference doc formatting
```

### Step 7: Offer Migration

If Diataxis structure doesn't exist:

```
Would you like me to:

1. Create Diataxis directory structure
2. Move existing docs to appropriate directories
3. Create index (docs/README.md) linking all docs

Note: This will reorganize your docs/ folder. Existing links may need updating.
```

If user agrees:

1. Run scaffold operation
2. Move documents to categorized directories
3. Update any internal links
4. Create index with all documents linked

### Step 8: Export Options

Offer export formats:

```
Export audit report?

1. Markdown file (docs/AUDIT-REPORT.md)
2. GitHub issue (list of tasks)
3. Task list (for /claude-skills:task-workflow)
```

## Interactive Analysis

If user asks about a specific document:

```
Analyzing: docs/deployment.md

Type: How-to guide (task-oriented)
Location: Should be in docs/how-to/

Issues:
- Contains explanation section (lines 45-78) - consider moving to
  docs/explanation/deployment-architecture.md
- Missing troubleshooting section

Suggestions:
1. Extract explanation to separate doc
2. Add troubleshooting section
3. Rename to "how-to-deploy-to-production.md"
```
